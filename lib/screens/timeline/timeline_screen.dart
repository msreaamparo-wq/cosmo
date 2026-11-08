import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/astronaut_mascot.dart';
import '../../widgets/media_tile.dart';

class _TimelineData {
  const _TimelineData(this.groups, this.undated);
  final List<TimelineGroup> groups;
  final int undated;
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});
  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  String _search = '';
  int? _year; // null = all years
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<_TimelineData> _load() async {
    final repo = ref.read(mediaRepositoryProvider);
    final results = await Future.wait([
      repo.timelineGroups(search: _search),
      repo.undatedCount(search: _search)
    ]);
    return _TimelineData(results[0] as List<TimelineGroup>, results[1] as int);
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(dataVersionProvider);
    final text = Theme.of(context).textTheme;

    return CosmicScaffold(
      title: 'Memory Timeline',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search memories (name or date)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: CosmosColors.midnightPurple.withValues(alpha: .8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300),
                    () => setState(() => _search = v));
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<_TimelineData>(
              key: ValueKey('$version|$_search'),
              future: _load(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done)
                  return const CosmicLoading();
                if (snap.hasError)
                  return ErrorMessage(onRetry: () => setState(() {}));
                final data = snap.data!;
                if (data.groups.isEmpty && data.undated == 0) {
                  return EmptyState(
                    title:
                        _search.isEmpty ? 'No memories yet' : 'Nothing found',
                    message: _search.isEmpty
                        ? 'Add pictures and they will line up here by date.'
                        : 'Try a different search.',
                    leading: const AstronautMascot(size: 100),
                    actionLabel: _search.isEmpty ? 'Add pictures' : null,
                    onAction: _search.isEmpty
                        ? () => context.go(CosmosRoutes.gallery)
                        : null,
                  );
                }
                final years = {for (final g in data.groups) g.year}.toList();
                final shown = data.groups
                    .where((g) => _year == null || g.year == _year)
                    .toList();
                final children = <Widget>[];
                int? lastYear;
                var first = true;
                for (final g in shown) {
                  if (g.year != lastYear) {
                    lastYear = g.year;
                    children.add(Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(children: [
                        const Icon(Icons.star,
                            color: CosmosColors.starYellow, size: 20),
                        const SizedBox(width: 8),
                        Text('${g.year}', style: text.headlineSmall),
                      ]),
                    ));
                  }
                  children.add(_MonthSection(
                    key: ValueKey('$version|$_search|${g.year}-${g.month}'),
                    group: g,
                    search: _search,
                    initiallyExpanded:
                        first && _year != null || first && shown.length <= 3,
                  ));
                  first = false;
                }
                if (data.undated > 0 && _year == null) {
                  children.add(const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Text('Date unknown',
                          style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 22,
                              fontWeight: FontWeight.w600))));
                  children.add(Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                        'These pictures have no date saved in them, so COSMOS does not guess one.',
                        style: text.bodyMedium
                            ?.copyWith(color: CosmosColors.softLavender)),
                  ));
                  children.add(_MonthSection(
                      key: ValueKey('$version|$_search|undated'),
                      group: null,
                      undatedCount: data.undated,
                      search: _search,
                      initiallyExpanded: false));
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    if (years.length > 1)
                      SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(
                                    right: 8, top: 6, bottom: 6),
                                child: ChoiceChip(
                                    label: const Text('All years'),
                                    selected: _year == null,
                                    onSelected: (_) =>
                                        setState(() => _year = null))),
                            for (final y in years)
                              Padding(
                                  padding: const EdgeInsets.only(
                                      right: 8, top: 6, bottom: 6),
                                  child: ChoiceChip(
                                      label: Text('$y'),
                                      selected: _year == y,
                                      onSelected: (_) =>
                                          setState(() => _year = y))),
                          ],
                        ),
                      ),
                    ...children,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSection extends ConsumerStatefulWidget {
  const _MonthSection(
      {super.key,
      required this.group,
      required this.search,
      required this.initiallyExpanded,
      this.undatedCount});
  final TimelineGroup? group; // null = undated
  final int? undatedCount;
  final String search;
  final bool initiallyExpanded;

  @override
  ConsumerState<_MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends ConsumerState<_MonthSection> {
  Future<List<MediaModel>>? _future;

  Future<List<MediaModel>> _fetch() {
    final repo = ref.read(mediaRepositoryProvider);
    final g = widget.group;
    return g == null
        ? repo.undated(search: widget.search)
        : repo.inMonth(g.year, g.month, search: widget.search);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) _future = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final title = g == null ? 'Memories without a date' : monthName(g.month);
    final count = g?.count ?? widget.undatedCount ?? 0;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (open) {
          if (open && _future == null) setState(() => _future = _fetch());
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(plural(count, 'memory', 'memories')),
        children: [
          if (_future != null)
            FutureBuilder<List<MediaModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done)
                  return const Padding(
                      padding: EdgeInsets.all(16), child: CosmicLoading());
                if (snap.hasError)
                  return ErrorMessage(
                      onRetry: () => setState(() => _future = _fetch()));
                final items = snap.data!;
                final ids = items.map((m) => m.id).toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => MediaTile(
                    media: items[i],
                    logicalWidth: 120,
                    onTap: () => context.push(CosmosRoutes.viewer(items[i].id),
                        extra: ids),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
