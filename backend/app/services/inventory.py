from __future__ import annotations

import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import psycopg
from fastapi import HTTPException
from psycopg.types.json import Jsonb

from app.auth import Actor
from app.config import MEDIA_DIR
from app.database import connection as _connection
from app.merge import apply_component_patch, normalize_component
from app.schemas import AuditEvent

def _record_audit(conn: psycopg.Connection, actor: Actor, event: AuditEvent,
                  operation_id: uuid.UUID | None = None) -> None:
    conn.execute(
        "INSERT INTO audit_log (google_sub, email, display_name, device_id, device_name, action, component_id, component_name, changed_fields, revision, operation_id) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) ON CONFLICT (operation_id, action) DO NOTHING",
        (actor.subject, actor.email, actor.display_name, actor.device_id, actor.device_name,
         event.action, event.component_id, event.component_name,
         Jsonb(event.changed_fields), event.revision, operation_id),
    )



def _purge_component_history(conn: psycopg.Connection, component_id: str, data: dict[str, Any]) -> None:
    conn.execute(
        "UPDATE change_log SET data = NULL WHERE component_id = %s AND deleted = TRUE",
        (component_id,),
    )
    conn.execute(
        "DELETE FROM change_log WHERE component_id = %s AND deleted = FALSE",
        (component_id,),
    )
    conn.execute(
        "UPDATE applied_operations SET response = jsonb_set(jsonb_set(response, '{component}', 'null'::jsonb, TRUE), '{deleted}', 'true'::jsonb, TRUE) "
        "WHERE component_id = %s",
        (component_id,),
    )
    image = str(data.get("image") or "")
    match = re.fullmatch(r"(?:/v1/media/)?([0-9a-f]{32}\.(?:jpg|png|webp))", image)
    if match:
        media_path = f"/v1/media/{match.group(1)}"
        other_reference = conn.execute(
            "SELECT 1 FROM components WHERE id <> %s AND purged = FALSE AND data->>'image' = %s LIMIT 1",
            (component_id, media_path),
        ).fetchone()
        if other_reference is None:
            (MEDIA_DIR / match.group(1)).unlink(missing_ok=True)


def _cleanup_expired_archive() -> None:
    with _connection() as conn:
        _expire_archive(conn)


def _valid_record_id(value: str) -> str:
    normalized = value.strip()
    if not normalized or len(normalized) > 128:
        raise HTTPException(status_code=422, detail="id must contain 1 to 128 characters")
    return normalized


