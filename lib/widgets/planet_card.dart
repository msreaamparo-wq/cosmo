import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../models/album_model.dart';
import 'floating_planet.dart';

/// Tappable card showing one album as its own planet.
class PlanetCard extends StatelessWidget {
  const PlanetCard(
      {super.key,
      required this.album,
      required this.onTap,
      this.animate = true});

  final AlbumModel album;
  final VoidCallback onTap;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = ColorOpacityX.fromHex(album.planetColor);
    final text = Theme.of(context).textTheme;
    final count = album.mediaCount;

    return Semantics(
      button: true,
      label: '${album.name}, $count ${count == 1 ? 'memory' : 'memories'}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: CosmosColors.midnightPurple.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Center(
                      child: FloatingPlanet(
                          color: color,
                          theme: album.planetTheme,
                          size: 104,
                          animate: animate),
                    ),
                    if (album.sticker != null && album.sticker!.isNotEmpty)
                      Text(album.sticker!,
                          style: const TextStyle(fontSize: 24)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(album.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.titleMedium),
                Text('$count ${count == 1 ? 'memory' : 'memories'}',
                    style: text.bodyMedium
                        ?.copyWith(color: CosmosColors.softLavender)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
