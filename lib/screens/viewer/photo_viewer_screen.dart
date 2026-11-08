import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/error_message.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_image.dart';

/// Immersive viewer: swipe, pinch-zoom, pan, favorite, add to planet, details, share.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.initialId, this.ids});
  final String initialId;
  final List<String>? ids;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  List<MediaModel>? _items;
  bool _error = false;
  late PageController _page;
  int _index = 0;
  bool _controls = true;
  bool _zoomed = false;
  bool _burst = false;

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = false;
    });
    try {
      final ids = widget.ids ?? [widget.initialId];
      final items = await ref.read(mediaRepositoryProvider).byIds(ids);
      final i = items.indexWhere((m) => m.id == widget.initialId);
      if (!mounted) return;
      _index = i < 0 ? 0 : i;
      _page.dispose();
      _page = PageController(initialPage: _index);
      setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  MediaModel get _current => _items![_index];

  void _step(int d) {
    final n = _items!.length;
    final next = _index + d;
    if (next < 0 || next >= n) return;
    _page.animateToPage(next,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _favorite() async {
    final m = _current;
    await ref.read(mediaRepositoryProvider).setFavorite([m.id], !m.isFavorite);
    final fresh = await ref.read(mediaRepositoryProvider).byId(m.id);
    refreshUniverse(ref);
    if (!mounted || fresh == null) return;
    setState(() {
      _items![_index] = fresh;
      _burst = fresh.isFavorite;
    });
    if (fresh.isFavorite) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _burst = false);
      });
    }
  }

  Future<void> _share() async {
    final m = _current;
    try {
      final bytes = await ref.read(mediaFileStoreProvider).readBytes(m);
      await Share.shareXFiles([
        XFile.fromData(bytes,
            name: m.fileName ?? '${m.id}.jpg', mimeType: m.mimeType)
      ]);
    } catch (_) {
      if (mounted)
        toast(context, 'Sharing is not available for this memory here.');
    }
  }

  void _info() {
    final m = _current;
    final text = Theme.of(context).textTheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 120,
                child: Text(k,
                    style: text.bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender))),
            Expanded(child: Text(v, style: text.bodyLarge)),
          ]),
        );
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: CosmosColors.midnightPurple,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About this memory', style: text.titleLarge),
            const SizedBox(height: 8),
            row('Name', m.fileName ?? 'Unknown'),
            row('Type', m.isVideo ? 'Video' : 'Photo'),
            row('Format', m.mimeType ?? 'Unknown'),
            row('Size', formatBytes(m.fileSize)),
            row(
                'Date taken',
                m.capturedAt == null
                    ? 'Date unknown'
                    : formatDateTime(m.capturedAt!)),
            row('Added to COSMOS', formatDateTime(m.importedAt)),
            row(
                'Backup',
                m.isBackedUp
                    ? 'Saved in your parent\'s private cloud'
                    : 'Only on this device'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error)
      return Scaffold(
          body: ErrorMessage(
              message: 'We could not open this memory.', onRetry: _load));
    final items = _items;
    if (items == null)
      return const Scaffold(
          backgroundColor: Colors.black, body: CosmicLoading());
    if (items.isEmpty) {
      return Scaffold(
        body: ErrorMessage(
            message: 'This memory is no longer available.',
            onRetry: () => context.canPop()
                ? context.pop()
                : context.go(CosmosRoutes.home)),
      );
    }
    final m = _current;
    final text = Theme.of(context).textTheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.canPop() ? context.pop() : context.go(CosmosRoutes.home),
        const SingleActivator(LogicalKeyboardKey.keyF): _favorite,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _page,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: items.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (_, i) => items[i].isVideo
                    ? _VideoPage(key: ValueKey(items[i].id), media: items[i])
                    : _ZoomablePage(
                        key: ValueKey(items[i].id),
                        media: items[i],
                        onZoom: (z) {
                          if (z != _zoomed) setState(() => _zoomed = z);
                        },
                        onTap: () => setState(() => _controls = !_controls),
                      ),
              ),
              if (_burst)
                IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1.6),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => Opacity(
                          opacity: (1.6 - v).clamp(0.0, 1.0),
                          child: Icon(Icons.star,
                              size: 120 * v, color: CosmosColors.starYellow)),
                    ),
                  ),
                ),
              AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controls,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black87, Colors.transparent])),
                        child: SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              IconButton(
                                  tooltip: 'Close',
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  onPressed: () => context.canPop()
                                      ? context.pop()
                                      : context.go(CosmosRoutes.home),
                                  icon: const Icon(Icons.close)),
                              Expanded(
                                  child: Text('${_index + 1} / ${items.length}',
                                      textAlign: TextAlign.center,
                                      style: text.titleMedium)),
                              IconButton(
                                  tooltip: 'Decorate with a frame',
                                  onPressed: m.isVideo
                                      ? null
                                      : () => context.push(
                                          '${CosmosRoutes.frames}?media=${m.id}'),
                                  icon:
                                      const Icon(Icons.filter_frames_outlined)),
                              IconButton(
                                  tooltip: 'Share',
                                  onPressed: _share,
                                  icon: const Icon(Icons.ios_share)),
                              IconButton(
                                  tooltip: 'Photo details',
                                  onPressed: _info,
                                  icon: const Icon(Icons.info_outline)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black87, Colors.transparent])),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  iconSize: 30,
                                  tooltip: 'Previous',
                                  constraints: const BoxConstraints(
                                      minWidth: 56, minHeight: 56),
                                  onPressed:
                                      _index > 0 ? () => _step(-1) : null,
                                  icon: const Icon(Icons.chevron_left)),
                              IconButton(
                                  iconSize: 30,
                                  tooltip: m.isFavorite
                                      ? 'Remove from favorites'
                                      : 'Add to favorites',
                                  constraints: const BoxConstraints(
                                      minWidth: 56, minHeight: 56),
                                  onPressed: _favorite,
                                  icon: Icon(
                                      m.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: CosmosColors.starYellow)),
                              IconButton(
                                  iconSize: 30,
                                  tooltip: 'Add to planet',
                                  constraints: const BoxConstraints(
                                      minWidth: 56, minHeight: 56),
                                  onPressed: () =>
                                      addToPlanet(context, ref, [m.id]),
                                  icon: const Icon(Icons.public)),
                              IconButton(
                                  iconSize: 30,
                                  tooltip: 'Next',
                                  constraints: const BoxConstraints(
                                      minWidth: 56, minHeight: 56),
                                  onPressed: _index < items.length - 1
                                      ? () => _step(1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage(
      {super.key,
      required this.media,
      required this.onZoom,
      required this.onTap});
  final MediaModel media;
  final ValueChanged<bool> onZoom;
  final VoidCallback onTap;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _tc = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _tc.addListener(() => widget.onZoom(_tc.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_tc.value.getMaxScaleOnAxis() > 1.02) {
      _tc.value = Matrix4.identity();
    } else {
      const s = 2.5;
      final p = _doubleTapAt;
      _tc.value = Matrix4.identity()
        ..translate(-p.dx * (s - 1), -p.dy * (s - 1))
        ..scale(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
            child: MediaImage(widget.media, full: true, fit: BoxFit.contain)),
      ),
    );
  }
}

class _VideoPage extends ConsumerStatefulWidget {
  const _VideoPage({super.key, required this.media});
  final MediaModel media;
  @override
  ConsumerState<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<_VideoPage> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c =
          await ref.read(mediaFileStoreProvider).videoController(widget.media);
      if (c == null) throw StateError('unavailable');
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('This video cannot be played here.',
                  textAlign: TextAlign.center)));
    }
    final c = _c;
    if (c == null) return const CosmicLoading();
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (_, v, __) => IconButton(
                iconSize: 64,
                tooltip: v.isPlaying ? 'Pause' : 'Play',
                onPressed: () => v.isPlaying ? c.pause() : c.play(),
                icon: Icon(v.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: CosmosColors.cloudWhite.withValues(alpha: .9)),
              ),
            ),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(c, allowScrubbing: true)),
          ],
        ),
      ),
    );
  }
}