def _valid_operation_id(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except (ValueError, AttributeError) as exc:
        raise HTTPException(status_code=422, detail="operationId must be a UUID") from exc


def _new_revision(conn: psycopg.Connection) -> int:
    # The singleton row lock is held until commit. Revisions therefore follow
    # commit order and cannot skip a transaction that commits later.
    row = conn.execute(
        "UPDATE sync_clock SET revision = revision + 1 WHERE id = 1 RETURNING revision"
    ).fetchone()
    return int(row["revision"])


def _record_change(
    conn: psycopg.Connection,
    revision: int,
    component_id: str,
    data: dict[str, Any] | None,
    deleted: bool,
) -> dict[str, Any]:
    conn.execute(
        "INSERT INTO change_log (revision, component_id, deleted, data) VALUES (%s, %s, %s, %s)",
        (revision, component_id, deleted, Jsonb(data) if data is not None else None),
    )
    return {
        "revision": revision,
        "id": str(component_id),
        "deleted": deleted,
        "component": data,
    }


def _apply_operation(
    operation_id: uuid.UUID,
    component_id: str,
    kind: str,
    component: dict[str, Any] | None = None,
    changes: dict[str, Any] | None = None,
    actor: Actor | None = None,
) -> dict[str, Any]:
    with _connection() as conn:
        # Serialize all writes using the same transaction-scoped lock. There
        # are two intended clients; this makes server processing order explicit.
        conn.execute("SELECT revision FROM sync_clock WHERE id = 1 FOR UPDATE").fetchone()
        previous = conn.execute(
            "SELECT response FROM applied_operations WHERE operation_id = %s",
            (operation_id,),
        ).fetchone()
        if previous:
            return previous["response"]

        current = conn.execute(
            "SELECT data, deleted, revision, purged FROM components WHERE id = %s FOR UPDATE",
            (component_id,),
        ).fetchone()
        if kind in {"create", "restore"}:
            if current is not None:
                if current["deleted"]:
                    raise HTTPException(status_code=410, detail="Deleted component IDs cannot be reused")
                if kind == "create":
                    # Legacy installs may independently contain the same component.
                    # Adopt central state without replacing newer server data.
                    response = {
                        "revision": current["revision"],
                        "id": str(component_id),
                        "deleted": False,
                        "component": current["data"],
                    }
                    conn.execute(
                        "INSERT INTO applied_operations (operation_id, component_id, response) VALUES (%s, %s, %s)",
                        (operation_id, component_id, Jsonb(response)),
                    )
                    return response
            data = normalize_component(component_id, component or {})
            now = datetime.now(timezone.utc).isoformat()
            data["created"] = now
            data["updated"] = now
            revision = _new_revision(conn)
            conn.execute(
                "INSERT INTO components (id, data, revision, deleted, deleted_at, purged) VALUES (%s, %s, %s, FALSE, NULL, FALSE) "
                "ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, revision = EXCLUDED.revision, deleted = FALSE, deleted_at = NULL, purged = FALSE",
                (component_id, Jsonb(data), revision),
            )
            response = _record_change(conn, revision, component_id, data, False)
        elif kind == "patch":
            if current is None:
                raise HTTPException(status_code=404, detail="Component not found")
            if current["deleted"]:
                raise HTTPException(status_code=410, detail="Component has been deleted")
            data = apply_component_patch(str(component_id), current["data"], changes or {})
            data["updated"] = datetime.now(timezone.utc).isoformat()
            revision = _new_revision(conn)
            conn.execute(
                "UPDATE components SET data = %s, revision = %s WHERE id = %s",
                (Jsonb(data), revision, component_id),
            )
            response = _record_change(conn, revision, component_id, data, False)
        else:
            revision = _new_revision(conn)
            if current is None:
                conn.execute(
                    "INSERT INTO components (id, data, revision, deleted, deleted_at) VALUES (%s, %s, %s, TRUE, %s)",
                    (component_id, Jsonb({}), revision, datetime.now(timezone.utc)),
                )
            elif not current["deleted"]:
                conn.execute(
                    "UPDATE components SET revision = %s, deleted = TRUE, deleted_at = %s WHERE id = %s",
                    (revision, datetime.now(timezone.utc), component_id),
                )
            response = _record_change(conn, revision, component_id, None, True)

        if actor is not None:
            action = {"create": "create", "restore": "restore", "patch": "modify", "delete": "delete"}[kind]
            current_name = str((component or {}).get("name", "")) if kind in {"create", "restore"} else str((current or {}).get("data", {}).get("name", ""))
            fields = list(component.keys()) if kind in {"create", "restore"} and component else list((changes or {}).keys()) if kind == "patch" else []
            _record_audit(
                conn,
                actor,
                AuditEvent(
                    action=action,
                    component_id=component_id,
                    component_name=current_name,
                    changed_fields=sorted(fields),
                    revision=int(response["revision"]),
                ),
                operation_id,
            )

        conn.execute(
            "INSERT INTO applied_operations (operation_id, component_id, response) VALUES (%s, %s, %s)",
            (operation_id, component_id, Jsonb(response)),
        )
        return response


def _expire_archive(conn: psycopg.Connection) -> None:
    # Keep the ID tombstone so stale offline devices cannot recreate an expired item.
    conn.execute("SELECT revision FROM sync_clock WHERE id = 1 FOR UPDATE").fetchone()
    expired = conn.execute(
        "SELECT id, data FROM components WHERE deleted = TRUE AND purged = FALSE AND deleted_at <= %s FOR UPDATE",
        (datetime.now(timezone.utc) - timedelta(days=7),),
    ).fetchall()
    for row in expired:
        _purge_component_history(conn, row["id"], row["data"])
        conn.execute(
            "UPDATE components SET data = '{}'::jsonb, purged = TRUE WHERE id = %s",
            (row["id"],),
        )


def list_changes(since: int, limit: int) -> dict[str, Any]:
    with _connection() as conn:
        rows = conn.execute(
            "SELECT revision, component_id, deleted, data FROM change_log "
            "WHERE revision > %s ORDER BY revision LIMIT %s",
            (since, limit),
        ).fetchall()
        changes = [
            {
                "revision": row["revision"],
                "id": str(row["component_id"]),
                "deleted": row["deleted"],
                "component": row["data"],
            }
            for row in rows
        ]
        latest = conn.execute("SELECT revision FROM sync_clock WHERE id = 1").fetchone()
        return {
            "changes": changes,
            "cursor": changes[-1]["revision"] if changes else since,
            "hasMore": bool(changes and changes[-1]["revision"] < latest["revision"]),
        }


def list_archive() -> dict[str, Any]:
    with _connection() as conn:
        _expire_archive(conn)
        rows = conn.execute(
            "SELECT id, data, deleted_at FROM components "
            "WHERE deleted = TRUE AND purged = FALSE ORDER BY deleted_at DESC"
        ).fetchall()
        return {
            "items": [
                {
                    "id": row["id"],
                    "name": row["data"].get("name", ""),
                    "qty": row["data"].get("qty", 0),
                    "deletedAt": row["deleted_at"].isoformat(),
                }
                for row in rows
            ]
        }


def restore_archived_component(
    component_id: str, operation_id: uuid.UUID, actor: Actor
) -> dict[str, Any]:
    _cleanup_expired_archive()
    with _connection() as conn:
        conn.execute("SELECT revision FROM sync_clock WHERE id = 1 FOR UPDATE").fetchone()
        existing = conn.execute(
            "SELECT data, revision, deleted, deleted_at, purged FROM components WHERE id = %s FOR UPDATE",
            (component_id,),
        ).fetchone()
        previous = conn.execute(
            "SELECT response FROM applied_operations WHERE operation_id = %s",
            (operation_id,),
        ).fetchone()
        if previous:
            return previous["response"]
        if existing is None or not existing["deleted"] or existing["purged"]:
            raise HTTPException(status_code=404, detail="Archived component not found")
        if existing["deleted_at"] <= datetime.now(timezone.utc) - timedelta(days=7):
            raise HTTPException(status_code=410, detail="Archive retention has expired")
        revision = _new_revision(conn)
        data = dict(existing["data"])
        data["updated"] = datetime.now(timezone.utc).isoformat()
        conn.execute(
            "UPDATE components SET data = %s, revision = %s, deleted = FALSE, deleted_at = NULL WHERE id = %s",
            (Jsonb(data), revision, component_id),
        )
        response = _record_change(conn, revision, component_id, data, False)
        _record_audit(
            conn,
            actor,
            AuditEvent(
                action="restore",
                component_id=component_id,
                component_name=str(data.get("name", "")),
                changed_fields=[],
                revision=revision,
            ),
            operation_id,
        )
        conn.execute(
            "INSERT INTO applied_operations (operation_id, component_id, response) VALUES (%s, %s, %s)",
            (operation_id, component_id, Jsonb(response)),
        )
        return response


def permanently_delete_archived_component(component_id: str, actor: Actor) -> dict[str, bool]:
    with _connection() as conn:
        _expire_archive(conn)
        archived = conn.execute(
            "SELECT data FROM components WHERE id = %s AND deleted = TRUE AND purged = FALSE FOR UPDATE",
            (component_id,),
        ).fetchone()
        if archived is None:
            return {"deleted": False}
        revision = int(
            conn.execute("SELECT revision FROM components WHERE id = %s", (component_id,)).fetchone()["revision"]
        )
        _record_audit(
            conn,
            actor,
            AuditEvent(
                action="delete_permanently",
                component_id=component_id,
                component_name=str(archived["data"].get("name", "")),
                changed_fields=[],
                revision=revision,
            ),
            None,
        )
        _purge_component_history(conn, component_id, archived["data"])
        conn.execute(
            "UPDATE components SET data = '{}'::jsonb, purged = TRUE WHERE id = %s",
            (component_id,),
        )
        return {"deleted": True}
