from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token

from app.database import connection
from app.config import BOOTSTRAP_ADMIN_EMAIL, GOOGLE_SERVER_CLIENT_ID

@dataclass(frozen=True)
class Actor:
    subject: str
    email: str
    display_name: str
    device_id: str
    device_name: str
    role: str
    email_verified: bool


bearer = HTTPBearer(auto_error=False)


def _google_identity(token: str) -> dict[str, Any]:
    if os.environ.get("APP_ENV") == "testing" and os.environ.get("ARMOURY_TEST_AUTH_BYPASS") == "1" and token == "armoury-integration-test-token":
        return {"sub": "integration-test-user", "email": "integration@example.invalid", "email_verified": True, "name": "Integration Test"}
    if os.environ.get("APP_ENV") == "testing" and os.environ.get("ARMOURY_TEST_AUTH_BYPASS") == "1" and token.startswith("armoury-test:"):
        parts = token.split(":", 2)
        if len(parts) == 3 and parts[1] and parts[2]:
            return {"sub": parts[1], "email": parts[2], "email_verified": True, "name": parts[2].split("@", 1)[0]}
    if not GOOGLE_SERVER_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google sign-in is not configured")
    try:
        claims = id_token.verify_oauth2_token(token, GoogleRequest(), GOOGLE_SERVER_CLIENT_ID)
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired Google ID token") from exc
    if claims.get("iss") not in {"accounts.google.com", "https://accounts.google.com"}:
        raise HTTPException(status_code=401, detail="Invalid Google token issuer")
    if not claims.get("sub"):
        raise HTTPException(status_code=401, detail="Google token has no subject")
    return claims


def require_device(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    device_id: str | None = Header(default=None, alias="X-Armoury-Device-ID"),
) -> Actor:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Google sign-in required")
    claims = _google_identity(credentials.credentials)
    if not device_id:
        raise HTTPException(status_code=401, detail="Registered device required")
    with connection() as conn:
        row = conn.execute(
            "SELECT d.device_name, u.email, u.display_name, u.account_status, u.role "
            "FROM devices d JOIN users u ON u.google_sub = d.google_sub "
            "WHERE d.device_id = %s AND d.google_sub = %s AND d.revoked = FALSE",
            (device_id, str(claims["sub"])),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="This installation is not registered")
    if row["account_status"] != "active":
        code = "account_pending" if row["account_status"] == "pending" else "account_disabled"
        detail = "Waiting for an administrator to approve this account" if code == "account_pending" else "This Armoury account is disabled"
        raise HTTPException(status_code=403, detail={"code": code, "message": detail})
    return Actor(str(claims["sub"]), row["email"], row["display_name"],
                 device_id, row["device_name"], row["role"],
                 claims.get("email_verified") is True)


def require_editor(actor: Actor = Depends(require_device)) -> Actor:
    if actor.role not in {"editor", "admin"}:
        raise HTTPException(status_code=403, detail={"code": "read_only", "message": "View-only access"})
    return actor


def require_admin(actor: Actor = Depends(require_device)) -> Actor:
    if (actor.role != "admin" or not BOOTSTRAP_ADMIN_EMAIL
            or actor.email.lower() != BOOTSTRAP_ADMIN_EMAIL
            or not actor.email_verified):
        raise HTTPException(status_code=403, detail={"code": "admin_required", "message": "Administrator access required"})
    return actor
