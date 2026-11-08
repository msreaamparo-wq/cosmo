-- COSMOS v2: multi-device sync (soft-delete tombstones), many-to-many album_media, richer planets.
-- ADDITIVE: adds columns/tables/policies only. Run AFTER migrations 01-03. Nothing is dropped.
-- (The only existing object replaced is the cosmos_set_updated_at() trigger function from migration 01.)

-- ---------------------------------------------------------------------------
-- albums: description, cover, icon (emoji sticker), tombstone, server sync cursor
-- ---------------------------------------------------------------------------
alter table public.albums
  add column description    text check (description is null or char_length(description) <= 500),
  add column cover_media_id uuid,   -- plain uuid, no FK: the cover photo may sync after the album
  add column icon           text check (icon is null or char_length(icon) <= 16),
  add column deleted_at     timestamptz,
  add column synced_at      timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- media_items: mime type, size, tombstone, server sync cursor
-- ---------------------------------------------------------------------------
alter table public.media_items
  add column mime_type  text check (mime_type is null or char_length(mime_type) <= 100),
  add column file_size  bigint check (file_size is null or file_size >= 0),
  add column deleted_at timestamptz,
  add column synced_at  timestamptz not null default now();

-- Target for album_media's ownership foreign key.
alter table public.media_items add constraint media_items_id_parent_id_key unique (id, parent_id);

-- ---------------------------------------------------------------------------
-- album_media: many-to-many link. Both ends must belong to the SAME parent.
-- ---------------------------------------------------------------------------
create table public.album_media (
  album_id   uuid not null,
  media_id   uuid not null,
  parent_id  uuid not null references public.parent_profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  synced_at  timestamptz not null default now(),
  primary key (album_id, media_id),
  constraint album_media_album_owner_fkey foreign key (album_id, parent_id)
    references public.albums (id, parent_id) on delete cascade,
  constraint album_media_media_owner_fkey foreign key (media_id, parent_id)
    references public.media_items (id, parent_id) on delete cascade
);

-- Indexes: ownership lookups + the incremental pull cursor (parent_id, synced_at).
create index album_media_parent_id_idx   on public.album_media (parent_id);
create index album_media_media_id_idx    on public.album_media (media_id);
create index album_media_parent_sync_idx on public.album_media (parent_id, synced_at);
create index albums_parent_sync_idx      on public.albums      (parent_id, synced_at);
create index media_items_parent_sync_idx on public.media_items (parent_id, synced_at);

-- ---------------------------------------------------------------------------
-- Timestamps
--  updated_at : CLIENT clock, used for last-writer-wins. The server only bumps it when the client did not.
--  synced_at  : SERVER clock, always now(). Devices pull "synced_at > my cursor", so a change made
--               offline yesterday and uploaded today is still picked up by every other device.
-- ---------------------------------------------------------------------------
create or replace function public.cosmos_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

create function public.cosmos_set_synced_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.synced_at := now();
  return new;
end;
$$;

create trigger albums_set_synced_at before insert or update on public.albums
  for each row execute function public.cosmos_set_synced_at();
create trigger media_items_set_synced_at before insert or update on public.media_items
  for each row execute function public.cosmos_set_synced_at();
create trigger album_media_set_synced_at before insert or update on public.album_media
  for each row execute function public.cosmos_set_synced_at();
create trigger album_media_set_updated_at before update on public.album_media
  for each row execute function public.cosmos_set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS for album_media (same ownership model as every other table)
-- ---------------------------------------------------------------------------
alter table public.album_media enable row level security;

revoke all on public.album_media from anon;
revoke all on public.album_media from authenticated;
grant select, insert, update, delete on public.album_media to authenticated;

create policy album_media_select_own on public.album_media
  for select to authenticated using ((select auth.uid()) = parent_id);
create policy album_media_insert_own on public.album_media
  for insert to authenticated with check ((select auth.uid()) = parent_id);
create policy album_media_update_own on public.album_media
  for update to authenticated
  using ((select auth.uid()) = parent_id) with check ((select auth.uid()) = parent_id);
create policy album_media_delete_own on public.album_media
  for delete to authenticated using ((select auth.uid()) = parent_id);
