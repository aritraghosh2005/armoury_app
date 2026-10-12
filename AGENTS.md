# Agent instructions for Orcus Armoury

## Active backend choice (owner confirmed)

- Supabase is the central backend for Auth, Postgres, private image Storage, and RPC-based inventory operations. This owner decision supersedes older FastAPI/standalone-Postgres deployment language elsewhere in this document and in historical README text. Keep FastAPI/Compose only as legacy/reference work until explicitly removed; do not connect the Flutter app to it or deploy it as the production backend.
- Use Supabase Auth email/password accounts with email confirmation by OTP. Do not use Google OAuth, Google Cloud OAuth clients, or a Google tester allowlist. Supabase owns session persistence and refresh. Supabase SQL/RLS/RPC is authoritative for approval, device registration, roles, audit, revisions, tombstones, and archive retention. The only admin remains the server-side allowlisted `aritraghosh.ag2005@gmail.com`; only its confirmed-email event may bootstrap it as admin.
- `supabase start` is the local development environment and uses Docker Desktop. Production uses a hosted Supabase project; end users install the APK and do not install Docker or enter endpoint settings. Release builds receive only the Supabase project URL and publishable key as build configuration. Never ship SMTP credentials, Supabase secret/service-role key, database password, or signing key in the app.

## Project context

- This repository is a Flutter/Dart mobile app (`pubspec.yaml`, Dart SDK constraint `^3.13.2`), not an Android Room application. It uses Riverpod 3, `sqflite`/SQLite, `dio`, image picker, local file storage, and ZIP backup/restore.
- The app stores component rows in the local `armoury_local.db`; attached images are copied into app documents. `assets/initial_data/current_components.zip` is the bundled starter catalog. Import it once on a genuinely empty installation through `IComponentRepository.create`, so normal timestamps and sync operations are generated. Never hardcode copies of its rows in Dart, overwrite a non-empty/previously-used catalog, or replace stable IDs. Copy bundled photos into app-private component storage. Backup/restore packages the database and media.
- Existing structure: `lib/screens` and `lib/widgets` are presentation; `lib/providers/viewmodels` holds Riverpod ViewModels; `lib/core/repositories` contains repository interfaces/implementations; `lib/core/database` contains SQLite access; `lib/core/media_service.dart` and `lib/services/backup_service.dart` implement device IO and backup. `Component` is in `lib/models/component.dart`.
- Current tests are `test/widget_test.dart`, `test/pixel_theme_transition_test.dart`, and `test/backup_service_test.dart`. CI in `.github/workflows/build_release.yml` runs `flutter analyze` and `flutter test` before Android release builds.
- `README.md` has historical/aspirational architecture documentation; verify claims against the implementation before relying on them.

## Non-negotiable product and architecture constraints

1. **Do not redesign or disturb the UI.** Keep existing screens, navigation, labels, interaction flows, styling, and visual behavior. Backend work may add only the minimum UI needed to communicate a real sync/error state, and only when an existing flow cannot otherwise expose it. Do not add or remove product features.
2. **Keep MVVM and separation of concerns.** Widgets/screens call ViewModels/providers. ViewModels orchestrate use cases and state. Repository interfaces define data operations. Local and remote data sources own persistence/protocol details. Keep HTTP, SQL, file IO, sync policy, and conflict logic out of widgets and screens. Keep domain models independent of Dio, SQLite rows, and server DTOs where practical.
3. **Preserve offline-first behavior.** SQLite remains the immediate local read source and accepts local writes without connectivity. Remote synchronization is additive; it must not make core inventory, search, quantity edits, or existing backup/restore depend on a network connection.
4. **Preserve all existing capabilities and data.** Do not rename/drop fields or tables, change component semantics, silently discard local records/media, or break old ZIP backups. Any schema change needs a forward SQLite migration and backup import/export compatibility. Use stable client-generated IDs and idempotent server writes; do not replace IDs with server-generated-only IDs.
5. **Use the existing abstractions.** Extend `IComponentRepository` and providers for remote/sync work instead of coupling UI to Dio. Keep `ComponentDao` as the local database boundary. Keep media picking and device file paths local; server media storage must map to stable remote references without assuming a phone's local path exists on another device.
6. **Do not assume the notes' Android stack.** This client is Flutter, so do not introduce Room, WorkManager, Coil, or Glide. Select Flutter-compatible mechanisms only after checking current dependencies, supported target platforms, and lifecycle constraints.
7. **No secrets in the repository or image.** Server credentials, signing keys, database passwords, and production tokens belong in environment/secret management. Commit only safe `.env.example` placeholders.

