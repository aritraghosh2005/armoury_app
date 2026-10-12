-- Armoury shared-data foundation for Supabase.
-- Client access is always through authenticated PostgREST/RPC with RLS enabled.
-- Keep server-only data and administrative helpers in the unexposed `private` schema.

create schema if not exists private;

create table if not exists private.bootstrap_admin_allowlist (
  email text primary key check (email = lower(email)),
  created_at timestamptz not null default now()
);

-- Sole administrator bootstrap identity supplied by the owner. The table is not
-- exposed by the Data API and has no grants for anon/authenticated.
insert into private.bootstrap_admin_allowlist(email)
values ('aritraghosh.ag2005@gmail.com')
on conflict (email) do nothing;

create table if not exists public.armoury_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  display_name text not null default '',
  account_status text not null default 'pending'
    check (account_status in ('pending', 'active', 'disabled')),
  role text not null default 'viewer'
    check (role in ('viewer', 'editor', 'admin')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references auth.users(id)
);

create table if not exists public.armoury_devices (
  device_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_name text not null,
  platform text not null,
  registered_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked boolean not null default false
);
create index if not exists armoury_devices_user_idx on public.armoury_devices(user_id);

create table if not exists public.armoury_components (
  id text primary key check (length(id) between 1 and 128),
  data jsonb not null,
  revision bigint not null,
  deleted boolean not null default false,
  deleted_at timestamptz,
  purged boolean not null default false
);

create table if not exists private.armoury_sync_clock (
  singleton boolean primary key default true check (singleton),
  revision bigint not null default 0
);
insert into private.armoury_sync_clock(singleton, revision)
values (true, 0) on conflict (singleton) do nothing;

create table if not exists private.armoury_change_log (
  revision bigint primary key,
  component_id text not null,
  deleted boolean not null,
  data jsonb
);

create table if not exists private.armoury_applied_operations (
  operation_id uuid primary key,
  component_id text not null,
  response jsonb not null
);

create table if not exists public.armoury_audit_log (
  audit_id bigint generated always as identity primary key,
  actor_id uuid not null,
  actor_email text not null,
  display_name text not null,
  device_id uuid not null,
  device_name text not null,
  action text not null,
  component_id text not null,
  component_name text not null default '',
  changed_fields jsonb not null default '[]'::jsonb,
  revision bigint not null,
  operation_id uuid,
  occurred_at timestamptz not null default now(),
  unique (operation_id, action)
);

create table if not exists public.armoury_access_audit_log (
  access_audit_id bigint generated always as identity primary key,
  actor_id uuid not null,
  actor_email text not null,
  target_id uuid not null,
  target_email text not null,
  action text not null,
  before_state jsonb not null,
  after_state jsonb not null,
  device_id uuid not null,
  device_name text not null,
  occurred_at timestamptz not null default now()
);

create or replace function private.sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(coalesce(new.email, ''));
  is_bootstrap_admin boolean;
begin
  is_bootstrap_admin := new.email_confirmed_at is not null and exists (
    select 1 from private.bootstrap_admin_allowlist a where a.email = normalized_email
  );

  insert into public.armoury_users(user_id, email, display_name, account_status, role,
                                   approved_at, approved_by)
  values (
    new.id,
    normalized_email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    case when is_bootstrap_admin then 'active' else 'pending' end,
    case when is_bootstrap_admin then 'admin' else 'viewer' end,
    case when is_bootstrap_admin then now() end,
    case when is_bootstrap_admin then new.id end
  )
  on conflict (user_id) do update set
    email = excluded.email,
    display_name = case when excluded.display_name = '' then public.armoury_users.display_name
                        else excluded.display_name end,
    account_status = case when is_bootstrap_admin then 'active'
                          else public.armoury_users.account_status end,
    role = case when is_bootstrap_admin then 'admin'
                when public.armoury_users.role = 'admin' then 'viewer'
                else public.armoury_users.role end,
    approved_at = case when is_bootstrap_admin then coalesce(public.armoury_users.approved_at, now())
                       else public.armoury_users.approved_at end,
    approved_by = case when is_bootstrap_admin then coalesce(public.armoury_users.approved_by, new.id)
                       else public.armoury_users.approved_by end;

  -- The only identity allowed to bootstrap admin is held in the private table.
  -- Never promote another account through user metadata, RPC arguments, or the app.
  if is_bootstrap_admin then
    update public.armoury_users set role = 'viewer', account_status = 'active'
    where role = 'admin' and user_id <> new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists armoury_auth_user_profile on auth.users;
