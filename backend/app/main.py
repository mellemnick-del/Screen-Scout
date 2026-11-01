"""Screen Scout API server.

Run (from the backend folder):  uvicorn app.main:app --host 0.0.0.0 --port 8000

Settings (environment variables):
  ANTHROPIC_API_KEY       Claude API key (required)
  SCOUT_APPLE_BUNDLE_ID   Must match the app's bundle identifier in Xcode
  SCOUT_MONTHLY_LIMIT     New reviews per family per month (default 50, 0 = unlimited)
  SCOUT_MAX_FAMILY_SIZE   People per family (default 6)
  SCOUT_SUPPORT_EMAIL     Shown on the /privacy and /support pages
  APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY_PATH
                          Optional. Lets account deletion revoke Apple sign-in (do before App Store)
"""

from __future__ import annotations

import json
import os
import time
import uuid

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from . import auth, families, pages
from .analyzer import AnalysisError, analyze
from .db import db
from .youtube import VideoError, extract_video_id, gather

FRAMES = int(os.environ.get("SCOUT_FRAMES", "16"))
MAX_MINUTES = int(os.environ.get("SCOUT_MAX_MINUTES", "60"))

app = FastAPI(title="Screen Scout")

OK = {"ok": True}


@app.get("/")
def root():
    return {"name": "Screen Scout", "ok": True}


@app.get("/health")
def health():
    return OK


@app.get("/privacy", response_class=HTMLResponse)
def privacy():
    return pages.privacy_policy()


@app.get("/support", response_class=HTMLResponse)
def support():
    return pages.support()


# ---------- Accounts ----------

class AppleSignIn(BaseModel):
    identity_token: str
    authorization_code: str | None = None
    nonce: str | None = None
    given_name: str | None = None
    family_name: str | None = None


@app.post("/api/auth/apple")
def sign_in_with_apple(body: AppleSignIn):
    claims = auth.verify_apple_token(body.identity_token, body.nonce)
    refresh_token = auth.exchange_code_for_refresh_token(body.authorization_code)
    apple_sub = claims["sub"]
    email = claims.get("email")
    # Apple only shares the name the very first time someone signs in.
    name = " ".join(p.strip() for p in (body.given_name, body.family_name) if p and p.strip()) or None

    with db() as conn:
        user = conn.execute("SELECT * FROM users WHERE apple_sub=?", (apple_sub,)).fetchone()
        if user is None:
            user_id = uuid.uuid4().hex
            conn.execute(
                "INSERT INTO users (id, apple_sub, email, name, created) VALUES (?,?,?,?,?)",
                (user_id, apple_sub, email, name, time.time()),
            )
            family_name = f"The {body.family_name.strip()} Family" if body.family_name and body.family_name.strip() else "My Family"
            families.create_family(conn, user_id, family_name)
        else:
            user_id = user["id"]
            if email and not user["email"]:
                conn.execute("UPDATE users SET email=? WHERE id=?", (email, user_id))
            if name and not user["name"]:
                conn.execute("UPDATE users SET name=? WHERE id=?", (name, user_id))
        if refresh_token:
            conn.execute("UPDATE users SET apple_refresh_token=? WHERE id=?", (refresh_token, user_id))
        token = auth.create_session(conn, user_id)
        me = families.me_payload(conn, user_id)
    return {"token": token, "me": me}


@app.post("/api/auth/logout")
def sign_out(user: dict = Depends(auth.current_user)):
    with db() as conn:
        auth.end_session(conn, user["_token"])
    return OK


@app.get("/api/me")
def get_me(user: dict = Depends(auth.current_user)):
    with db() as conn:
        return families.me_payload(conn, user["id"])


class NameUpdate(BaseModel):
    name: str


@app.patch("/api/me")
def update_me(body: NameUpdate, user: dict = Depends(auth.current_user)):
    name = " ".join(body.name.split())[:40]
    if not name:
        raise HTTPException(400, "Enter a name.")
    with db() as conn:
        conn.execute("UPDATE users SET name=? WHERE id=?", (name, user["id"]))
        return families.me_payload(conn, user["id"])


@app.delete("/api/me")
def delete_me(user: dict = Depends(auth.current_user)):
    with db() as conn:
        refresh_token = families.delete_account(conn, user["id"])
    auth.revoke_apple_token(refresh_token)
    return OK


# ---------- Family ----------

class JoinRequest(BaseModel):
    code: str


class RenameRequest(BaseModel):
    name: str


