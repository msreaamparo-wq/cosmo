import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_database.dart';
import '../models/media_model.dart';
import '../platform/media_file_store.dart';
import '../repositories/media_repository.dart';
import '../repositories/settings_repository.dart';
import 'supabase_service.dart';

class SyncReport {
  const SyncReport(
      {this.pushed = 0, this.pulled = 0, this.error, this.offline = false});
  final int pushed, pulled;
  final String? error;
  final bool offline;
  bool get ok => error == null;
}

class BackupToken {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class BackupReport {
  const BackupReport(
      {this.uploaded = 0,
      this.failedIds = const [],
      this.tooLarge = 0,
      this.cancelled = false,
      this.error});
  final int uploaded, tooLarge;
  final List<String> failedIds;
  final bool cancelled;
  final String? error;
  bool get ok => error == null && failedIds.isEmpty && !cancelled;
}

/// Offline-first sync.
///  * Every local change is queued in `pending_sync` (no network needed).
///  * Sync = PULL remote changes (by server `synced_at` cursor), then PUSH what is still pending.
///  * Conflicts: last-writer-wins on the client `updated_at`. If the remote row is newer, it replaces
///    the local row and the local pending change is dropped; otherwise the local change is pushed.
///  * Deletions are soft (`deleted_at` tombstones) so other devices learn about them.
///  * Photo FILES are uploaded by [backup] after the parent has approved automatic cloud backup.
class SyncService {
  SyncService(this._local, this._store, this._settings, this._media);
  final LocalDatabase _local;
  final MediaFileStore _store;
  final SettingsRepository _settings;
  final MediaRepository _media;

  static const bucket = 'cosmos-media';
  static const maxUploadBytes = 50 * 1024 * 1024;

  Future<int> pendingCount() async {
    final db = await _local.database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM pending_sync')) ??
        0;
  }

  // ---------------------------------------------------------------- sync now
  Future<SyncReport> syncNow({void Function(String step)? onStep}) async {
    final client = SupabaseService.client;
    if (client == null)
      return const SyncReport(error: 'Cloud is not set up in this build.');
    final user = client.auth.currentUser;
    if (user == null)
      return const SyncReport(error: 'Please sign in as a parent first.');
    try {
      onStep?.call('Checking your account…');
      await client.from('parent_profiles').upsert({'id': user.id});
      onStep?.call('Getting changes from the cloud…');
      final pulled = await _pull(client);
      onStep?.call('Sending your changes…');
      final pushed = await _push(client, user.id);
      return SyncReport(pushed: pushed, pulled: pulled);
    } catch (e) {
      debugPrint('Sync failed: ${e.runtimeType}');
      return SyncReport(error: _friendly(e), offline: _isOffline(e));
    }
  }

  // -------------------------------------------------------------------- pull
  Future<int> _pull(SupabaseClient client) async {
    var n = 0;
    n += await _pullTable(client, 'albums', _applyAlbum);
    n += await _pullTable(client, 'media_items', _applyMedia);
    n += await _pullTable(client, 'album_media', _applyAlbumMedia);
    return n;
  }

  Future<int> _pullTable(SupabaseClient client, String table,
      Future<bool> Function(Map<String, dynamic>) apply) async {
    var cursor = await _settings.get('pull_$table') ?? '1970-01-01T00:00:00Z';
    var applied = 0;
    while (true) {
      final rows = await client
          .from(table)
          .select()
          .gt('synced_at', cursor)
          .order('synced_at', ascending: true)
          .limit(500);
      if (rows.isEmpty) break;
      for (final r in rows) {
        if (await apply(Map<String, dynamic>.from(r))) applied++;
      }
      cursor = rows.last['synced_at'] as String;
      await _settings.set('pull_$table', cursor);
      if (rows.length < 500) break;
    }
    return applied;
  }

  int? _ms(Object? iso) =>
      iso == null ? null : DateTime.parse(iso as String).millisecondsSinceEpoch;
  String? _iso(int? ms) => ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

