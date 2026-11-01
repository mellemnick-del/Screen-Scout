"""Families: who shares reviews with whom, invite codes, and monthly limits."""

from __future__ import annotations

import os
import re
import secrets
import time
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException

# New reviews per family per calendar month (UTC). 0 means unlimited.
MONTHLY_LIMIT = int(os.environ.get("SCOUT_MONTHLY_LIMIT", "50"))
MAX_MEMBERS = int(os.environ.get("SCOUT_MAX_FAMILY_SIZE", "6"))

_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I/L mix-ups


# ---------- Basics ----------

def get_user(conn, user_id: str):
    return conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()


def _new_invite_code(conn) -> str:
    while True:
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(6))
        if not conn.execute("SELECT 1 FROM families WHERE invite_code=?", (code,)).fetchone():
            return code


def create_family(conn, owner_id: str, name: str = "My Family") -> str:
    family_id = uuid.uuid4().hex
    conn.execute(
        "INSERT INTO families VALUES (?,?,?,?,?)",
        (family_id, name, owner_id, _new_invite_code(conn), time.time()),
    )
    conn.execute("UPDATE users SET family_id=? WHERE id=?", (family_id, owner_id))
    return family_id


def ensure_family(conn, user_id: str) -> str:
    user = get_user(conn, user_id)
    if user["family_id"] and conn.execute("SELECT 1 FROM families WHERE id=?", (user["family_id"],)).fetchone():
        return user["family_id"]
    return create_family(conn, user_id)


def _other_members(conn, family_id: str, user_id: str):
    return conn.execute(
        "SELECT id FROM users WHERE family_id=? AND id<>? ORDER BY created",
        (family_id, user_id),
    ).fetchall()


def _detach(conn, user_id: str) -> None:
    """Take a user out of their family. Hands off ownership, or deletes an empty family."""
    user = get_user(conn, user_id)
    family_id = user["family_id"] if user else None
    if not family_id:
        return
    others = _other_members(conn, family_id, user_id)
    conn.execute("UPDATE users SET family_id=NULL WHERE id=?", (user_id,))
    if others:
        conn.execute(
            "UPDATE families SET owner_id=? WHERE id=? AND owner_id=?",
            (others[0]["id"], family_id, user_id),
        )
    else:
        conn.execute("DELETE FROM family_reviews WHERE family_id=?", (family_id,))
        conn.execute("DELETE FROM kids WHERE family_id=?", (family_id,))
        conn.execute("DELETE FROM families WHERE id=?", (family_id,))


def _require_owner(conn, user_id: str):
    family_id = ensure_family(conn, user_id)
    family = conn.execute("SELECT * FROM families WHERE id=?", (family_id,)).fetchone()
    if family["owner_id"] != user_id:
        raise HTTPException(403, "Only the family organizer can do that.")
    return family


# ---------- Usage limits ----------

def _month_bounds(now: float | None = None) -> tuple[float, float]:
    dt = datetime.fromtimestamp(now or time.time(), tz=timezone.utc)
    start = dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    end = start.replace(year=start.year + 1, month=1) if start.month == 12 else start.replace(month=start.month + 1)
    return start.timestamp(), end.timestamp()


def usage(conn, family_id: str) -> dict:
    start, end = _month_bounds()
    # Count the family's reviews plus anything current members ran elsewhere this
    # month, so leaving and rejoining families doesn't reset the counter.
    used = conn.execute(
        """SELECT COUNT(*) FROM review_events
           WHERE created >= ? AND (family_id = ? OR user_id IN (SELECT id FROM users WHERE family_id = ?))""",
        (start, family_id, family_id),
    ).fetchone()[0]
    return {"used": used, "limit": MONTHLY_LIMIT, "resets_at": end}


def check_quota(conn, family_id: str) -> None:
    if MONTHLY_LIMIT <= 0:
        return
    u = usage(conn, family_id)
    if u["used"] >= MONTHLY_LIMIT:
        resets = datetime.fromtimestamp(u["resets_at"], tz=timezone.utc)
        raise HTTPException(
            429,
            f"Your family has used all {MONTHLY_LIMIT} new reviews for this month. "
            f"More unlock on {resets:%B} {resets.day}. Saved reviews are always free to open.",
        )


