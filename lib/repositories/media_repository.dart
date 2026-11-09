import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../database/pending_sync.dart';
import '../models/media_model.dart';

enum MediaFilter { all, photos, videos, favorites }

class MediaQueryOptions {
  const MediaQueryOptions({
    this.search = '',
    this.filter = MediaFilter.all,
    this.newestFirst = true,
    this.albumId,
  });
  final String search;
  final MediaFilter filter;
  final bool newestFirst;
  final String? albumId;

  MediaQueryOptions copyWith(
          {String? search, MediaFilter? filter, bool? newestFirst}) =>
      MediaQueryOptions(
        search: search ?? this.search,
        filter: filter ?? this.filter,
        newestFirst: newestFirst ?? this.newestFirst,
        albumId: albumId,
      );
}

class UniverseStats {
  const UniverseStats(
      {this.photos = 0,
      this.videos = 0,
      this.favorites = 0,
      this.planets = 0,
      this.missing = 0});
  final int photos, videos, favorites, planets, missing;
  int get memories => photos + videos;
}

class TimelineGroup {
  const TimelineGroup(this.year, this.month, this.count);
  final int year, month, count;
}

class MediaRepository {
  MediaRepository(this._local);
  final LocalDatabase _local;

  static const _active = 'm.deleted_at IS NULL AND m.is_available = 1';
  static const _dateLocal =
      "strftime('%Y-%m-%d', m.captured_at / 1000, 'unixepoch', 'localtime')";