create trigger armoury_auth_user_profile
after insert or update of email, email_confirmed_at on auth.users
for each row execute function private.sync_auth_user_profile();

create or replace function private.armoury_actor(p_device_id uuid, p_write boolean default false)
returns table(user_id uuid, email text, display_name text, role text, device_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile public.armoury_users%rowtype;
  registered_device public.armoury_devices%rowtype;
begin
  if auth.uid() is null then raise exception using errcode = '42501', message = 'sign_in_required'; end if;
  select * into profile from public.armoury_users u where u.user_id = auth.uid();
  if not found then raise exception using errcode = '42501', message = 'account_pending'; end if;
  if profile.account_status = 'pending' then raise exception using errcode = '42501', message = 'account_pending'; end if;
  if profile.account_status <> 'active' then raise exception using errcode = '42501', message = 'account_disabled'; end if;
  if p_write and profile.role not in ('editor', 'admin') then
    raise exception using errcode = '42501', message = 'read_only';
  end if;
  select * into registered_device from public.armoury_devices d
    where d.device_id = p_device_id and d.user_id = auth.uid() and not d.revoked;
  if not found then raise exception using errcode = '42501', message = 'device_not_registered'; end if;
  update public.armoury_devices set last_seen_at = now() where device_id = p_device_id;
  update public.armoury_users set last_seen_at = now() where public.armoury_users.user_id = auth.uid();
  return query select profile.user_id, profile.email, profile.display_name,
                      profile.role, registered_device.device_name;
end;
$$;

create or replace function public.armoury_register_device(
  p_device_id uuid, p_device_name text, p_platform text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  u public.armoury_users%rowtype;
  existing_user uuid;
begin
  if auth.uid() is null then raise exception using errcode = '42501', message = 'sign_in_required'; end if;
  select * into u from public.armoury_users where user_id = auth.uid();
  if not found then raise exception using errcode = '42501', message = 'account_pending'; end if;
  select user_id into existing_user from public.armoury_devices where device_id = p_device_id for update;
  if existing_user is not null and existing_user <> auth.uid() then
    raise exception using errcode = '23505', message = 'device_already_registered';
  end if;
  insert into public.armoury_devices(device_id, user_id, device_name, platform)
  values (p_device_id, auth.uid(), left(coalesce(p_device_name, 'Armoury device'), 120), left(coalesce(p_platform, 'unknown'), 40))
  on conflict (device_id) do update set device_name = excluded.device_name,
    platform = excluded.platform, last_seen_at = now(), revoked = false;
  update public.armoury_users set last_seen_at = now() where user_id = auth.uid();
  return jsonb_build_object('registered', true, 'email', u.email,
    'displayName', u.display_name, 'status', u.account_status, 'role', u.role);
end;
$$;

create or replace function public.armoury_current_access()
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object('email', u.email, 'displayName', u.display_name,
    'status', u.account_status, 'role', u.role)
  from public.armoury_users u where u.user_id = auth.uid()
$$;

-- Browser/mobile users can read only their own access profile. All writes to the
-- profile, component, device, and audit records are via the guarded RPC functions.
alter table public.armoury_users enable row level security;
alter table public.armoury_devices enable row level security;
alter table public.armoury_components enable row level security;
alter table public.armoury_audit_log enable row level security;
alter table public.armoury_access_audit_log enable row level security;

drop policy if exists armoury_users_read_self on public.armoury_users;
create policy armoury_users_read_self on public.armoury_users
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists armoury_components_read_active on public.armoury_components;
create policy armoury_components_read_active on public.armoury_components
  for select to authenticated using (
    not deleted and exists (
      select 1 from public.armoury_users u where u.user_id = (select auth.uid())
        and u.account_status = 'active'
    )
  );
drop policy if exists armoury_audit_read_active on public.armoury_audit_log;
create policy armoury_audit_read_active on public.armoury_audit_log
  for select to authenticated using (exists (
    select 1 from public.armoury_users u where u.user_id = (select auth.uid())
      and u.account_status = 'active'
  ));
drop policy if exists armoury_access_audit_admin_read on public.armoury_access_audit_log;
create policy armoury_access_audit_admin_read on public.armoury_access_audit_log
  for select to authenticated using (exists (
    select 1 from public.armoury_users u where u.user_id = (select auth.uid())
      and u.account_status = 'active' and u.role = 'admin'
  ));

revoke all on schema private from public, anon, authenticated;
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on public.armoury_users, public.armoury_devices, public.armoury_components,
  public.armoury_audit_log, public.armoury_access_audit_log from anon, authenticated;
-- Inventory, audit, archive, and admin data are read through RPCs that verify
-- device registration. Only the signed-in user's own pending/active profile is
-- directly readable, so knowing the publishable key alone never exposes data.
grant select on public.armoury_users to authenticated;
grant usage on schema public to authenticated;
grant execute on function public.armoury_register_device(uuid, text, text) to authenticated;
grant execute on function public.armoury_current_access() to authenticated;

create or replace function public.armoury_apply_operation(
  p_device_id uuid,
  p_operation_id uuid,
  p_component_id text,
  p_kind text,
  p_component jsonb default null,
  p_changes jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  current_row public.armoury_components%rowtype;
  response jsonb;
  component_data jsonb;
  field_name text;
  next_revision bigint;
  now_utc timestamptz := now();
begin
  if p_component_id is null or length(btrim(p_component_id)) not between 1 and 128 then
    raise exception using errcode = '22023', message = 'invalid_component_id';
  end if;
  if p_kind not in ('create', 'patch', 'delete', 'restore') then
    raise exception using errcode = '22023', message = 'invalid_operation_kind';
  end if;
  select * into actor from private.armoury_actor(p_device_id, true);

  -- The singleton row lock serializes accepted operations through commit. The
  -- feed's revision order therefore cannot skip a transaction allocated earlier.
  select revision into next_revision from private.armoury_sync_clock
    where singleton for update;
  select response into response from private.armoury_applied_operations
    where operation_id = p_operation_id;
  if found then return response; end if;

  select * into current_row from public.armoury_components
    where id = p_component_id for update;

  if p_kind = 'create' then
    if found then
      if current_row.deleted then
        raise exception using errcode = '23505', message = 'component_id_tombstoned';
      end if;
      response := jsonb_build_object('revision', current_row.revision, 'id', p_component_id,
        'deleted', false, 'component', current_row.data);
      insert into private.armoury_applied_operations values (p_operation_id, p_component_id, response);
      return response;
    end if;
    if jsonb_typeof(coalesce(p_component, '{}'::jsonb)) <> 'object' then
      raise exception using errcode = '22023', message = 'invalid_component';
    end if;
    component_data := coalesce(p_component, '{}'::jsonb) - 'id' - 'created' - 'updated';
    component_data := component_data || jsonb_build_object('id', p_component_id,
      'created', now_utc, 'updated', now_utc);
  elsif p_kind = 'patch' then
    if not found or current_row.deleted then
      raise exception using errcode = 'P0002', message = 'component_not_active';
    end if;
    if jsonb_typeof(coalesce(p_changes, '{}'::jsonb)) <> 'object' then
      raise exception using errcode = '22023', message = 'invalid_component_patch';
    end if;
    for field_name in select jsonb_object_keys(coalesce(p_changes, '{}'::jsonb)) loop
      if field_name not in ('namespace', 'category', 'subcategory', 'name', 'qty', 'desc',
                            'pic', 'image', 'location', 'specs', 'status', 'tags') then
        raise exception using errcode = '22023', message = 'invalid_component_field';
      end if;
    end loop;
    component_data := (current_row.data || coalesce(p_changes, '{}'::jsonb))
      || jsonb_build_object('id', p_component_id, 'updated', now_utc);
  elsif p_kind = 'restore' then
    if not found or not current_row.deleted or current_row.purged
       or current_row.deleted_at <= now_utc - interval '7 days' then
      raise exception using errcode = 'P0002', message = 'archive_unavailable';
    end if;
    component_data := (current_row.data || coalesce(p_component, '{}'::jsonb) - 'id' - 'created')
      || jsonb_build_object('id', p_component_id,
        'created', current_row.data -> 'created', 'updated', now_utc);
  else
    if found and current_row.deleted then
      response := jsonb_build_object('revision', current_row.revision, 'id', p_component_id,
        'deleted', true, 'component', null);
      insert into private.armoury_applied_operations values (p_operation_id, p_component_id, response);
      return response;
    end if;
    update private.armoury_sync_clock set revision = revision + 1
      where singleton returning revision into next_revision;
    if current_row.id is null then
      insert into public.armoury_components(id, data, revision, deleted, deleted_at)
      values (p_component_id, '{}'::jsonb, next_revision, true, now_utc);
    else
      update public.armoury_components set revision = next_revision, deleted = true,
        deleted_at = now_utc where id = p_component_id;
    end if;
    insert into private.armoury_change_log(revision, component_id, deleted, data)
      values (next_revision, p_component_id, true, null);
    response := jsonb_build_object('revision', next_revision, 'id', p_component_id,
      'deleted', true, 'component', null);
    insert into public.armoury_audit_log(actor_id, actor_email, display_name, device_id,
      device_name, action, component_id, component_name, changed_fields, revision, operation_id)
    values (actor.user_id, actor.email, actor.display_name, p_device_id, actor.device_name,
      'delete', p_component_id, coalesce(current_row.data ->> 'name', ''), '[]'::jsonb,
      next_revision, p_operation_id) on conflict (operation_id, action) do nothing;
    insert into private.armoury_applied_operations values (p_operation_id, p_component_id, response);
    return response;
  end if;

  update private.armoury_sync_clock set revision = revision + 1
    where singleton returning revision into next_revision;
  if p_kind = 'create' then
    insert into public.armoury_components(id, data, revision, deleted, deleted_at, purged)
      values (p_component_id, component_data, next_revision, false, null, false);
  else
    update public.armoury_components set data = component_data, revision = next_revision,
      deleted = false, deleted_at = null, purged = false where id = p_component_id;
  end if;
  insert into private.armoury_change_log(revision, component_id, deleted, data)
    values (next_revision, p_component_id, false, component_data);
  response := jsonb_build_object('revision', next_revision, 'id', p_component_id,
    'deleted', false, 'component', component_data);
  insert into public.armoury_audit_log(actor_id, actor_email, display_name, device_id,
    device_name, action, component_id, component_name, changed_fields, revision, operation_id)
  values (actor.user_id, actor.email, actor.display_name, p_device_id, actor.device_name,
    case p_kind when 'create' then 'create' when 'restore' then 'restore' else 'modify' end,
    p_component_id, coalesce(component_data ->> 'name', ''),
    case when p_kind = 'patch' then (select coalesce(jsonb_agg(k), '[]'::jsonb)
      from jsonb_object_keys(coalesce(p_changes, '{}'::jsonb)) k)
      else (select coalesce(jsonb_agg(k), '[]'::jsonb)
        from jsonb_object_keys(component_data - 'id' - 'created' - 'updated') k) end,
    next_revision, p_operation_id) on conflict (operation_id, action) do nothing;
  insert into private.armoury_applied_operations values (p_operation_id, p_component_id, response);
  return response;
end;
$$;

create or replace function public.armoury_changes_since(
  p_device_id uuid, p_since bigint default 0, p_limit integer default 200
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  items jsonb;
  returned_cursor bigint;
  latest bigint;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  select coalesce(jsonb_agg(jsonb_build_object('revision', q.revision, 'id', q.component_id,
      'deleted', q.deleted, 'component', q.data) order by q.revision), '[]'::jsonb),
      max(q.revision)
    into items, returned_cursor
    from (select * from private.armoury_change_log where revision > greatest(p_since, 0)
      order by revision limit least(greatest(p_limit, 1), 500)) q;
  select revision into latest from private.armoury_sync_clock where singleton;
  return jsonb_build_object('changes', items,
    'cursor', coalesce(returned_cursor, p_since),
    'hasMore', coalesce(returned_cursor, p_since) < latest);
end;
$$;

create or replace function public.armoury_list_archive(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  -- Purge expired details opportunistically on archive access, while leaving
  -- their ID tombstones in place to block stale offline resurrection.
  perform 1 from private.armoury_sync_clock where singleton for update;
  update private.armoury_change_log l set data = null
    from public.armoury_components c
    where c.id = l.component_id and c.deleted and not c.purged
      and c.deleted_at <= now() - interval '7 days' and l.deleted;
  update private.armoury_applied_operations o set response =
    jsonb_set(o.response, '{component}', 'null'::jsonb, true) || jsonb_build_object('deleted', true)
    from public.armoury_components c
    where c.id = o.component_id and c.deleted and not c.purged
      and c.deleted_at <= now() - interval '7 days';
  update public.armoury_components set data = '{}'::jsonb, purged = true
    where deleted and not purged and deleted_at <= now() - interval '7 days';
  -- Keep the archive projection deliberately limited to name and quantity.
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('id', id, 'name', coalesce(data ->> 'name', ''),
      'qty', coalesce(data -> 'qty', '0'::jsonb), 'deletedAt', deleted_at)
      order by deleted_at desc)
    from public.armoury_components where deleted and not purged
      and deleted_at > now() - interval '7 days'
  ), '[]'::jsonb));
end;
$$;

create or replace function public.armoury_restore_archived(
  p_device_id uuid, p_component_id text, p_operation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  existing public.armoury_components%rowtype;
  response jsonb;
  next_revision bigint;
  restored jsonb;
begin
  select * into actor from private.armoury_actor(p_device_id, true);
  perform 1 from private.armoury_sync_clock where singleton for update;
  select o.response into response from private.armoury_applied_operations o
    where o.operation_id = p_operation_id;
  if found then return response; end if;
  select * into existing from public.armoury_components c
    where c.id = p_component_id for update;
  if not found or not existing.deleted or existing.purged
     or existing.deleted_at <= now() - interval '7 days' then
    raise exception using errcode = 'P0002', message = 'archive_unavailable';
  end if;
  update private.armoury_sync_clock set revision = revision + 1
    where singleton returning revision into next_revision;
  restored := existing.data || jsonb_build_object('updated', now());
  update public.armoury_components set data = restored, revision = next_revision,
    deleted = false, deleted_at = null where id = p_component_id;
  insert into private.armoury_change_log(revision, component_id, deleted, data)
    values (next_revision, p_component_id, false, restored);
  response := jsonb_build_object('revision', next_revision, 'id', p_component_id,
    'deleted', false, 'component', restored);
  insert into private.armoury_audit_log(actor_id, actor_email, display_name, device_id,
    device_name, action, component_id, component_name, changed_fields, revision, operation_id)
  values (actor.user_id, actor.email, actor.display_name, p_device_id, actor.device_name,
    'restore', p_component_id, coalesce(restored ->> 'name', ''), '[]'::jsonb,
    next_revision, p_operation_id) on conflict (operation_id, action) do nothing;
  insert into private.armoury_applied_operations values (p_operation_id, p_component_id, response);
  return response;
end;
$$;

create or replace function public.armoury_purge_archived(p_device_id uuid, p_component_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  existing public.armoury_components%rowtype;
begin
  select * into actor from private.armoury_actor(p_device_id, true);
  select * into existing from public.armoury_components c
    where c.id = p_component_id for update;
  if not found or not existing.deleted or existing.purged then
    return jsonb_build_object('deleted', false);
  end if;
  if existing.data ->> 'image' like '%/%' then
    delete from storage.objects where bucket_id = 'component-images'
      and name = regexp_replace(existing.data ->> 'image', '^.*/', '');
  end if;
  update private.armoury_change_log set data = null
    where component_id = p_component_id and deleted;
  delete from private.armoury_change_log
    where component_id = p_component_id and not deleted;
  update private.armoury_applied_operations set response =
    jsonb_set(response, '{component}', 'null'::jsonb, true) || jsonb_build_object('deleted', true)
    where component_id = p_component_id;
  update public.armoury_components set data = '{}'::jsonb, purged = true
    where id = p_component_id;
  insert into public.armoury_audit_log(actor_id, actor_email, display_name, device_id,
    device_name, action, component_id, component_name, changed_fields, revision)
  values (actor.user_id, actor.email, actor.display_name, p_device_id, actor.device_name,
    'purge', p_component_id, coalesce(existing.data ->> 'name', ''), '[]'::jsonb,
    existing.revision);
  return jsonb_build_object('deleted', true);
end;
$$;

create or replace function public.armoury_admin_list_users(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  if actor.role <> 'admin' or not exists (
    select 1 from private.bootstrap_admin_allowlist a
      where a.email = actor.email
  ) then raise exception using errcode = '42501', message = 'admin_required'; end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'userId', u.user_id, 'email', u.email, 'displayName', u.display_name,
      'status', u.account_status, 'role', u.role, 'createdAt', u.created_at,
      'lastSeenAt', u.last_seen_at,
      'devices', coalesce((select jsonb_agg(jsonb_build_object('name', d.device_name,
        'platform', d.platform, 'lastSeenAt', d.last_seen_at) order by d.last_seen_at desc)
        from public.armoury_devices d where d.user_id = u.user_id and not d.revoked), '[]'::jsonb)
    ) order by (u.account_status = 'pending') desc, u.created_at desc)
    from public.armoury_users u
  ), '[]'::jsonb));
