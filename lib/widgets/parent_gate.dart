import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';

/// A simple grown-up check (addition question) shown before sensitive actions.
///
/// IMPORTANT: this is a child barrier ONLY. It is NOT authentication and must
/// never be described as secure. Real protection of cloud data comes from the
/// parent's Supabase login + RLS.
abstract final class ParentGate {
  /// Resolves true only if the correct answer was entered.
  static Future<bool> verify(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ParentGateDialog(),
    );
    return ok ?? false;
  }
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog();

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  final _rnd = Random();
  late int _a = 11 + _rnd.nextInt(8); // 11..18
  late int _b = 12 + _rnd.nextInt(8); // 12..19
  final _controller = TextEditingController();
  bool _wrong = false;

  void _submit() {
    if (int.tryParse(_controller.text.trim()) == _a + _b) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _wrong = true;
        _a = 11 + _rnd.nextInt(8);
        _b = 12 + _rnd.nextInt(8);
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: CosmosColors.midnightPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Grown-ups only', style: text.titleLarge),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please solve this to continue:', style: text.bodyLarge),
            const SizedBox(height: 12),
            Text('$_a + $_b = ?', style: text.headlineMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: text.titleLarge,
              decoration: InputDecoration(
                hintText: 'Your answer',
                errorText: _wrong ? 'Not quite. Try this new one!' : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}
