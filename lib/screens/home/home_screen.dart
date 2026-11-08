import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../providers/core_providers.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/error_message.dart';
import '../../widgets/media_tile.dart';
import '../../widgets/planet_card.dart';
import '../../widgets/section_header.dart';

/// "My Little Universe". Every number, photo and planet comes from the local database.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(universeStatsProvider);
    final albums = ref.watch(albumsProvider);
    final recent = ref.watch(recentMediaProvider);
    final text = Theme.of(context).textTheme;

    return CosmicScaffold(
      showBack: false,
      body: RefreshIndicator(
        onRefresh: () async => ref.read(dataVersionProvider.notifier).bump(),
        child: LayoutBuilder(builder: (context, c) {
          final pad = c.maxWidth > 900 ? (c.maxWidth - 860) / 2 : 20.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
            children: [
              Row(
                children: [
                  const AstronautMascot(size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COSMOS',
                            style: text.titleLarge?.copyWith(
                                color: CosmosColors.starYellow,
                                letterSpacing: 2)),
                        Text('Hello, Little Explorer!',
                            style: text.headlineSmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Grown-ups: settings',
                    iconSize: 28,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => context.push(CosmosRoutes.settings),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Counters (real data)
              stats.when(
                loading: () => const SizedBox(
                    height: 84,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => ErrorMessage(
                    message: 'Could not count your memories.',
                    onRetry: () => ref.invalidate(universeStatsProvider)),
                data: (s) => Row(
                  children: [
                    Expanded(
                        child: _Counter(
                            label: s.memories == 1 ? 'Memory' : 'Memories',
                            value: s.memories,
                            icon: Icons.auto_awesome,
                            color: CosmosColors.skyBlue,
                            onTap: () => context.go(CosmosRoutes.gallery))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Counter(
                            label: s.planets == 1 ? 'Planet' : 'Planets',
                            value: s.planets,
                            icon: Icons.public,
                            color: CosmosColors.nebulaPink,
                            onTap: () => context.go(CosmosRoutes.planets))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Counter(
                            label: 'Favorites',
                            value: s.favorites,
                            icon: Icons.star,
                            color: CosmosColors.starYellow,
                            onTap: () => context.go(CosmosRoutes.favorites))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recently added
              SectionHeader('Recently added',
                  actionLabel: 'Gallery',
                  onAction: () => context.go(CosmosRoutes.gallery)),
              recent.when(
                loading: () => const SizedBox(
                    height: 110,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => ErrorMessage(
                    onRetry: () => ref.invalidate(recentMediaProvider)),
                data: (items) {
                  if (items.isEmpty) {
                    return _Invite(
                      title: 'Your sky is empty',
                      message: 'Add some pictures and watch your stars appear!',
                      button: 'Add pictures',
                      icon: Icons.add_photo_alternate_outlined,
                      onTap: () => context.go(CosmosRoutes.gallery),
                    );
                  }
                  final ids = items.map((m) => m.id).toList();
                  return SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => SizedBox(
                        width: 112,
                        child: MediaTile(
                            media: items[i],
                            onTap: () => context.push(
                                CosmosRoutes.viewer(items[i].id),
                                extra: ids)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Featured planets
              SectionHeader('Featured planets',
                  actionLabel: 'See all',
                  onAction: () => context.go(CosmosRoutes.planets)),
              albums.when(
                loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) =>
                    ErrorMessage(onRetry: () => ref.invalidate(albumsProvider)),
                data: (list) {
                  if (list.isEmpty) {
                    return _Invite(
                      title: 'No planets yet',
                      message:
                          'Make a planet to keep your favorite pictures together.',
                      button: 'Create a planet',
                      icon: Icons.add,
                      onTap: () => context.push(CosmosRoutes.createPlanet),
                    );
                  }
                  final shown = list.take(8).toList();
                  return SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                          width: 160,
                          child: PlanetCard(
                              album: shown[i],
                              onTap: () => context
                                  .push(CosmosRoutes.planet(shown[i].id)))),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Explore
              const SectionHeader('Explore your universe'),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 640 ? 4 : 2;
                const gap = 12.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                final tiles = [
                  (
                    Icons.slideshow,
                    'Space Show',
                    'A slideshow journey',
                    CosmosColors.nebulaPink,
                    CosmosRoutes.slideshow
                  ),
                  (
                    Icons.rocket_launch,
                    'Discovery',
                    'Rediscover a memory',
                    CosmosColors.coral,
                    CosmosRoutes.discover
                  ),
                  (
                    Icons.timeline,
                    'Timeline',
                    'By month and year',
                    CosmosColors.mint,
                    CosmosRoutes.timeline
                  ),
                  (
                    Icons.auto_graph,
                    'Constellations',
                    'Connect your stars',
                    CosmosColors.skyBlue,
                    CosmosRoutes.constellation
                  ),
                  (
                    Icons.filter_frames,
                    'Frames',
                    'Decorate a photo',
                    CosmosColors.starYellow,
                    CosmosRoutes.frames
                  ),
                  (
                    Icons.emoji_events_outlined,
                    'Achievements',
                    'Your little wins',
                    CosmosColors.nebulaPurple,
                    CosmosRoutes.achievements
                  ),
                ];
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles)
                      SizedBox(
                          width: w,
                          child: _ExploreTile(
                              icon: t.$1,
                              title: t.$2,
                              subtitle: t.$3,
                              color: t.$4,
                              route: t.$5))
                  ],
                );
              }),
            ],
          );
        }),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${plural(value, label.replaceAll(RegExp(r's$'), ''), label)}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: CosmosColors.midnightPurple.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 4),
                Text('$value', style: text.headlineSmall),
                Text(label,
                    style: text.bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.route});
  final IconData icon;
  final String title, subtitle, route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: () => context.push(route),
      child: Material(
        color: CosmosColors.midnightPurple.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .2),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 10),
                Text(title, style: text.titleMedium),
                Text(subtitle,
                    style: text.bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Invite extends StatelessWidget {
  const _Invite(
      {required this.title,
      required this.message,
      required this.button,
      required this.icon,
      required this.onTap});
  final String title, message, button;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: CosmosColors.midnightPurple.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  text.bodyMedium?.copyWith(color: CosmosColors.softLavender)),
          const SizedBox(height: 12),
          CosmicButton(label: button, icon: icon, onPressed: onTap),
        ],
      ),
    );
  }
}
