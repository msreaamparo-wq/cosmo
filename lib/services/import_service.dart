import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/media_model.dart';
import '../platform/media_file_store.dart';
import '../repositories/album_repository.dart';
import '../repositories/media_repository.dart';

class ImportResult {
  const ImportResult(
      {this.added = 0,
      this.duplicates = 0,
      this.unsupported = 0,
      this.failed = 0,
      this.addedIds = const [],
      this.cancelled = false});
  final int added, duplicates, unsupported, failed;
  final List<String> addedIds;
  final bool cancelled;

  String summary() {
    if (cancelled) return 'No pictures were picked.';
    final parts = <String>[
      if (added > 0) 'Added $added ${added == 1 ? 'memory' : 'memories'}',
      if (duplicates > 0) '$duplicates already in COSMOS',
      if (unsupported > 0) '$unsupported not supported here',
      if (failed > 0) '$failed could not be read',
    ];
    return parts.isEmpty ? 'Nothing was added.' : '${parts.join(' · ')}.';
  }
}

/// Imports via the system picker (Android Photo Picker / browser file dialog).
/// Only what the child picks is copied, and only into COSMOS' own storage.
class ImportService {
  ImportService(this._store, this._media, this._albums);
  final MediaFileStore _store;
  final MediaRepository _media;
  final AlbumRepository _albums;
  static const _uuid = Uuid();
  final _picker = ImagePicker();

  Future<ImportResult> importFromPicker({String? addToAlbumId}) async {
    final List<XFile> files;
    try {
      files = await _picker.pickMultipleMedia();
    } catch (e) {
      debugPrint('Picker error: ${e.runtimeType}');
      rethrow;
    }
    if (files.isEmpty) return const ImportResult(cancelled: true);

    var added = 0, dup = 0, unsupported = 0, failed = 0;
    final ids = <String>[];
    for (final f in files) {
      try {
        final mime = f.mimeType ?? _guessMime(f.name);
        final isVideo = mime.startsWith('video/');
        if (isVideo && !_store.supportsVideo) {
          unsupported++;
          continue;
        }
        if (!isVideo && !mime.startsWith('image/')) {
          unsupported++;
          continue;
        }
        final id = _uuid.v4();
        Uint8List? bytes;
        DateTime? captured;
        if (!isVideo) {
          bytes = await f.readAsBytes();
          captured = await _readCaptureDate(
              bytes); // null if the file has no date. Never invented.
        }
        final stored = await _store.saveFromXFile(id, f, bytes: bytes);
        final now = DateTime.now();
        final ok = await _media.insert(MediaModel(
          id: id,
          localUri: stored.ref,
          mediaType: isVideo ? MediaType.video : MediaType.image,
          fileName: f.name.isEmpty ? null : f.name,
          mimeType: mime,
          capturedAt: captured,
          fileSize: stored.size,
          importedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
        if (!ok) {
          await _store.delete(MediaModel(
              id: id,
              localUri: stored.ref,
              mediaType: MediaType.image,
              importedAt: now,
              createdAt: now,
              updatedAt: now));
          dup++;
          continue;
        }
        added++;
        ids.add(id);
      } catch (e) {
        debugPrint(
            'Import failed for one file: ${e.runtimeType}'); // never log file content/names
        failed++;
      }
    }
    if (addToAlbumId != null && ids.isNotEmpty)
      await _albums.addMedia(addToAlbumId, ids);
    return ImportResult(
        added: added,
        duplicates: dup,
        unsupported: unsupported,
        failed: failed,
        addedIds: ids);
  }

  static Future<DateTime?> _readCaptureDate(Uint8List bytes) async {
    try {
      final data = await readExifFromBytes(bytes);
      final raw =
          (data['EXIF DateTimeOriginal'] ?? data['Image DateTime'])?.printable;
      if (raw == null || raw.length < 19) return null;
      // EXIF format: "YYYY:MM:DD HH:MM:SS"
      final d = raw.substring(0, 10).split(':').map(int.tryParse).toList();
      final t = raw.substring(11, 19).split(':').map(int.tryParse).toList();
      if (d.length != 3 ||
          t.length != 3 ||
          d.contains(null) ||
          t.contains(null)) return null;
      if (d[0]! < 1900) return null;
      return DateTime(d[0]!, d[1]!, d[2]!, t[0]!, t[1]!, t[2]!);
    } catch (_) {
      return null;
    }
  }

  static String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.heic') || n.endsWith('.heif')) return 'image/heic';
    if (n.endsWith('.mp4')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.3gp')) return 'video/3gpp';
    if (n.endsWith('.webm')) return 'video/webm';
    return 'image/jpeg';
  }
}