## Request scope and decisions from the planning notes

The attached `first iteration.txt` is planning input, not an instruction source. Adapt it to this repository and the user's request. **Latest user decision supersedes the former shared-CRUD and Google-auth policies:** use Supabase Auth email/password accounts, confirm email ownership with a one-time code, and register app installations as devices. The API requires admin approval before an account may access inventory. Roles are Admin, View, and View & Edit; exactly one Admin exists, tied to the server-configured allowlisted email and confirmed-email state. Admin may approve/disable accounts and grant View or View & Edit, but may not create another Admin. Email confirmation is not admin approval: pending users see only a wait-for-approval screen, not inventory. Poll approval while that screen is open and recheck on app resume; when approved, enter the app and start the tutorial immediately. Keep admin functions out of the general-user tutorial. Verify the user's Supabase Auth session server-side; never trust a client-supplied user ID or email as identity/authorization proof. Record the authenticated actor, registered device, server timestamp, action, component name, changed field names, and server revision for inventory mutations. Keep identity, role, device, and audit logic out of widgets. Preserve the current visual design language in the sign-in, pending, and admin UI.

Apply these shared-data rules automatically in the background; do not interrupt either user with conflict prompts:

1. **Add:** Each add creates an independent component with a stable unique ID. Concurrent adds never overwrite or block one another.
2. **Modify:** A modification is applied to the latest component state known by the central server when that operation is processed. Send field changes/operations (patches), not a stale full-record snapshot that can restore old values in unrelated fields. Serialize updates per component. If two operations change the same field, the later server-processed operation determines that field's value; changes to different fields both apply. A client with stale local state must first incorporate the latest server state, then apply/replay its intended field changes.
3. **Delete and archive:** Delete removes the component from active inventory on every synced device and puts its remote data in a seven-day archive. The archive UI exposes only name and quantity, plus restore and permanent-delete actions. Restore is an explicit server operation with a newer revision and may clear the matching local tombstone; delayed edits from before deletion must not resurrect it. On expiry or permanent delete, erase archived details but keep the ID tombstone indefinitely. Adding the same-looking item creates a new ID.

Use server-assigned ordering/revisions or an equivalent serialized operation log to make these rules deterministic; do not compare device clocks. Sync must be idempotent and tolerate retries, duplicate/reordered delivery, offline changes, and reconnects while converging every client to the server's resulting state. This product rule does not require Yjs or a general-purpose CRDT; do not add CRDT machinery unless a later requirement needs it. Keep behavior automatic and do not change the existing screens.

The delivered client should be **download and ready to use**: the released app must point to the hosted Supabase project using build configuration. Users should not need to install Docker or configure a server URL. Sign-up uses email/password and OTP confirmation; inventory access then awaits admin approval. Docker is needed only for the local Supabase CLI stack, not for app users. Keep explicit development endpoint overrides for maintainers.

## Latest product decisions

