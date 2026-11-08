import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/utilities/motion.dart';

/// Large, friendly button with press feedback. Minimum 56dp tall.
class CosmicButton extends StatefulWidget {
  const CosmicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = CosmosColors.cosmicViolet,
    this.foreground = CosmosColors.cloudWhite,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool expand;

  @override
  State<CosmicButton> createState() => _CosmicButtonState();
}

class _CosmicButtonState extends State<CosmicButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && widget.onPressed != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduce = !MotionScope.of(context);
    final bg =
        enabled ? widget.color : CosmosColors.mutedGray.withValues(alpha: .35);

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: widget.foreground, size: 24),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: widget.foreground, fontSize: 18),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down && !reduce ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                          color: bg.withValues(alpha: .45),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
