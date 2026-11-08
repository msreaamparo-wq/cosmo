import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/utilities/motion.dart';

/// A five-point star that gently pulses. Use [burst] for the favorite "starburst".
class AnimatedStar extends StatefulWidget {
  const AnimatedStar({
    super.key,
    this.size = 28,
    this.color = CosmosColors.starYellow,
    this.animate = true,
    this.filled = true,
  });

  final double size;
  final Color color;
  final bool animate;
  final bool filled;

  @override
  State<AnimatedStar> createState() => _AnimatedStarState();
}

class _AnimatedStarState extends State<AnimatedStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && MotionScope.of(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: 0.9 + 0.2 * Curves.easeInOut.transform(_c.value),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: StarShapePainter(widget.color, filled: widget.filled),
          ),
        ),
      ),
    );
  }
}

class StarShapePainter extends CustomPainter {
  const StarShapePainter(this.color, {this.filled = true});
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.5;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(StarShapePainter old) =>
      old.color != color || old.filled != filled;
}
