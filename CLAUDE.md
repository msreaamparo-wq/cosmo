# COSMOS: project guide (for Claude Code or any developer)

Flutter app, Android + Chrome. A child-friendly photo memory gallery ("photos = stars, albums = planets").
Local-first SQLite; optional parent-controlled cloud on Supabase. Tagline: "Your Memories, Your Little Universe."

## Non-negotiable rules
1. Never upload media automatically. Backup is an explicit parent action; mark "backed up" only after the upload succeeds.
2. Never put a service-role/secret key in the app. URL + PUBLISHABLE key come from `--dart-define`.
3. Never disable RLS or use `USING (true)` on private data. No SECURITY DEFINER shortcuts.
4. Do not drop/alter existing Supabase tables except via additive migrations. Run `supabase/preflight_inspect.sql` first.
5. Deleting a planet never deletes media. Removing media never touches the original in the device gallery.
6. Local media and cloud media are separate concepts (`MediaModel` is local; `cloud_path` is only a pointer to a backup copy).
7. The parent gate is a child barrier, NOT authentication. Never call it secure.
8. No ads/tracking/analytics/location/social/public sharing. Do not claim COPPA/GDPR-K compliance.
9. No dead buttons, no mock gallery data, no invented dates (`captured_at` is NULL when unknown).
10. Report only checks you actually ran, with real output.

## STATUS: what was verified and what was not
VERIFIED (executed against real SQLite in the authoring sandbox):
- `lib/database/schema.dart`: fresh v2 creates; v1→v2 upgrade yields identical tables/columns and migrates settings and pending rows.
- All SQL used by `media_repository.dart` / `album_repository.dart` (paging, album join, search by name/date, timeline groups, undated, on-this-day, counts, stats, random with exclusion, link revive) returns the expected rows on test data.
- Static checks: every relative import resolves, every imported package is in pubspec, brackets balance.

NOT VERIFIED (no Flutter SDK, Postgres or network was available):
- The Dart has never been compiled, analyzed or run. **First action: `./scripts/setup.ps1` (or `.sh`) and fix what `flutter analyze` reports.**
- No widget has been rendered; layout/overflow/animation behavior is untested on any device or in Chrome.
- `supabase/migrations/*` and `supabase/tests/*` were never run against a database.
- `SyncService` (pull/push/backup/restore) has never talked to Supabase.
- Tests in `test/` are written but unrun (`flutter test`).
- No APK/web build was attempted. No performance measurements were taken.

## Layout
See `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/SUPABASE_SETUP.md`, `docs/PRIVACY_AND_SECURITY.md`.

## Suggested order of work
1. [ ] `flutter pub get`, web sqlite setup, `dart format .`, `flutter analyze` → fix compile errors. Tighten `any` versions to the resolved ones.
2. [ ] `flutter test` → fix failures (database_test.dart, app_flow_test.dart).
3. [ ] `flutter run -d chrome`: walk splash → onboarding → home → import photos → create planet → add photos → viewer → favorites → timeline → Space Show → discovery → frames → constellation → achievements → settings (gate) → restart/refresh and confirm persistence (IndexedDB).
4. [ ] `flutter run` on Android: same walk-through using the system Photo Picker; try a video, delete/move a photo, airplane mode.
5. [ ] Supabase: preflight → migrations 01-04 → both SQL tests → two real accounts cross-access test (incl. Storage).
6. [ ] Sync: sign in, enable sync, Sync Now, Backup, Cancel, Retry, Restore; test two devices/browsers incl. delete propagation.
7. [ ] `flutter build apk --release` and `flutter build web --release`; record real results.
8. [ ] Accessibility pass (TalkBack, keyboard on web, 200% font scale, small phone) and a large-gallery performance check (thousands of items).

## Known limitations / design decisions
- Web: no video import/playback; HEIC may not decode in Chrome (thumbnail falls back to the original); data lives in browser storage and can be cleared by the user.
- Android: video thumbnails are a generic play tile (no thumbnail plugin).
- Dates: EXIF DateTimeOriginal at import; otherwise unknown (shown under "Date unknown"). File timestamps are deliberately NOT used.
- Sync: last-writer-wins by client `updated_at`; pull cursor is server `synced_at`; tombstones (`deleted_at`) everywhere; settings are not synced. Pages of exactly-equal `synced_at` at a page boundary could be skipped (rare; use a (synced_at, id) cursor if it matters).
- Backup reads whole files into memory; files > 50 MB are skipped; cancel takes effect between files.
- Session storage is supabase_flutter's default (not an encrypted keystore). Password-reset emails open the configured Site URL (no Android deep link).
- Constellations connect photos in order (planet / recent), not by "relatedness".
- Sound setting is stored but there are no sound effects (none bundled, by design).
- Naming: `local_uri` ≙ local_path; `achievement_code` ≙ achievement_type; cloud `media_items.album_id` (from migration 01) is unused. Membership lives in `album_media`.
- `/viewer/:id` deep link without an id list shows only that one photo.
