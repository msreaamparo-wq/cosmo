/// SQLite schema for COSMOS. Kept as plain SQL lists so it is easy to review and test.
/// Booleans are INTEGER 0/1, timestamps are epoch milliseconds (UTC).
/// Soft-delete (`deleted_at`) is used for synced entities so deletions propagate to other devices.
abstract final class CosmosSchema {
  static const int version = 2;

  static const List<String> v2 = [
    '''
CREATE TABLE albums (
  id             TEXT PRIMARY KEY,
  name           TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 60),
  planet_theme   TEXT NOT NULL DEFAULT 'rings',
  planet_color   TEXT NOT NULL DEFAULT '#8065E8',
  sticker        TEXT,
  description    TEXT,
  cover_media_id TEXT,
  created_at     INTEGER NOT NULL,
  updated_at     INTEGER NOT NULL,
  deleted_at     INTEGER
)''',
    '''
CREATE TABLE media (
  id            TEXT PRIMARY KEY,
  local_uri     TEXT NOT NULL UNIQUE,
  file_name     TEXT,
  media_type    TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
  mime_type     TEXT,
  captured_at   INTEGER,
  file_size     INTEGER,
  is_favorite   INTEGER NOT NULL DEFAULT 0 CHECK (is_favorite IN (0, 1)),
  is_available  INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
  imported_at   INTEGER NOT NULL,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  deleted_at    INTEGER,
  cloud_path    TEXT,
  backed_up_at  INTEGER
)''',
    '''
CREATE TABLE album_media (
  album_id   TEXT NOT NULL REFERENCES albums (id) ON DELETE CASCADE,
  media_id   TEXT NOT NULL REFERENCES media (id)  ON DELETE CASCADE,
  added_at   INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  PRIMARY KEY (album_id, media_id)
) WITHOUT ROWID''',
    '''
CREATE TABLE settings_kv (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)''',
    '''
CREATE TABLE achievements (
  achievement_code TEXT PRIMARY KEY,
  unlocked_at      INTEGER NOT NULL
)''',
    '''
CREATE TABLE pending_sync (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  entity     TEXT NOT NULL CHECK (entity IN ('album', 'media', 'album_media', 'achievement')),
  entity_id  TEXT NOT NULL,
  op         TEXT NOT NULL CHECK (op IN ('upsert', 'delete')),
  created_at INTEGER NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0,
  UNIQUE (entity, entity_id)
)''',
    // Web only: bytes of imported files live here (IndexedDB-backed SQLite). Empty on Android,
    // where files are kept on disk and only their path is stored.
    '''
CREATE TABLE media_blobs (
  media_id TEXT PRIMARY KEY,
  bytes    BLOB NOT NULL,
  thumb    BLOB
)''',
    'CREATE INDEX idx_media_captured    ON media (captured_at DESC)',
    'CREATE INDEX idx_media_type        ON media (media_type)',
    'CREATE INDEX idx_media_favorite    ON media (is_favorite) WHERE is_favorite = 1',
    'CREATE INDEX idx_media_active      ON media (deleted_at, is_available)',
    'CREATE INDEX idx_album_media_media ON album_media (media_id)',
    'CREATE INDEX idx_albums_created    ON albums (created_at DESC)',
  ];

  /// v1 -> v2. Never drops user data (the old `settings` row is migrated before it is removed).
  static const List<String> upgradeV1ToV2 = [
    'ALTER TABLE albums ADD COLUMN description TEXT',
    'ALTER TABLE albums ADD COLUMN cover_media_id TEXT',
    'ALTER TABLE albums ADD COLUMN deleted_at INTEGER',
    'ALTER TABLE media ADD COLUMN mime_type TEXT',
    'ALTER TABLE media ADD COLUMN imported_at INTEGER',
    'ALTER TABLE media ADD COLUMN updated_at INTEGER',
    'ALTER TABLE media ADD COLUMN deleted_at INTEGER',
    'ALTER TABLE media ADD COLUMN cloud_path TEXT',
    'ALTER TABLE media ADD COLUMN backed_up_at INTEGER',
    'UPDATE media SET imported_at = created_at, updated_at = created_at',
    'ALTER TABLE album_media ADD COLUMN updated_at INTEGER',
    'ALTER TABLE album_media ADD COLUMN deleted_at INTEGER',
    'UPDATE album_media SET updated_at = added_at',
    '''
CREATE TABLE settings_kv (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)''',
    "INSERT INTO settings_kv (key, value, updated_at) SELECT 'theme', 'midnight', 0 FROM settings WHERE id = 1",
    "INSERT INTO settings_kv (key, value, updated_at) SELECT 'animations_enabled', CASE animations_enabled WHEN 1 THEN 'true' ELSE 'false' END, 0 FROM settings WHERE id = 1",
    "INSERT INTO settings_kv (key, value, updated_at) SELECT 'sound_enabled', CASE sound_enabled WHEN 1 THEN 'true' ELSE 'false' END, 0 FROM settings WHERE id = 1",
    "INSERT INTO settings_kv (key, value, updated_at) SELECT 'cloud_sync_enabled', CASE cloud_sync_enabled WHEN 1 THEN 'true' ELSE 'false' END, 0 FROM settings WHERE id = 1",
    "INSERT INTO settings_kv (key, value, updated_at) SELECT 'onboarding_done', CASE onboarding_done WHEN 1 THEN 'true' ELSE 'false' END, 0 FROM settings WHERE id = 1",
    'DROP TABLE settings',
    '''
CREATE TABLE pending_sync_v2 (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  entity     TEXT NOT NULL CHECK (entity IN ('album', 'media', 'album_media', 'achievement')),
  entity_id  TEXT NOT NULL,
  op         TEXT NOT NULL CHECK (op IN ('upsert', 'delete')),
  created_at INTEGER NOT NULL,
  attempts   INTEGER NOT NULL DEFAULT 0,
  UNIQUE (entity, entity_id)
)''',
    'INSERT INTO pending_sync_v2 (entity, entity_id, op, created_at, attempts) SELECT entity, entity_id, op, created_at, attempts FROM pending_sync',
    'DROP TABLE pending_sync',
    'ALTER TABLE pending_sync_v2 RENAME TO pending_sync',
    '''
CREATE TABLE media_blobs (
  media_id TEXT PRIMARY KEY,
  bytes    BLOB NOT NULL,
  thumb    BLOB
)''',
    'CREATE INDEX idx_media_active ON media (deleted_at, is_available)',
  ];
}