- Keep the product name Armoury. Do not show internal component IDs in user-facing UI.
- Preserve the current UI style and 65:35 Config/content split. Archive replaces Config inside that pane; its back action returns to Config, and the settings control returns to Config when Archive is open.
- Add Admin as another Config-pane subview that slides in like Archive, retains the same split and visual treatment, and has a dedicated return-to-Config action. Only active admins see or can open it.
- Roles: `viewer` can browse/search inventory and view archive/activity; `editor` has viewer access plus component create/modify/archive/restore and permanent archive deletion; `admin` has editor access plus approve/disable users and assign only `viewer` or `editor`. Exactly one Admin is the server-configured email after Supabase confirms ownership; the client and API must never grant another Admin. Server authorization is authoritative; disabled controls in Flutter are only presentation.
- A confirmed Supabase Auth session registers/refreshes the installation and returns account access state. New users confirm email with a six-digit OTP before proceeding; this proves address control but does not grant inventory access. Pending or disabled users do not receive inventory, archive, media, delta, or audit data. Existing locally cached data is available offline only to an installation with a previously approved cached role; approval/revocation takes effect on a server check/reconnect. Pending state must refresh automatically while the waiting screen is open and on resume. The tutorial must start on first entry after approval, including approval detected while the app is open, and tutorial completion must be tracked per Supabase account. Never let an offline entry path bypass a first-time account's pending state.
- Establish the sole admin via a server-only email allowlist and Supabase Auth's confirmed-email state; never let a user self-assign admin or expose a bootstrap endpoint. Only that configured identity may use admin endpoints or see the Admin pane. Preserve an operator-only recovery procedure if that email is misconfigured.
- Keep an append-only access audit for admin approval, denial/disable, reactivation, and role changes. Admin user rows show display name/email, status/role, device count, and last-seen time; do not expose Supabase user/device IDs in UI.
- Keep EDIT and PURGE actions in the component card footer, outside the image. Do not overlay edit/delete controls on list images in normal view; image upload/removal belongs in the component editor. The card's PURGE action follows the archive workflow, so it moves the component to the seven-day archive rather than deleting it permanently.
- First launch shows the current tutorial, not a ZIP import prompt. Bump the tutorial version when users need to see updated instructions.
- Backup UI is download-only: export one ZIP package containing an inventory CSV (including created/updated date-time values and relative image-file references) plus every referenced component photo. Do not expose ZIP import/restore controls. Legacy ZIP parsing may remain for compatibility but is not a user-facing workflow.
- Store created/updated server timestamps in UTC and show local date and time. The archive overview shows only name and quantity, with deleted records retained remotely for seven days.
- Double-tap search must work on open inventory areas without hijacking controls or scrolling.
- Use `assets/res/armoury_logo.svg` as the source artwork for Android launcher icons. Android launcher icons use a constant white background and black SVG mark in every system theme. Preserve the submitted SVG path geometry; omit only its full-canvas black backdrop from adaptive foreground and legacy density PNGs. Android 8+ uses a proper adaptive icon with a transparent, generously scaled foreground vector. Do not nest a square icon inside a second launcher tile or leave excessive empty padding. Preserve the original Orcus ASCII insignia in the in-app wallpaper (`AnimatedOrcusLogo`); do not replace the background insignia with the Armoury icon.

Treat Supabase as the central hosted backend and Docker as the local Supabase CLI runtime, not as a replacement for the Flutter mobile UI. Do not build a separate production API/Compose deployment unless a concrete Supabase limitation justifies it. Do not containerize an Android emulator or claim that Docker runs the installed mobile app. Keep local Flutter commands and Android release CI usable. The production app build must have hosted Supabase URL and publishable key configured so installation requires no endpoint or credential setup.

## Required test and validation loop

After each generated implementation batch (a coherent code change, not every individual keystroke), run the checks relevant to that batch before proceeding. Do not defer failures or claim unrun checks passed.

```powershell
flutter pub get
flutter analyze
flutter test
```

For Supabase changes, also apply and test database migrations against the local Supabase stack. If an environment lacks Flutter, Docker, or a required service, report that plainly and run the available checks. Preserve and fix failures introduced by the change; do not weaken tests or analysis settings to hide regressions.

Backend checks for this repository are:

```powershell
python -m compileall -q backend/app backend/tests
python -m unittest discover -s backend/tests -v
docker compose --env-file .env.example -f compose.yaml config --quiet
docker compose --env-file .env.example -f compose.yaml -f compose.dev.yaml config --quiet
```

The app's former FastAPI tests may be run as legacy regression checks, but they do not validate the selected Supabase backend. For Supabase, start the local stack with `npx supabase start`, apply pending migrations with `npx supabase migration up --local`, and run database regression tests with `npx supabase test db` when available.

When changing persistence/sync/archive/backup/auth/roles, validation must cover old database migration, offline create/update/delete, retry/idempotency, media references, concurrent add independence, modifications against fresh state, same-field update ordering, delete-versus-edit precedence, stale-edit non-resurrection, revisioned archive restore, seven-day expiry, ZIP/CSV export content, invalid email OTP rejection, confirmed-email bootstrap security, registered-device enforcement, viewer/editor/admin route matrix, pending/disabled denial, sole-admin bootstrap and non-transferability, approval polling/resume, tutorial entry after approval per account, admin-action audit, inventory audit attribution and duplicate-operation audit idempotency. Add regression tests alongside each new behavior. UI regression tests must verify existing navigation and flows remain intact; visual snapshots are useful for changes near layout but do not justify a redesign.

## Project-grounded migration plan

Work in reviewable phases. Do not skip discovery or combine the whole migration into one code-generation batch.

### Phase 0 — baseline and contracts

