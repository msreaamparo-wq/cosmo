import 'package:flutter/material.dart';

import '../core/utilities/motion.dart';
import 'animated_star.dart';

/// A little spinning star. Static when animations are off.
class CosmicLoading extends StatefulWidget {
  const CosmicLoading({super.key, this.label});
  final String? label;

  @override
  State<CosmicLoading> createState() => _CosmicLoadingState();
}

class _CosmicLoadingState extends State<CosmicLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.of(context)) {
      if (!_c.isAnimating) _c.repeat();
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
      label: widget.label ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
                turns: _c, child: const AnimatedStar(size: 40, animate: false)),
            if (widget.label != null) ...[
              const SizedBox(height: 12),
              Text(widget.label!)
            ],
          ],
        ),
      ),
    );
  }
}
