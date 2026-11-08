import 'package:flutter/material.dart';

import 'cosmic_button.dart';

/// Friendly error with a retry. Never shows raw exceptions.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(
      {super.key,
      this.message = 'Oops! The stars got tangled. Please try again.',
      this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              CosmicButton(
                  label: 'Try again', icon: Icons.refresh, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
