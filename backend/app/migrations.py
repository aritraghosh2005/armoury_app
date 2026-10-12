from __future__ import annotations

import psycopg

from app.config import BOOTSTRAP_ADMIN_EMAIL
from app.database import connection


def run_migrations() -> None:
    """Apply the existing idempotent PostgreSQL schema and access migration."""
    with connection() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS sync_clock (
                id SMALLINT PRIMARY KEY CHECK (id = 1),
                revision BIGINT NOT NULL
            )
        """)
        conn.execute("INSERT INTO sync_clock (id, revision) VALUES (1, 0) ON CONFLICT DO NOTHING")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS components (
                id TEXT PRIMARY KEY,
                data JSONB NOT NULL,
                revision BIGINT NOT NULL,
                deleted BOOLEAN NOT NULL DEFAULT FALSE,
                deleted_at TIMESTAMPTZ,
                purged BOOLEAN NOT NULL DEFAULT FALSE
            )
        """)
        conn.execute("ALTER TABLE components ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ")
        conn.execute("ALTER TABLE components ADD COLUMN IF NOT EXISTS purged BOOLEAN NOT NULL DEFAULT FALSE")
        conn.execute("UPDATE components SET deleted_at = NOW() WHERE deleted = TRUE AND deleted_at IS NULL")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS change_log (
                revision BIGINT PRIMARY KEY,
                component_id TEXT NOT NULL,
                deleted BOOLEAN NOT NULL,
                data JSONB
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS applied_operations (
                operation_id UUID PRIMARY KEY,
                component_id TEXT NOT NULL,
                response JSONB NOT NULL
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                google_sub TEXT PRIMARY KEY,
                email TEXT NOT NULL DEFAULT '',
                display_name TEXT NOT NULL DEFAULT '',
                last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                account_status TEXT NOT NULL DEFAULT 'active',
                role TEXT NOT NULL DEFAULT 'editor',
                approved_at TIMESTAMPTZ,
                approved_by TEXT
            )
        """)
        # Existing Google accounts keep their former shared edit access. New
        # enrollments explicitly start pending in register_device().
        conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()")
        conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active'")
        conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'editor'")
        conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ")
        conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS approved_by TEXT")
        if BOOTSTRAP_ADMIN_EMAIL:
            conn.execute(
                "UPDATE users SET role = 'editor' WHERE role = 'admin' AND lower(email) <> %s",
                (BOOTSTRAP_ADMIN_EMAIL,),
            )
        else:
            conn.execute("UPDATE users SET role = 'editor' WHERE role = 'admin'")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS devices (
                device_id TEXT PRIMARY KEY,
                google_sub TEXT NOT NULL REFERENCES users(google_sub) ON DELETE CASCADE,
                device_name TEXT NOT NULL,
                platform TEXT NOT NULL,
                registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                revoked BOOLEAN NOT NULL DEFAULT FALSE
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS audit_log (
                audit_id BIGSERIAL PRIMARY KEY,
                google_sub TEXT NOT NULL,
                email TEXT NOT NULL,
                display_name TEXT NOT NULL,
                device_id TEXT NOT NULL,
                device_name TEXT NOT NULL,
                action TEXT NOT NULL,
                component_id TEXT NOT NULL,
                component_name TEXT NOT NULL,
                changed_fields JSONB NOT NULL,
                revision BIGINT NOT NULL,
                operation_id UUID,
                occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE (operation_id, action)
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS app_access_state (
                id SMALLINT PRIMARY KEY CHECK (id = 1),
                bootstrap_completed BOOLEAN NOT NULL DEFAULT FALSE
            )
        """)
        conn.execute("INSERT INTO app_access_state (id, bootstrap_completed) VALUES (1, FALSE) ON CONFLICT DO NOTHING")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS access_audit_log (
                access_audit_id BIGSERIAL PRIMARY KEY,
                actor_sub TEXT NOT NULL,
                actor_email TEXT NOT NULL,
                target_sub TEXT NOT NULL,
                target_email TEXT NOT NULL,
                action TEXT NOT NULL,
                before JSONB NOT NULL,
                after JSONB NOT NULL,
                device_id TEXT NOT NULL,
                device_name TEXT NOT NULL,
                occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS app_migrations (
                migration_id TEXT PRIMARY KEY,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """)
        access_migration = conn.execute(
            "SELECT 1 FROM app_migrations WHERE migration_id = 'require_account_approval_v1'"
        ).fetchone()
        if access_migration is None:
            conn.execute(
                "INSERT INTO access_audit_log (actor_sub, actor_email, target_sub, target_email, action, before, after, device_id, device_name) "
                "SELECT 'system', 'system', google_sub, email, 'require_approval_migration', "
                "jsonb_build_object('status', account_status, 'role', role), "
                "jsonb_build_object('status', 'pending', 'role', 'viewer'), '', 'system migration' "
                "FROM users WHERE account_status <> 'pending' OR role <> 'viewer'"
            )
            conn.execute(
                "UPDATE users SET account_status = 'pending', role = 'viewer', approved_at = NULL, approved_by = NULL"
            )
            conn.execute(
                "INSERT INTO app_migrations (migration_id) VALUES ('require_account_approval_v1')"
            )
