-- Private media objects are accessible only to signed-in active accounts.
-- Write permissions remain role gated; client-generated links are time limited.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'component-images',
  'component-images',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create extension if not exists pg_cron with schema extensions;
alter table private.armoury_change_log
  add column if not exists purged boolean not null default false;

drop policy if exists armoury_component_images_read on storage.objects;
drop policy if exists armoury_component_images_insert on storage.objects;
drop policy if exists armoury_component_images_update on storage.objects;
drop policy if exists armoury_component_images_delete on storage.objects;

-- Do not expose direct Storage operations to app clients. The Edge Function
-- verifies both Supabase identity and registered device before using service role.

create or replace function private.armoury_delete_component_image(p_reference text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare object_key text;
begin
  if p_reference like 'storage://component-images/%' then
    object_key := substr(p_reference, length('storage://component-images/') + 1);
    delete from storage.objects where bucket_id = 'component-images' and name = object_key;
  end if;
end;
$$;

create or replace function private.armoury_cleanup_expired_archive()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare expired record;
  next_revision bigint;
begin
  perform 1 from private.armoury_sync_clock where singleton for update;
  for expired in
    select id, data from public.armoury_components
    where deleted and not purged and deleted_at <= now() - interval '7 days'
    for update
  loop
    perform private.armoury_delete_component_image(expired.data ->> 'image');
    update private.armoury_sync_clock set revision = revision + 1
      where singleton returning revision into next_revision;
    -- Replace all historical snapshots with a new permanent purge tombstone.
    delete from private.armoury_change_log
      where component_id = expired.id;
    insert into private.armoury_change_log(revision, component_id, deleted, data, purged)
      values (next_revision, expired.id, true, null, true);
    update private.armoury_applied_operations set response =
      jsonb_set(response, '{component}', 'null'::jsonb, true)
        || jsonb_build_object('deleted', true)
      where component_id = expired.id;
    update public.armoury_components set data = '{}'::jsonb, purged = true
      , revision = next_revision
      where id = expired.id;
  end loop;
end;
$$;

create or replace function public.armoury_authorize_media(
  p_device_id uuid,
  p_write boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, p_write);
  return jsonb_build_object('authorized', true);
end;
$$;
grant execute on function public.armoury_authorize_media(uuid, boolean) to authenticated;

revoke all on function private.armoury_delete_component_image(text) from public, anon, authenticated;
revoke all on function private.armoury_cleanup_expired_archive() from public, anon, authenticated;

drop trigger if exists armoury_component_image_replaced on public.armoury_components;
create or replace function private.armoury_remove_replaced_component_image()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not old.deleted and not new.deleted
     and old.data ->> 'image' is distinct from new.data ->> 'image' then
    perform private.armoury_delete_component_image(old.data ->> 'image');
  end if;
  return new;
end;
$$;
create trigger armoury_component_image_replaced
after update of data on public.armoury_components
for each row execute function private.armoury_remove_replaced_component_image();
revoke all on function private.armoury_remove_replaced_component_image() from public, anon, authenticated;

select cron.schedule(
  'armoury-archive-expiry',
  '*/5 * * * *',
  'select private.armoury_cleanup_expired_archive();'
);

create or replace function public.armoury_list_archive(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare actor record;
begin
  select * into actor from private.armoury_actor(p_device_id, false);
  perform private.armoury_cleanup_expired_archive();
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object('id', id, 'name', coalesce(data ->> 'name', ''),
      'qty', coalesce(data -> 'qty', '0'::jsonb), 'deletedAt', deleted_at)
      order by deleted_at desc)
    from public.armoury_components where deleted and not purged
      and deleted_at > now() - interval '7 days'
  ), '[]'::jsonb));
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
      'deleted', q.deleted, 'purged', q.purged, 'component', q.data) order by q.revision), '[]'::jsonb),
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

create or replace function public.armoury_purge_archived(p_device_id uuid, p_component_id text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor record;
  existing public.armoury_components%rowtype;
  next_revision bigint;
begin
  select * into actor from private.armoury_actor(p_device_id, true);
  perform 1 from private.armoury_sync_clock where singleton for update;
  select * into existing from public.armoury_components c
    where c.id = p_component_id for update;
  if not found or not existing.deleted or existing.purged then
    return jsonb_build_object('deleted', false);
  end if;
  perform private.armoury_delete_component_image(existing.data ->> 'image');
  update private.armoury_sync_clock set revision = revision + 1
    where singleton returning revision into next_revision;
  delete from private.armoury_change_log where component_id = p_component_id;
  insert into private.armoury_change_log(revision, component_id, deleted, data, purged)
    values (next_revision, p_component_id, true, null, true);
  update private.armoury_applied_operations set response =
    jsonb_set(response, '{component}', 'null'::jsonb, true)
      || jsonb_build_object('deleted', true)
    where component_id = p_component_id;
    update public.armoury_components set data = '{}'::jsonb, purged = true,
      revision = next_revision
    where id = p_component_id;
  insert into public.armoury_audit_log(actor_id, actor_email, display_name, device_id,
    device_name, action, component_id, component_name, changed_fields, revision)
  values (actor.user_id, actor.email, actor.display_name, p_device_id, actor.device_name,
    'purge', p_component_id, coalesce(existing.data ->> 'name', ''), '[]'::jsonb,
    next_revision);
  return jsonb_build_object('deleted', true);
end;
$$;
