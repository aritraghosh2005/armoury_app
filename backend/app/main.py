from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from app.config import MEDIA_DIR
from app.services.inventory import _cleanup_expired_archive
from app.routes import audit_admin, auth, inventory, media


async def _archive_cleanup_loop() -> None:
    while True:
        await asyncio.to_thread(_cleanup_expired_archive)
        await asyncio.sleep(60 * 60)


@asynccontextmanager
async def lifespan(_: FastAPI):
    MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    cleanup_task = asyncio.create_task(_archive_cleanup_loop())
    try:
        yield
    finally:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass


app = FastAPI(title="Orcus Armoury API", version="1.0.0", lifespan=lifespan)
app.include_router(auth.router)
app.include_router(inventory.router)
app.include_router(media.router)
app.include_router(audit_admin.router)
