from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ComponentWrite(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: str
    component: dict[str, Any]
    operation_id: str = Field(alias="operationId")


class ComponentPatch(BaseModel):
    model_config = ConfigDict(extra="allow")

    changes: dict[str, Any]
    operation_id: str = Field(alias="operationId")


class DeleteWrite(BaseModel):
    model_config = ConfigDict(extra="allow")

    operation_id: str = Field(alias="operationId")


class DeviceRegistration(BaseModel):
    device_id: str = Field(alias="deviceId", min_length=8, max_length=128)
    device_name: str = Field(alias="deviceName", min_length=1, max_length=160)
    platform: str = Field(min_length=1, max_length=40)


class UserAccessUpdate(BaseModel):
    status: str
    role: str


class AuditEvent(BaseModel):
    action: str
    component_id: str
    component_name: str
    changed_fields: list[str]
    revision: int
