"""SQLite storage for reviews, accounts and families."""

from __future__ import annotations

import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = Path(os.environ.get("SCOUT_DB", ROOT / "data" / "reviews.db"))

SCHEMA = """
-- Shared cache of finished reviews. Any family can open these for free.
CREATE TABLE IF NOT EXISTS reviews (
    video_id TEXT, child_age INTEGER, created REAL,
    video TEXT, report TEXT,
    PRIMARY KEY (video_id, child_age)
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    apple_sub TEXT UNIQUE NOT NULL,     -- Apple's stable user id
    email TEXT,
    name TEXT,
    family_id TEXT,
    apple_refresh_token TEXT,           -- only used to revoke on account deletion
    created REAL
);

CREATE TABLE IF NOT EXISTS families (
    id TEXT PRIMARY KEY,
    name TEXT,
    owner_id TEXT,
    invite_code TEXT UNIQUE,
    created REAL
);

-- Login tokens. Only a hash is stored, so a leaked database can't log anyone in.
CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created REAL,
    last_used REAL
);

-- Which reviews each family has in its list.
CREATE TABLE IF NOT EXISTS family_reviews (
    family_id TEXT, video_id TEXT, child_age INTEGER,
    added_by TEXT, added REAL,
    PRIMARY KEY (family_id, video_id, child_age)
);

-- One row per new (paid) analysis, for monthly limits.
CREATE TABLE IF NOT EXISTS review_events (
    family_id TEXT, user_id TEXT, video_id TEXT, created REAL
);

CREATE INDEX IF NOT EXISTS idx_users_family ON users(family_id);
CREATE INDEX IF NOT EXISTS idx_events_family ON review_events(family_id, created);
CREATE INDEX IF NOT EXISTS idx_events_user ON review_events(user_id, created);
"""

_initialized = False


@contextmanager
def db():
    """Open a connection, commit on success, roll back on error, always close."""
    global _initialized
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        if not _initialized:
            conn.executescript(SCHEMA)
            _initialized = True
        yield conn
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()
