import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/media_pager.dart';
import '../../repositories/media_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_message.dart';
import '../../widgets/floating_planet.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/media_grid.dart';
import '../../widgets/media_image.dart';
import '../../widgets/media_picker_sheet.dart';

class _PlanetInfo {
  const _PlanetInfo(this.album, this.photos, this.videos, this.cover);
  final AlbumModel album;
  final int photos, videos;
  final MediaModel? cover;
}

final _planetInfoProvider =
    FutureProvider.family<_PlanetInfo?, String>((ref, id) async {
  ref.watch(dataVersionProvider);
  final repo = ref.watch(albumRepositoryProvider);
  final album = await repo.byId(id);
  if (album == null) return null;
  final counts = await repo.typeCounts(id);
  final cover = album.coverMediaId == null
      ? null
      : await ref.watch(mediaRepositoryProvider).byId(album.coverMediaId!);
  return _PlanetInfo(album, counts.photos, counts.videos, cover);
});

class PlanetDetailScreen extends ConsumerStatefulWidget {
  const PlanetDetailScreen({super.key, required this.albumId});
  final String albumId;
  @override
  ConsumerState<PlanetDetailScreen> createState() => _PlanetDetailScreenState();
}

class _PlanetDetailScreenState extends ConsumerState<PlanetDetailScreen> {
  late final MediaPager _pager;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _pager = MediaPager(ref.read(mediaRepositoryProvider),
        MediaQueryOptions(albumId: widget.albumId))
      ..reload();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final ids = await showMediaPickerSheet(context,
        excludeAlbumId: widget.albumId, title: 'Add memories to this planet');
    if (ids == null || ids.isEmpty) return;
    await ref.read(albumRepositoryProvider).addMedia(widget.albumId, ids);
    refreshUniverse(ref);
    if (mounted)
      toast(context, 'Added ${plural(ids.length, 'memory', 'memories')} 🪐');
  }

  Future<void> _deletePlanet(AlbumModel a) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${a.name}"?',
      message:
          'The planet will be removed. Your pictures are NOT deleted. They stay in your gallery and on your device.',
      confirmLabel: 'Delete planet',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(albumRepositoryProvider).softDelete(a.id);
    refreshUniverse(ref);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataVersionProvider, (_, __) => _pager.reload());
    final info = ref.watch(_planetInfoProvider(widget.albumId));
    final text = Theme.of(context).textTheme;

    return info.when(
      loading: () =>
          const CosmicScaffold(title: 'Planet', body: CosmicLoading()),
      error: (_, __) => CosmicScaffold(
          title: 'Planet',
          body: ErrorMessage(
              onRetry: () =>
                  ref.invalidate(_planetInfoProvider(widget.albumId)))),
      data: (data) {
        if (data == null) {
          return CosmicScaffold(
            title: 'Planet',
            body: EmptyState(
                title: 'This planet is gone',
                message: 'It may have been deleted.',
                actionLabel: 'Back to planets',
                onAction: () => context.go(CosmosRoutes.planets)),
          );
        }
        final a = data.album;
        final selecting = _selected.isNotEmpty;
        return CosmicScaffold(
          title: selecting ? '${_selected.length} selected' : a.name,
          actions: [
            if (selecting) ...[
              IconButton(
                tooltip: 'Remove from this planet',
                onPressed: () async {
                  await ref
                      .read(albumRepositoryProvider)
                      .removeMedia(a.id, _selected);
                  setState(_selected.clear);
                  refreshUniverse(ref);
                  if (context.mounted)
                    toast(context,
                        'Removed from the planet. The pictures are still in your gallery.');
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                  tooltip: 'Cancel selection',
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close)),
            ] else
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (v) {
                  if (v == 'edit') context.push(CosmosRoutes.editPlanet(a.id));
                  if (v == 'delete') _deletePlanet(a);
                  if (v == 'show')
                    context.push('${CosmosRoutes.slideshow}?planet=${a.id}');
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'show', child: Text('Space Show')),
                  PopupMenuItem(value: 'edit', child: Text('Edit planet')),
                  PopupMenuItem(value: 'delete', child: Text('Delete planet')),
                ],
              ),
          ],
          floatingActionButton: selecting
              ? null
              : FloatingActionButton.extended(
                  onPressed: _addPhotos,
                  backgroundColor: CosmosColors.cosmicViolet,
                  foregroundColor: CosmosColors.cloudWhite,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add photos'),
                ),
          body: MediaGridView(
            pager: _pager,
            selected: _selected,
            onOpen: (m, ids) =>
                context.push(CosmosRoutes.viewer(m.id), extra: ids),
            onToggle: (m) => setState(() => _selected.contains(m.id)
                ? _selected.remove(m.id)
                : _selected.add(m.id)),
            header: _Header(
                data: data,
                text: text,
                onEdit: () => context.push(CosmosRoutes.editPlanet(a.id))),
            empty: EmptyState(
              title: 'This planet is empty',
              message: 'Add some memories to bring it to life!',
              leading: FloatingPlanet(
                  color: ColorOpacityX.fromHex(a.planetColor),
                  theme: a.planetTheme,
                  size: 100),
              actionLabel: 'Add photos',
              onAction: _addPhotos,
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.text, required this.onEdit});
  final _PlanetInfo data;
  final TextTheme text;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final a = data.album;
    final color = ColorOpacityX.fromHex(a.planetColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          if (data.cover != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: MediaImage(data.cover!, logicalWidth: 600)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                FloatingPlanet(
                    color: color,
                    theme: a.planetTheme,
                    size: 88,
                    semanticLabel: '${a.name} planet'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.sticker ?? ''} ${a.name}'.trim(),
                          style: text.headlineSmall),
                      Text(
                          '${plural(data.photos, 'photo')} · ${plural(data.videos, 'video')}',
                          style: text.bodyMedium
                              ?.copyWith(color: CosmosColors.softLavender)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (a.description != null && a.description!.isNotEmpty)
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(a.description!, style: text.bodyLarge))),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CosmicButton(
                    label: 'Edit planet',
                    icon: Icons.edit,
                    color: CosmosColors.midnightPurple,
                    onPressed: onEdit),
                CosmicButton(
                    label: 'Space Show',
                    icon: Icons.slideshow,
                    color: CosmosColors.nebulaPink,
                    foreground: CosmosColors.deepSpaceNavy,
                    onPressed: () => context
                        .push('${CosmosRoutes.slideshow}?planet=${a.id}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
