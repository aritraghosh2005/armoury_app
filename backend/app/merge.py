from __future__ import annotations

from typing import Any


COMPONENT_FIELDS = {
    "namespace", "category", "subcategory", "name", "qty", "desc", "pic",
    "image", "location", "specs", "status", "tags", "created", "updated",
}


def normalize_component(component_id: str, component: dict[str, Any]) -> dict[str, Any]:
    """Return an independent component payload with its stable ID enforced."""
    result = {key: value for key, value in component.items() if key in COMPONENT_FIELDS}
    result["id"] = component_id
    return result


def apply_component_patch(
    component_id: str,
    current: dict[str, Any],
    changes: dict[str, Any],
) -> dict[str, Any]:
    """Apply only submitted fields to the latest server-side component state."""
    result = dict(current)
    for key, value in changes.items():
        if key in COMPONENT_FIELDS:
            result[key] = value
    result["id"] = component_id
    return result
