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
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_grid.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});
  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late final MediaPager _pager;
  final _search = TextEditingController();
  Timer? _debounce;
  final _selected = <String>{};
  bool _listMode = false;
  bool _importing = false;
  var _opts = const MediaQueryOptions();

  @override
  void initState() {
    super.initState();
    _pager = MediaPager(ref.read(mediaRepositoryProvider), _opts)..reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _apply(MediaQueryOptions o) {
    _opts = o;
    _selected.clear();
    _pager.setOptions(o);
    setState(() {});
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final r = await ref.read(importServiceProvider).importFromPicker();
      refreshUniverse(ref);
      if (mounted) toast(context, r.summary());
    } catch (_) {
      if (mounted)
        toast(context,
            'We could not open your pictures. Please check permissions and try again.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<MediaModel> get _selectedItems =>
      _pager.items.where((m) => _selected.contains(m.id)).toList();

  @override
  Widget build(BuildContext context) {
    ref.listen(dataVersionProvider, (_, __) => _pager.reload());
    final text = Theme.of(context).textTheme;
    final selecting = _selected.isNotEmpty;

    return CosmicScaffold(
      title: selecting
          ? '${_selected.length} selected'
          : 'Your Galaxy of Memories',
      showBack: false,
      actions: [
        if (selecting) ...[
          IconButton(
              tooltip: 'Favorite',
              onPressed: () async {
                await toggleFavorites(context, ref, _selectedItems);
                setState(_selected.clear);
              },
              icon: const Icon(Icons.star_outline)),
          IconButton(
              tooltip: 'Add to planet',
              onPressed: () async {
                await addToPlanet(context, ref, _selected.toList());
                setState(_selected.clear);
              },
              icon: const Icon(Icons.public)),
          IconButton(
              tooltip: 'Remove from COSMOS',
              onPressed: () async {
                if (await deleteFromCosmos(context, ref, _selectedItems))
                  setState(_selected.clear);
              },
              icon: const Icon(Icons.delete_outline)),
          IconButton(
              tooltip: 'Cancel selection',
              onPressed: () => setState(_selected.clear),
              icon: const Icon(Icons.close)),
        ] else ...[
          PopupMenuButton<bool>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: (newest) => _apply(_opts.copyWith(newestFirst: newest)),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: true,
                  checked: _opts.newestFirst,
                  child: const Text('Newest first')),
              CheckedPopupMenuItem(
                  value: false,
                  checked: !_opts.newestFirst,
                  child: const Text('Oldest first')),
            ],
          ),
          IconButton(
            tooltip: _listMode ? 'Show grid' : 'Show list',
            onPressed: () => setState(() => _listMode = !_listMode),
            icon: Icon(_listMode ? Icons.grid_view : Icons.view_list),
          ),
        ],
      ],
      floatingActionButton: selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _importing ? null : _import,
              backgroundColor: CosmosColors.cosmicViolet,
              foregroundColor: CosmosColors.cloudWhite,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_importing ? 'Opening…' : 'Add pictures'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or date (like 2025-06)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          _apply(_opts.copyWith(search: ''));
                        },
                        icon: const Icon(Icons.close)),
                filled: true,
                fillColor: CosmosColors.midnightPurple.withValues(alpha: .8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300),
                    () => _apply(_opts.copyWith(search: v)));
              },
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in const [
                  (MediaFilter.all, 'All'),
                  (MediaFilter.photos, 'Photos'),
                  (MediaFilter.videos, 'Videos'),
                  (MediaFilter.favorites, 'Favorites')
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _opts.filter == f.$1,
                      onSelected: (_) => _apply(_opts.copyWith(filter: f.$1)),
                    ),
                  ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _pager,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(plural(_pager.total, 'memory', 'memories'),
                    style: text.bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender)),
              ),
            ),
          ),
          Expanded(
            child: MediaGridView(
              pager: _pager,
              selected: _selected,
              listMode: _listMode,
              onOpen: (m, ids) =>
                  context.push(CosmosRoutes.viewer(m.id), extra: ids),
              onToggle: (m) => setState(() => _selected.contains(m.id)
                  ? _selected.remove(m.id)
                  : _selected.add(m.id)),
              empty: _opts.search.isNotEmpty || _opts.filter != MediaFilter.all
                  ? const EmptyState(
                      title: 'Nothing found',
                      message: 'Try a different search or filter.',
                      leading: AstronautMascot(size: 90))
                  : EmptyState(
                      title: 'Your galaxy is waiting',
                      message:
                          'Add pictures from your device to turn them into stars.',
                      leading: const AstronautMascot(size: 110),
                      actionLabel: 'Add pictures',
                      onAction: _importing ? null : _import,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
