import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import 'cosmic_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.leading,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final Widget? leading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(height: 16)],
            Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    text.bodyLarge?.copyWith(color: CosmosColors.softLavender)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              CosmicButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
