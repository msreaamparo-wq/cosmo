import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import '../database/pending_sync.dart';
import '../models/album_model.dart';

enum AlbumSort { newest, name, mostMemories }

class AlbumRepository {
  AlbumRepository(this._local);
  final LocalDatabase _local;
  static const _uuid = Uuid();

  static const _countSql =
      '(SELECT COUNT(*) FROM album_media am JOIN media m ON m.id = am.media_id '
      'WHERE am.album_id = a.id AND am.deleted_at IS NULL AND m.deleted_at IS NULL AND m.is_available = 1)';

  Future<List<AlbumModel>> all(
      {String search = '', AlbumSort sort = AlbumSort.newest}) async {
    final db = await _local.database;
    final args = <Object?>[];
    var where = 'a.deleted_at IS NULL';
    if (search.trim().isNotEmpty) {
      where += ' AND LOWER(a.name) LIKE ?';
      args.add('%${search.trim().toLowerCase()}%');
    }
    final order = switch (sort) {
      AlbumSort.newest => 'a.created_at DESC',
      AlbumSort.name => 'LOWER(a.name) ASC',
      AlbumSort.mostMemories => 'media_count DESC, LOWER(a.name) ASC',
    };
    final rows = await db.rawQuery(
        'SELECT a.*, $_countSql AS media_count FROM albums a WHERE $where ORDER BY $order',
        args);
    return rows.map(AlbumModel.fromMap).toList();
  }

  Future<AlbumModel?> byId(String id) async {
    final db = await _local.database;
    final rows = await db.rawQuery(
        'SELECT a.*, $_countSql AS media_count FROM albums a WHERE a.id = ? AND a.deleted_at IS NULL',
        [id]);
    return rows.isEmpty ? null : AlbumModel.fromMap(rows.first);
  }

  Future<({int photos, int videos})> typeCounts(String albumId) async {
    final db = await _local.database;
    final r = (await db.rawQuery('''
      SELECT COALESCE(SUM(m.media_type = 'image'), 0) AS p, COALESCE(SUM(m.media_type = 'video'), 0) AS v
      FROM album_media am JOIN media m ON m.id = am.media_id
      WHERE am.album_id = ? AND am.deleted_at IS NULL AND m.deleted_at IS NULL AND m.is_available = 1''',
            [albumId]))
        .first;
    return (photos: r['p']! as int, videos: r['v']! as int);
  }

  Future<List<String>> mediaIds(String albumId) async {
    final db = await _local.database;
    final rows = await db.rawQuery('''
      SELECT m.id FROM album_media am JOIN media m ON m.id = am.media_id
      WHERE am.album_id = ? AND am.deleted_at IS NULL AND m.deleted_at IS NULL AND m.is_available = 1
      ORDER BY COALESCE(m.captured_at, m.imported_at)''', [albumId]);
    return rows.map((r) => r['id']! as String).toList();
  }

  Future<AlbumModel> create({
    required String name,
    required String planetTheme,
    required String planetColor,
    String? sticker,
    String? description,
    String? coverMediaId,
  }) async {
    final now = DateTime.now();
    final album = AlbumModel(
      id: _uuid.v4(),
      name: name.trim(),
      planetTheme: planetTheme,
      planetColor: planetColor,
      sticker: sticker,
      description:
          (description ?? '').trim().isEmpty ? null : description!.trim(),
      coverMediaId: coverMediaId,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _local.database;
    await db.transaction((txn) async {
      await txn.insert('albums', album.toMap());
      await enqueueSync(txn, 'album', album.id);
    });
    return album;
  }

  Future<void> update(AlbumModel a) async {
    final db = await _local.database;
    await db.transaction((txn) async {
      await txn.update(
        'albums',
        {
          'name': a.name.trim(),
          'planet_theme': a.planetTheme,
          'planet_color': a.planetColor,
          'sticker': a.sticker,
          'description': (a.description ?? '').trim().isEmpty
              ? null
              : a.description!.trim(),
          'cover_media_id': a.coverMediaId,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [a.id],
      );
      await enqueueSync(txn, 'album', a.id);
    });
  }

  /// Soft-deletes the planet only. Media records and device photos are untouched.
  Future<void> softDelete(String albumId) async {
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update('albums', {'deleted_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [albumId]);
      await enqueueSync(txn, 'album', albumId);
    });
  }

  /// Links existing media to a planet (no file copy). Re-adding a previously removed item revives its link.
  Future<void> addMedia(String albumId, Iterable<String> mediaIds) async {
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in mediaIds) {
        await txn.insert(
          'album_media',
          {
            'album_id': albumId,
            'media_id': id,
            'added_at': now,
            'updated_at': now,
            'deleted_at': null
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await enqueueSync(txn, 'album_media', '$albumId|$id');
      }
      await txn.update('albums', {'updated_at': now},
          where: 'id = ?', whereArgs: [albumId]);
      await enqueueSync(txn, 'album', albumId);
    });
  }

  Future<void> removeMedia(String albumId, Iterable<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in mediaIds) {
        await txn.update('album_media', {'deleted_at': now, 'updated_at': now},
            where: 'album_id = ? AND media_id = ?', whereArgs: [albumId, id]);
        await enqueueSync(txn, 'album_media', '$albumId|$id');
      }
      // If the removed photo was the cover, clear the cover.
      await txn.update('albums', {'cover_media_id': null, 'updated_at': now},
          where:
              'id = ? AND cover_media_id IN (${List.filled(mediaIds.length, '?').join(',')})',
          whereArgs: [albumId, ...mediaIds]);
    });
  }
}