@app.post("/api/family/join")
def join_family(body: JoinRequest, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.join(conn, user["id"], body.code)
        return families.me_payload(conn, user["id"])


@app.post("/api/family/leave")
def leave_family(user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.leave(conn, user["id"])
        return families.me_payload(conn, user["id"])


@app.patch("/api/family")
def rename_family(body: RenameRequest, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.rename(conn, user["id"], body.name)
        return families.me_payload(conn, user["id"])


@app.post("/api/family/invite-code")
def new_invite_code(user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.reset_invite_code(conn, user["id"])
        return families.me_payload(conn, user["id"])


@app.delete("/api/family/members/{member_id}")
def remove_member(member_id: str, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.remove_member(conn, user["id"], member_id)
        return families.me_payload(conn, user["id"])


class KidCreate(BaseModel):
    name: str
    age: int


class KidUpdate(BaseModel):
    name: str | None = None
    age: int | None = None


@app.post("/api/family/kids")
def add_kid(body: KidCreate, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.add_kid(conn, user["id"], body.name, body.age)
        return families.me_payload(conn, user["id"])


@app.patch("/api/family/kids/{kid_id}")
def update_kid(kid_id: str, body: KidUpdate, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.update_kid(conn, user["id"], kid_id, body.name, body.age)
        return families.me_payload(conn, user["id"])


@app.delete("/api/family/kids/{kid_id}")
def delete_kid(kid_id: str, user: dict = Depends(auth.current_user)):
    with db() as conn:
        families.delete_kid(conn, user["id"], kid_id)
        return families.me_payload(conn, user["id"])


# ---------- Reviews ----------

class ReviewRequest(BaseModel):
    url: str
    child_age: int | None = None
    kid_id: str | None = None
    refresh: bool = False


def _row_to_dict(row, kid: dict | None = None) -> dict:
    return {
        "video_id": row["video_id"],
        "child_age": row["child_age"],
        "created": row["created"],
        "video": json.loads(row["video"]),
        "report": json.loads(row["report"]),
        "kid_id": kid["id"] if kid else None,
        "kid_name": kid["name"] if kid else None,
    }


@app.post("/api/review")
async def review(req: ReviewRequest, user: dict = Depends(auth.current_user)):
    try:
        video_id = extract_video_id(req.url)
    except VideoError as e:
        raise HTTPException(400, str(e))
    age = req.child_age or 0
    kid = None

    with db() as conn:
        family_id = families.ensure_family(conn, user["id"])
        if req.kid_id:
            k = families.get_kid(conn, family_id, req.kid_id)
            kid = {"id": k["id"], "name": k["name"]}
            age = families.kid_age(k["birth_year"], k["birth_month"])
        row = conn.execute("SELECT * FROM reviews WHERE video_id=? AND child_age=?", (video_id, age)).fetchone()
        if row and not req.refresh:
            # Already scouted (by anyone): free, just add it to this family's list.
            families.save_to_family(conn, family_id, video_id, age, user["id"], kid and kid["id"])
            return {**_row_to_dict(row, kid), "cached": True}
        families.check_quota(conn, family_id)

    try:
        ev = await run_in_threadpool(gather, req.url, FRAMES, MAX_MINUTES)
        report = await run_in_threadpool(analyze, ev, age or None)
    except (VideoError, AnalysisError) as e:
        raise HTTPException(422, str(e))

    video = {
        "video_id": ev.video_id, "url": ev.url, "title": ev.title, "channel": ev.channel,
        "duration": ev.duration, "thumbnail_url": ev.thumbnail_url,
        "had_transcript": bool(ev.transcript), "frames_reviewed": len(ev.frames), "notes": ev.notes,
    }
    created = time.time()
    with db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO reviews VALUES (?,?,?,?,?)",
            (video_id, age, created, json.dumps(video), report.model_dump_json()),
        )
        families.record_review(conn, family_id, user["id"], video_id)
        families.save_to_family(conn, family_id, video_id, age, user["id"], kid and kid["id"])
    return {"video_id": video_id, "child_age": age, "created": created,
            "video": video, "report": report.model_dump(), "cached": False,
            "kid_id": kid and kid["id"], "kid_name": kid and kid["name"]}


@app.get("/api/reviews")
def list_reviews(user: dict = Depends(auth.current_user)):
    with db() as conn:
        family_id = families.ensure_family(conn, user["id"])
        rows = conn.execute(
            """SELECT r.*, k.id AS kid_id, k.name AS kid_name FROM family_reviews f
               JOIN reviews r ON r.video_id = f.video_id AND r.child_age = f.child_age
               LEFT JOIN kids k ON k.id = f.kid_id
               WHERE f.family_id = ? ORDER BY f.added DESC LIMIT 500""",
            (family_id,),
        ).fetchall()
    return [
        {**_row_to_dict(r, {"id": r["kid_id"], "name": r["kid_name"]} if r["kid_id"] else None), "cached": True}
        for r in rows
    ]


@app.delete("/api/reviews/{video_id}/{child_age}")
def delete_review(video_id: str, child_age: int, user: dict = Depends(auth.current_user)):
    with db() as conn:
        family_id = families.ensure_family(conn, user["id"])
        conn.execute(
            "DELETE FROM family_reviews WHERE family_id=? AND video_id=? AND child_age=?",
            (family_id, video_id, child_age),
        )
    return OK


class ImportItem(BaseModel):
    video_id: str
    child_age: int


class ImportRequest(BaseModel):
    items: list[ImportItem]


@app.post("/api/reviews/import")
def import_reviews(body: ImportRequest, user: dict = Depends(auth.current_user)):
    """Moves reviews saved on a phone before accounts existed into the family list."""
    with db() as conn:
        family_id = families.ensure_family(conn, user["id"])
        for item in body.items[:300]:
            exists = conn.execute(
                "SELECT 1 FROM reviews WHERE video_id=? AND child_age=?", (item.video_id, item.child_age)
            ).fetchone()
            if exists:
                conn.execute(
                    """INSERT OR IGNORE INTO family_reviews (family_id, video_id, child_age, added_by, added)
                       VALUES (?,?,?,?,?)""",
                    (family_id, item.video_id, item.child_age, user["id"], time.time()),
                )
    return OK