- Trace every component operation from UI through `ArmouryViewModel`, `IComponentRepository`, `ComponentRepository`, `ComponentDao`, and SQLite. Trace image lifecycle through `MediaViewModel`/`IMediaRepository`/`MediaService`, and backup/restore through `BackupService` and its UI providers.
- Inventory every existing feature and data field from `Component`, all screens/sheets, database schema/migrations, settings, and tests. Record the exact local behavior that must remain.
- Inspect Android platform integration, target platforms, current Flutter/Gradle versions, and any remaining `dio` usage. Supabase Auth/Postgres/Storage is the central backend; Docker runs only the local Supabase CLI stack.
- Specify the API contract, error model, Supabase Auth email/password and OTP confirmation, device registration, pending/active/disabled lifecycle, bootstrap-admin procedure, role-to-route matrix, access-audit schema, media upload/download contract, seven-day archive/tombstone semantics, and serialized patch/update ordering before implementing a client. Keep component fields and existing CRUD semantics; apply the latest product decisions above when older plan wording differs.

### Phase 1 — Supabase foundation

- Keep schema and policy changes in ordered Supabase migrations under `supabase/migrations/`. Use local `supabase start`/`supabase stop` for development and tests; do not create a second production API unless Supabase limits or product requirements demonstrate the need.
- Use Supabase Auth email/password with confirmation OTP, private Supabase Storage for component media, RLS for tables/objects, and SECURITY DEFINER RPCs for device-checked business operations. Never ship a service-role key to a client. Production Auth email delivery requires configured SMTP for public users. Production TLS, Postgres backups, and object storage are managed by the hosted Supabase project.
- Keep local and hosted project configuration distinct. Require confirmed email for sign-up and send a numeric OTP, not an email link. Local email is captured by Mailpit; check migration application and rollback/recovery instructions; set the sole admin identity in server-side configuration. Local publishable keys are for local development only.
- Add Supabase migration/database tests and Flutter analyze/test to CI without breaking Android release builds. Document local CLI commands, hosted-project linking/pushing, email OTP/SMTP setup, and how an Android emulator or physical device reaches the local Supabase API.

### Phase 2 — stable API and server persistence

- Model the complete existing component fields (`id`, namespace, category, subcategory, name, quantity, description, icon/pic, image reference, location, specs, status, tags, created, updated) and preserve their current meanings. Keep actor attribution in audit metadata; do not add per-record ownership or authorization fields.
- Use client-generated stable IDs and idempotent RPC operations so retries cannot duplicate rows. Validate payloads and image type/size in database/RPC and Storage policies. Store image bytes in private Supabase Storage and persist stable object references in metadata.
- Provide Supabase RPC operations covering every existing client operation. Add paging and search only to support current inventory/search behavior; do not change visible semantics. Require a valid Supabase Auth session, a registered device, approved account status, and route-appropriate role for every data operation. Do not add per-record ownership or workspace restrictions.
- Migrate existing authenticated accounts without silently deleting records or audit history. New users default to pending; bootstrap the sole Admin from the server-configured allowlisted email only after Supabase confirms it. Demote any stale admin assignment that does not match that identity; never offer or accept Admin assignment in the app/API. Enforce role/status checks centrally on every data/media/audit route, including restore and permanent purge; add Admin-only user listing, approval/disable, and View/View & Edit assignment endpoints with an append-only access audit.
- Persist ordered, idempotent component operations or equivalent revisioned state. Apply modifications to the latest server state and retain deletion tombstones; reject or ignore updates after deletion so stale clients cannot resurrect records. Do not use device timestamps to order changes. No user-facing conflict resolution is part of the product.
- Make deletion syncable (tombstones/soft delete) and define retention/cleanup. A hard delete alone cannot propagate removal to offline clients.

### Phase 3 — Flutter data and offline synchronization

- Extend local schema through versioned SQLite migrations with sync metadata (for example pending/synced/error state, operation/revision metadata, tombstone state, and a durable sync cursor). Keep old installs and ZIP backups readable.
- Implement the Supabase RPC/Storage client and remote repository behind interfaces. Compose local and remote sources in a repository/sync coordinator; do not put Supabase calls in ViewModels or widgets. Configure Supabase URL and publishable key per build/runtime environment without embedding server secrets.
- Local writes should commit to SQLite first, then be queued for retry. Upload pending records and their media safely to Supabase Storage; make retries idempotent. Do not mark a record synced until RPC acknowledgement and required media upload are complete. Preserve local image access if upload fails.
- Ship the hosted Supabase URL and publishable key in release configuration so a freshly installed app connects without developer setup. Preserve developer-only overrides. Require Supabase email/password authentication and email OTP confirmation for shared sync, while retaining local-first operation and queued offline writes for the signed-in identity.
- Pull server changes incrementally and reconcile SQLite by stable ID and server revision/operation order, never by blindly uploading or applying a stale full snapshot. Handle tombstones, stale cursors, pagination, initial sync, retries/backoff, duplicate/reordered events, and connectivity restoration while ensuring updates are not lost or deleted records resurrected.
- A bare PostgreSQL `bigserial`/sequence is **not automatically a commit-safe sync cursor**: transaction sequence values can be allocated and committed out of order, so a client advancing past a higher value can miss a later-committing lower value. The Supabase change feed must serialize revision allocation through commit or use an equivalent safe watermark; test concurrent transactions. Keep push notifications advisory; every notification should only trigger the same durable delta pull.
- Retain local search and local browsing while offline. If catalog size eventually requires server search/paging, preserve the current search fields and filtering behavior and still make already-cached results useful offline.