  // ---- query building -------------------------------------------------------
  ({String join, List<Object?> joinArgs, String where, List<Object?> args})
      _build(MediaQueryOptions o,
          {String extra = '', List<Object?> extraArgs = const []}) {
    final where = <String>[_active];
    final args = <Object?>[];
    switch (o.filter) {
      case MediaFilter.photos:
        where.add("m.media_type = 'image'");
      case MediaFilter.videos:
        where.add("m.media_type = 'video'");
      case MediaFilter.favorites:
        where.add('m.is_favorite = 1');
      case MediaFilter.all:
        break;
    }
    final q = o.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      where.add(
          '(LOWER(COALESCE(m.file_name, \'\')) LIKE ? OR $_dateLocal LIKE ?)');
      args
        ..add('%$q%')
        ..add('%$q%');
    }
    if (extra.isNotEmpty) {
      where.add(extra);
      args.addAll(extraArgs);
    }
    final join = o.albumId == null
        ? ''
        : 'JOIN album_media am ON am.media_id = m.id AND am.album_id = ? AND am.deleted_at IS NULL';
    return (
      join: join,
      joinArgs: o.albumId == null ? const [] : [o.albumId],
      where: where.join(' AND '),
      args: args
    );
  }

  Future<List<MediaModel>> page(MediaQueryOptions o,
      {required int offset, required int limit}) async {
    final db = await _local.database;
    final b = _build(o);
    final dir = o.newestFirst ? 'DESC' : 'ASC';
    final rows = await db.rawQuery(
      'SELECT m.* FROM media m ${b.join} WHERE ${b.where} '
      'ORDER BY COALESCE(m.captured_at, m.imported_at) $dir, m.id LIMIT ? OFFSET ?',
      [...b.joinArgs, ...b.args, limit, offset],
    );
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<int> count(MediaQueryOptions o) async {
    final db = await _local.database;
    final b = _build(o);
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM media m ${b.join} WHERE ${b.where}',
        [...b.joinArgs, ...b.args]);
    return r.first['n']! as int;
  }

  Future<MediaModel?> byId(String id) async {
    final db = await _local.database;
    final r = await db.query('media',
        where: 'id = ? AND deleted_at IS NULL', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : MediaModel.fromMap(r.first);
  }

  /// Returns media in the SAME order as [ids]; missing/deleted ids are skipped.
  Future<List<MediaModel>> byIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await _local.database;
    final out = <String, MediaModel>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final marks = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT m.* FROM media m WHERE $_active AND m.id IN ($marks)', chunk);
      for (final r in rows) {
        final m = MediaModel.fromMap(r);
        out[m.id] = m;
      }
    }
    return [
      for (final id in ids)
        if (out[id] != null) out[id]!
    ];
  }

  Future<List<MediaModel>> recent({int limit = 12}) async {
    final db = await _local.database;
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m WHERE $_active ORDER BY m.imported_at DESC LIMIT ?',
        [limit]);
    return rows.map(MediaModel.fromMap).toList();
  }

  // ---- discovery / timeline -------------------------------------------------
  Future<MediaModel?> random(
      {Set<String> excludeIds = const {},
      String? albumId,
      bool imagesOnly = true}) async {
    final db = await _local.database;
    final args = <Object?>[];
    final join = albumId == null
        ? ''
        : 'JOIN album_media am ON am.media_id = m.id AND am.album_id = ? AND am.deleted_at IS NULL';
    if (albumId != null) args.add(albumId);
    final where = StringBuffer(_active);
    if (imagesOnly) where.write(" AND m.media_type = 'image'");
    if (excludeIds.isNotEmpty) {
      where.write(
          ' AND m.id NOT IN (${List.filled(excludeIds.length, '?').join(',')})');
      args.addAll(excludeIds);
    }
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m $join WHERE $where ORDER BY RANDOM() LIMIT 1',
        args);
    return rows.isEmpty ? null : MediaModel.fromMap(rows.first);
  }

  /// Real photos taken on today's month/day in PREVIOUS years (only media with a real captured date).
  Future<List<MediaModel>> onThisDay(DateTime today, {int limit = 30}) async {
    final db = await _local.database;
    final md =
        '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery(
      "SELECT m.* FROM media m WHERE $_active AND m.captured_at IS NOT NULL "
      "AND strftime('%m-%d', m.captured_at / 1000, 'unixepoch', 'localtime') = ? "
      "AND CAST(strftime('%Y', m.captured_at / 1000, 'unixepoch', 'localtime') AS INTEGER) < ? "
      'ORDER BY m.captured_at DESC LIMIT ?',
      [md, today.year, limit],
    );
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<List<TimelineGroup>> timelineGroups({String search = ''}) async {
    final db = await _local.database;
    final b = _build(MediaQueryOptions(search: search),
        extra: 'm.captured_at IS NOT NULL');
    final rows = await db.rawQuery(
      "SELECT CAST(strftime('%Y', m.captured_at / 1000, 'unixepoch', 'localtime') AS INTEGER) AS y, "
      "CAST(strftime('%m', m.captured_at / 1000, 'unixepoch', 'localtime') AS INTEGER) AS mo, COUNT(*) AS c "
      'FROM media m WHERE ${b.where} GROUP BY y, mo ORDER BY y DESC, mo DESC',
      b.args,
    );
    return rows
        .map((r) =>
            TimelineGroup(r['y']! as int, r['mo']! as int, r['c']! as int))
        .toList();
  }

  Future<List<MediaModel>> inMonth(int year, int month,
      {String search = '', int limit = 300}) async {
    final db = await _local.database;
    final ym = '$year-${month.toString().padLeft(2, '0')}';
    final b = _build(MediaQueryOptions(search: search),
        extra:
            "strftime('%Y-%m', m.captured_at / 1000, 'unixepoch', 'localtime') = ?",
        extraArgs: [ym]);
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m WHERE ${b.where} ORDER BY m.captured_at DESC LIMIT ?',
        [...b.args, limit]);
    return rows.map(MediaModel.fromMap).toList();
  }

  /// Media with no known capture date. Shown separately, never given an invented date.
  Future<List<MediaModel>> undated(
      {String search = '', int limit = 300}) async {
    final db = await _local.database;
    final b = _build(MediaQueryOptions(search: search),
        extra: 'm.captured_at IS NULL');
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m WHERE ${b.where} ORDER BY m.imported_at DESC LIMIT ?',
        [...b.args, limit]);
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<int> undatedCount({String search = ''}) async {
    final db = await _local.database;
    final b = _build(MediaQueryOptions(search: search),
        extra: 'm.captured_at IS NULL');
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM media m WHERE ${b.where}', b.args);
    return r.first['n']! as int;
  }

  // ---- stats ----------------------------------------------------------------
  Future<UniverseStats> stats() async {
    final db = await _local.database;
    final r = (await db.rawQuery('''
      SELECT
        COALESCE(SUM(media_type = 'image' AND is_available = 1), 0) AS photos,
        COALESCE(SUM(media_type = 'video' AND is_available = 1), 0) AS videos,
        COALESCE(SUM(is_favorite = 1 AND is_available = 1), 0)      AS favorites,
        COALESCE(SUM(is_available = 0), 0)                          AS missing,
        (SELECT COUNT(*) FROM albums WHERE deleted_at IS NULL)       AS planets
      FROM media WHERE deleted_at IS NULL''')).first;
    return UniverseStats(
      photos: r['photos']! as int,
      videos: r['videos']! as int,
      favorites: r['favorites']! as int,
      planets: r['planets']! as int,
      missing: r['missing']! as int,
    );
  }

  // ---- writes ---------------------------------------------------------------
  /// Adds an imported record. Returns false when an identical file (same name + size) is already in COSMOS.
  Future<bool> insert(MediaModel m) async {
    final db = await _local.database;
    if (m.fileName != null && m.fileSize != null) {
      final dup = await db.rawQuery(
        'SELECT 1 FROM media WHERE deleted_at IS NULL AND file_name = ? AND file_size = ? LIMIT 1',
        [m.fileName, m.fileSize],
      );
      if (dup.isNotEmpty) return false;
    }
    await db.transaction((txn) async {
      await txn.insert('media', m.toMap());
      await enqueueSync(txn, 'media', m.id);
    });
    return true;
  }

  Future<void> setFavorite(Iterable<String> ids, bool value) async {
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update(
            'media', {'is_favorite': value ? 1 : 0, 'updated_at': now},
            where: 'id = ?', whereArgs: [id]);
        await enqueueSync(txn, 'media', id);
      }
    });
  }

  /// Soft delete: removes the item from COSMOS (record tombstoned so other devices learn about it).
  /// Caller deletes COSMOS' private copy via MediaFileStore. The photo in the device gallery is never touched.
  Future<void> softDelete(Iterable<String> ids) async {
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      for (final id in ids) {
        await txn.update('media', {'deleted_at': now, 'updated_at': now},
            where: 'id = ?', whereArgs: [id]);
        await enqueueSync(txn, 'media', id);
      }
    });
  }

  Future<void> markUnavailable(String id) async {
    final db = await _local.database;
    await db.update(
        'media',
        {
          'is_available': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch
        },
        where: 'id = ? AND is_available = 1',
        whereArgs: [id]);
  }

  Future<void> markAvailable(String id, String newUri) async {
    final db = await _local.database;
    await db.update(
        'media',
        {
          'is_available': 1,
          'local_uri': newUri,
          'updated_at': DateTime.now().millisecondsSinceEpoch
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<List<MediaModel>> allActive() async {
    final db = await _local.database;
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m WHERE m.deleted_at IS NULL AND m.is_available = 1');
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<List<MediaModel>> unavailable() async {
    final db = await _local.database;
    final rows = await db.query('media',
        where: 'deleted_at IS NULL AND is_available = 0');
    return rows.map(MediaModel.fromMap).toList();
  }

  /// Items with no cloud copy yet (candidates for parent-approved automatic backup).
  Future<List<MediaModel>> notBackedUp({int? limit}) async {
    final db = await _local.database;
    final rows = await db.rawQuery(
        'SELECT m.* FROM media m WHERE $_active AND m.cloud_path IS NULL ORDER BY m.imported_at DESC ${limit == null ? '' : 'LIMIT $limit'}');
    return rows.map(MediaModel.fromMap).toList();
  }

  Future<void> setBackedUp(String id, String cloudPath) async {
    final db = await _local.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update('media',
          {'cloud_path': cloudPath, 'backed_up_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [id]);
      await enqueueSync(txn, 'media', id);
    });
  }
}
