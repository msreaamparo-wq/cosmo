import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../providers/core_providers.dart';

final _flagged = <String>{};

/// Shows a media item without ever decoding more than needed.
/// [logicalWidth] sets the decode size (x device pixel ratio); full=true loads the original (viewer).
class MediaImage extends ConsumerWidget {
  const MediaImage(this.media,
      {super.key,
      this.logicalWidth = 200,
      this.fit = BoxFit.cover,
      this.full = false});
  final MediaModel media;
  final double logicalWidth;
  final BoxFit fit;
  final bool full;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final store = ref.watch(mediaFileStoreProvider);
    if (media.isVideo) {
      return ColoredBox(
        color: const Color(0xFF21194D),
        child: Center(
            child: Icon(Icons.play_circle_fill,
                size: (logicalWidth * 0.3).clamp(28, 64),
                color: const Color(0xFFFFF9F0))),
      );
    }
    return store.image(
      media,
      fit: fit,
      thumbnail: !full,
      cacheWidth: full ? 2048 : (logicalWidth * dpr).round().clamp(64, 1024),
      onMissing: () {
        // Never pretend a missing file still exists: flag it once so it leaves the gallery.
        if (_flagged.add(media.id)) {
          ref.read(mediaRepositoryProvider).markUnavailable(media.id).then((_) {
            ref.read(dataVersionProvider.notifier).bump();
          });
        }
      },
    );
  }
}
