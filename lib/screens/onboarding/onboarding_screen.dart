import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../providers/core_providers.dart';
import '../../widgets/animated_star.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/floating_planet.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _titles = [
    'Your Little Universe',
    'Every Memory Has a Planet',
    'Keep Memories Safe'
  ];
  static const _texts = [
    'COSMOS is your own space for keeping precious memories. Every picture becomes a star in your sky.',
    'Group your pictures onto planets: Family, Friends, Adventures. Make each planet look the way you like!',
    'Your pictures stay on this device. A grown-up can choose to turn on a private cloud backup, but nothing is ever uploaded without their say-so.',
  ];

  Future<void> _finish() async {
    await ref.read(settingsProvider.notifier).setOnboardingDone(true);
    if (mounted) context.go(CosmosRoutes.home);
  }

  void _go(int delta) {
    final next = (_page + delta).clamp(0, 2);
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _art(int i) => switch (i) {
        0 => const Stack(
            alignment: Alignment.center,
            children: [
              FloatingPlanet(
                  color: CosmosColors.cosmicViolet,
                  size: 200,
                  semanticLabel: 'A purple planet'),
              Positioned(
                  right: 10, bottom: 0, child: AstronautMascot(size: 90)),
              Positioned(left: 20, top: 10, child: AnimatedStar(size: 30)),
            ],
          ),
        1 => const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                  child: FloatingPlanet(
                      color: CosmosColors.nebulaPink,
                      theme: 'craters',
                      size: 110)),
              Flexible(
                  child: FloatingPlanet(
                      color: CosmosColors.skyBlue,
                      theme: 'stripes',
                      size: 130)),
              Flexible(
                  child: FloatingPlanet(
                      color: CosmosColors.mint, theme: 'rings', size: 110)),
            ],
          ),
        _ => const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.shield_moon_outlined,
                  size: 140, color: CosmosColors.nebulaPurple),
              Positioned(right: 30, top: 10, child: AnimatedStar(size: 34)),
              Positioned(
                  left: 30,
                  bottom: 10,
                  child:
                      AnimatedStar(size: 22, color: CosmosColors.nebulaPink)),
            ],
          ),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _page == 2;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: CosmicBackground(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: last
                              ? const SizedBox(height: 48)
                              : TextButton(
                                  style: TextButton.styleFrom(
                                      minimumSize: const Size(64, 48)),
                                  onPressed: _finish,
                                  child: const Text('Skip')),
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: 3,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 16),
                                SizedBox(height: 230, child: _art(i)),
                                const SizedBox(height: 24),
                                Text(_titles[i],
                                    textAlign: TextAlign.center,
                                    style: text.headlineMedium),
                                const SizedBox(height: 12),
                                Text(_texts[i],
                                    textAlign: TextAlign.center,
                                    style: text.bodyLarge?.copyWith(
                                        color: CosmosColors.softLavender)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.all(4),
                              width: i == _page ? 24 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? CosmosColors.starYellow
                                    : CosmosColors.mutedGray,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            if (_page > 0)
                              Expanded(
                                child: CosmicButton(
                                    label: 'Previous',
                                    icon: Icons.arrow_back,
                                    color: CosmosColors.midnightPurple,
                                    expand: true,
                                    onPressed: () => _go(-1)),
                              ),
                            if (_page > 0) const SizedBox(width: 12),
                            Expanded(
                              child: CosmicButton(
                                label: last ? 'Get Started' : 'Next',
                                icon: last
                                    ? Icons.rocket_launch
                                    : Icons.arrow_forward,
                                expand: true,
                                onPressed: last ? _finish : () => _go(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
