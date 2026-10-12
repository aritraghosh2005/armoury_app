from __future__ import annotations

import os
from pathlib import Path


DATABASE_URL = os.environ.get("DATABASE_URL")
MEDIA_DIR = Path(os.environ.get("MEDIA_DIR", "/data/media"))
MAX_MEDIA_BYTES = 10 * 1024 * 1024
GOOGLE_SERVER_CLIENT_ID = os.environ.get("GOOGLE_SERVER_CLIENT_ID", "").strip()
BOOTSTRAP_ADMIN_EMAIL = os.environ.get("ARMOURY_BOOTSTRAP_ADMIN_EMAIL", "").strip().lower()
ALLOWED_MEDIA_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
