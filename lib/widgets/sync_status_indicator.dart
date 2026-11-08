import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/cosmos_colors.dart';
import '../providers/core_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncControllerProvider);
    final (icon, color, label) = switch (s.status) {
      SyncStatus.disabled => (
          Icons.cloud_off_outlined,
          CosmosColors.mutedGray,
          'Cloud backup off'
        ),
      SyncStatus.signedOut => (
          Icons.person_outline,
          CosmosColors.mutedGray,
          'Sign in to sync'
        ),
      SyncStatus.offline => (Icons.wifi_off, CosmosColors.coral, 'Offline'),
      SyncStatus.synced => (
          Icons.cloud_done_outlined,
          CosmosColors.mint,
          'Synced'
        ),
      SyncStatus.syncing => (
          Icons.cloud_sync_outlined,
          CosmosColors.skyBlue,
          'Syncing'
        ),
      SyncStatus.backupPending => (
          Icons.cloud_upload_outlined,
          CosmosColors.starYellow,
          'Backup pending'
        ),
      SyncStatus.failed => (
          Icons.error_outline,
          CosmosColors.coral,
          'Sync failed'
        ),
    };
    return Semantics(
      label: 'Cloud status: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Flexible(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: color))),
        ],
      ),
    );
  }
}