### Phase 4 — media, backup, and cross-device behavior

- Keep capture/pick behavior and local image availability intact. Upload compressed media (the current picker caps at 1600px and quality 88) with resumable/retry-safe semantics as needed; use stable server media IDs and lazy remote retrieval/cache. Do not expose private local paths as server identifiers.
- Keep internal compatibility with older ZIP data if required for migration, but do not expose ZIP import in the current backup UI. The user-facing export is one downloadable ZIP bundle of CSV and component photos, not a database backup. Document server-side database and media backup/restore separately.

### Phase 5 — multi-instance updates and operations (only when justified)

- Start with durable polling/delta sync on the hosted Supabase project. Add Realtime/FCM or another change signal only after durable pull sync works and deployment requirements justify it. Signals never carry component data and never replace delta sync.
- If Supabase Realtime is used later, confirm authorization and missed-event recovery against the durable RPC delta feed. Use push only after Flutter lifecycle and platform configuration are designed. Account for best-effort push, reconnects, missed signals, debouncing, and periodic/app-open sync.
- Do not add Redis, load balancing across multiple API instances, shared-workspace ACLs, FCM topics, or cache layers just because they appear in the notes. Add each only against a demonstrated requirement. Avoid caching authenticated or user-specific responses without a correct cache key and invalidation policy.
- Add rate limits, observability, Supabase database/storage backup drills, migration recovery procedures, and deployment/health documentation before production rollout.

## Change workflow

### Bundled starter inventory

- Use `assets/initial_data/current_components.zip` as the sole source for the initial inventory. Do not add component names, IDs, quantities, tags, or other starter records as hardcoded Dart defaults.
- On first launch only, when the local inventory and sync history are genuinely empty, import records through `IComponentRepository.create` with their stable bundled IDs. This gives each record ordinary local creation/update timestamps and queues it for sync exactly like a user-created record.
- Copy only referenced bundled images into the app's private `component_images` directory and rewrite their paths before repository creation. Do not use the source device's old absolute paths.
- Make import retry-safe across interrupted launches. Existing components, tombstones, or sync history must prevent seeding; never overwrite user data. If a matching stable ID already exists or is tombstoned, skip it.
- Keep regression coverage for one-time import, repository/sync-path use, image copying, retry behavior, and preservation of existing catalogs.

- Before editing, inspect relevant code and repository status. Preserve unrelated user changes (including untracked files).
- Implement one phase-sized slice at a time. State assumptions when product/security/deployment requirements are absent; do not invent new UI/features to resolve them.
- Keep changes focused, update docs with real commands, and update/add regression tests for each behavior. After each slice, run the validation loop above and report exact results.
- Do not claim the backend is central, synchronized, or production-ready until the corresponding server, persistence, retry/conflict, backup, deployment, and preconfigured release endpoint are implemented and verified. Do not claim authentication is active until Supabase Auth OTP confirmation, device registration, and audit logging are verified.

## Unblock the user instead of concluding

- When a required command, service, build, or test cannot proceed because of an environment/setup issue (for example, Docker Desktop is installed but its engine is stopped, or Gradle cannot bind a loopback connection), do not treat that as a final conclusion or simply stop at the error.
- Explain in plain language what the error means, give the user the exact next action and copyable commands for their environment, and ask them to run the relevant step and share its output. Resume the task from that output; do not ask them to repeat steps that already succeeded.
- Separate commands that must be run independently into distinct code blocks or clearly numbered steps. Never combine commands from different tools (such as `docker compose ...` and a PowerShell `Invoke-RestMethod` health check) into one pasted command unless explicitly joined with correct shell syntax.
- Continue any independent work that does not depend on the user's action. State which verification is pending and why; do not imply success or failure for checks that have not completed.
- Prefer actionable recovery instructions over declaring the environment unavailable. If a workaround is needed, explain its scope and how to remove/reset it after use.
