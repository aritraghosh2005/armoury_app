from __future__ import annotations

import os

import psycopg
from psycopg.rows import dict_row

from app.config import DATABASE_URL


def connection() -> psycopg.Connection:
    """Open a PostgreSQL connection using the configured URL or PG* settings."""
    if DATABASE_URL:
        return psycopg.connect(DATABASE_URL, row_factory=dict_row)
    return psycopg.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ.get("PGDATABASE", "armoury"),
        user=os.environ.get("PGUSER", "armoury"),
        password=os.environ.get("PGPASSWORD", "armoury_dev"),
        row_factory=dict_row,
    )


def initialize_database() -> None:
    """Compatibility entry point for Docker and existing callers."""
    from app.migrations import run_migrations

    run_migrations()
