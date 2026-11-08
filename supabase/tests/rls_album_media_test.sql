-- Extra RLS / sync checks for migration 04. Run in the SQL editor AFTER migrations 01-04.
-- One transaction, ROLLED BACK at the end. Read the NOTICE output; any failure aborts with TEST FAILED.
begin;

insert into auth.users (id, instance_id, aud, role, email) values
 ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent-a@test.invalid'),
 ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'parent-b@test.invalid');
insert into public.parent_profiles (id) values
 ('aaaaaaaa-0000-0000-0000-00000000000a'), ('bbbbbbbb-0000-0000-0000-00000000000b');
insert into public.albums (id, parent_id, name) values
 ('a1a1a1a1-0000-0000-0000-0000000000a1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'A planet'),
 ('b1b1b1b1-0000-0000-0000-0000000000b1', 'bbbbbbbb-0000-0000-0000-00000000000b', 'B planet');
insert into public.media_items (id, parent_id, media_type) values
 ('a2a2a2a2-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-00000000000a', 'image'),
 ('b2b2b2b2-0000-0000-0000-0000000000b2', 'bbbbbbbb-0000-0000-0000-00000000000b', 'image');
insert into public.album_media (album_id, media_id, parent_id) values
 ('b1b1b1b1-0000-0000-0000-0000000000b1', 'b2b2b2b2-0000-0000-0000-0000000000b2', 'bbbbbbbb-0000-0000-0000-00000000000b');

-- ---------- timestamps (as postgres) ----------
do $$
declare s1 timestamptz; s2 timestamptz; u1 timestamptz; u2 timestamptz;
begin
  select synced_at, updated_at into s1, u1 from public.albums where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  perform pg_sleep(0.05);
  -- client supplies its own (older) updated_at: server keeps it, but still advances synced_at
  update public.albums set name = 'A planet 2', updated_at = '2020-01-01T00:00:00Z' where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  select synced_at, updated_at into s2, u2 from public.albums where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  if u2 <> '2020-01-01T00:00:00Z' then raise exception 'TEST FAILED: server overwrote client updated_at'; end if;
  if s2 <= s1 then raise exception 'TEST FAILED: synced_at did not advance'; end if;
  -- client sends no new updated_at: server bumps it
  update public.albums set name = 'A planet 3' where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  select updated_at into u1 from public.albums where id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  if u1 <= u2 then raise exception 'TEST FAILED: updated_at not bumped when client did not set it'; end if;
  raise notice 'PASS: updated_at (client LWW) and synced_at (server cursor) behave';
end $$;

-- ---------- act as Parent A ----------
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-00000000000a', true);
set local role authenticated;

do $$ begin
  if exists (select 1 from public.album_media) then raise exception 'TEST FAILED: A can read B''s album_media'; end if;
  insert into public.album_media (album_id, media_id, parent_id)
  values ('a1a1a1a1-0000-0000-0000-0000000000a1', 'a2a2a2a2-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-00000000000a');
  raise notice 'PASS: A links own media to own album; sees none of B''s links';
end $$;

do $$ begin
  begin   -- own media -> B's album
    insert into public.album_media (album_id, media_id, parent_id)
    values ('b1b1b1b1-0000-0000-0000-0000000000b1', 'a2a2a2a2-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-00000000000a');
    raise exception 'TEST FAILED: A linked own media into B''s album';
  exception when foreign_key_violation then raise notice 'PASS: cannot link into another parent''s album'; end;
  begin   -- B's media -> own album
    insert into public.album_media (album_id, media_id, parent_id)
    values ('a1a1a1a1-0000-0000-0000-0000000000a1', 'b2b2b2b2-0000-0000-0000-0000000000b2', 'aaaaaaaa-0000-0000-0000-00000000000a');
    raise exception 'TEST FAILED: A linked B''s media';
  exception when foreign_key_violation then raise notice 'PASS: cannot link another parent''s media'; end;
  begin   -- forging parent_id
    insert into public.album_media (album_id, media_id, parent_id)
    values ('b1b1b1b1-0000-0000-0000-0000000000b1', 'b2b2b2b2-0000-0000-0000-0000000000b2', 'bbbbbbbb-0000-0000-0000-00000000000b');
    raise exception 'TEST FAILED: A inserted a row owned by B';
  exception when insufficient_privilege or unique_violation then raise notice 'PASS: cannot forge another parent_id'; end;
end $$;

do $$ declare n int; begin
  update public.album_media set deleted_at = now() where album_id = 'b1b1b1b1-0000-0000-0000-0000000000b1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'TEST FAILED: A tombstoned B''s link'; end if;
  update public.album_media set deleted_at = now() where album_id = 'a1a1a1a1-0000-0000-0000-0000000000a1';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'TEST FAILED: A cannot tombstone own link'; end if;
  raise notice 'PASS: soft-delete works on own links only';
end $$;

-- ---------- anon: nothing ----------
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
do $$ begin
  begin
    perform 1 from public.album_media;
    raise exception 'TEST FAILED: anon can read album_media';
  exception when insufficient_privilege then raise notice 'PASS: anon has no access to album_media'; end;
end $$;
reset role;

rollback;
