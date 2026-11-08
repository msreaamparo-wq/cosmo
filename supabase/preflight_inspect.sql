-- COSMOS preflight (READ-ONLY). Run this in the Supabase SQL editor BEFORE the
-- migrations. It changes nothing. If any COSMOS table already exists, review
-- its shape first: the migrations use plain CREATE TABLE (no IF NOT EXISTS) on
-- purpose, so they fail loudly instead of silently skipping or overwriting.

select table_schema, table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('parent_profiles','albums','media_items','app_settings','achievements')
order by table_name;

select id, name, public
from storage.buckets
where id = 'cosmos-media';

select schemaname, tablename, policyname
from pg_policies
where (schemaname = 'public'
       and tablename in ('parent_profiles','albums','media_items','app_settings','achievements'))
   or (schemaname = 'storage' and tablename = 'objects' and policyname like 'cosmos_%');
