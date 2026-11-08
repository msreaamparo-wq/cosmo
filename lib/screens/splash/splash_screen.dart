import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/motion.dart';
import '../../providers/core_providers.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/floating_planet.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = MotionScope.of(context);
    if (motion) {
      _c.forward();
    } else {
      _c.value = 1;
    }
    unawaited(_continue(motion
        ? const Duration(milliseconds: 2300)
        : const Duration(milliseconds: 500)));
  }

  Future<void> _continue(Duration minimum) async {
    try {
      final settings = await ref.read(settingsProvider.future);
      await Future<void>.delayed(minimum);
      if (settings.cloudSyncEnabled) {
        // Only if the parent turned cloud sync on. Never otherwise.
        final ctl = ref.read(syncControllerProvider.notifier);
        await ctl.refreshStatus();
        unawaited(ctl.syncNow());
      }
      if (!mounted) return;
      context.go(settings.onboardingDone
          ? CosmosRoutes.home
          : CosmosRoutes.onboarding);
    } catch (_) {
      if (mounted)
        context.go(CosmosRoutes
            .home); // data problems are shown on the screens themselves
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Animation<double> iv(double a, double b, [Curve curve = Curves.easeOut]) =>
        CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));
    final planet = iv(0.15, 0.55);
    final astro = iv(0.4, 0.8);
    final logo = iv(0.65, 1.0, Curves.elasticOut);

    return Scaffold(
      body: CosmicBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: planet,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.6, end: 1.0).animate(planet),
                      child: const FloatingPlanet(
                          color: CosmosColors.cosmicViolet,
                          theme: 'rings',
                          size: 200,
                          semanticLabel: 'A friendly purple planet'),
                    ),
                  ),
                  FadeTransition(
                    opacity: astro,
                    child: SlideTransition(
                      position:
                          Tween(begin: const Offset(0, 0.6), end: Offset.zero)
                              .animate(astro),
                      child: const AstronautMascot(size: 96),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScaleTransition(
                    scale: Tween(begin: 0.7, end: 1.0).animate(logo),
                    child: FadeTransition(
                      opacity: iv(0.65, 0.85),
                      child: Column(
                        children: [
                          Text('COSMOS',
                              style: text.displayMedium?.copyWith(
                                  color: CosmosColors.starYellow,
                                  letterSpacing: 4)),
                          const SizedBox(height: 6),
                          Text('Your Memories, Your Little Universe.',
                              textAlign: TextAlign.center,
                              style: text.titleMedium
                                  ?.copyWith(color: CosmosColors.softLavender)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
