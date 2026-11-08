# Architecture

```
lib/
  main.dart / app.dart          bootstrap (DB factory, Supabase init), MaterialApp.router, achievement toasts
  core/    config/ constants/ theme/ routing/ utilities/   palette, theme, GoRouter + responsive shell, motion scope
  database/ schema.dart local_database.dart pending_sync.dart db_factory*.dart
  models/        AlbumModel, MediaModel (LOCAL media, never a cloud object)
  platform/      MediaFileStore (io: files in app-private storage; web: blobs + thumbnails in SQLite/IndexedDB)
  repositories/  media, album, settings, achievement (all SQL lives here)
  services/      import, achievements, supabase, auth, sync (+ backup/restore)
  providers/     Riverpod providers, settings notifier, sync controller, MediaPager (paged loading)
  screens/       one folder per screen
  widgets/       reusable cosmic widgets
```

**State management:** Riverpod 2. Repositories are plain providers. `dataVersionProvider` is bumped after any
data change; list providers watch it and reload. Large lists use `MediaPager` (limit/offset paging).

**Navigation:** GoRouter. `StatefulShellRoute.indexedStack` with 4 branches (Home, Gallery, Planets, Favorites):
bottom bar below 720px wide, navigation rail above. Everything else is a full-screen route. `/viewer/:id`
takes the ordered id list via `extra`; without it only that one photo is shown. Unknown paths show a friendly
"Lost in space" page.

**Platform split:** conditional imports (`dart.library.io` / `dart.library.js_interop`) in
`platform/media_file_store*.dart` and `database/db_factory*.dart`. No `dart:io` is imported by shared code.

**Thumbnails / memory:** grids decode with `cacheWidth` (a few hundred px). Full resolution is decoded only in the
viewer and Space Show (capped at 2048px). On web a 360px PNG thumbnail is generated at import and stored.

**Motion:** `MotionScope` (setting) combined with the OS reduced-motion flag. Every animated widget checks it.

**Local-first:** all features run offline. Cloud is optional (`SyncService`), driven by `pending_sync`.
