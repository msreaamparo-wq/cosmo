import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/media_pager.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/animated_star.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_grid.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});
  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late final MediaPager _pager;
  final _search = TextEditingController();
  Timer? _debounce;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _pager = MediaPager(ref.read(mediaRepositoryProvider),
        const MediaQueryOptions(filter: MediaFilter.favorites))
      ..reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _pager.dispose();
    super.dispose();
  }

  List<MediaModel> get _selectedItems =>
      _pager.items.where((m) => _selected.contains(m.id)).toList();

  @override
  Widget build(BuildContext context) {
    ref.listen(dataVersionProvider, (_, __) => _pager.reload());
    final selecting = _selected.isNotEmpty;
    return CosmicScaffold(
      title: selecting ? '${_selected.length} selected' : 'Your Favorite Stars',
      showBack: false,
      actions: [
        if (selecting) ...[
          IconButton(
              tooltip: 'Remove from favorites',
              onPressed: () async {
                await toggleFavorites(context, ref, _selectedItems);
                setState(_selected.clear);
              },
              icon: const Icon(Icons.star_border)),
          IconButton(
              tooltip: 'Cancel selection',
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.close)),
        ] else
          IconButton(
              tooltip: 'Space Show of favorites',
              onPressed: () =>
                  context.push('${CosmosRoutes.slideshow}?favorites=1'),
              icon: const Icon(Icons.slideshow)),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search your favorite stars',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: CosmosColors.midnightPurple.withValues(alpha: .8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () =>
                        _pager.setOptions(_pager.options.copyWith(search: v)));
              },
            ),
          ),
          ListenableBuilder(
            listenable: _pager,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(plural(_pager.total, 'favorite star'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender)),
              ),
            ),
          ),
          Expanded(
            child: MediaGridView(
              pager: _pager,
              selected: _selected,
              onOpen: (m, ids) =>
                  context.push(CosmosRoutes.viewer(m.id), extra: ids),
              onToggle: (m) => setState(() => _selected.contains(m.id)
                  ? _selected.remove(m.id)
                  : _selected.add(m.id)),
              empty: EmptyState(
                title: _search.text.isEmpty
                    ? 'No favorite stars yet'
                    : 'Nothing found',
                message: _search.text.isEmpty
                    ? 'Tap the star on any picture to make it glow here.'
                    : 'Try a different search.',
                leading: const AnimatedStar(size: 72),
                actionLabel: _search.text.isEmpty ? 'Browse my memories' : null,
                onAction: _search.text.isEmpty
                    ? () => context.go(CosmosRoutes.gallery)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
