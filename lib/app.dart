import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/cosmos_colors.dart';
import 'core/routing/router.dart';
import 'core/theme/cosmos_theme.dart';
import 'core/utilities/motion.dart';
import 'providers/core_providers.dart';
import 'services/achievement_service.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

class CosmosApp extends ConsumerWidget {
  const CosmosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final animations = ref.watch(
        settingsProvider.select((s) => s.value?.animationsEnabled ?? true));

    ref.listen(achievementUnlockProvider, (_, next) {
      next.whenData(_showAchievement);
    });

    return MaterialApp.router(
      title: 'COSMOS',
      debugShowCheckedModeBanner: false,
      theme: CosmosTheme.dark(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: router,
      builder: (context, child) => MotionScope(
          enabled: animations, child: child ?? const SizedBox.shrink()),
    );
  }

  void _showAchievement(AchievementDef def) {
    rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: CosmosColors.cosmicViolet,
          content: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Text(def.emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New achievement!',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(def.title),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
