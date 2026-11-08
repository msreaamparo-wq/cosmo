import 'package:flutter/material.dart';

import '../core/utilities/motion.dart';

import 'planet_painter.dart';

/// A planet that bobs gently. Respects reduced motion.
class FloatingPlanet extends StatefulWidget {
  const FloatingPlanet({
    super.key,
    required this.color,
    this.theme = 'rings',
    this.size = 96,
    this.animate = true,
    this.bobDistance = 6,
    this.semanticLabel,
  });

  final Color color;
  final String theme;
  final double size;
  final bool animate;
  final double bobDistance;
  final String? semanticLabel;

  @override
  State<FloatingPlanet> createState() => _FloatingPlanetState();
}

class _FloatingPlanetState extends State<FloatingPlanet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));

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
    final planet = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: PlanetPainter(color: widget.color, theme: widget.theme),
      ),
    );
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      excludeSemantics: widget.semanticLabel != null,
      child: AnimatedBuilder(
        animation: _c,
        child: planet,
        builder: (_, child) => Transform.translate(
          offset: Offset(
              0,
              (Curves.easeInOut.transform(_c.value) - .5) *
                  2 *
                  widget.bobDistance),
          child: child,
        ),
      ),
    );
  }
}
