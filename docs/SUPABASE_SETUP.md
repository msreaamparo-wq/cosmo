# Supabase setup (optional cloud)

COSMOS works fully without this.

1. **Inspect first.** SQL Editor → run `supabase/preflight_inspect.sql` (read-only). If any COSMOS table already exists with a different shape, stop and review.
2. **Migrations,** in order (SQL editor or `supabase db push`): `…01_cosmos_schema`, `…02_cosmos_rls`, `…03_cosmos_storage`, `…04_cosmos_sync_v2`.
3. **Run the tests:** `supabase/tests/rls_ownership_test.sql` then `rls_album_media_test.sql`. Every line must print `PASS`. Each runs in a transaction that is rolled back. If an insert into `auth.users` / `storage.objects` fails because column lists differ in your version, adjust the columns, not the assertions.
4. **Authentication:** Dashboard → Authentication → Providers: enable Email. Decide whether email confirmation is required (the app handles both). For password-reset emails set Authentication → URL Configuration → Site URL to where the app is served. (Native deep links for Android are not implemented, so the reset link opens in the browser.)
5. **Storage:** migration 03 creates the private bucket `cosmos-media` (100 MB/object, image+video MIME types) and owner-only policies on `{user_id}/…` paths. Confirm in Dashboard → Storage that it shows as **Private**.
6. **App configuration:** pass only the project URL and the **publishable** key:
   `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…`
   Never use or commit a service-role/secret key.
7. **Manual cross-account test:** create two parent accounts in the app, back up a photo from each, and confirm neither can see the other's planets/photos (and that downloading the other's `cosmos-media/{id}/…` path fails).

Backup uploads read the whole file into memory; files over 50 MB are skipped and reported.
