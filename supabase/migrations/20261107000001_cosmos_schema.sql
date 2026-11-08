-- COSMOS schema. Non-destructive: only CREATE statements, no DROP/TRUNCATE/ALTER of existing objects.

-- ---------------------------------------------------------------------------
-- Shared helper: keep updated_at fresh. SECURITY INVOKER (default), empty search_path.
-- ---------------------------------------------------------------------------
create function public.cosmos_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8.1 parent_profiles  (created by the client on first login; see RLS file)
-- ---------------------------------------------------------------------------
create table public.parent_profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) between 1 and 80),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 8.2 albums ("planets")
-- ---------------------------------------------------------------------------
create table public.albums (
  id           uuid primary key default gen_random_uuid(),   -- client may supply its own id (idempotent sync)
  parent_id    uuid not null references public.parent_profiles (id) on delete cascade,
  name         text not null check (char_length(btrim(name)) between 1 and 60),
  planet_theme text check (planet_theme is null or char_length(planet_theme) <= 32),
  planet_color text check (planet_color is null or planet_color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Target for the composite FK below: lets media_items prove album and media share one owner.
  constraint albums_id_parent_id_key unique (id, parent_id)
);
create index albums_parent_id_idx on public.albums (parent_id);

-- ---------------------------------------------------------------------------
-- 8.3 media_items  (METADATA ONLY; storage_path is set only after a successful, parent-approved upload)
-- ---------------------------------------------------------------------------
create table public.media_items (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid not null references public.parent_profiles (id) on delete cascade,
  album_id     uuid,
  file_name    text check (file_name is null or char_length(file_name) <= 255),
  media_type   text not null check (media_type in ('image', 'video')),
  storage_path text,
  captured_at  timestamptz,
  is_favorite  boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  -- Ownership guard: (album_id, parent_id) must match an album owned by the SAME parent.
  -- MATCH SIMPLE (default) skips the check when album_id is NULL.
  -- Deleting an album only nulls album_id (column-list SET NULL needs Postgres 15+, which Supabase runs).
  constraint media_items_album_owner_fkey
    foreign key (album_id, parent_id)
    references public.albums (id, parent_id)
    on delete set null (album_id),

  -- A cloud path must live under the owner's own folder: {user_id}/{media_id}/{filename}
  constraint media_items_storage_path_owner_chk
    check (storage_path is null or storage_path like (parent_id::text || '/%'))
);
create index media_items_parent_id_idx        on public.media_items (parent_id);
create index media_items_album_id_idx         on public.media_items (album_id) where album_id is not null;
create index media_items_parent_favorite_idx  on public.media_items (parent_id) where is_favorite;
create index media_items_parent_captured_idx  on public.media_items (parent_id, captured_at desc);

-- ---------------------------------------------------------------------------
-- 8.4 app_settings  (one row per parent)
-- ---------------------------------------------------------------------------
create table public.app_settings (
  id                 uuid primary key default gen_random_uuid(),
  parent_id          uuid not null unique references public.parent_profiles (id) on delete cascade,
  selected_theme     text check (selected_theme is null or char_length(selected_theme) <= 32),
  animations_enabled boolean not null default true,
  sound_enabled      boolean not null default false,
  cloud_sync_enabled boolean not null default false,
  updated_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 8.5 achievements
-- ---------------------------------------------------------------------------
create table public.achievements (
  id               uuid primary key default gen_random_uuid(),
  parent_id        uuid not null references public.parent_profiles (id) on delete cascade,
  achievement_code text not null check (char_length(achievement_code) between 1 and 64),
  unlocked_at      timestamptz not null default now(),
  constraint achievements_parent_code_key unique (parent_id, achievement_code)
);
create index achievements_parent_id_idx on public.achievements (parent_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create trigger parent_profiles_set_updated_at before update on public.parent_profiles
  for each row execute function public.cosmos_set_updated_at();
create trigger albums_set_updated_at before update on public.albums
  for each row execute function public.cosmos_set_updated_at();
create trigger media_items_set_updated_at before update on public.media_items
  for each row execute function public.cosmos_set_updated_at();
create trigger app_settings_set_updated_at before update on public.app_settings
  for each row execute function public.cosmos_set_updated_at();
