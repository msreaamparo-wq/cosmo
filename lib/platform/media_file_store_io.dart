import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../database/local_database.dart';
import '../models/media_model.dart';
import 'media_file_store.dart';

MediaFileStore createStore(LocalDatabase db) => _IoMediaFileStore();

class _IoMediaFileStore implements MediaFileStore {
  Directory? _dir;

  Future<Directory> _mediaDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(docs.path, 'cosmos_media'));
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  @override
  bool get supportsVideo => true;

  String _ext(String name, [String fallback = '.jpg']) {
    final e = p.extension(name);
    return (e.isEmpty || e.length > 6) ? fallback : e.toLowerCase();
  }

  @override
  Future<StoredFile> saveFromXFile(String id, XFile file,
      {Uint8List? bytes}) async {
    final dir = await _mediaDir();
    final dest = File(p.join(dir.path, '$id${_ext(file.name)}'));
    // A COPY inside COSMOS' private storage: the original in the device gallery is never modified.
    await File(file.path).copy(dest.path);
    return StoredFile(dest.path, await dest.length());
  }

  @override
  Future<StoredFile> saveBytes(String id, Uint8List bytes, String ext) async {
    final dir = await _mediaDir();
    final dest = File(p.join(dir.path, '$id$ext'));
    await dest.writeAsBytes(bytes, flush: true);
    return StoredFile(dest.path, bytes.length);
  }

  @override
  Widget image(MediaModel m,
      {BoxFit fit = BoxFit.cover,
      int? cacheWidth,
      bool thumbnail = true,
      VoidCallback? onMissing}) {
    return Image.file(
      File(m.localUri),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stack) {
        if (onMissing != null)
          WidgetsBinding.instance.addPostFrameCallback((_) => onMissing());
        return const _MissingMedia();
      },
    );
  }

  @override
  Future<bool> exists(MediaModel m) => File(m.localUri).exists();

  @override
  Future<Uint8List> readBytes(MediaModel m) => File(m.localUri).readAsBytes();

  @override
  Future<void> delete(MediaModel m) async {
    final f = File(m.localUri);
    if (await f.exists()) await f.delete(); // our private copy only
  }

  @override
  Future<int> usedBytes() async {
    final dir = await _mediaDir();
    var total = 0;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  @override
  Future<void> clearCache() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    try {
      final tmp = await getTemporaryDirectory();
      if (await tmp.exists()) {
        await for (final e in tmp.list(followLinks: false)) {
          try {
            await e.delete(recursive: true);
          } catch (_) {/* in use: skip */}
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> wipe() async {
    final dir = await _mediaDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _dir = null;
    }
  }

  @override
  Future<VideoPlayerController?> videoController(MediaModel m) async {
    if (!await File(m.localUri).exists()) return null;
    return VideoPlayerController.file(File(m.localUri));
  }
}

class _MissingMedia extends StatelessWidget {
  const _MissingMedia();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF21194D),
        child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: Color(0xFF9298B5))),
      );
}
