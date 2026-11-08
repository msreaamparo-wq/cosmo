import 'package:flutter/material.dart';

import '../core/constants/cosmos_colors.dart';
import '../models/media_model.dart';
import 'media_image.dart';

/// Grid tile: thumbnail + favorite star + video badge + selection state.
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.media,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
    this.logicalWidth = 160,
  });

  final MediaModel media;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected, selectionMode;
  final double logicalWidth;

  @override
  Widget build(BuildContext context) {
    final label =
        '${media.isVideo ? 'Video' : 'Photo'}${media.isFavorite ? ', favorite' : ''}${selected ? ', selected' : ''}';
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                  child: MediaImage(media, logicalWidth: logicalWidth)),
              if (media.isFavorite)
                const Positioned(
                    top: 6,
                    right: 6,
                    child: _Badge(
                        icon: Icons.star, color: CosmosColors.starYellow)),
              if (media.isVideo && !selectionMode)
                const Positioned(
                    bottom: 6,
                    left: 6,
                    child: _Badge(
                        icon: Icons.videocam, color: CosmosColors.skyBlue)),
              if (selectionMode)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? CosmosColors.cosmicViolet.withValues(alpha: .45)
                          : Colors.black26,
                      border: selected
                          ? Border.all(color: CosmosColors.starYellow, width: 3)
                          : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: CosmosColors.cloudWhite),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: CosmosColors.deepSpaceNavy.withValues(alpha: .7),
            shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color),
      );
}
