-- COSMOS Row Level Security. RLS is enabled on every table; nothing here disables it,
-- and no policy uses USING (true) / WITH CHECK (true).
-- Every policy is `TO authenticated` AND has an ownership predicate (auth alone is not authorization).
-- (select auth.uid()) is wrapped so Postgres evaluates it once per query, not per row.
-- No SECURITY DEFINER functions are used anywhere.

alter table public.parent_profiles enable row level security;
alter table public.albums          enable row level security;
alter table public.media_items     enable row level security;
alter table public.app_settings    enable row level security;
alter table public.achievements    enable row level security;

-- Table privileges: RLS filters rows, GRANTs decide whether the table is reachable at all.
-- anon gets nothing: there is no anonymous access to any COSMOS data.
revoke all on public.parent_profiles, public.albums, public.media_items,
              public.app_settings, public.achievements from anon;
revoke all on public.parent_profiles, public.albums, public.media_items,
              public.app_settings, public.achievements from authenticated;

grant select, insert, update on public.parent_profiles to authenticated;   -- no delete: account deletion goes through Auth
grant select, insert, update, delete on public.albums       to authenticated;
grant select, insert, update, delete on public.media_items  to authenticated;
grant select, insert, update         on public.app_settings to authenticated;
grant select, insert, delete         on public.achievements to authenticated;

-- parent_profiles: key is `id` (= auth.users.id)
create policy parent_profiles_select_own on public.parent_profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy parent_profiles_insert_own on public.parent_profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy parent_profiles_update_own on public.parent_profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- albums
create policy albums_select_own on public.albums
  for select to authenticated using ((select auth.uid()) = parent_id);
create policy albums_insert_own on public.albums
  for insert to authenticated with check ((select auth.uid()) = parent_id);
create policy albums_update_own on public.albums
  for update to authenticated
  using ((select auth.uid()) = parent_id) with check ((select auth.uid()) = parent_id);
create policy albums_delete_own on public.albums
  for delete to authenticated using ((select auth.uid()) = parent_id);

-- media_items (cross-parent album assignment is blocked by the composite FK in the schema migration)
create policy media_items_select_own on public.media_items
  for select to authenticated using ((select auth.uid()) = parent_id);
create policy media_items_insert_own on public.media_items
  for insert to authenticated with check ((select auth.uid()) = parent_id);
create policy media_items_update_own on public.media_items
  for update to authenticated
  using ((select auth.uid()) = parent_id) with check ((select auth.uid()) = parent_id);
create policy media_items_delete_own on public.media_items
  for delete to authenticated using ((select auth.uid()) = parent_id);

-- app_settings
create policy app_settings_select_own on public.app_settings
  for select to authenticated using ((select auth.uid()) = parent_id);
create policy app_settings_insert_own on public.app_settings
  for insert to authenticated with check ((select auth.uid()) = parent_id);
create policy app_settings_update_own on public.app_settings
  for update to authenticated
  using ((select auth.uid()) = parent_id) with check ((select auth.uid()) = parent_id);

-- achievements (unlocks are permanent: no update policy)
create policy achievements_select_own on public.achievements
  for select to authenticated using ((select auth.uid()) = parent_id);
create policy achievements_insert_own on public.achievements
  for insert to authenticated with check ((select auth.uid()) = parent_id);
create policy achievements_delete_own on public.achievements
  for delete to authenticated using ((select auth.uid()) = parent_id);
