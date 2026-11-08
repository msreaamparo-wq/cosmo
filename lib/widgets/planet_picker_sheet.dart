import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/cosmos_colors.dart';
import '../core/routing/routes.dart';
import '../models/album_model.dart';
import '../providers/core_providers.dart';
import 'floating_planet.dart';

/// Lets the child choose a planet. Returns its id, or null.
Future<String?> showPlanetPicker(BuildContext context, WidgetRef ref) async {
  final albums = await ref.read(albumRepositoryProvider).all();
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: CosmosColors.midnightPurple,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _PlanetList(albums: albums),
  );
}

class _PlanetList extends StatelessWidget {
  const _PlanetList({required this.albums});
  final List<AlbumModel> albums;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Add to which planet?', style: text.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            minVerticalPadding: 12,
            leading: const CircleAvatar(
                backgroundColor: CosmosColors.nebulaPink,
                child: Icon(Icons.add, color: CosmosColors.deepSpaceNavy)),
            title: const Text('Create a new planet'),
            onTap: () {
              Navigator.of(context).pop();
              context.push(CosmosRoutes.createPlanet);
            },
          ),
          for (final a in albums)
            ListTile(
              minVerticalPadding: 8,
              leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingPlanet(
                      color: ColorOpacityX.fromHex(a.planetColor),
                      theme: a.planetTheme,
                      size: 48,
                      animate: false,
                      bobDistance: 0)),
              title: Text(a.name),
              subtitle: Text(
                  '${a.mediaCount} ${a.mediaCount == 1 ? 'memory' : 'memories'}'),
              onTap: () => Navigator.of(context).pop(a.id),
            ),
          if (albums.isEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text('You have no planets yet.', style: text.bodyLarge)),
        ],
      ),
    );
  }
}
