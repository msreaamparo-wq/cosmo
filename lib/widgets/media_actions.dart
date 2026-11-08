import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../providers/core_providers.dart';
import 'confirm_dialog.dart';
import 'planet_picker_sheet.dart';

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Favorites: if every item is already a favorite, un-favorite them; otherwise favorite them all.
Future<void> toggleFavorites(
    BuildContext context, WidgetRef ref, List<MediaModel> items) async {
  if (items.isEmpty) return;
  final makeFav = !items.every((m) => m.isFavorite);
  await ref
      .read(mediaRepositoryProvider)
      .setFavorite(items.map((m) => m.id), makeFav);
  refreshUniverse(ref);
  if (context.mounted)
    toast(context,
        makeFav ? 'Added to your favorite stars ⭐' : 'Removed from favorites');
}

Future<void> addToPlanet(
    BuildContext context, WidgetRef ref, List<String> mediaIds) async {
  final albumId = await showPlanetPicker(context, ref);
  if (albumId == null) return;
  await ref.read(albumRepositoryProvider).addMedia(albumId, mediaIds);
  refreshUniverse(ref);
  if (context.mounted) toast(context, 'Added to your planet 🪐');
}

/// Removes items from COSMOS only (its private copy). Photos in the device gallery are never touched.
Future<bool> deleteFromCosmos(
    BuildContext context, WidgetRef ref, List<MediaModel> items) async {
  if (items.isEmpty) return false;
  final ok = await confirmDialog(
    context,
    title: 'Remove from COSMOS?',
    message:
        'This removes ${items.length == 1 ? 'this memory' : '${items.length} memories'} from your COSMOS universe. '
        'The original pictures in your device gallery stay safe.',
    confirmLabel: 'Remove',
    destructive: true,
  );
  if (!ok) return false;
  final store = ref.read(mediaFileStoreProvider);
  await ref.read(mediaRepositoryProvider).softDelete(items.map((m) => m.id));
  for (final m in items) {
    await store.delete(m);
  }
  refreshUniverse(ref);
  return true;
}
