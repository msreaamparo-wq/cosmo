import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/utilities/motion.dart';
import '../providers/core_providers.dart';

const _palettes = <String, List<Color>>{
  'midnight': [CosmosColors.deepSpaceNavy, CosmosColors.midnightPurple],
  'nebula': [Color(0xFF241046), Color(0xFF4A2A7A)],
  'aurora': [Color(0xFF0B2230), Color(0xFF1B4A56)],
};

/// Deep-space gradient with softly twinkling stars. ONE controller + ONE painter for the whole
/// field, inside a RepaintBoundary. Stops animating for reduced motion / animations-off.
class CosmicBackground extends ConsumerStatefulWidget {
  const CosmicBackground({super.key, required this.child, this.starCount = 70});
  final Widget child;
  final int starCount;

  @override
  ConsumerState<CosmicBackground> createState() => _CosmicBackgroundState();
}

class _CosmicBackgroundState extends ConsumerState<CosmicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final List<_Star> _stars = _makeStars(widget.starCount);

  static List<_Star> _makeStars(int n) {
    final rnd = math.Random(42);
    return List.generate(
        n,
        (_) => _Star(
            rnd.nextDouble(),
            rnd.nextDouble(),
            0.6 + rnd.nextDouble() * 1.8,
            rnd.nextDouble(),
            rnd.nextInt(5) == 0));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.of(context)) {
      if (!_twinkle.isAnimating) _twinkle.repeat();
    } else {
      _twinkle.stop();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        ref.watch(settingsProvider.select((s) => s.value?.theme ?? 'midnight'));
    final colors = _palettes[theme] ?? _palettes['midnight']!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: IgnorePointer(
              child: RepaintBoundary(
                  child: CustomPaint(
                      painter: _StarFieldPainter(_stars, _twinkle))),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  const _Star(this.x, this.y, this.radius, this.phase, this.gold);
  final double x, y, radius, phase;
  final bool gold;
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter(this.stars, this.t) : super(repaint: t);
  final List<_Star> stars;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final tw = 0.55 + 0.45 * math.sin((t.value + s.phase) * 2 * math.pi);
      paint.color = (s.gold ? CosmosColors.starYellow : CosmosColors.cloudWhite)
          .withValues(alpha: 0.25 + 0.65 * tw);
      canvas.drawCircle(
          Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) => old.stars != stars;
}