end;
$$;

create or replace function public.armoury_admin_set_user(
  p_device_id uuid, p_target_id uuid, p_status text, p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  target public.armoury_users%rowtype;
  before_state jsonb;
  after_state jsonb;
  action_name text;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  if actor.role <> 'admin' or not exists (
    select 1 from private.bootstrap_admin_allowlist a where a.email = actor.email
  ) then raise exception using errcode = '42501', message = 'admin_required'; end if;
  if p_status not in ('active', 'disabled') or p_role not in ('viewer', 'editor') then
    raise exception using errcode = '22023', message = 'invalid_access_assignment';
  end if;
  select * into target from public.armoury_users where user_id = p_target_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'user_not_found'; end if;
  if target.role = 'admin' then raise exception using errcode = '23514', message = 'admin_role_is_fixed'; end if;
  if target.account_status = p_status and target.role = p_role then
    return jsonb_build_object('updated', false, 'status', target.account_status, 'role', target.role);
  end if;
  before_state := jsonb_build_object('status', target.account_status, 'role', target.role);
  after_state := jsonb_build_object('status', p_status, 'role', p_role);
  action_name := case
    when target.account_status = 'pending' and p_status = 'active' then 'approve'
    when p_status = 'disabled' then 'disable'
    when target.account_status = 'disabled' and p_status = 'active' then 'reactivate'
    else 'role_change' end;
  update public.armoury_users set account_status = p_status, role = p_role,
    approved_at = case when p_status = 'active' and account_status <> 'active' then now() else approved_at end,
    approved_by = case when p_status = 'active' and account_status <> 'active' then actor.user_id else approved_by end
    where user_id = p_target_id;
  insert into public.armoury_access_audit_log(actor_id, actor_email, target_id, target_email,
    action, before_state, after_state, device_id, device_name)
  values (actor.user_id, actor.email, p_target_id, target.email, action_name,
    before_state, after_state, p_device_id, actor.device_name);
  return jsonb_build_object('updated', true, 'status', p_status, 'role', p_role);
end;
$$;

create or replace function public.armoury_admin_audit(p_device_id uuid, p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  if actor.role <> 'admin' or not exists (
    select 1 from private.bootstrap_admin_allowlist a where a.email = actor.email
  ) then raise exception using errcode = '42501', message = 'admin_required'; end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('actorEmail', actor_email,
      'targetEmail', target_email, 'action', action, 'before', before_state,
      'after', after_state, 'deviceName', device_name, 'occurredAt', occurred_at)
      order by access_audit_id desc)
    from (select * from public.armoury_access_audit_log
      order by access_audit_id desc limit least(greatest(p_limit, 1), 500)) q
  ), '[]'::jsonb));
end;
$$;

create or replace function public.armoury_audit(p_device_id uuid, p_limit integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('email', email, 'displayName', display_name,
      'deviceName', device_name, 'action', action, 'componentName', component_name,
      'changedFields', changed_fields, 'revision', revision, 'occurredAt', occurred_at)
      order by audit_id desc)
    from (select * from public.armoury_audit_log order by audit_id desc
      limit least(greatest(p_limit, 1), 500)) q
  ), '[]'::jsonb));
end;
$$;

grant execute on function public.armoury_apply_operation(uuid, uuid, text, text, jsonb, jsonb) to authenticated;
grant execute on function public.armoury_changes_since(uuid, bigint, integer) to authenticated;
grant execute on function public.armoury_list_archive(uuid) to authenticated;
grant execute on function public.armoury_restore_archived(uuid, text, uuid) to authenticated;
grant execute on function public.armoury_purge_archived(uuid, text) to authenticated;
grant execute on function public.armoury_admin_list_users(uuid) to authenticated;
grant execute on function public.armoury_admin_set_user(uuid, uuid, text, text) to authenticated;
grant execute on function public.armoury_admin_audit(uuid, integer) to authenticated;
grant execute on function public.armoury_audit(uuid, integer) to authenticated;
