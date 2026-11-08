import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/achievements/achievements_screen.dart';
import '../../screens/auth/parent_auth_screen.dart';
import '../../screens/constellation/constellation_screen.dart';
import '../../screens/discovery/discovery_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/frames/frames_screen.dart';
import '../../screens/gallery/gallery_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/planets/create_planet_screen.dart';
import '../../screens/planets/planet_detail_screen.dart';
import '../../screens/planets/planets_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/slideshow/slideshow_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/timeline/timeline_screen.dart';
import '../../screens/viewer/photo_viewer_screen.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/astronaut_mascot.dart';
import 'app_shell.dart';
import 'routes.dart';

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child),
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: CosmosRoutes.splash,
    errorBuilder: (context, state) => const _NotFound(),
    routes: [
      GoRoute(path: '/', redirect: (_, __) => CosmosRoutes.splash),
      GoRoute(
          path: CosmosRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: CosmosRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: CosmosRoutes.home, builder: (_, __) => const HomeScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: CosmosRoutes.gallery,
                builder: (_, __) => const GalleryScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: CosmosRoutes.planets,
                builder: (_, __) => const PlanetsScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: CosmosRoutes.favorites,
                builder: (_, __) => const FavoritesScreen())
          ]),
        ],
      ),
      // 'new' must come before ':id'
      GoRoute(
          path: CosmosRoutes.createPlanet,
          builder: (_, __) => const CreatePlanetScreen()),
      GoRoute(
          path: '/planets/:id',
          builder: (_, s) =>
              PlanetDetailScreen(albumId: s.pathParameters['id']!)),
      GoRoute(
          path: '/planets/:id/edit',
          builder: (_, s) =>
              CreatePlanetScreen(editAlbumId: s.pathParameters['id'])),
      GoRoute(
        path: '/viewer/:id',
        pageBuilder: (_, s) => _fade(
            s,
            PhotoViewerScreen(
                initialId: s.pathParameters['id']!,
                ids:
                    s.extra is List<String> ? s.extra! as List<String> : null)),
      ),
      GoRoute(
          path: CosmosRoutes.timeline,
          builder: (_, __) => const TimelineScreen()),
      GoRoute(
        path: CosmosRoutes.slideshow,
        builder: (_, s) => SlideshowScreen(
            planetId: s.uri.queryParameters['planet'],
            favoritesOnly: s.uri.queryParameters['favorites'] == '1'),
      ),
      GoRoute(
          path: CosmosRoutes.discover,
          builder: (_, __) => const DiscoveryScreen()),
      GoRoute(
          path: CosmosRoutes.frames,
          builder: (_, s) =>
              FramesScreen(initialMediaId: s.uri.queryParameters['media'])),
      GoRoute(
          path: CosmosRoutes.constellation,
          builder: (_, __) => const ConstellationScreen()),
      GoRoute(
          path: CosmosRoutes.achievements,
          builder: (_, __) => const AchievementsScreen()),
      GoRoute(
          path: CosmosRoutes.settings,
          builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: CosmosRoutes.parentAuth,
          builder: (_, __) => const ParentAuthScreen()),
    ],
  );
});

class _NotFound extends StatelessWidget {
  const _NotFound();
  @override
  Widget build(BuildContext context) {
    return CosmicScaffold(
      showBack: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AstronautMascot(size: 120),
              const SizedBox(height: 16),
              Text('Lost in space!',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('We could not find that page.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              CosmicButton(
                  label: 'Back to my universe',
                  icon: Icons.home,
                  onPressed: () => context.go(CosmosRoutes.home)),
            ],
          ),
        ),
      ),
    );
  }
}
