# Legacy Armoury API Reference

> This FastAPI/PostgreSQL service is retained only as historical reference. The current Flutter app uses Supabase Auth, Postgres, Storage, and RPCs. Do not connect the app to this service or deploy it as the production backend. Its Google ID-token authentication is obsolete and must not be used for new accounts or releases.

FastAPI + PostgreSQL service for the shared component catalog. Google sign-in verifies a Google ID token and registers the installation as a device. New accounts are pending until approved. Roles are `viewer`, `editor`, and `admin`; exactly one admin identity is allowed, from `ARMOURY_BOOTSTRAP_ADMIN_EMAIL`, and the API does not allow assigning admin to another account. The API checks account status and role on every route. Every accepted component mutation and admin access change is attributed to the verified Google account and registered device in durable audit logs. PostgreSQL uses a separate limited `armoury_app` database role for API reads/writes, while the one-shot Compose migration service uses the administrative role for schema setup.

## Backend layout

- `app/main.py` wires the FastAPI app and HTTP endpoints.
- `app/config.py` centralizes environment-backed settings.
- `app/auth.py` verifies Google identity and enforces registered-device, account, editor, and sole-admin access.
- `app/database.py` owns PostgreSQL connection configuration and schema initialization/migrations.
- `app/migrations.py` applies the idempotent PostgreSQL schema and one-time data migration.
- `app/schemas.py` owns validated request models and audit event data.
- `app/routes/` groups HTTP handlers by device registration, inventory/archive, media, and audit/admin access. Inventory handlers validate request values and delegate behavior to services.
- `app/services/inventory.py` owns shared component-operation ordering, PostgreSQL inventory transactions, audit writes, and archive expiry/purge operations.
- `app/main.py` owns app lifecycle and router composition.
- `app/merge.py` contains the component field allowlist and latest-state patch rules.
- `app/migrate.py` is the one-shot schema initialization entry point used by Docker.
- `tests/` contains pure merge tests and opt-in API integration tests. The test Compose override enables fake identities only for the disposable integration stack.

## Local run

From the repository root, copy `.env.example` to `.env`, replace both database passwords and `GOOGLE_SERVER_CLIENT_ID` with the Google Web OAuth client ID, and set `ARMOURY_BOOTSTRAP_ADMIN_EMAIL` to your Google-verified email. Keep this value stable: it is the only account allowed to use admin routes. On its first registration, the configured account becomes the sole admin. Then run:

```powershell
docker compose -f compose.yaml -f compose.dev.yaml up --build -d
Invoke-RestMethod http://localhost:8000/health
docker compose -f compose.yaml -f compose.dev.yaml down
```

The local development override publishes the API on port 8000. The production Compose profile publishes the Caddy HTTPS/HTTP proxy; the API and database are private to the Compose network. On a production server, start with `docker compose --profile production up -d --build`, set `PUBLIC_HOST` to its DNS name, and allow inbound ports 80 and 443 for certificate issuance and HTTPS. Configure an Android OAuth client in Google Cloud for the application package and signing certificate SHA-1, plus a Web OAuth client ID used as `GOOGLE_SERVER_CLIENT_ID` in the server and `ARMOURY_GOOGLE_SERVER_CLIENT_ID` in Flutter builds. Do not commit client tokens or server secrets. The server verifies Google issuer, expiry and audience, and validates each `X-Armoury-Device-ID` against the signed-in account.

## API

- `GET /health`
- `POST /v1/auth/devices/register` — verify Google ID token, register/update this installation, and return account display information.
- `GET /v1/admin/users`, `PATCH /v1/admin/users/{google-subject}` — admin-only account list, approval/disable, and role assignment. The subject is an internal API key and is not shown in the app.
- `GET /v1/admin/audit` — admin-only access-change history.
- Authenticated API requests use `Authorization: Bearer <Google ID token>` and `X-Armoury-Device-ID: <registered installation ID>`.
- `GET /v1/changes?since=<revision>&limit=<1..500>` — ordered durable change feed.
- `POST /v1/components` — create with stable `id`, full `component`, and UUID `operationId`.
- `PATCH /v1/components/{id}` — apply only changed fields from `changes` against the latest stored component, with UUID `operationId`.
- `DELETE /v1/components/{id}` — soft-delete with UUID `operationId`; active clients remove it and server retains it in Archive for seven days.
- `GET /v1/archive` — deleted component overview (ID is only an action key; response includes name, quantity, deletion time).
- `POST /v1/archive/{id}/restore` — explicitly restore a retained archive record; emits a newer sync revision.
- `DELETE /v1/archive/{id}` — permanently remove its data while retaining a non-resurrectable ID tombstone.
- `PUT /v1/components/{id}/restore` — legacy internal ZIP compatibility endpoint; not used by the current app backup screen.
- `POST /v1/media` — upload a JPEG, PNG, or WebP image up to 10 MiB; returns a stable media path.
- `GET /v1/media/{filename}` — retrieve uploaded media.
- `GET /v1/audit?limit=<1..500>` — recent actor, device, action, component name, changed fields, revision, and server time (no internal component IDs returned).

Component writes are idempotent by `operationId`. The server serializes write transactions and assigns revisions while holding a transaction-scoped clock-row lock, so committed revisions are gap-safe and ordered. Archive expiry runs hourly and on archive access. After seven days, component history/media data is erased while the ID tombstone remains in the sync feed to prevent resurrection. Database and media use separate persistent Docker volumes; back them up together. The app's export is a downloadable CSV list, not a server or media backup. Example database dump:

Component audit rows are stored in `audit_log`; access decisions are stored in `access_audit_log`. Repeated operation IDs do not create duplicate component audit entries. Permanent archive deletion is recorded before retained data is purged. Pending and disabled users, viewers attempting writes, non-admins attempting access management, and requests from unregistered devices are rejected. The test-only auth bypass exists only in `compose.test.yaml` and is guarded by `APP_ENV=testing`; never deploy that Compose override. If bootstrap configuration is lost, restore it through the protected server environment and register that configured account; there is no public admin-promotion route.

```powershell
docker compose exec -T db pg_dump -U armoury_admin armoury > armoury.sql
```

Copy the `media_data` volume at the same time as the SQL dump and retain both as one backup set; restoring only the database can leave component image links without image files.

## Checks

```powershell
python -m unittest discover -s backend/tests -v
docker compose -f compose.yaml config
docker compose -f compose.yaml -f compose.dev.yaml config
docker compose --env-file .env.example -f compose.yaml -f compose.dev.yaml -f compose.test.yaml config --quiet
```

For the API/database integration check, start with `docker compose --env-file .env.example -f compose.yaml -f compose.dev.yaml -f compose.test.yaml up --build -d --wait`, set `$env:ARMOURY_TEST_API_URL='http://localhost:8000'`, then run `python -m unittest discover -s backend/tests -v`. The test override uses a fake identity only in its isolated test environment. Keep production secrets out of source control.
