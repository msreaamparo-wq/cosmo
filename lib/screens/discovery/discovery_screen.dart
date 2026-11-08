import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_image.dart';
import '../../widgets/media_tile.dart';
import '../../widgets/section_header.dart';

class _Discovery {
  const _Discovery(
      this.first, this.recent, this.onThisDay, this.albums, this.total);
  final MediaModel? first;
  final List<MediaModel> recent, onThisDay;
  final List<AlbumModel> albums;
  final int total;
}

/// Everything here comes from real stored media. Nothing is invented.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  _Discovery? _data;
  bool _error = false;
  MediaModel? _current;
  String? _albumFilter;
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    ref.read(achievementServiceProvider).visit('discovery');
  }

  Future<void> _load() async {
    setState(() {
      _error = false;
      _data = null;
    });
    try {
      final media = ref.read(mediaRepositoryProvider);
      final results = await Future.wait([
        media.random(),
        media.recent(limit: 12),
        media.onThisDay(DateTime.now()),
        ref.read(albumRepositoryProvider).all(),
        media.stats(),
      ]);
      if (!mounted) return;
      final first = results[0] as MediaModel?;
      if (first != null) _seen.add(first.id);
      setState(() {
        _data = _Discovery(
            first,
            results[1] as List<MediaModel>,
            results[2] as List<MediaModel>,
            (results[3] as List).cast<AlbumModel>(),
            (results[4] as UniverseStats).memories);
        _current = first;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _another() async {
    final media = ref.read(mediaRepositoryProvider);
    var next = await media.random(excludeIds: _seen, albumId: _albumFilter);
    if (next == null) {
      _seen.clear(); // seen them all: start over
      next = await media.random(albumId: _albumFilter);
    }
    if (next != null && mounted) {
      _seen.add(next.id);
      setState(() => _current = next);
    } else if (mounted) {
      toast(context, 'No pictures here yet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_error)
      return CosmicScaffold(
          title: 'Memory Discovery', body: ErrorMessage(onRetry: _load));
    final d = _data;
    if (d == null)
      return const CosmicScaffold(
          title: 'Memory Discovery', body: CosmicLoading());
    if (d.total == 0 || _current == null) {
      return CosmicScaffold(
        title: 'Memory Discovery',
        body: EmptyState(
          title: 'Nothing to discover yet',
          message: 'Add some pictures, then blast off to rediscover them!',
          leading: const AstronautMascot(size: 110),
          actionLabel: 'Add pictures',
          onAction: () => context.go(CosmosRoutes.gallery),
        ),
      );
    }
    final m = _current!;
    return CosmicScaffold(
      title: 'Memory Discovery',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Blast Off! Here's a memory to explore!",
              textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
              child: AspectRatio(
                aspectRatio: 1,
                child: GestureDetector(
                  onTap: () =>
                      context.push(CosmosRoutes.viewer(m.id), extra: [m.id]),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: MediaImage(m, logicalWidth: 520)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              m.capturedAt == null ? 'Date unknown' : formatDate(m.capturedAt!),
              textAlign: TextAlign.center,
              style:
                  text.bodyMedium?.copyWith(color: CosmosColors.softLavender)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              CosmicButton(
                  label: 'View memory',
                  icon: Icons.open_in_full,
                  onPressed: () =>
                      context.push(CosmosRoutes.viewer(m.id), extra: [m.id])),
              CosmicButton(
                  label: 'Discover another',
                  icon: Icons.casino_outlined,
                  color: CosmosColors.nebulaPink,
                  foreground: CosmosColors.deepSpaceNavy,
                  onPressed: _another),
              CosmicButton(
                label: m.isFavorite ? 'Favorite ⭐' : 'Add to favorites',
                icon: m.isFavorite ? Icons.star : Icons.star_border,
                color: CosmosColors.midnightPurple,
                onPressed: () async {
                  await toggleFavorites(context, ref, [m]);
                  final fresh =
                      await ref.read(mediaRepositoryProvider).byId(m.id);
                  if (mounted && fresh != null)
                    setState(() => _current = fresh);
                },
              ),
            ],
          ),
          if (d.albums.isNotEmpty) ...[
            const SectionHeader('Discover from a planet'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('Everywhere'),
                    selected: _albumFilter == null,
                    onSelected: (_) {
                      setState(() => _albumFilter = null);
                      _another();
                    }),
                for (final a in d.albums)
                  ChoiceChip(
                    label: Text('${a.sticker ?? ''} ${a.name}'.trim()),
                    selected: _albumFilter == a.id,
                    onSelected: (_) {
                      setState(() => _albumFilter = a.id);
                      _another();
                    },
                  ),
              ],
            ),
          ],
          if (d.onThisDay.isNotEmpty) ...[
            const SectionHeader('On this day, in past years'),
            _Row(items: d.onThisDay),
          ],
          const SectionHeader('Recently added'),
          _Row(items: d.recent),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.items});
  final List<MediaModel> items;

  @override
  Widget build(BuildContext context) {
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
                onTap: () => context.push(CosmosRoutes.viewer(items[i].id),
                    extra: ids))),
      ),
    );
  }
}
