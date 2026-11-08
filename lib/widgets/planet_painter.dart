import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';

/// Draws one cute smiling planet. Themes: rings | stripes | craters | plain.
class PlanetPainter extends CustomPainter {
  const PlanetPainter({required this.color, this.theme = 'rings'});

  final Color color;
  final String theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final hasRings = theme == 'rings';
    final r = size.shortestSide * (hasRings ? 0.32 : 0.42);
    final rect = Rect.fromCircle(center: c, radius: r);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..color = color.lighten(.2).withValues(alpha: .9);
    final ringRect = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.96,
        height: size.height * 0.30);

    void ring(double start, double sweep) {
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(-0.35)
        ..drawArc(ringRect, start, sweep, false, ringPaint)
        ..restore();
    }

    if (hasRings) ring(math.pi, math.pi); // back half of the ring

    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        colors: [color.lighten(.22), color, color.darken(.22)],
        stops: const [0, .55, 1],
      ).createShader(rect);
    canvas.drawCircle(c, r, body);

    canvas
      ..save()
      ..clipPath(Path()..addOval(rect));
    if (theme == 'stripes') {
      final stripe = Paint()..color = color.darken(.12).withValues(alpha: .55);
      for (var i = 0; i < 3; i++) {
        final y = c.dy - r * .55 + i * r * .55;
        canvas.drawRect(Rect.fromLTWH(c.dx - r, y, r * 2, r * .2), stripe);
      }
    } else if (theme == 'craters') {
      final crater = Paint()..color = color.darken(.15).withValues(alpha: .5);
      canvas
        ..drawCircle(c + Offset(r * .45, -r * .45), r * .16, crater)
        ..drawCircle(c + Offset(-r * .55, r * .35), r * .2, crater)
        ..drawCircle(c + Offset(r * .35, r * .55), r * .11, crater);
    }
    canvas.restore();

    // Face
    final ink = Paint()..color = CosmosColors.deepSpaceNavy;
    canvas
      ..drawCircle(c + Offset(-r * .3, -r * .05), r * .07, ink)
      ..drawCircle(c + Offset(r * .3, -r * .05), r * .07, ink)
      ..drawArc(
        Rect.fromCenter(
            center: c + Offset(0, r * .12), width: r * .5, height: r * .34),
        0.2,
        math.pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .07
          ..strokeCap = StrokeCap.round
          ..color = CosmosColors.deepSpaceNavy,
      );
    // Cheeks
    final cheek = Paint()
      ..color = CosmosColors.nebulaPink.withValues(alpha: .55);
    canvas
      ..drawCircle(c + Offset(-r * .5, r * .12), r * .08, cheek)
      ..drawCircle(c + Offset(r * .5, r * .12), r * .08, cheek);

    if (hasRings) ring(0, math.pi); // front half of the ring
  }

  @override
  bool shouldRepaint(PlanetPainter old) =>
      old.color != color || old.theme != theme;
}
