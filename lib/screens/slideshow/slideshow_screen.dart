import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/motion.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/media_image.dart';

enum _Transition { auto, shootingStar, galaxyFade, floating }

/// Space Show: full-screen slideshow of real photos (all, one planet, or favorites).
/// No music is bundled; sound stays off.
class SlideshowScreen extends ConsumerStatefulWidget {
  const SlideshowScreen({super.key, this.planetId, this.favoritesOnly = false});
  final String? planetId;
  final bool favoritesOnly;
  @override
  ConsumerState<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends ConsumerState<SlideshowScreen> {
  List<MediaModel>? _items;
  bool _error = false;
  bool _needsSource = false;
  List<AlbumModel> _albums = [];
  int _index = 0;
  bool _playing = true;
  bool _controls = true;
  int _seconds = 5;
  _Transition _transition = _Transition.auto;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
    if (widget.planetId != null || widget.favoritesOnly) {
      _load(planetId: widget.planetId, favorites: widget.favoritesOnly);
    } else {
      _needsSource = true;
      ref.read(albumRepositoryProvider).all().then((a) {
        if (mounted) setState(() => _albums = a);
      });
    }
  }

  Future<void> _load({String? planetId, bool favorites = false}) async {
    setState(() {
      _needsSource = false;
      _error = false;
      _items = null;
    });
    try {
      final media = ref.read(mediaRepositoryProvider);
      List<MediaModel> items;
      if (planetId != null) {
        items = await media
            .byIds(await ref.read(albumRepositoryProvider).mediaIds(planetId));
      } else {
        items = await media.page(
            MediaQueryOptions(
                filter: favorites ? MediaFilter.favorites : MediaFilter.all),
            offset: 0,
            limit: 1000);
      }
      items = items.where((m) => !m.isVideo).toList(); // photos only
      if (!mounted) return;
      setState(() {
        _items = items;
        _index = 0;
      });
      if (items.isNotEmpty) {
        ref.read(achievementServiceProvider).visit('slideshow');
        _schedule();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_playing || (_items?.length ?? 0) < 2) return;
    _timer = Timer(Duration(seconds: _seconds), () => _go(1));
  }

  void _go(int d) {
    final n = _items!.length;
    if (n == 0) return;
    setState(() => _index = (_index + d + n) % n);
    _schedule();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  void _exit() =>
      context.canPop() ? context.pop() : context.go(CosmosRoutes.home);

  @override
  void dispose() {
    _timer?.cancel();
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
    super.dispose();
  }

  _Transition get _effective => _transition == _Transition.auto
      ? _Transition.values[1 + (_index % 3)]
      : _transition;

  Widget _build(Widget child, Animation<double> a) {
    switch (_effective) {
      case _Transition.shootingStar:
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
              position: Tween(begin: const Offset(0.6, -0.4), end: Offset.zero)
                  .animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child),
        );
      case _Transition.floating:
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.12), end: Offset.zero)
                  .animate(a),
              child: child),
        );
      case _Transition.galaxyFade:
      case _Transition.auto:
        return FadeTransition(
            opacity: a,
            child: ScaleTransition(
                scale: Tween(begin: 1.1, end: 1.0).animate(a), child: child));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSource)
      return _SourcePicker(
          albums: _albums,
          onPick: (planet, fav) => _load(planetId: planet, favorites: fav),
          onExit: _exit);
    if (_error)
      return Scaffold(
          body: ErrorMessage(
              onRetry: () => _load(
                  planetId: widget.planetId, favorites: widget.favoritesOnly)));
    final items = _items;
    if (items == null)
      return const Scaffold(
          body: CosmicLoading(label: 'Preparing your Space Show…'));
    if (items.isEmpty) {
      return Scaffold(
        body: CosmicBackground(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                        tooltip: 'Exit',
                        onPressed: _exit,
                        icon: const Icon(Icons.close))),
                const Expanded(
                    child: EmptyState(
                        title: 'Nothing to show yet',
                        message:
                            'Add some photos first, then come back for your Space Show!',
                        leading: AstronautMascot(size: 100))),
              ],
            ),
          ),
        ),
      );
    }
    final m = items[_index];
    final motion = MotionScope.of(context);
    final text = Theme.of(context).textTheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.escape): _exit,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _controls = !_controls),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CosmicBackground(
                  child: AnimatedSwitcher(
                    duration: motion
                        ? const Duration(milliseconds: 900)
                        : Duration.zero,
                    transitionBuilder: (child, a) => _build(child, a),
                    child: SizedBox.expand(
                        key: ValueKey('${m.id}|$_index'),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: MediaImage(m,
                                full: true, fit: BoxFit.contain))),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _controls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controls,
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              IconButton(
                                  tooltip: 'Exit Space Show',
                                  constraints: const BoxConstraints(
                                      minWidth: 48, minHeight: 48),
                                  onPressed: _exit,
                                  icon: const Icon(Icons.close)),
                              Expanded(
                                  child: Text('${_index + 1} / ${items.length}',
                                      textAlign: TextAlign.center,
                                      style: text.titleMedium)),
                              PopupMenuButton<_Transition>(
                                tooltip: 'Transition style',
                                icon: const Icon(Icons.auto_awesome),
                                initialValue: _transition,
                                onSelected: (t) =>
                                    setState(() => _transition = t),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: _Transition.auto,
                                      child: Text('Mix it up')),
                                  PopupMenuItem(
                                      value: _Transition.shootingStar,
                                      child: Text('Shooting Star')),
                                  PopupMenuItem(
                                      value: _Transition.galaxyFade,
                                      child: Text('Galaxy Fade')),
                                  PopupMenuItem(
                                      value: _Transition.floating,
                                      child: Text('Floating Memories')),
                                ],
                              ),
                              PopupMenuButton<int>(
                                tooltip: 'Speed',
                                icon: const Icon(Icons.speed),
                                initialValue: _seconds,
                                onSelected: (s) {
                                  setState(() => _seconds = s);
                                  _schedule();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 8, child: Text('Slow')),
                                  PopupMenuItem(
                                      value: 5, child: Text('Normal')),
                                  PopupMenuItem(value: 3, child: Text('Fast')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    iconSize: 36,
                                    tooltip: 'Previous',
                                    constraints: const BoxConstraints(
                                        minWidth: 64, minHeight: 64),
                                    onPressed: () => _go(-1),
                                    icon: const Icon(Icons.skip_previous)),
                                IconButton.filled(
                                  iconSize: 40,
                                  tooltip: _playing ? 'Pause' : 'Play',
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          CosmosColors.cosmicViolet,
                                      minimumSize: const Size(72, 72)),
                                  onPressed: _togglePlay,
                                  icon: Icon(_playing
                                      ? Icons.pause
                                      : Icons.play_arrow),
                                ),
                                IconButton(
                                    iconSize: 36,
                                    tooltip: 'Next',
                                    constraints: const BoxConstraints(
                                        minWidth: 64, minHeight: 64),
                                    onPressed: () => _go(1),
                                    icon: const Icon(Icons.skip_next)),
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
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker(
      {required this.albums, required this.onPick, required this.onExit});
  final List<AlbumModel> albums;
  final void Function(String? planetId, bool favorites) onPick;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'Back',
                        onPressed: onExit,
                        icon: const Icon(Icons.arrow_back)),
                    Expanded(
                        child: Text('Space Show', style: text.headlineSmall)),
                  ]),
                  const SizedBox(height: 8),
                  Text('What would you like to watch?', style: text.bodyLarge),
                  const SizedBox(height: 12),
                  _tile(Icons.photo_library, 'All my photos',
                      CosmosColors.skyBlue, () => onPick(null, false)),
                  _tile(Icons.star, 'My favorite stars',
                      CosmosColors.starYellow, () => onPick(null, true)),
                  for (final a in albums)
                    _tile(
                        Icons.public,
                        '${a.sticker ?? ''} ${a.name} (${a.mediaCount})'.trim(),
                        ColorOpacityX.fromHex(a.planetColor),
                        () => onPick(a.id, false)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, Color color, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: CosmosColors.midnightPurple.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(20),
          child: ListTile(
            minVerticalPadding: 14,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            leading: Icon(icon, color: color),
            title: Text(label),
            trailing: const Icon(Icons.play_arrow),
            onTap: onTap,
          ),
        ),
      );
}
