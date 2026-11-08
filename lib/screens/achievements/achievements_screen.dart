import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/cosmos_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../providers/core_providers.dart';
import '../../services/achievement_service.dart';
import '../../widgets/cosmic_loading.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/error_message.dart';

final _unlockedProvider = FutureProvider<Map<String, DateTime>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(achievementRepositoryProvider).unlocked();
});

/// Gentle, non-competitive. No streaks, no timers, no leaderboards.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(_unlockedProvider);
    final text = Theme.of(context).textTheme;
    return CosmicScaffold(
      title: 'Achievements',
      body: unlocked.when(
        loading: () => const CosmicLoading(),
        error: (_, __) =>
            ErrorMessage(onRetry: () => ref.invalidate(_unlockedProvider)),
        data: (map) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${map.length} of ${achievementDefs.length} discovered',
                style: text.titleMedium
                    ?.copyWith(color: CosmosColors.softLavender)),
            const SizedBox(height: 12),
            for (final d in achievementDefs)
              _Card(def: d, unlockedAt: map[d.code]),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.def, required this.unlockedAt});
  final AchievementDef def;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = unlockedAt != null;
    return Semantics(
      label:
          '${def.title}. ${def.description}. ${done ? 'Unlocked' : 'Not yet'}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CosmosColors.midnightPurple.withValues(alpha: done ? .95 : .6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: done
                  ? CosmosColors.starYellow.withValues(alpha: .6)
                  : Colors.transparent,
              width: 2),
        ),
        child: Row(
          children: [
            Opacity(
                opacity: done ? 1 : .35,
                child: Text(def.emoji, style: const TextStyle(fontSize: 40))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(def.description,
                      style: text.bodyMedium
                          ?.copyWith(color: CosmosColors.softLavender)),
                  const SizedBox(height: 4),
                  Text(
                      done
                          ? 'Unlocked ${formatDate(unlockedAt!)}'
                          : 'Keep exploring. It will happen!',
                      style: text.bodyMedium?.copyWith(
                          color: done
                              ? CosmosColors.mint
                              : CosmosColors.mutedGray)),
                ],
              ),
            ),
            if (done) const Icon(Icons.check_circle, color: CosmosColors.mint),
          ],
        ),
      ),
    );
  }
}