  Future<bool> _applyAlbum(Map<String, dynamic> r) async {
    final db = await _local.database;
    final id = r['id'] as String;
    final remoteUpdated = _ms(r['updated_at'])!;
    final deleted = _ms(r['deleted_at']);
    final local = await db.query('albums',
        columns: ['updated_at'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (local.isEmpty && deleted != null) return false;
    if (local.isNotEmpty &&
        (local.first['updated_at']! as int) >= remoteUpdated)
      return false; // local wins
    await db.transaction((txn) async {
      await txn.insert(
        'albums',
        {
          'id': id,
          'name': r['name'],
          'planet_theme': r['planet_theme'] ?? 'rings',
          'planet_color': r['planet_color'] ?? '#8065E8',
          'sticker': r['icon'],
          'description': r['description'],
          'cover_media_id': r['cover_media_id'],
          'created_at': _ms(r['created_at']),
          'updated_at': remoteUpdated,
          'deleted_at': deleted,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('pending_sync',
          where: 'entity = ? AND entity_id = ?', whereArgs: ['album', id]);
    });
    return true;
  }

  Future<bool> _applyMedia(Map<String, dynamic> r) async {
    final db = await _local.database;
    final id = r['id'] as String;
    final remoteUpdated = _ms(r['updated_at'])!;
    final deleted = _ms(r['deleted_at']);
    final rows =
        await db.query('media', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      if (deleted != null) return false;
      // A photo from another device: record it, but it is NOT available here until restored from backup.
      await db.insert('media', {
        'id': id,
        'local_uri': 'cloud://$id',
        'file_name': r['file_name'],
        'media_type': r['media_type'],
        'mime_type': r['mime_type'],
        'captured_at': _ms(r['captured_at']),
        'file_size': r['file_size'],
        'is_favorite': (r['is_favorite'] == true) ? 1 : 0,
        'is_available': 0,
        'imported_at': _ms(r['created_at']),
        'created_at': _ms(r['created_at']),
        'updated_at': remoteUpdated,
        'cloud_path': r['storage_path'],
        'backed_up_at': r['storage_path'] == null ? null : remoteUpdated,
      });
      return true;
    }
    final local = MediaModel.fromMap(rows.first);
    if (local.updatedAt.millisecondsSinceEpoch >= remoteUpdated)
      return false; // local wins
    await db.transaction((txn) async {
      await txn.update(
        'media',
        {
          'is_favorite': (r['is_favorite'] == true) ? 1 : 0,
          'file_name': r['file_name'] ?? local.fileName,
          'captured_at':
              _ms(r['captured_at']) ?? local.capturedAt?.millisecondsSinceEpoch,
          'cloud_path': r['storage_path'] ?? local.cloudPath,
          'deleted_at': deleted,
          'updated_at': remoteUpdated,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('pending_sync',
          where: 'entity = ? AND entity_id = ?', whereArgs: ['media', id]);
    });
    if (deleted != null) await _store.delete(local); // our private copy only
    return true;
  }

  Future<bool> _applyAlbumMedia(Map<String, dynamic> r) async {
    final db = await _local.database;
    final aid = r['album_id'] as String, mid = r['media_id'] as String;
    final remoteUpdated = _ms(r['updated_at'])!;
    final hasParents = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT (SELECT COUNT(*) FROM albums WHERE id = ?) + (SELECT COUNT(*) FROM media WHERE id = ?)',
            [aid, mid])) ==
        2;
    if (!hasParents) return false;
    final local = await db.query('album_media',
        columns: ['updated_at'],
        where: 'album_id = ? AND media_id = ?',
        whereArgs: [aid, mid],
        limit: 1);
    if (local.isNotEmpty &&
        (local.first['updated_at']! as int) >= remoteUpdated) return false;
    await db.transaction((txn) async {
      await txn.insert(
        'album_media',
        {
          'album_id': aid,
          'media_id': mid,
          'added_at': _ms(r['created_at']),
          'updated_at': remoteUpdated,
          'deleted_at': _ms(r['deleted_at']),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('pending_sync',
          where: 'entity = ? AND entity_id = ?',
          whereArgs: ['album_media', '$aid|$mid']);
    });
    return true;
  }

  // -------------------------------------------------------------------- push
  Future<int> _push(SupabaseClient client, String uid) async {
    final db = await _local.database;
    var pushed = 0;
    for (final entity in const [
      'album',
      'media',
      'album_media',
      'achievement'
    ]) {
      final pending = await db.query('pending_sync',
          where: 'entity = ?', whereArgs: [entity], orderBy: 'created_at');
      if (pending.isEmpty) continue;
      final keys = pending.map((p) => p['entity_id']! as String).toList();
      try {
        for (var i = 0; i < keys.length; i += 100) {
          final chunk =
              keys.sublist(i, i + 100 > keys.length ? keys.length : i + 100);
          pushed += await _pushChunk(client, uid, entity, chunk);
          for (final k in chunk) {
            await db.delete('pending_sync',
                where: 'entity = ? AND entity_id = ?', whereArgs: [entity, k]);
          }
        }
      } catch (e) {
        await db.rawUpdate(
            'UPDATE pending_sync SET attempts = attempts + 1 WHERE entity = ?',
            [entity]);
        rethrow;
      }
    }
    return pushed;
  }

  Future<int> _pushChunk(SupabaseClient client, String uid, String entity,
      List<String> keys) async {
    final db = await _local.database;
    switch (entity) {
      case 'album':
        final albumRows = await db.rawQuery(
            'SELECT * FROM albums WHERE id IN (${_marks(keys)})', keys);
        if (albumRows.isEmpty) return 0;
        await client.from('albums').upsert([
          for (final r in albumRows)
            {
              'id': r['id'],
              'parent_id': uid,
              'name': r['name'],
              'planet_theme': r['planet_theme'],
              'planet_color': r['planet_color'],
              'icon': r['sticker'],
              'description': r['description'],
              'cover_media_id': r['cover_media_id'],
              'created_at': _iso(r['created_at'] as int),
              'updated_at': _iso(r['updated_at'] as int),
              'deleted_at': _iso(r['deleted_at'] as int?),
            }
        ]);
        return albumRows.length;
      case 'media':
        final mediaRows = await db.rawQuery(
            'SELECT * FROM media WHERE id IN (${_marks(keys)})', keys);
        if (mediaRows.isEmpty) return 0;
        for (final r in mediaRows) {
          // A deleted photo also loses its cloud backup copy.
          if (r['deleted_at'] != null && r['cloud_path'] != null) {
            try {
              await client.storage
                  .from(bucket)
                  .remove([r['cloud_path']! as String]);
            } catch (e) {
              debugPrint('Backup copy removal failed: ${e.runtimeType}');
            }
          }
        }
        await client.from('media_items').upsert([
          for (final r in mediaRows)
            {
              'id': r['id'],
              'parent_id': uid,
              'file_name': r['file_name'],
              'media_type': r['media_type'],
              'mime_type': r['mime_type'],
              'captured_at': _iso(r['captured_at'] as int?),
              'file_size': r['file_size'],
              'is_favorite': r['is_favorite'] == 1,
              'storage_path': r['deleted_at'] != null ? null : r['cloud_path'],
              'created_at': _iso(r['created_at'] as int),
              'updated_at': _iso(r['updated_at'] as int),
              'deleted_at': _iso(r['deleted_at'] as int?),
            }
        ]);
        return mediaRows.length;
      case 'album_media':
        var n = 0;
        final out = <Map<String, Object?>>[];
        for (final k in keys) {
          final parts = k.split('|');
          final rows = await db.query('album_media',
              where: 'album_id = ? AND media_id = ?', whereArgs: parts);
          if (rows.isEmpty) continue;
          final r = rows.first;
          out.add({
            'album_id': r['album_id'],
            'media_id': r['media_id'],
            'parent_id': uid,
            'created_at': _iso(r['added_at'] as int),
            'updated_at': _iso(r['updated_at'] as int),
            'deleted_at': _iso(r['deleted_at'] as int?),
          });
          n++;
        }
        if (out.isNotEmpty)
          await client
              .from('album_media')
              .upsert(out, onConflict: 'album_id,media_id');
        return n;
      case 'achievement':
        final achRows = await db.rawQuery(
            'SELECT * FROM achievements WHERE achievement_code IN (${_marks(keys)})',
            keys);
        if (achRows.isEmpty) return 0;
        await client.from('achievements').upsert([
          for (final r in achRows)
            {
              'parent_id': uid,
              'achievement_code': r['achievement_code'],
              'unlocked_at': _iso(r['unlocked_at'] as int)
            }
        ], onConflict: 'parent_id,achievement_code');
        return achRows.length;
    }
    return 0;
  }

  String _marks(List<Object?> l) => List.filled(l.length, '?').join(',');

  // ------------------------------------------------------------------ backup
  /// Uploads the given media files to the PRIVATE bucket at {user_id}/{media_id}/{filename}.
  /// The controller calls this only after the signed-in parent has approved automatic backup.
  /// A file is marked backed-up ONLY after its upload succeeds.
  Future<BackupReport> backup(List<MediaModel> items,
      {BackupToken? token,
      void Function(int done, int total)? onProgress}) async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null)
      return const BackupReport(error: 'Please sign in as a parent first.');
    var uploaded = 0, tooLarge = 0, done = 0;
    final failed = <String>[];
    try {
      await client.from('parent_profiles').upsert({'id': user.id});
    } catch (e) {
      return BackupReport(error: _friendly(e));
    }
    for (final m in items) {
      if (token?.cancelled ?? false)
        return BackupReport(
            uploaded: uploaded,
            failedIds: failed,
            tooLarge: tooLarge,
            cancelled: true);
      onProgress?.call(done, items.length);
      try {
        if ((m.fileSize ?? 0) > maxUploadBytes) {
          tooLarge++;
        } else {
          final Uint8List bytes = await _store.readBytes(m);
          final path =
              '${user.id}/${m.id}/${_safeName(m.fileName ?? '${m.id}.jpg')}';
          await client.storage.from(bucket).uploadBinary(path, bytes,
              fileOptions: FileOptions(upsert: true, contentType: m.mimeType));
          await _media.setBackedUp(m.id, path);
          uploaded++;
        }
      } catch (e) {
        debugPrint('Backup of one item failed: ${e.runtimeType}');
        failed.add(m.id);
      }
      done++;
    }
    onProgress?.call(items.length, items.length);
    return BackupReport(
        uploaded: uploaded, failedIds: failed, tooLarge: tooLarge);
  }

  /// Downloads photos that exist in the parent's backup but not on this device.
  Future<({int restored, int failed})> restoreMissing() async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null)
      return (restored: 0, failed: 0);
    var restored = 0, failed = 0;
    for (final m in await _media.unavailable()) {
      if (m.cloudPath == null) continue;
      try {
        final bytes = await client.storage.from(bucket).download(m.cloudPath!);
        final dot = (m.fileName ?? '').lastIndexOf('.');
        final ext = dot >= 0 ? m.fileName!.substring(dot) : '.jpg';
        final stored = await _store.saveBytes(m.id, bytes, ext);
        await _media.markAvailable(m.id, stored.ref);
        restored++;
      } catch (e) {
        debugPrint('Restore failed: ${e.runtimeType}');
        failed++;
      }
    }
    return (restored: restored, failed: failed);
  }

  static String _safeName(String n) {
    final s = n.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return s.isEmpty ? 'file' : s;
  }

  bool _isOffline(Object e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('XMLHttpRequest') ||
        s.contains('Connection');
  }

  String _friendly(Object e) {
    if (_isOffline(e))
      return 'You seem to be offline. Your changes are saved and will sync later.';
    if (e is AuthException) return 'Please sign in again.';
    if (e is PostgrestException || e is StorageException) {
      return 'The cloud could not save that right now. Please try again.';
    }
    return 'Something went wrong while syncing. Please try again.';
  }
}
