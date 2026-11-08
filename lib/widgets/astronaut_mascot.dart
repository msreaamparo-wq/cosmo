import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/utilities/motion.dart';

/// The COSMOS astronaut. One consistent drawing used everywhere
/// (splash, home avatar, empty states). Floats gently unless reduced motion is on.
class AstronautMascot extends StatefulWidget {
  const AstronautMascot({super.key, this.size = 96, this.animate = true});
  final double size;
  final bool animate;

  @override
  State<AstronautMascot> createState() => _AstronautMascotState();
}

class _AstronautMascotState extends State<AstronautMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3600));

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
    return Semantics(
      label: 'Little astronaut',
      image: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform.translate(
            offset: Offset(0, (t - .5) * widget.size * 0.08),
            child: Transform.rotate(angle: (t - .5) * 0.08, child: child),
          );
        },
        child: RepaintBoundary(
          child: CustomPaint(
              size: Size.square(widget.size),
              painter: const _AstronautPainter()),
        ),
      ),
    );
  }
}

class _AstronautPainter extends CustomPainter {
  const _AstronautPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final suit = Paint()..color = CosmosColors.cloudWhite;
    final shade = Paint()..color = CosmosColors.softLavender;

    // Backpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .18, w * .50, w * .64, w * .34),
          Radius.circular(w * .1)),
      Paint()..color = CosmosColors.nebulaPurple,
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * .26, w * .52, w * .48, w * .36),
          Radius.circular(w * .14)),
      suit,
    );
    // Chest light
    canvas.drawCircle(
        Offset(w * .5, w * .68), w * .045, Paint()..color = CosmosColors.coral);
    // Arms
    canvas
      ..drawCircle(Offset(w * .22, w * .66), w * .08, shade)
      ..drawCircle(Offset(w * .78, w * .66), w * .08, shade);
    // Helmet
    canvas.drawCircle(Offset(w * .5, w * .34), w * .27, suit);
    // Visor
    final visor = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w * .5, w * .35), width: w * .38, height: w * .26),
        Radius.circular(w * .12));
    canvas.drawRRect(visor, Paint()..color = CosmosColors.deepSpaceNavy);
    // Visor shine + smile
    canvas.drawCircle(Offset(w * .42, w * .30), w * .025,
        Paint()..color = CosmosColors.skyBlue);
    canvas
      ..drawCircle(Offset(w * .45, w * .35), w * .02,
          Paint()..color = CosmosColors.cloudWhite)
      ..drawCircle(Offset(w * .55, w * .35), w * .02,
          Paint()..color = CosmosColors.cloudWhite)
      ..drawArc(
        Rect.fromCenter(
            center: Offset(w * .5, w * .38), width: w * .12, height: w * .08),
        0.2,
        2.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .02
          ..strokeCap = StrokeCap.round
          ..color = CosmosColors.mint,
      );
    // Antenna
    canvas
      ..drawLine(
          Offset(w * .5, w * .07),
          Offset(w * .5, w * .13),
          Paint()
            ..color = CosmosColors.softLavender
            ..strokeWidth = w * .02)
      ..drawCircle(Offset(w * .5, w * .06), w * .03,
          Paint()..color = CosmosColors.starYellow);
  }

  @override
  bool shouldRepaint(_AstronautPainter old) => false;
}
