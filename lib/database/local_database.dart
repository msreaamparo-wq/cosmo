import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Local-first SQLite layer (Android: sqflite; Web: sqflite_common_ffi_web, persisted in IndexedDB).
/// Stores metadata and file references only; image bytes never go in the main tables
/// (the web-only `media_blobs` table is the browser's substitute for a file system).
class LocalDatabase {
  LocalDatabase._();

  /// For tests: wrap an already-open (e.g. in-memory) database.
  LocalDatabase.forTest(Database db) : _db = db;
  static final LocalDatabase instance = LocalDatabase._();

  static const String _fileName = 'cosmos.db';
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: CosmosSchema.version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        for (final s in CosmosSchema.v2) {
          await db.execute(s);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final s in CosmosSchema.upgradeV1ToV2) {
            await db.execute(s);
          }
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// "Clear local app data" (after confirmation). Original device files are never touched.
  Future<void> wipeAll() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in const [
        'album_media',
        'albums',
        'media',
        'achievements',
        'pending_sync',
        'settings_kv',
        'media_blobs',
      ]) {
        await txn.delete(t);
      }
    });
  }
}
