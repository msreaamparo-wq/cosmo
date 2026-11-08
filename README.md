# COSMOS: Your Memories, Your Little Universe.

A child-friendly photo memory gallery for Android and Chrome. Photos are stars, albums are planets,
and a parent can optionally back everything up to a private Supabase cloud.

> **Honest status.** This code base was written without access to a Flutter SDK, so it has **not been
> compiled, analyzed or run yet**. Step 1 below is `flutter analyze`; expect to fix a few issues.
> The SQLite schema, its v1→v2 upgrade and the repository queries *were* executed against real SQLite.
> The Supabase SQL and RLS tests have **not** been run against a database. See `CLAUDE.md` for the exact
> verified / unverified list.

## Features
Splash + 3-page onboarding · Home dashboard (real counts, recent memories, featured planets) · Gallery
(import, grid/list, search, sort, filters, multi-select, paging) · Photo viewer (zoom, pan, swipe,
favorite, add to planet, details, share) · Planets (create/edit/delete, color, style, sticker, cover,
description, add/remove photos) · Favorites · Memory Timeline (year/month, real dates only) · Space Show
(3 transitions, speed, pause) · Memory Discovery (random, recent, "on this day") · Cosmic Frames (save
a decorated copy) · Constellations · Achievements (non-competitive) · Settings behind a parent gate ·
Optional parent-controlled cloud sync and photo backup.

## Stack
Flutter/Dart · Riverpod 2 · GoRouter · SQLite (`sqflite` on Android, `sqflite_common_ffi_web` on Chrome,
persisted in IndexedDB) · Supabase (Auth, Postgres, private Storage, RLS).

## Setup
```bash
# Windows PowerShell
./scripts/setup.ps1
# macOS / Linux / Git Bash
./scripts/setup.sh
```
This runs `flutter pub get`, the web SQLite setup, `dart format .`, `flutter analyze` and `flutter test`.
Paste any analyzer errors back to whoever is helping you (or fix them): that is the real "first build".

Optional: put the Fredoka and Nunito fonts in `assets/fonts` and uncomment the `fonts:` block in `pubspec.yaml`.

## Run
```bash
# Chrome (local only)
flutter run -d chrome
# Android (device or emulator)
flutter devices
flutter run -d <device-id>
# With the optional cloud (never use a service-role/secret key here)
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## Android notes
In `android/app/src/main/AndroidManifest.xml` make sure `<uses-permission android:name="android.permission.INTERNET"/>`
is present in the **main** manifest (release builds need it for the cloud). No storage permission is needed:
pictures come from the system Photo Picker.

## Build
```bash
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
flutter build web --release          # build/web  (host on any static host; needs HTTPS in production)
```

## Docs
`docs/ARCHITECTURE.md` · `docs/DATABASE.md` · `docs/SUPABASE_SETUP.md` · `docs/PRIVACY_AND_SECURITY.md`

## Screenshots
_Add after the first successful run._
