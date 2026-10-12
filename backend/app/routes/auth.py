from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from psycopg.types.json import Jsonb

from app.auth import _google_identity, bearer
from app.config import BOOTSTRAP_ADMIN_EMAIL
from app.database import connection as _connection
from app.schemas import DeviceRegistration

router = APIRouter()

@router.post("/v1/auth/devices/register")
def register_device(body: DeviceRegistration,
                    credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Google sign-in required")
    claims = _google_identity(credentials.credentials)
    subject = str(claims["sub"])
    email = str(claims.get("email", ""))
    display_name = str(claims.get("name", ""))
    status, role = "pending", "viewer"
    bootstrapped = False
    with _connection() as conn:
        conn.execute("SELECT id FROM app_access_state WHERE id = 1 FOR UPDATE")
        user = conn.execute(
            "INSERT INTO users (google_sub, email, display_name, account_status, role) "
            "VALUES (%s, %s, %s, 'pending', 'viewer') "
            "ON CONFLICT (google_sub) DO UPDATE SET email = EXCLUDED.email, "
            "display_name = EXCLUDED.display_name, last_seen_at = NOW() "
            "RETURNING account_status, role",
            (subject, email, display_name),
        ).fetchone()
        status, role = user["account_status"], user["role"]
        is_configured_admin = (
            bool(BOOTSTRAP_ADMIN_EMAIL)
            and email.lower() == BOOTSTRAP_ADMIN_EMAIL
            and claims.get("email_verified") is True
        )
        if is_configured_admin:
            # Exactly one account may hold the admin role: the server-configured
            # Google identity. This also repairs stale admin assignments from
            # earlier deployments while preserving those accounts' editor access.
            conn.execute(
                "UPDATE users SET role = 'editor' WHERE role = 'admin' AND google_sub <> %s",
                (subject,),
            )
            conn.execute(
                "UPDATE users SET account_status = 'active', role = 'admin', "
                "approved_at = COALESCE(approved_at, NOW()), approved_by = COALESCE(approved_by, 'bootstrap') "
                "WHERE google_sub = %s",
                (subject,),
            )
            conn.execute("UPDATE app_access_state SET bootstrap_completed = TRUE WHERE id = 1")
            status, role = "active", "admin"
            bootstrapped = user["account_status"] != "active" or user["role"] != "admin"
        else:
            configured_admin = conn.execute(
                "SELECT 1 FROM users WHERE lower(email) = %s AND account_status = 'active' AND role = 'admin' LIMIT 1",
                (BOOTSTRAP_ADMIN_EMAIL,),
            ).fetchone() if BOOTSTRAP_ADMIN_EMAIL else None
            if configured_admin is None:
                conn.execute("UPDATE users SET role = 'editor' WHERE role = 'admin'")
                conn.execute("UPDATE app_access_state SET bootstrap_completed = FALSE WHERE id = 1")
            else:
                conn.execute(
                    "UPDATE users SET role = 'editor' WHERE role = 'admin' AND lower(email) <> %s",
                    (BOOTSTRAP_ADMIN_EMAIL,),
                )
                conn.execute("UPDATE app_access_state SET bootstrap_completed = TRUE WHERE id = 1")
            refreshed = conn.execute(
                "SELECT account_status, role FROM users WHERE google_sub = %s",
                (subject,),
            ).fetchone()
            status, role = refreshed["account_status"], refreshed["role"]
        existing = conn.execute("SELECT google_sub FROM devices WHERE device_id = %s FOR UPDATE", (body.device_id,)).fetchone()
        if existing and existing["google_sub"] != subject:
            raise HTTPException(status_code=409, detail="Device is already registered to another Google account")
        conn.execute("INSERT INTO devices (device_id, google_sub, device_name, platform) VALUES (%s, %s, %s, %s) "
                     "ON CONFLICT (device_id) DO UPDATE SET device_name = EXCLUDED.device_name, platform = EXCLUDED.platform, last_seen_at = NOW(), revoked = FALSE",
                     (body.device_id, subject, body.device_name, body.platform))
        if bootstrapped:
            conn.execute(
                "INSERT INTO access_audit_log (actor_sub, actor_email, target_sub, target_email, action, before, after, device_id, device_name) "
                "VALUES (%s, %s, %s, %s, 'bootstrap_admin', %s, %s, %s, %s)",
                (subject, email, subject, email, Jsonb({"status": "pending", "role": "viewer"}),
                 Jsonb({"status": "active", "role": "admin"}), body.device_id, body.device_name),
            )
    return {"registered": True, "email": email, "displayName": display_name,
            "status": status, "role": role}
