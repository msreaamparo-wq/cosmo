# Database

## Local (SQLite, schema v2: `lib/database/schema.dart`)
Booleans are 0/1; timestamps are epoch milliseconds. Foreign keys are ON.

| Table | Purpose |
|---|---|
| `albums` | planets: name, planet_theme, planet_color, sticker, description, cover_media_id, `deleted_at` tombstone |
| `media` | local media records: `local_uri` (file path on Android, `web:<id>` in browser, `cloud://<id>` if only in backup), type, mime, captured_at (NULL if unknown), size, is_favorite, is_available, imported_at, `deleted_at`, `cloud_path`, `backed_up_at` |
| `album_media` | many-to-many link (album_id, media_id), `updated_at`, `deleted_at` |
| `settings_kv` | key / value / updated_at |
| `achievements` | achievement_code, unlocked_at |
| `pending_sync` | one row per changed record (entity, entity_id, op, attempts) |
| `media_blobs` | WEB ONLY: bytes + thumbnail (empty on Android) |

Naming vs. the brief: `local_uri` is the "local_path", `achievement_code` is the "achievement_type".
Indexes: captured_at, media_type, favorites (partial), (deleted_at, is_available), album_media(media_id), albums(created_at).

Migrations: `onUpgrade` runs `upgradeV1ToV2` (adds columns, migrates the old `settings` row into `settings_kv`,
rebuilds `pending_sync`). Verified against real SQLite for column parity with a fresh v2 install.

## Cloud (Postgres, `supabase/migrations`)
`parent_profiles` 1—n `albums` / `media_items` / `app_settings` / `achievements`; `album_media` links
albums and media. Ownership is enforced structurally: `media_items.(album_id, parent_id)` and
`album_media.(album_id, parent_id)` / `(media_id, parent_id)` are composite foreign keys to rows with the
same `parent_id`, so a parent can never attach their data to someone else's.
Each synced table has `updated_at` (client clock, last-writer-wins) and `synced_at` (server clock, pull cursor), plus `deleted_at`.
`app_settings` exists in the cloud but settings are not synced yet.
