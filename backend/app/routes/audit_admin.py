from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from psycopg.types.json import Jsonb

from app.auth import Actor, require_admin, require_device
from app.database import connection as _connection
from app.schemas import UserAccessUpdate

router = APIRouter()

@router.get("/v1/audit")
def get_audit(limit: int = 100, actor: Actor = Depends(require_device)) -> dict[str, Any]:
    limit = min(max(limit, 1), 500)
    with _connection() as conn:
        rows = conn.execute(
            "SELECT email, display_name, device_name, action, component_name, changed_fields, revision, occurred_at "
            "FROM audit_log ORDER BY audit_id DESC LIMIT %s", (limit,),
        ).fetchall()
    return {"items": [{"email": r["email"], "displayName": r["display_name"],
                       "deviceName": r["device_name"], "action": r["action"],
                       "componentName": r["component_name"], "changedFields": r["changed_fields"],
                       "revision": r["revision"], "occurredAt": r["occurred_at"].isoformat()}
                      for r in rows]}


@router.get("/v1/admin/users")
def get_admin_users(actor: Actor = Depends(require_admin)) -> dict[str, Any]:
    with _connection() as conn:
        rows = conn.execute(
            "SELECT u.google_sub, u.email, u.display_name, u.account_status, u.role, "
            "u.created_at, u.last_seen_at, "
            "COALESCE(jsonb_agg(jsonb_build_object('name', d.device_name, 'platform', d.platform, "
            "'lastSeenAt', d.last_seen_at) ORDER BY d.last_seen_at DESC) FILTER (WHERE d.device_id IS NOT NULL), '[]'::jsonb) AS devices "
            "FROM users u LEFT JOIN devices d ON d.google_sub = u.google_sub AND d.revoked = FALSE "
            "GROUP BY u.google_sub ORDER BY CASE u.account_status WHEN 'pending' THEN 0 ELSE 1 END, u.created_at DESC"
        ).fetchall()
    return {"items": [{
        "userId": row["google_sub"], "email": row["email"],
        "displayName": row["display_name"], "status": row["account_status"],
        "role": row["role"], "createdAt": row["created_at"].isoformat(),
        "lastSeenAt": row["last_seen_at"].isoformat(), "devices": row["devices"],
    } for row in rows]}


@router.patch("/v1/admin/users/{target_sub}")
def update_user_access(target_sub: str, body: UserAccessUpdate,
                       actor: Actor = Depends(require_admin)) -> dict[str, Any]:
    if body.status not in {"active", "disabled"}:
        raise HTTPException(status_code=422, detail="status must be active or disabled")
    if body.role not in {"viewer", "editor"}:
        raise HTTPException(status_code=422, detail="role must be viewer or editor")
    with _connection() as conn:
        conn.execute("SELECT id FROM app_access_state WHERE id = 1 FOR UPDATE")
        target = conn.execute(
            "SELECT google_sub, email, account_status, role FROM users WHERE google_sub = %s FOR UPDATE",
            (target_sub,),
        ).fetchone()
        if target is None:
            raise HTTPException(status_code=404, detail="User not found")
        old_status, old_role = target["account_status"], target["role"]
        if old_status == body.status and old_role == body.role:
            return {"updated": False, "status": old_status, "role": old_role}
        if old_role == "admin" and target_sub == actor.subject:
            raise HTTPException(status_code=409, detail="The configured administrator role is fixed")
        conn.execute(
            "UPDATE users SET account_status = %s, role = %s, "
            "approved_at = CASE WHEN %s = 'active' AND account_status <> 'active' THEN NOW() ELSE approved_at END, "
            "approved_by = CASE WHEN %s = 'active' AND account_status <> 'active' THEN %s ELSE approved_by END "
            "WHERE google_sub = %s",
            (body.status, body.role, body.status, body.status, actor.subject, target_sub),
        )
        action = (
            "approve" if old_status == "pending" and body.status == "active"
            else "disable" if body.status == "disabled"
            else "reactivate" if old_status == "disabled" and body.status == "active"
            else "role_change"
        )
        conn.execute(
            "INSERT INTO access_audit_log (actor_sub, actor_email, target_sub, target_email, action, before, after, device_id, device_name) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
            (actor.subject, actor.email, target_sub, target["email"], action,
             Jsonb({"status": old_status, "role": old_role}),
             Jsonb({"status": body.status, "role": body.role}), actor.device_id, actor.device_name),
        )
    return {"updated": True, "status": body.status, "role": body.role}


@router.get("/v1/admin/audit")
def get_admin_audit(limit: int = 100, actor: Actor = Depends(require_admin)) -> dict[str, Any]:
    limit = min(max(limit, 1), 500)
    with _connection() as conn:
        rows = conn.execute(
            "SELECT actor_email, target_email, action, before, after, device_name, occurred_at "
            "FROM access_audit_log ORDER BY access_audit_id DESC LIMIT %s", (limit,),
        ).fetchall()
    return {"items": [{"actorEmail": row["actor_email"], "targetEmail": row["target_email"],
                       "action": row["action"], "before": row["before"], "after": row["after"],
                       "deviceName": row["device_name"], "occurredAt": row["occurred_at"].isoformat()}
                      for row in rows]}
