-- COSMOS RLS / ownership test. Run in the Supabase SQL editor (as the postgres role) AFTER the 3 migrations.
-- Everything runs in one transaction that is ROLLED BACK at the end, so no data is left behind.
-- Each check prints "PASS ..." via NOTICE, or aborts with "TEST FAILED ...".
-- Read the NOTICE output; an aborted run means a real security problem.

begin;

-- ---------- setup (as postgres; bypasses RLS) ----------
insert into auth.users (id, instance_id, aud, role, email)
values
 ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent-a@test.invalid'),
 ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent-b@test.invalid');

insert into public.parent_profiles (id, display_name) values
 ('aaaaaaaa-0000-0000-0000-00000000000a', 'Parent A'),
 ('bbbbbbbb-0000-0000-0000-00000000000b', 'Parent B');

insert into public.albums (id, parent_id, name, planet_color) values
 ('a1a1a1a1-0000-0000-0000-0000000000a1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'A Family Planet', '#8065E8'),
 ('b1b1b1b1-0000-0000-0000-0000000000b1', 'bbbbbbbb-0000-0000-0000-00000000000b', 'B Secret Planet', '#FFD76A');

insert into public.media_items (id, parent_id, media_type, file_name) values
 ('b2b2b2b2-0000-0000-0000-0000000000b2', 'bbbbbbbb-0000-0000-0000-00000000000b', 'image', 'b.jpg');

-- ---------- act as Parent A ----------
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set local role authenticated;

do $$ begin
  if (select count(*) from public.albums) <> 1 then
    raise exception 'TEST FAILED: A sees % albums (expected exactly 1)', (select count(*) from public.albums);
  end if;
  if exists (select 1 from public.albums where id = 'b1b1b1b1-0000-0000-0000-0000000000b1') then
    raise exception 'TEST FAILED: A can read B''s album';
  end if;
  if exists (select 1 from public.media_items) then
    raise exception 'TEST FAILED: A can read B''s media record';
  end if;
  if exists (select 1 from public.parent_profiles where id = 'bbbbbbbb-0000-0000-0000-00000000000b') then
    raise exception 'TEST FAILED: A can read B''s profile';
  end if;
  raise notice 'PASS: A only sees own rows';
end $$;

-- A cannot create an album owned by B
do $$ begin
  begin
    insert into public.albums (parent_id, name) values ('bbbbbbbb-0000-0000-0000-00000000000b', 'hijack');
    raise exception 'TEST FAILED: A inserted an album for B';
  exception when insufficient_privilege then
    raise notice 'PASS: A cannot insert album for B';
  end;
end $$;

-- A cannot reassign own album to B (WITH CHECK)
do $$ begin
  begin
    update public.albums set parent_id = 'bbbbbbbb-0000-0000-0000-00000000000b'
      where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
    raise exception 'TEST FAILED: A reassigned own album to B';
  exception when insufficient_privilege then
    raise notice 'PASS: A cannot reassign album ownership';
  end;
end $$;

-- A cannot update or delete B's album (0 rows affected, no error)
do $$
declare n int;
begin
  update public.albums set name = 'pwned' where id = 'b1b1b1b1-0000-0000-0000-0000000000b1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'TEST FAILED: A updated B''s album'; end if;
  delete from public.albums where id = 'b1b1b1b1-0000-0000-0000-0000000000b1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'TEST FAILED: A deleted B''s album'; end if;
  raise notice 'PASS: A cannot update/delete B''s album';
end $$;

-- Own media may go in own album...
do $$ begin
  insert into public.media_items (parent_id, album_id, media_type, file_name)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'a1a1a1a1-0000-0000-0000-0000000000a1', 'image', 'a.jpg');
  raise notice 'PASS: A can put own media in own album';
end $$;

-- ...but NOT in B's album (composite FK) even though the RLS check on parent_id passes
do $$ begin
  begin
    insert into public.media_items (parent_id, album_id, media_type)
    values ('aaaaaaaa-0000-0000-0000-00000000000a', 'b1b1b1b1-0000-0000-0000-0000000000b1', 'image');
    raise exception 'TEST FAILED: A attached media to B''s album';
  exception when foreign_key_violation then
    raise notice 'PASS: cross-parent album_id rejected';
  end;
end $$;

-- storage_path must live in the owner's folder
do $$ begin
  begin
    insert into public.media_items (parent_id, media_type, storage_path)
    values ('aaaaaaaa-0000-0000-0000-00000000000a', 'image',
            'bbbbbbbb-0000-0000-0000-00000000000b/x/y.jpg');
    raise exception 'TEST FAILED: A recorded a storage_path inside B''s folder';
  exception when check_violation then
    raise notice 'PASS: storage_path must be in own folder';
  end;
end $$;

-- Storage: A may upload into own folder, not B's
do $$ begin
  insert into storage.objects (bucket_id, name, owner_id)
  values ('cosmos-media', 'aaaaaaaa-0000-0000-0000-00000000000a/m1/a.jpg', 'aaaaaaaa-0000-0000-0000-00000000000a');
  raise notice 'PASS: A can upload into own folder';
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('cosmos-media', 'bbbbbbbb-0000-0000-0000-00000000000b/m1/evil.jpg', 'aaaaaaaa-0000-0000-0000-00000000000a');
    raise exception 'TEST FAILED: A uploaded into B''s folder';
  exception when insufficient_privilege then
    raise notice 'PASS: A cannot upload into B''s folder';
  end;
end $$;

-- Bucket must be private
reset role;
do $$ begin
  if (select public from storage.buckets where id = 'cosmos-media') is not false then
    raise exception 'TEST FAILED: cosmos-media is public (or missing)';
  end if;
  raise notice 'PASS: cosmos-media is private';
end $$;

-- ---------- act as anon: no access at all ----------
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
do $$ begin
  begin
    perform 1 from public.albums;
    raise exception 'TEST FAILED: anon can query albums';
  exception when insufficient_privilege then
    raise notice 'PASS: anon has no access to albums';
  end;
end $$;
reset role;

rollback;
-- NOTE: if your Supabase version rejects the direct auth.users / storage.objects inserts above
-- (columns vary slightly between versions), adjust the column lists; do NOT weaken the assertions.
-- Also run this manually from the Flutter app with two real accounts before shipping.
