-- Private backup bucket + Storage RLS.
-- Object path convention: {user_id}/{media_id}/{filename}  ->  first folder must equal auth.uid().
-- Run as the project owner (SQL editor / `supabase db push`); storage.objects already has RLS enabled by Supabase.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cosmos-media', 'cosmos-media', false,
  104857600,  -- 100 MB per object; adjust to your plan's limits
  array['image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif',
        'video/mp4','video/quicktime','video/3gpp','video/webm']
)
on conflict (id) do nothing;   -- never overwrite an existing bucket's configuration

-- SELECT (download / signed URLs)
create policy cosmos_media_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'cosmos-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- INSERT (upload)
create policy cosmos_media_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'cosmos-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- UPDATE (needed for upsert/replace together with INSERT + SELECT)
create policy cosmos_media_update_own on storage.objects
  for update to authenticated
  using      (bucket_id = 'cosmos-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'cosmos-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- DELETE
create policy cosmos_media_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'cosmos-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- No anon policies exist, so the bucket has no public or anonymous access.
