"""Pull everything we can learn about a YouTube / YouTube Kids video.

Three sources of evidence:
  1. Metadata (title, channel, description, tags, duration) via yt-dlp
  2. Transcript (captions) via youtube-transcript-api, with timestamps
  3. Still frames sampled across the video via yt-dlp + ffmpeg, so the
     reviewer can see what's on screen, not just what's said. This matters
     for kids content, where a lot of the bad stuff has no dialogue at all.
"""

from __future__ import annotations

import base64
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import yt_dlp
from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import YouTubeTranscriptApiException

_ID_PATTERNS = [
    r"(?:v=|/videos/|embed/|youtu\.be/|/v/|/e/|shorts/|live/|watch/)([A-Za-z0-9_-]{11})",
    r"^([A-Za-z0-9_-]{11})$",
]


class VideoError(Exception):
    """Raised when we can't get a usable video."""


@dataclass
class Frame:
    timestamp: float  # seconds
    jpeg_b64: str


@dataclass
class VideoEvidence:
    video_id: str
    url: str
    title: str
    channel: str
    duration: int  # seconds
    description: str
    tags: list[str]
    thumbnail_url: str | None
    view_count: int | None
    made_for_kids: bool | None
    transcript: list[tuple[float, str]] = field(default_factory=list)
    frames: list[Frame] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)  # what we could NOT get


def extract_video_id(url: str) -> str:
    url = url.strip()
    for pat in _ID_PATTERNS:
        m = re.search(pat, url)
        if m:
            return m.group(1)
    raise VideoError("That doesn't look like a YouTube link. Paste the full video URL.")


def fmt_ts(seconds: float) -> str:
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def _metadata(video_id: str) -> dict:
    opts = {"quiet": True, "no_warnings": True, "skip_download": True, "no_color": True}
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            return ydl.extract_info(f"https://www.youtube.com/watch?v={video_id}", download=False)
    except yt_dlp.utils.DownloadError as e:
        msg = re.sub(r"\x1b\[[0-9;]*m", "", str(e))
        msg = re.sub(r"^ERROR:\s*(\[youtube\]\s*[\w-]+:\s*)?", "", msg).strip()
        if "confirm you" in msg and "bot" in msg:
            msg = "YouTube is blocking automated requests from this server right now. Try again later."
        elif "not available" in msg or "unavailable" in msg.lower():
            msg = "YouTube says this video isn't available. It may be private, removed, or limited to certain countries or apps."
        raise VideoError(msg) from e


def _transcript(video_id: str) -> list[tuple[float, str]]:
    api = YouTubeTranscriptApi()
    try:
        fetched = api.fetch(video_id, languages=["en", "en-US", "en-GB"])
    except YouTubeTranscriptApiException:
        # Fall back to whatever language exists, translated to English if possible.
        transcripts = api.list(video_id)
        t = next(iter(transcripts))
        if t.language_code not in ("en",) and t.is_translatable:
            t = t.translate("en")
        fetched = t.fetch()
    return [(s.start, s.text.replace("\n", " ")) for s in fetched]


def _frames(video_id: str, duration: int, count: int) -> list[Frame]:
    if not shutil.which("ffmpeg"):
        raise VideoError("ffmpeg is not installed")
    tmp = Path(tempfile.mkdtemp(prefix="scout_"))
    try:
        opts = {
            "quiet": True,
            "no_warnings": True,
            # Smallest video-only stream is plenty for content review.
            "format": "worstvideo[height>=240][ext=mp4]/worstvideo[height>=240]/worst",
            "outtmpl": str(tmp / "video.%(ext)s"),
            "no_color": True,
        }
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([f"https://www.youtube.com/watch?v={video_id}"])
        src = next(tmp.glob("video.*"))

        # Evenly spaced, skipping the very first/last second.
        step = max(duration, 1) / (count + 1)
        frames: list[Frame] = []
        for i in range(1, count + 1):
            ts = step * i
            out = tmp / f"f{i:03d}.jpg"
            subprocess.run(
                ["ffmpeg", "-loglevel", "error", "-ss", f"{ts:.2f}", "-i", str(src),
                 "-frames:v", "1", "-vf", "scale=512:-2", "-q:v", "5", str(out)],
                check=False, timeout=60,
            )
            if out.exists():
                frames.append(Frame(ts, base64.standard_b64encode(out.read_bytes()).decode()))
        return frames
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def gather(url: str, frame_count: int = 16, max_minutes: int = 60) -> VideoEvidence:
    video_id = extract_video_id(url)
    info = _metadata(video_id)
    duration = int(info.get("duration") or 0)
    if max_minutes and duration > max_minutes * 60:
        raise VideoError(f"Video is {duration // 60} minutes long; the limit is {max_minutes}.")

    ev = VideoEvidence(
        video_id=video_id,
        url=f"https://www.youtube.com/watch?v={video_id}",
        title=info.get("title") or "",
        channel=info.get("channel") or info.get("uploader") or "",
        duration=duration,
        description=(info.get("description") or "")[:4000],
        tags=list(info.get("tags") or [])[:40],
        thumbnail_url=info.get("thumbnail"),
        view_count=info.get("view_count"),
        made_for_kids=info.get("is_made_for_kids") if "is_made_for_kids" in info else None,
    )

    try:
        ev.transcript = _transcript(video_id)
    except Exception:  # noqa: BLE001 - many failure modes, all non-fatal
        ev.notes.append("No captions were available, so spoken words were not reviewed directly.")

    if frame_count > 0:
        try:
            ev.frames = _frames(video_id, duration, frame_count)
        except Exception:  # noqa: BLE001
            ev.notes.append("Couldn't sample video frames, so visuals were judged from title, thumbnail and description only.")

    return ev
