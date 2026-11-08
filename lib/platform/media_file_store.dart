import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import '../database/local_database.dart';
import '../models/media_model.dart';
import 'media_file_store_stub.dart'
    if (dart.library.io) 'media_file_store_io.dart'
    if (dart.library.js_interop) 'media_file_store_web.dart' as impl;

class StoredFile {
  const StoredFile(this.ref, this.size);
  final String ref; // value for media.local_uri
  final int size;
}

/// Where imported media lives. Android: files in app-private storage (path kept in SQLite).
/// Web: bytes + a generated thumbnail in the browser database (IndexedDB-backed).
abstract class MediaFileStore {
  bool get supportsVideo;

  Future<StoredFile> saveFromXFile(String id, XFile file, {Uint8List? bytes});
  Future<StoredFile> saveBytes(String id, Uint8List bytes, String ext);

  /// Image widget. [cacheWidth] (physical px) makes the decoder produce a small image,
  /// so grids never decode full-resolution originals. [onMissing] fires if the file is gone.
  Widget image(MediaModel m,
      {BoxFit fit = BoxFit.cover,
      int? cacheWidth,
      bool thumbnail = true,
      VoidCallback? onMissing});

  Future<bool> exists(MediaModel m);
  Future<Uint8List> readBytes(MediaModel m);
  Future<void> delete(MediaModel m);
  Future<int> usedBytes();
  Future<void> clearCache();
  Future<void> wipe();

  /// null where video playback is not supported (web in this version).
  Future<VideoPlayerController?> videoController(MediaModel m);
}

MediaFileStore createMediaFileStore(LocalDatabase db) => impl.createStore(db);
