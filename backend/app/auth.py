"""Sign in with Apple and login sessions.

Flow:
  1. The iPhone signs in with Apple and sends us Apple's identity token (a signed JWT).
  2. We check Apple's signature, that it was issued for OUR app, and the nonce.
  3. We create (or find) the user and hand back our own random session token.
  4. The app sends that token as `Authorization: Bearer <token>` on every request.

Optional, needed before App Store submission: set APPLE_TEAM_ID, APPLE_KEY_ID and
APPLE_PRIVATE_KEY_PATH so we can revoke Apple sign-in when someone deletes their account.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import time
import urllib.parse
import urllib.request
from pathlib import Path

import jwt
from fastapi import Header, HTTPException
from jwt import PyJWKClient

from .db import db

APPLE_ISSUER = "https://appleid.apple.com"
BUNDLE_ID = os.environ.get("SCOUT_APPLE_BUNDLE_ID", "com.example.screenscout")

APPLE_TEAM_ID = os.environ.get("APPLE_TEAM_ID", "")
APPLE_KEY_ID = os.environ.get("APPLE_KEY_ID", "")
APPLE_PRIVATE_KEY_PATH = os.environ.get("APPLE_PRIVATE_KEY_PATH", "")

_jwks = PyJWKClient(f"{APPLE_ISSUER}/auth/keys", cache_keys=True, lifespan=3600)


# ---------- Apple identity tokens ----------

def verify_apple_token(identity_token: str, raw_nonce: str | None) -> dict:
    try:
        key = _jwks.get_signing_key_from_jwt(identity_token).key
        claims = jwt.decode(
            identity_token,
            key,
            algorithms=["RS256"],
            audience=BUNDLE_ID,
            issuer=APPLE_ISSUER,
        )
    except jwt.PyJWTError as e:
        raise HTTPException(401, "Apple sign-in couldn't be verified. Please try again.") from e

    if raw_nonce is not None:
        expected = hashlib.sha256(raw_nonce.encode()).hexdigest()
        if not secrets.compare_digest(str(claims.get("nonce", "")), expected):
            raise HTTPException(401, "Apple sign-in couldn't be verified. Please try again.")
    return claims


# ---------- Optional: Apple token revocation (App Store requirement) ----------

def _revocation_configured() -> bool:
    return bool(APPLE_TEAM_ID and APPLE_KEY_ID and APPLE_PRIVATE_KEY_PATH)


def _client_secret() -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": APPLE_TEAM_ID, "iat": now, "exp": now + 300, "aud": APPLE_ISSUER, "sub": BUNDLE_ID},
        Path(APPLE_PRIVATE_KEY_PATH).read_text(),
        algorithm="ES256",
        headers={"kid": APPLE_KEY_ID},
    )


def _post_form(url: str, fields: dict) -> dict | None:
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read()
            return json.loads(body) if body else {}
    except Exception:  # noqa: BLE001 - revocation is best effort
        return None


def exchange_code_for_refresh_token(authorization_code: str | None) -> str | None:
    if not authorization_code or not _revocation_configured():
        return None
    result = _post_form(f"{APPLE_ISSUER}/auth/token", {
        "client_id": BUNDLE_ID,
        "client_secret": _client_secret(),
        "code": authorization_code,
        "grant_type": "authorization_code",
    })
    return (result or {}).get("refresh_token")


def revoke_apple_token(refresh_token: str | None) -> None:
    if not refresh_token or not _revocation_configured():
        return
    _post_form(f"{APPLE_ISSUER}/auth/revoke", {
        "client_id": BUNDLE_ID,
        "client_secret": _client_secret(),
        "token": refresh_token,
        "token_type_hint": "refresh_token",
    })


# ---------- Sessions ----------

def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def create_session(conn, user_id: str) -> str:
    token = secrets.token_urlsafe(32)
    now = time.time()
    conn.execute("INSERT INTO sessions VALUES (?,?,?,?)", (_hash(token), user_id, now, now))
    return token


def end_session(conn, token: str) -> None:
    conn.execute("DELETE FROM sessions WHERE token_hash=?", (_hash(token),))


def bearer_token(authorization: str) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "Please sign in.")
    return authorization.removeprefix("Bearer ").strip()


def current_user(authorization: str = Header(default="")) -> dict:
    """FastAPI dependency: the signed-in user, or a 401."""
    token = bearer_token(authorization)
    with db() as conn:
        row = conn.execute(
            "SELECT users.* FROM sessions JOIN users ON users.id = sessions.user_id WHERE token_hash=?",
            (_hash(token),),
        ).fetchone()
        if row is None:
            raise HTTPException(401, "Your session ended. Please sign in again.")
        conn.execute("UPDATE sessions SET last_used=? WHERE token_hash=?", (time.time(), _hash(token)))
        user = dict(row)
    user["_token"] = token
    return user
