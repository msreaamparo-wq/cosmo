import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/utilities/formatters.dart';
import '../models/media_model.dart';
import '../providers/media_pager.dart';
import 'cosmic_loading.dart';
import 'error_message.dart';
import 'media_image.dart';
import 'media_tile.dart';

/// Scrollable, lazily-paged grid (or list) of media. Shared by Gallery, Favorites and Planet detail.
class MediaGridView extends StatefulWidget {
  const MediaGridView({
    super.key,
    required this.pager,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
    this.listMode = false,
    this.header,
    this.empty,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 96),
  });

  final MediaPager pager;
  final Set<String> selected;
  final void Function(MediaModel item, List<String> allIds) onOpen;
  final void Function(MediaModel item) onToggle;
  final bool listMode;
  final Widget? header;
  final Widget? empty;
  final EdgeInsets padding;

  @override
  State<MediaGridView> createState() => _MediaGridViewState();
}

class _MediaGridViewState extends State<MediaGridView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        widget.pager.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pager,
      builder: (context, _) {
        final p = widget.pager;
        if (p.loading && p.items.isEmpty)
          return const CosmicLoading(label: 'Gathering your stars…');
        if (p.error != null && p.items.isEmpty)
          return ErrorMessage(onRetry: p.reload);
        final items = p.items;
        final ids = items.map((m) => m.id).toList();
        final selecting = widget.selected.isNotEmpty;

        return CustomScrollView(
          controller: _scroll,
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            if (items.isEmpty)
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: widget.empty ?? const SizedBox.shrink())
            else if (widget.listMode)
              SliverPadding(
                padding: widget.padding,
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ListRow(
                    media: items[i],
                    selected: widget.selected.contains(items[i].id),
                    selecting: selecting,
                    onTap: () => selecting
                        ? widget.onToggle(items[i])
                        : widget.onOpen(items[i], ids),
                    onLongPress: () => widget.onToggle(items[i]),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: widget.padding,
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8),
                  itemCount: items.length,
                  itemBuilder: (_, i) => MediaTile(
                    media: items[i],
                    selectionMode: selecting,
                    selected: widget.selected.contains(items[i].id),
                    onTap: () => selecting
                        ? widget.onToggle(items[i])
                        : widget.onOpen(items[i], ids),
                    onLongPress: () => widget.onToggle(items[i]),
                  ),
                ),
              ),
            if (p.loading && items.isNotEmpty)
              const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()))),
          ],
        );
      },
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow(
      {required this.media,
      required this.selected,
      required this.selecting,
      required this.onTap,
      required this.onLongPress});
  final MediaModel media;
  final bool selected, selecting;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = media.capturedAt == null
        ? 'Date unknown'
        : formatDate(media.capturedAt!);
    return Card(
      color: selected
          ? CosmosColors.cosmicViolet.withValues(alpha: .4)
          : CosmosColors.midnightPurple.withValues(alpha: .8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minVerticalPadding: 8,
        onTap: onTap,
        onLongPress: onLongPress,
        leading: SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MediaImage(media, logicalWidth: 56))),
        title: Text(media.fileName ?? (media.isVideo ? 'Video' : 'Photo'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium),
        subtitle: Text('$date · ${formatBytes(media.fileSize)}',
            style: text.bodyMedium?.copyWith(color: CosmosColors.softLavender)),
        trailing: selecting
            ? Icon(selected ? Icons.check_circle : Icons.circle_outlined)
            : (media.isFavorite
                ? const Icon(Icons.star, color: CosmosColors.starYellow)
                : null),
      ),
    );
  }
}
