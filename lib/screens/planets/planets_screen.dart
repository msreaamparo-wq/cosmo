import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../models/album_model.dart';
import '../../providers/core_providers.dart';
import '../../repositories/album_repository.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/planet_card.dart';

class PlanetsScreen extends ConsumerStatefulWidget {
  const PlanetsScreen({super.key});
  @override
  ConsumerState<PlanetsScreen> createState() => _PlanetsScreenState();
}

class _PlanetsScreenState extends ConsumerState<PlanetsScreen> {
  String _search = '';
  AlbumSort _sort = AlbumSort.newest;

  @override
  Widget build(BuildContext context) {
    ref.watch(dataVersionProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

    return CosmicScaffold(
      title: 'Your Planets',
      showBack: false,
      actions: [
        PopupMenuButton<AlbumSort>(
          tooltip: 'Sort planets',
          icon: const Icon(Icons.sort),
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
                value: AlbumSort.newest,
                checked: _sort == AlbumSort.newest,
                child: const Text('Newest first')),
            CheckedPopupMenuItem(
                value: AlbumSort.name,
                checked: _sort == AlbumSort.name,
                child: const Text('Name (A to Z)')),
            CheckedPopupMenuItem(
                value: AlbumSort.mostMemories,
                checked: _sort == AlbumSort.mostMemories,
                child: const Text('Most memories')),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(CosmosRoutes.createPlanet),
        backgroundColor: CosmosColors.nebulaPink,
        foregroundColor: CosmosColors.deepSpaceNavy,
        icon: const Icon(Icons.add),
        label: const Text('New planet'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search planets',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: CosmosColors.midnightPurple.withValues(alpha: .8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AlbumModel>>(
              key: ValueKey(
                  '$_search|${_sort.name}|${ref.read(dataVersionProvider)}'),
              future: ref
                  .read(albumRepositoryProvider)
                  .all(search: _search, sort: _sort),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done)
                  return const CosmicLoading();
                if (snap.hasError)
                  return ErrorMessage(onRetry: () => setState(() {}));
                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyState(
                    title:
                        _search.isEmpty ? 'No planets yet' : 'No planets found',
                    message: _search.isEmpty
                        ? 'Create a planet and fill it with your favorite memories.'
                        : 'Try a different name.',
                    leading: const AstronautMascot(size: 100),
                    actionLabel: _search.isEmpty ? 'Create a planet' : null,
                    onAction: _search.isEmpty
                        ? () => context.push(CosmosRoutes.createPlanet)
                        : null,
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      mainAxisExtent: 220 + 36 * (scale - 1),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => PlanetCard(
                      album: list[i],
                      onTap: () =>
                          context.push(CosmosRoutes.planet(list[i].id))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
