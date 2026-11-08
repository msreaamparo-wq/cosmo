import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../core/utilities/motion.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/media_image.dart';

class _Group {
  const _Group(this.name, this.items, this.color);
  final String name;
  final List<MediaModel> items;
  final Color color;
}

/// Each planet (plus "All memories") becomes a constellation: real photos as stars joined by lines.
class ConstellationScreen extends ConsumerStatefulWidget {
  const ConstellationScreen({super.key});
  @override
  ConsumerState<ConstellationScreen> createState() =>
      _ConstellationScreenState();
}

class _ConstellationScreenState extends ConsumerState<ConstellationScreen> {
  List<_Group>? _groups;
  bool _error = false;
  final _page = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(achievementServiceProvider).visit('constellation');
  }

  Future<void> _load() async {
    setState(() {
      _error = false;
      _groups = null;
    });
    try {
      final media = ref.read(mediaRepositoryProvider);
      final albumsRepo = ref.read(albumRepositoryProvider);
      final groups = <_Group>[];
      final all = await media.page(
          const MediaQueryOptions(filter: MediaFilter.photos),
          offset: 0,
          limit: 12);
      if (all.isNotEmpty)
        groups.add(_Group('All my memories', all, CosmosColors.starYellow));
      for (final a in await albumsRepo.all()) {
        final ids = (await albumsRepo.mediaIds(a.id)).take(12).toList();
        final items =
            (await media.byIds(ids)).where((m) => !m.isVideo).toList();
        if (items.isNotEmpty)
          groups.add(_Group('${a.sticker ?? ''} ${a.name}'.trim(), items,
              ColorOpacityX.fromHex(a.planetColor)));
      }
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error)
      return CosmicScaffold(
          title: 'Constellations', body: ErrorMessage(onRetry: _load));
    final groups = _groups;
    if (groups == null)
      return const CosmicScaffold(
          title: 'Constellations', body: CosmicLoading());
    if (groups.isEmpty) {
      return CosmicScaffold(
        title: 'Constellations',
        body: EmptyState(
          title: 'No stars to connect yet',
          message:
              'Add some pictures and they will join up into constellations.',
          leading: const AstronautMascot(size: 100),
          actionLabel: 'Add pictures',
          onAction: () => context.go(CosmosRoutes.gallery),
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    return CosmicScaffold(
      title: 'Constellations',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                IconButton(
                    tooltip: 'Previous constellation',
                    onPressed: _current > 0
                        ? () => _page.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut)
                        : null,
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Column(
                    children: [
                      Text(groups[_current].name,
                          textAlign: TextAlign.center, style: text.titleLarge),
                      Text(plural(groups[_current].items.length, 'star'),
                          style: text.bodyMedium
                              ?.copyWith(color: CosmosColors.softLavender)),
                    ],
                  ),
                ),
                IconButton(
                    tooltip: 'Next constellation',
                    onPressed: _current < groups.length - 1
                        ? () => _page.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut)
                        : null,
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: groups.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => _ConstellationCanvas(
                  key: ValueKey(groups[i].name), group: groups[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < groups.length; i++)
                  Container(
                      margin: const EdgeInsets.all(3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _current
                              ? CosmosColors.starYellow
                              : CosmosColors.mutedGray))
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationCanvas extends StatefulWidget {
  const _ConstellationCanvas({super.key, required this.group});
  final _Group group;
  @override
  State<_ConstellationCanvas> createState() => _ConstellationCanvasState();
}

class _ConstellationCanvasState extends State<_ConstellationCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.of(context)) {
      _draw.forward();
    } else {
      _draw.value = 1;
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  /// Deterministic zig-zag layout, top to bottom, with a little jitter seeded by the photo id.
  List<Offset> _positions(int n) {
    return List.generate(n, (i) {
      final seed = widget.group.items[i].id.hashCode;
      final rnd = math.Random(seed);
      final t = n == 1 ? 0.5 : i / (n - 1);
      final x =
          0.15 + 0.7 * ((i * 0.618) % 1.0) + (rnd.nextDouble() - .5) * 0.06;
      final y = 0.08 + 0.84 * t + (rnd.nextDouble() - .5) * 0.04;
      return Offset(x.clamp(0.1, 0.9), y.clamp(0.06, 0.94));
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.group.items;
    final pos = _positions(items.length);
    return LayoutBuilder(builder: (context, c) {
      const star = 64.0;
      final w = c.maxWidth, h = c.maxHeight;
      Offset at(int i) => Offset(pos[i].dx * w, pos[i].dy * h);
      return Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _draw,
                builder: (_, __) => CustomPaint(
                    painter: _LinesPainter(
                        [for (var i = 0; i < items.length; i++) at(i)],
                        widget.group.color,
                        _draw.value)),
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: at(i).dx - star / 2,
              top: at(i).dy - star / 2,
              width: star,
              height: star,
              child: Semantics(
                button: true,
                label: 'Open star ${i + 1} of ${items.length}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => context.push(CosmosRoutes.viewer(items[i].id),
                      extra: items.map((m) => m.id).toList()),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.group.color, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: widget.group.color.withValues(alpha: .5),
                            blurRadius: 14)
                      ],
                    ),
                    child: ClipOval(
                        child: MediaImage(items[i], logicalWidth: star)),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.points, this.color, this.progress);
  final List<Offset> points;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: .7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final segs = points.length - 1;
    final drawn = progress * segs;
    for (var i = 0; i < segs; i++) {
      final t = (drawn - i).clamp(0.0, 1.0);
      if (t <= 0) break;
      canvas.drawLine(
          points[i], Offset.lerp(points[i], points[i + 1], t)!, paint);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) =>
      old.progress != progress || old.points != points;
}
