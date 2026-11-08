import 'package:flutter/material.dart';

import 'cosmic_background.dart';

/// Every screen uses this: cosmic background + transparent Scaffold + consistent app bar.
class CosmicScaffold extends StatelessWidget {
  const CosmicScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showBack = true,
    this.bottom,
    this.extendBody = false,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return CosmicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: extendBody,
        appBar: title == null && actions == null
            ? null
            : AppBar(
                title: title == null ? null : Text(title!),
                automaticallyImplyLeading: false,
                leading: showBack && canPop ? const BackButton() : null,
                actions: actions,
                bottom: bottom,
              ),
        floatingActionButton: floatingActionButton,
        body: SafeArea(top: title == null && actions == null, child: body),
      ),
    );
  }
}
