from __future__ import annotations

from typing import Any

import psycopg
from fastapi import APIRouter, Depends, HTTPException

from app.auth import Actor, require_device, require_editor
from app.database import connection as _connection
from app.schemas import ComponentPatch, ComponentWrite, DeleteWrite
from app.services.inventory import (
    _apply_operation,
    list_archive,
    list_changes,
    permanently_delete_archived_component as _permanently_delete_archived_component,
    restore_archived_component as _restore_archived_component,
    _valid_operation_id,
    _valid_record_id,
)

router = APIRouter()

@router.get("/health")
def health() -> dict[str, str]:
    try:
        with _connection() as conn:
            conn.execute("SELECT 1")
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return {"status": "ok"}


@router.get("/v1/changes")
def get_changes(since: int = 0, limit: int = 200, actor: Actor = Depends(require_device)) -> dict[str, Any]:
    if since < 0:
        raise HTTPException(status_code=422, detail="since must be non-negative")
    limit = min(max(limit, 1), 500)
    return list_changes(since, limit)


@router.post("/v1/components")
def create_component(body: ComponentWrite, actor: Actor = Depends(require_editor)) -> dict[str, Any]:
    component_id = _valid_record_id(body.id)
    operation_id = _valid_operation_id(body.operation_id)
    return _apply_operation(operation_id, component_id, "create", component=body.component, actor=actor)


@router.put("/v1/components/{component_id}/restore")
def restore_component(component_id: str, body: ComponentWrite, actor: Actor = Depends(require_editor)) -> dict[str, Any]:
    normalized_id = _valid_record_id(component_id)
    if _valid_record_id(body.id) != normalized_id:
        raise HTTPException(status_code=422, detail="body id must match path id")
    return _apply_operation(
        _valid_operation_id(body.operation_id), normalized_id, "restore", component=body.component, actor=actor,
    )


@router.patch("/v1/components/{component_id}")
def patch_component(component_id: str, body: ComponentPatch, actor: Actor = Depends(require_editor)) -> dict[str, Any]:
    return _apply_operation(
        _valid_operation_id(body.operation_id),
        _valid_record_id(component_id),
        "patch",
        changes=body.changes, actor=actor,
    )


@router.delete("/v1/components/{component_id}")
def delete_component(component_id: str, body: DeleteWrite, actor: Actor = Depends(require_editor)) -> dict[str, Any]:
    return _apply_operation(
        _valid_operation_id(body.operation_id),
        _valid_record_id(component_id),
        "delete", actor=actor,
    )


@router.get("/v1/archive")
def get_archive(actor: Actor = Depends(require_device)) -> dict[str, Any]:
    return list_archive()


@router.post("/v1/archive/{component_id}/restore")
def restore_archived_component(component_id: str, body: DeleteWrite, actor: Actor = Depends(require_editor)) -> dict[str, Any]:
    component_id = _valid_record_id(component_id)
    operation_id = _valid_operation_id(body.operation_id)
    return _restore_archived_component(component_id, operation_id, actor)


@router.delete("/v1/archive/{component_id}")
def permanently_delete_archived_component(component_id: str, actor: Actor = Depends(require_editor)) -> dict[str, bool]:
    component_id = _valid_record_id(component_id)
    return _permanently_delete_archived_component(component_id, actor)