def record_review(conn, family_id: str, user_id: str, video_id: str) -> None:
    conn.execute("INSERT INTO review_events VALUES (?,?,?,?)", (family_id, user_id, video_id, time.time()))


def save_to_family(conn, family_id: str, video_id: str, child_age: int, user_id: str, kid_id: str | None = None) -> None:
    conn.execute(
        """INSERT INTO family_reviews (family_id, video_id, child_age, added_by, added, kid_id)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(family_id, video_id, child_age)
           DO UPDATE SET added=excluded.added, added_by=excluded.added_by,
                         kid_id=COALESCE(excluded.kid_id, family_reviews.kid_id)""",
        (family_id, video_id, child_age, user_id, time.time(), kid_id),
    )


# ---------- What the app sees ----------

def me_payload(conn, user_id: str) -> dict:
    family_id = ensure_family(conn, user_id)
    user = get_user(conn, user_id)
    family = conn.execute("SELECT * FROM families WHERE id=?", (family_id,)).fetchone()
    members = conn.execute(
        "SELECT id, name FROM users WHERE family_id=? ORDER BY created", (family_id,)
    ).fetchall()
    return {
        "user": {"id": user["id"], "name": user["name"], "email": user["email"]},
        "family": {
            "id": family["id"],
            "name": family["name"],
            "invite_code": family["invite_code"],
            "is_owner": family["owner_id"] == user_id,
            "members": [
                {
                    "id": m["id"],
                    "name": m["name"] or "Family member",
                    "is_owner": m["id"] == family["owner_id"],
                    "is_you": m["id"] == user_id,
                }
                for m in members
            ],
            "max_members": MAX_MEMBERS,
            "usage": usage(conn, family_id),
            "kids": list_kids(conn, family_id),
        },
    }


# ---------- Family actions ----------

def join(conn, user_id: str, code: str) -> None:
    code = re.sub(r"[^A-Z0-9]", "", code.upper())
    family = conn.execute("SELECT * FROM families WHERE invite_code=?", (code,)).fetchone()
    if family is None:
        raise HTTPException(404, "That invite code didn't work. Double-check it and try again.")

    old_family_id = ensure_family(conn, user_id)
    if old_family_id == family["id"]:
        raise HTTPException(400, "You're already in this family.")

    count = conn.execute("SELECT COUNT(*) FROM users WHERE family_id=?", (family["id"],)).fetchone()[0]
    if count >= MAX_MEMBERS:
        raise HTTPException(400, f"That family is full ({MAX_MEMBERS} people max).")

    # If you were on your own, your saved reviews come with you.
    if not _other_members(conn, old_family_id, user_id):
        conn.execute(
            """INSERT OR IGNORE INTO family_reviews (family_id, video_id, child_age, added_by, added)
               SELECT ?, video_id, child_age, added_by, added FROM family_reviews WHERE family_id=?""",
            (family["id"], old_family_id),
        )
    _detach(conn, user_id)
    conn.execute("UPDATE users SET family_id=? WHERE id=?", (family["id"], user_id))


def leave(conn, user_id: str) -> None:
    family_id = ensure_family(conn, user_id)
    if not _other_members(conn, family_id, user_id):
        raise HTTPException(400, "You're the only one in this family, so there's nothing to leave.")
    _detach(conn, user_id)
    create_family(conn, user_id)


def remove_member(conn, owner_id: str, member_id: str) -> None:
    family = _require_owner(conn, owner_id)
    if member_id == owner_id:
        raise HTTPException(400, "You can't remove yourself. Use Leave Family instead.")
    member = get_user(conn, member_id)
    if member is None or member["family_id"] != family["id"]:
        raise HTTPException(404, "That person isn't in your family.")
    _detach(conn, member_id)
    create_family(conn, member_id)


