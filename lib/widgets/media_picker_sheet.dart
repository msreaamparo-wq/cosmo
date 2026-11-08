import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/cosmos_colors.dart';
import '../providers/core_providers.dart';
import '../providers/media_pager.dart';
import '../repositories/media_repository.dart';
import 'cosmic_button.dart';
import 'cosmic_loading.dart';
import 'media_tile.dart';

/// Pick memories from COSMOS' library (optionally importing new ones first).
/// Returns the chosen media ids, or null if cancelled.
Future<List<String>?> showMediaPickerSheet(
  BuildContext context, {
  String? excludeAlbumId,
  bool single = false,
  String title = 'Choose memories',
  bool photosOnly = false,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CosmosColors.midnightPurple,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _PickerBody(
          excludeAlbumId: excludeAlbumId,
          single: single,
          title: title,
          photosOnly: photosOnly),
    ),
  );
}

class _PickerBody extends ConsumerStatefulWidget {
  const _PickerBody(
      {required this.excludeAlbumId,
      required this.single,
      required this.title,
      required this.photosOnly});
  final String? excludeAlbumId;
  final bool single, photosOnly;
  final String title;

  @override
  ConsumerState<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends ConsumerState<_PickerBody> {
  late final MediaPager _pager;
  final _selected = <String>{};
  Set<String> _already = {};
  final _scroll = ScrollController();
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _pager = MediaPager(
      ref.read(mediaRepositoryProvider),
      MediaQueryOptions(
          filter: widget.photosOnly ? MediaFilter.photos : MediaFilter.all),
    )..reload();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400)
        _pager.loadMore();
    });
    if (widget.excludeAlbumId != null) {
      ref
          .read(albumRepositoryProvider)
          .mediaIds(widget.excludeAlbumId!)
          .then((ids) {
        if (mounted) setState(() => _already = ids.toSet());
      });
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final r = await ref.read(importServiceProvider).importFromPicker();
      if (!mounted) return;
      refreshUniverse(ref);
      await _pager.reload();
      setState(() => _selected.addAll(r.addedIds));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.summary())));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open your pictures. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: text.titleLarge)),
              IconButton(
                tooltip: 'Close',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CosmicButton(
              label: _importing ? 'Opening…' : 'Import new pictures',
              icon: Icons.add_photo_alternate_outlined,
              color: CosmosColors.nebulaPink,
              foreground: CosmosColors.deepSpaceNavy,
              onPressed: _importing ? null : _import,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListenableBuilder(
            listenable: _pager,
            builder: (context, _) {
              if (_pager.loading && _pager.items.isEmpty)
                return const CosmicLoading();
              final items =
                  _pager.items.where((m) => !_already.contains(m.id)).toList();
              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _pager.items.isEmpty
                          ? 'No memories yet. Import some pictures to get started!'
                          : 'All your memories are already here.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge,
                    ),
                  ),
                );
              }
              return GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final m = items[i];
                  return MediaTile(
                    media: m,
                    logicalWidth: 120,
                    selectionMode: !widget.single,
                    selected: _selected.contains(m.id),
                    onTap: () {
                      if (widget.single) {
                        Navigator.of(context).pop([m.id]);
                      } else {
                        setState(() => _selected.contains(m.id)
                            ? _selected.remove(m.id)
                            : _selected.add(m.id));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        if (!widget.single)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: CosmicButton(
              label: _selected.isEmpty
                  ? 'Pick some memories'
                  : 'Add ${_selected.length}',
              icon: Icons.check,
              expand: true,
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ),
      ],
    );
  }
}
