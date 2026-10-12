from __future__ import annotations

import re
import uuid
from typing import Any

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.auth import Actor, require_device, require_editor
from app.config import ALLOWED_MEDIA_TYPES, MAX_MEDIA_BYTES, MEDIA_DIR

router = APIRouter()

@router.post("/v1/media")
async def upload_media(file: UploadFile = File(...), actor: Actor = Depends(require_editor)) -> dict[str, str]:
    suffix = ALLOWED_MEDIA_TYPES.get(file.content_type or "")
    if suffix is None:
        raise HTTPException(status_code=415, detail="Only JPEG, PNG, and WebP images are supported")
    media_id = uuid.uuid4().hex
    target = MEDIA_DIR / f"{media_id}{suffix}"
    size = 0
    try:
        with target.open("xb") as output:
            first_chunk = True
            while chunk := await file.read(64 * 1024):
                size += len(chunk)
                if size > MAX_MEDIA_BYTES:
                    raise HTTPException(status_code=413, detail="Image exceeds 10 MB limit")
                if first_chunk:
                    signatures = {
                        "image/jpeg": chunk.startswith(b"\xff\xd8\xff"),
                        "image/png": chunk.startswith(b"\x89PNG\r\n\x1a\n"),
                        "image/webp": len(chunk) >= 12 and chunk[:4] == b"RIFF" and chunk[8:12] == b"WEBP",
                    }
                    if not signatures[file.content_type]:
                        raise HTTPException(status_code=415, detail="Image content does not match its media type")
                    first_chunk = False
                output.write(chunk)
            if first_chunk:
                raise HTTPException(status_code=400, detail="Image file is empty")
    except Exception:
        target.unlink(missing_ok=True)
        raise
    finally:
        await file.close()
    return {"path": f"/v1/media/{media_id}{suffix}"}


@router.get("/v1/media/{filename}")
def get_media(filename: str, actor: Actor = Depends(require_device)) -> FileResponse:
    if not re.fullmatch(r"[0-9a-f]{32}\.(jpg|png|webp)", filename):
        raise HTTPException(status_code=404, detail="Image not found")
    target = MEDIA_DIR / filename
    if not target.is_file():
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(target)