def rename(conn, user_id: str, name: str) -> None:
    family = _require_owner(conn, user_id)
    name = " ".join(name.split())[:40]
    if not name:
        raise HTTPException(400, "Give your family a name.")
    conn.execute("UPDATE families SET name=? WHERE id=?", (name, family["id"]))


def reset_invite_code(conn, user_id: str) -> None:
    family = _require_owner(conn, user_id)
    conn.execute("UPDATE families SET invite_code=? WHERE id=?", (_new_invite_code(conn), family["id"]))


def delete_account(conn, user_id: str) -> str | None:
    """Removes the user everywhere. Returns their Apple refresh token so it can be revoked."""
    user = get_user(conn, user_id)
    if user is None:
        return None
    _detach(conn, user_id)
    conn.execute("DELETE FROM sessions WHERE user_id=?", (user_id,))
    conn.execute("UPDATE review_events SET user_id=NULL WHERE user_id=?", (user_id,))
    conn.execute("DELETE FROM users WHERE id=?", (user_id,))
    return user["apple_refresh_token"]


# ---------- Kid profiles ----------

MAX_KIDS = 10


def kid_age(birth_year: int, birth_month: int, now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    age = now.year - birth_year - (1 if now.month < birth_month else 0)
    return max(age, 0)


def _birth_from_age(age: int) -> tuple[int, int]:
    now = datetime.now(timezone.utc)
    return now.year - age, now.month


def _clean_kid(name: str | None, age: int | None) -> tuple[str | None, int | None]:
    if name is not None:
        name = " ".join(name.split())[:20]
        if not name:
            raise HTTPException(400, "Enter your kid's name.")
    if age is not None and not 1 <= age <= 17:
        raise HTTPException(400, "Age should be between 1 and 17.")
    return name, age


def list_kids(conn, family_id: str) -> list[dict]:
    rows = conn.execute(
        "SELECT * FROM kids WHERE family_id=? ORDER BY birth_year, birth_month, created", (family_id,)
    ).fetchall()
    return [
        {"id": k["id"], "name": k["name"], "age": kid_age(k["birth_year"], k["birth_month"]), "color": k["color"]}
        for k in rows
    ]


def get_kid(conn, family_id: str, kid_id: str):
    kid = conn.execute("SELECT * FROM kids WHERE id=? AND family_id=?", (kid_id, family_id)).fetchone()
    if kid is None:
        raise HTTPException(404, "That kid profile wasn't found.")
    return kid


def add_kid(conn, user_id: str, name: str, age: int) -> None:
    name, age = _clean_kid(name, age)
    family_id = ensure_family(conn, user_id)
    count = conn.execute("SELECT COUNT(*) FROM kids WHERE family_id=?", (family_id,)).fetchone()[0]
    if count >= MAX_KIDS:
        raise HTTPException(400, f"You can save up to {MAX_KIDS} kids.")
    year, month = _birth_from_age(age)
    conn.execute(
        "INSERT INTO kids VALUES (?,?,?,?,?,?,?)",
        (uuid.uuid4().hex, family_id, name, year, month, count % 8, time.time()),
    )


def update_kid(conn, user_id: str, kid_id: str, name: str | None, age: int | None) -> None:
    name, age = _clean_kid(name, age)
    family_id = ensure_family(conn, user_id)
    get_kid(conn, family_id, kid_id)
    if name is not None:
        conn.execute("UPDATE kids SET name=? WHERE id=?", (name, kid_id))
    if age is not None:
        year, month = _birth_from_age(age)
        conn.execute("UPDATE kids SET birth_year=?, birth_month=? WHERE id=?", (year, month, kid_id))


def delete_kid(conn, user_id: str, kid_id: str) -> None:
    family_id = ensure_family(conn, user_id)
    get_kid(conn, family_id, kid_id)
    conn.execute("DELETE FROM kids WHERE id=?", (kid_id,))
    conn.execute("UPDATE family_reviews SET kid_id=NULL WHERE kid_id=?", (kid_id,))
