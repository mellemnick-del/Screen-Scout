"""Screen Scout web server.

Run (from the backend folder):  uvicorn app.main:app --reload
Then open http://localhost:8000
"""

from __future__ import annotations

import json
import os
import sqlite3
import time
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .analyzer import AnalysisError, analyze
from .youtube import VideoError, extract_video_id, gather

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = Path(os.environ.get("SCOUT_DB", ROOT / "data" / "reviews.db"))
FRAMES = int(os.environ.get("SCOUT_FRAMES", "16"))
MAX_MINUTES = int(os.environ.get("SCOUT_MAX_MINUTES", "60"))
# Shared secret the iPhone app sends in the X-App-Token header. Set this in
# production so random people can't spend your Claude credits.
APP_TOKEN = os.environ.get("SCOUT_APP_TOKEN", "")


def require_token(x_app_token: str = Header(default="")):
    if APP_TOKEN and x_app_token != APP_TOKEN:
        raise HTTPException(401, "Not authorized.")

app = FastAPI(title="Screen Scout")
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")


def db() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        """CREATE TABLE IF NOT EXISTS reviews (
            video_id TEXT, child_age INTEGER, created REAL,
            video TEXT, report TEXT, PRIMARY KEY (video_id, child_age))"""
    )
    return conn


class ReviewRequest(BaseModel):
    url: str
    child_age: int | None = None
    refresh: bool = False


def _row_to_dict(row) -> dict:
    return {"video_id": row[0], "child_age": row[1], "created": row[2],
            "video": json.loads(row[3]), "report": json.loads(row[4])}


@app.get("/")
def index():
    return FileResponse(Path(__file__).parent / "static" / "index.html")


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/api/review", dependencies=[Depends(require_token)])
async def review(req: ReviewRequest):
    try:
        vid = extract_video_id(req.url)
    except VideoError as e:
        raise HTTPException(400, str(e))
    age = req.child_age or 0

    with db() as conn:
        row = conn.execute("SELECT * FROM reviews WHERE video_id=? AND child_age=?", (vid, age)).fetchone()
    if row and not req.refresh:
        return {**_row_to_dict(row), "cached": True}

    try:
        ev = await run_in_threadpool(gather, req.url, FRAMES, MAX_MINUTES)
        report = await run_in_threadpool(analyze, ev, req.child_age)
    except (VideoError, AnalysisError) as e:
        raise HTTPException(422, str(e))

    video = {
        "video_id": ev.video_id, "url": ev.url, "title": ev.title, "channel": ev.channel,
        "duration": ev.duration, "thumbnail_url": ev.thumbnail_url,
        "had_transcript": bool(ev.transcript), "frames_reviewed": len(ev.frames), "notes": ev.notes,
    }
    with db() as conn:
        conn.execute("INSERT OR REPLACE INTO reviews VALUES (?,?,?,?,?)",
                     (vid, age, time.time(), json.dumps(video), report.model_dump_json()))
    return {"video_id": vid, "child_age": age, "created": time.time(),
            "video": video, "report": report.model_dump(), "cached": False}


@app.get("/api/history", dependencies=[Depends(require_token)])
def history(limit: int = 50):
    with db() as conn:
        rows = conn.execute("SELECT * FROM reviews ORDER BY created DESC LIMIT ?", (limit,)).fetchall()
    return [_row_to_dict(r) for r in rows]


@app.delete("/api/history/{video_id}", dependencies=[Depends(require_token)])
def forget(video_id: str):
    with db() as conn:
        conn.execute("DELETE FROM reviews WHERE video_id=?", (video_id,))
    return {"ok": True}
