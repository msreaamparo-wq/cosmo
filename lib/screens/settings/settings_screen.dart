import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/cosmos_colors.dart';
import '../../core/routing/routes.dart';
import '../../core/utilities/formatters.dart';
import '../../providers/core_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_scaffold.dart';
import '../../widgets/media_actions.dart';
import '../../widgets/parent_gate.dart';
import '../../widgets/sync_status_indicator.dart';

const privacyText = '''
COSMOS keeps your memories on this device by default.

STORED ON THIS DEVICE
• Copies of the pictures you choose to add, kept in COSMOS' private storage (in a browser: in the browser's own storage).
• Your planets, favorites, achievements and settings.
• Your original pictures in the device gallery are never changed or deleted.

CLOUD BACKUP (OPTIONAL, PARENT ONLY)
• Off unless a grown-up signs in and turns it on.
• When on, COSMOS syncs: planet names, colors and descriptions, which pictures are on which planet, favorite marks, picture details (file name, type, date taken, size) and achievements.
• Picture FILES are uploaded only when a grown-up taps "Back up photos now", and only the pictures not yet backed up. They go to a private storage area that only that parent account can open.
• You can stop at any time. Removing a memory from COSMOS also removes its cloud backup copy the next time sync runs.

WHAT COSMOS DOES NOT DO
• No ads. No tracking or analytics. No location collection. No social features, messaging or public sharing.

IMPORTANT
• The grown-up check is a simple question to keep young children out of settings. It is not a security lock.
• This app has not had a legal review for children's privacy laws (such as COPPA or GDPR-K). Get one before releasing it publicly.
''';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(parentGateProvider.notifier)
          .lock(); // every visit requires the check again
      _askGate();
    });
  }

  Future<void> _askGate() async {
    final ok = await ParentGate.verify(context);
    if (!mounted) return;
    if (ok) {
      ref.read(parentGateProvider.notifier).pass();
      ref.read(syncControllerProvider.notifier).refreshStatus();
    } else if (!ref.read(parentGateProvider)) {
      // cancelled: leave unless they retry
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = ref.watch(parentGateProvider);
    if (!passed) {
      return CosmicScaffold(
        title: 'Grown-ups only',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 12),
                Text('Settings are for grown-ups.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CosmicButton(
                    label: 'Solve the grown-up check',
                    icon: Icons.calculate_outlined,
                    onPressed: _askGate),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => context.go(CosmosRoutes.home),
                    child: const Text('Back to my universe')),
              ],
            ),
          ),
        ),
      );
    }
    return const _SettingsBody();
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final text = Theme.of(context).textTheme;

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: CosmosColors.midnightPurple.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(24)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                  header: true, child: Text(title, style: text.titleLarge)),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );

    return CosmicScaffold(
      title: 'Settings',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              section('Appearance', [
                Text('Sky color', style: text.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in const [
                      ('midnight', 'Midnight'),
                      ('nebula', 'Nebula'),
                      ('aurora', 'Aurora')
                    ])
                      ChoiceChip(
                          label: Text(t.$2),
                          selected: settings.theme == t.$1,
                          onSelected: (_) => ref
                              .read(settingsProvider.notifier)
                              .setTheme(t.$1)),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Animations'),
                  subtitle: Text(MediaQuery.disableAnimationsOf(context)
                      ? 'Your device asks for reduced motion, so animations stay off.'
                      : 'Twinkling stars and floating planets.'),
                  value: settings.animationsEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setAnimations(v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sound'),
                  subtitle: const Text(
                      'COSMOS has no sound effects yet. This choice is saved for when they arrive.'),
                  value: settings.soundEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setSound(v),
                ),
              ]),
              const _StorageSection(),
              const _CloudSection(),
              section('About COSMOS', [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App version'),
                    subtitle: Text(snap.hasData
                        ? '${snap.data!.version} (${snap.data!.buildNumber})'
                        : '…'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy information'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: CosmosColors.midnightPurple,
                      title: const Text('Privacy'),
                      content: SingleChildScrollView(
                          child: Text(privacyText, style: text.bodyMedium)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'))
                      ],
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.rocket_launch_outlined),
                  title: const Text('About COSMOS'),
                  subtitle: const Text('Your Memories, Your Little Universe.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.replay),
                  title: const Text('Show the welcome tour again'),
                  onTap: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setOnboardingDone(false);
                    if (context.mounted)
                      toast(context,
                          'The welcome tour will show next time COSMOS opens.');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: CosmosColors.coral),
                  title: const Text('Clear all local app data'),
                  subtitle: const Text(
                      'Removes planets, memories and settings from COSMOS. Pictures in your device gallery stay.'),
                  onTap: () => _wipe(context, ref),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Clear everything in COSMOS?',
      message:
          'This removes all planets, memories, favorites, achievements and settings from this device. '
          'Your original pictures in the device gallery are NOT touched. Anything already backed up to the cloud stays in the cloud. This cannot be undone.',
      confirmLabel: 'Clear everything',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(mediaFileStoreProvider).wipe();
    await ref.read(localDatabaseProvider).wipeAll();
    ref.read(settingsProvider.notifier).resetToDefaults();
    ref.read(dataVersionProvider.notifier).bump();
    if (context.mounted) context.go(CosmosRoutes.splash);
  }
}

class _StorageSection extends ConsumerStatefulWidget {
  const _StorageSection();
  @override
  ConsumerState<_StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<_StorageSection> {
  Future<(int, int, int)>? _info;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _info = _load();
  }

  Future<(int, int, int)> _load() async {
    final stats = await ref.read(mediaRepositoryProvider).stats();
    final bytes = await ref.read(mediaFileStoreProvider).usedBytes();
    return (stats.memories, bytes, stats.missing);
  }

  void _refresh() => setState(() => _info = _load());

  Future<void> _check() async {
    setState(() => _busy = true);
    final store = ref.read(mediaFileStoreProvider);
    final repo = ref.read(mediaRepositoryProvider);
    var gone = 0;
    for (final m in await repo.allActive()) {
      if (!await store.exists(m)) {
        await repo.markUnavailable(m.id);
        gone++;
      }
    }
    refreshUniverse(ref);
    if (mounted) {
      setState(() => _busy = false);
      _refresh();
      toast(context,
          gone == 0 ? 'All files are there.' : '$gone files are missing.');
    }
  }

  Future<void> _removeMissing() async {
    final repo = ref.read(mediaRepositoryProvider);
    final missing = await repo.unavailable();
    // keep items that can be restored from a cloud backup
    final removable =
        missing.where((m) => m.cloudPath == null).map((m) => m.id).toList();
    await repo.softDelete(removable);
    refreshUniverse(ref);
    if (mounted) {
      _refresh();
      toast(context, 'Removed ${plural(removable.length, 'missing item')}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: CosmosColors.midnightPurple.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(24)),
        child: FutureBuilder<(int, int, int)>(
          future: _info,
          builder: (context, snap) {
            final d = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                    d == null
                        ? 'Counting…'
                        : 'Memories on this device: ${d.$1}\nSpace used by COSMOS: ${formatBytes(d.$2)}${d.$3 > 0 ? '\nMissing files: ${d.$3}' : ''}',
                    style: text.bodyLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CosmicButton(
                      label: 'Clear cache',
                      icon: Icons.cleaning_services_outlined,
                      color: CosmosColors.midnightPurple,
                      onPressed: () async {
                        await ref.read(mediaFileStoreProvider).clearCache();
                        if (context.mounted)
                          toast(context,
                              'Cache cleared. Your memories are safe.');
                      },
                    ),
                    CosmicButton(
                        label: _busy ? 'Checking…' : 'Check files',
                        icon: Icons.fact_check_outlined,
                        color: CosmosColors.midnightPurple,
                        onPressed: _busy ? null : _check),
                    if ((d?.$3 ?? 0) > 0)
                      CosmicButton(
                          label: 'Remove missing items',
                          icon: Icons.delete_outline,
                          color: CosmosColors.coral,
                          foreground: CosmosColors.deepSpaceNavy,
                          onPressed: _removeMissing),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CloudSection extends ConsumerWidget {
  const _CloudSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final sync = ref.watch(syncControllerProvider);
    final user = ref.watch(authUserProvider).value;
    final ctl = ref.read(syncControllerProvider.notifier);
    final busy = sync.status == SyncStatus.syncing;

    Widget frame(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: CosmosColors.midnightPurple.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(24)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cloud backup (parents)', style: text.titleLarge),
              const SizedBox(height: 8),
              ...children
            ]),
          ),
        );

    if (!AppConfig.supabaseConfigured || !SupabaseService.isReady) {
      return frame([
        Text(
          AppConfig.supabaseConfigured
              ? 'The cloud could not be reached when COSMOS started. Everything still works on this device. Restart the app to try again.'
              : 'Cloud backup is not set up in this build. COSMOS works fully without it. To enable it, see docs/SUPABASE_SETUP.md.',
          style: text.bodyLarge,
        ),
      ]);
    }

    return frame([
      if (user == null) ...[
        Text('Sign in with a parent account to use cloud backup.',
            style: text.bodyLarge),
        const SizedBox(height: 12),
        CosmicButton(
            label: 'Sign in as parent',
            icon: Icons.login,
            onPressed: () => context.push(CosmosRoutes.parentAuth)),
      ] else ...[
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(user.email ?? 'Parent account'),
            subtitle: const Text('Signed in')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cloud sync'),
          subtitle: const Text(
              'Syncs planets, favorites and picture details. Photo files upload only when you tap "Back up photos now".'),
          value: settings.cloudSyncEnabled,
          onChanged: (v) async {
            if (v) {
              final ok = await confirmDialog(
                context,
                title: 'Turn on cloud sync?',
                message:
                    'COSMOS will send planet names and colors, which pictures are on which planet, favorite marks, picture details and achievements to this parent account\'s private cloud storage. '
                    'No photo files are uploaded unless you tap "Back up photos now".',
                confirmLabel: 'Turn on',
              );
              if (!ok) return;
            }
            await ref.read(settingsProvider.notifier).setCloudSync(v);
            await ctl.refreshStatus();
            if (v) ctl.syncNow();
          },
        ),
        const SizedBox(height: 4),
        const SyncStatusIndicator(),
        if (sync.message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sync.message,
                  style: text.bodyMedium
                      ?.copyWith(color: CosmosColors.softLavender))),
        if (sync.lastSyncedAt != null)
          Text('Last synced ${formatDateTime(sync.lastSyncedAt!)}',
              style: text.bodyMedium?.copyWith(color: CosmosColors.mutedGray)),
        if (sync.progress != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                  value: sync.progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CosmicButton(
                label: 'Sync now',
                icon: Icons.sync,
                onPressed:
                    settings.cloudSyncEnabled && !busy ? ctl.syncNow : null),
            CosmicButton(
              label: 'Back up photos now',
              icon: Icons.cloud_upload_outlined,
              color: CosmosColors.nebulaPink,
              foreground: CosmosColors.deepSpaceNavy,
              onPressed: settings.cloudSyncEnabled && !busy
                  ? () async {
                      final n = (await ref
                              .read(mediaRepositoryProvider)
                              .notBackedUp())
                          .length;
                      if (!context.mounted) return;
                      if (n == 0) {
                        toast(context, 'Everything is already backed up.');
                        return;
                      }
                      final ok = await confirmDialog(
                        context,
                        title: 'Back up $n ${n == 1 ? 'photo' : 'photos'}?',
                        message:
                            'These pictures will be uploaded to this parent account\'s private cloud storage. Only that account can open them. You can remove a memory later and its backup copy is removed too.',
                        confirmLabel: 'Back up',
                      );
                      if (ok) ctl.backup();
                    }
                  : null,
            ),
            if (busy && sync.progress != null)
              CosmicButton(
                  label: 'Stop',
                  icon: Icons.stop,
                  color: CosmosColors.coral,
                  foreground: CosmosColors.deepSpaceNavy,
                  onPressed: ctl.cancelBackup),
            if (sync.failedBackupIds.isNotEmpty && !busy)
              CosmicButton(
                  label: 'Retry failed',
                  icon: Icons.refresh,
                  color: CosmosColors.starYellow,
                  foreground: CosmosColors.deepSpaceNavy,
                  onPressed: ctl.retryFailedBackup),
            CosmicButton(
              label: 'Restore from backup',
              icon: Icons.cloud_download_outlined,
              color: CosmosColors.midnightPurple,
              onPressed: busy
                  ? null
                  : () async {
                      final r =
                          await ref.read(syncServiceProvider).restoreMissing();
                      refreshUniverse(ref);
                      if (context.mounted)
                        toast(
                            context,
                            r.restored == 0 && r.failed == 0
                                ? 'Nothing to restore.'
                                : 'Restored ${r.restored}${r.failed > 0 ? ', ${r.failed} failed' : ''}.');
                    },
            ),
            CosmicButton(
              label: 'Sign out',
              icon: Icons.logout,
              color: CosmosColors.midnightPurple,
              onPressed: busy
                  ? null
                  : () async {
                      await ref.read(authServiceProvider).signOut();
                      await ctl.refreshStatus();
                    },
            ),
          ],
        ),
      ],
    ]);
  }
}
