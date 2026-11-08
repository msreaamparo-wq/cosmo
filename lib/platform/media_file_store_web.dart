import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:sqflite/sqflite.dart';
import 'package:video_player/video_player.dart';

import '../database/local_database.dart';
import '../models/media_model.dart';
import 'media_file_store.dart';

MediaFileStore createStore(LocalDatabase db) => _WebMediaFileStore(db);

class _WebMediaFileStore implements MediaFileStore {
  _WebMediaFileStore(this._local);
  final LocalDatabase _local;

  // Small in-memory LRU so scrolling does not re-read blobs from IndexedDB.
  final LinkedHashMap<String, Future<Uint8List?>> _cache = LinkedHashMap();
  static const _maxCached = 80;

  @override
  bool get supportsVideo =>
      false; // video import/playback is Android-only in this version

  String _id(MediaModel m) =>
      m.localUri.startsWith('web:') ? m.localUri.substring(4) : m.id;

  Future<Uint8List?> _thumbOf(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 360);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null; // e.g. HEIC in Chrome: the original is used instead
    }
  }

  @override
  Future<StoredFile> saveFromXFile(String id, XFile file,
      {Uint8List? bytes}) async {
    final b = bytes ?? await file.readAsBytes();
    return _put(id, b);
  }

  @override
  Future<StoredFile> saveBytes(String id, Uint8List bytes, String ext) =>
      _put(id, bytes);

  Future<StoredFile> _put(String id, Uint8List bytes) async {
    final db = await _local.database;
    await db.insert(
      'media_blobs',
      {'media_id': id, 'bytes': bytes, 'thumb': await _thumbOf(bytes)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return StoredFile('web:$id', bytes.length);
  }

  Future<Uint8List?> _load(String id, bool thumb) async {
    final db = await _local.database;
    if (thumb) {
      final t = await db.query('media_blobs',
          columns: ['thumb'], where: 'media_id = ?', whereArgs: [id], limit: 1);
      final data = t.isEmpty ? null : t.first['thumb'] as Uint8List?;
      if (data != null) return data;
      // No generated thumbnail (e.g. unsupported format): fall through to the original.
    }
    final rows = await db.query('media_blobs',
        columns: ['bytes'], where: 'media_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first['bytes'] as Uint8List?;
  }

  Future<Uint8List?> _cached(String id, bool thumb) {
    final key = '$id|$thumb';
    final hit = _cache.remove(key);
    final f = hit ?? _load(id, thumb);
    _cache[key] = f;
    while (_cache.length > _maxCached) {
      _cache.remove(_cache.keys.first);
    }
    return f;
  }

  @override
  Widget image(MediaModel m,
      {BoxFit fit = BoxFit.cover,
      int? cacheWidth,
      bool thumbnail = true,
      VoidCallback? onMissing}) {
    return FutureBuilder<Uint8List?>(
      key: ValueKey('${m.id}|$thumbnail'),
      future: _cached(_id(m), thumbnail),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Color(0xFF21194D));
        }
        final bytes = snap.data;
        if (bytes == null) {
          if (onMissing != null)
            WidgetsBinding.instance.addPostFrameCallback((_) => onMissing());
          return const ColoredBox(
            color: Color(0xFF21194D),
            child: Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: Color(0xFF9298B5))),
          );
        }
        return Image.memory(bytes,
            fit: fit,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low);
      },
    );
  }

  @override
  Future<bool> exists(MediaModel m) async {
    final db = await _local.database;
    final r = await db.rawQuery(
        'SELECT 1 FROM media_blobs WHERE media_id = ? LIMIT 1', [_id(m)]);
    return r.isNotEmpty;
  }

  @override
  Future<Uint8List> readBytes(MediaModel m) async {
    final b = await _load(_id(m), false);
    if (b == null) throw StateError('Media not available');
    return b;
  }

  @override
  Future<void> delete(MediaModel m) async {
    final db = await _local.database;
    await db.delete('media_blobs', where: 'media_id = ?', whereArgs: [_id(m)]);
    _cache.removeWhere((k, _) => k.startsWith('${_id(m)}|'));
  }

  @override
  Future<int> usedBytes() async {
    final db = await _local.database;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(LENGTH(bytes) + COALESCE(LENGTH(thumb), 0)), 0) AS n FROM media_blobs');
    return (r.first['n'] as int?) ?? 0;
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }

  @override
  Future<void> wipe() async {
    final db = await _local.database;
    await db.delete('media_blobs');
    _cache.clear();
  }

  @override
  Future<VideoPlayerController?> videoController(MediaModel m) async => null;
}
