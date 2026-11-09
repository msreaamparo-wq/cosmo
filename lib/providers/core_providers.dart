import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_database.dart';
import '../models/album_model.dart';
import '../models/media_model.dart';
import '../platform/media_file_store.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/album_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/achievement_service.dart';
import '../services/auth_service.dart';
import '../services/import_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

final localDatabaseProvider =
    Provider<LocalDatabase>((ref) => LocalDatabase.instance);
final mediaFileStoreProvider = Provider<MediaFileStore>(
    (ref) => createMediaFileStore(ref.watch(localDatabaseProvider)));

final albumRepositoryProvider =
    Provider((ref) => AlbumRepository(ref.watch(localDatabaseProvider)));
final mediaRepositoryProvider =
    Provider((ref) => MediaRepository(ref.watch(localDatabaseProvider)));
final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(localDatabaseProvider)));
final achievementRepositoryProvider =
    Provider((ref) => AchievementRepository(ref.watch(localDatabaseProvider)));

final importServiceProvider = Provider((ref) => ImportService(
      ref.watch(mediaFileStoreProvider),
      ref.watch(mediaRepositoryProvider),
      ref.watch(albumRepositoryProvider),
    ));

final achievementServiceProvider = Provider<AchievementService>((ref) {
  final albums = ref.watch(albumRepositoryProvider);
  final s = AchievementService(
    ref.watch(achievementRepositoryProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    () async => (await albums.all()).length,
  );
  ref.onDispose(s.dispose);
  return s;
});

final achievementUnlockProvider = StreamProvider<AchievementDef>(
    (ref) => ref.watch(achievementServiceProvider).unlocks);

final authServiceProvider = Provider((ref) => AuthService());

final syncServiceProvider = Provider((ref) => SyncService(
      ref.watch(localDatabaseProvider),
      ref.watch(mediaFileStoreProvider),
      ref.watch(settingsRepositoryProvider),
      ref.watch(mediaRepositoryProvider),
    ));

/// Bumped after any data change so dependent providers/screens reload.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

/// Call after anything that changes media, planets or favorites. Also re-checks achievements.
void refreshUniverse(WidgetRef ref) {
  ref.read(dataVersionProvider.notifier).bump();
  ref.read(achievementServiceProvider).evaluate();
  // If a parent has approved automatic cloud backup, queue the changed data and
  // any new photo/video files without requiring a manual Sync now action.
  unawaited(ref.read(syncControllerProvider.notifier).autoSyncAndBackup());
}

final albumsProvider = FutureProvider<List<AlbumModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(albumRepositoryProvider).all();
});

final universeStatsProvider = FutureProvider<UniverseStats>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(mediaRepositoryProvider).stats();
});

final recentMediaProvider = FutureProvider<List<MediaModel>>((ref) {
  ref.watch(dataVersionProvider);
  return ref.watch(mediaRepositoryProvider).recent(limit: 12);
});

// ------------------------------------------------------------------ settings
class AppSettings {
  const AppSettings({
    this.onboardingDone = false,
    this.animationsEnabled = true,
    this.soundEnabled = false,
    this.cloudSyncEnabled = false,
    this.cloudBackupOwnerId,
    this.theme = 'midnight',
  });
  final bool onboardingDone, animationsEnabled, soundEnabled, cloudSyncEnabled;
  final String? cloudBackupOwnerId;
  final String theme; // midnight | nebula | aurora

  factory AppSettings.fromMap(Map<String, String> m) => AppSettings(
        onboardingDone: m['onboarding_done'] == 'true',
        animationsEnabled: m['animations_enabled'] != 'false',
        soundEnabled: m['sound_enabled'] == 'true',
        cloudSyncEnabled: m['cloud_sync_enabled'] == 'true',
        cloudBackupOwnerId: m['cloud_backup_owner_id'],
        theme: m['theme'] ?? 'midnight',
      );

  AppSettings copyWith(
          {bool? onboardingDone,
          bool? animationsEnabled,
          bool? soundEnabled,
          bool? cloudSyncEnabled,
          String? cloudBackupOwnerId,
          String? theme}) =>
      AppSettings(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
        cloudBackupOwnerId: cloudBackupOwnerId ?? this.cloudBackupOwnerId,
        theme: theme ?? this.theme,
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async =>
      AppSettings.fromMap(await ref.read(settingsRepositoryProvider).all());

  Future<void> _write(String key, String value, AppSettings next) async {
    await ref.read(settingsRepositoryProvider).set(key, value);
    state = AsyncData(next);
  }

  AppSettings get _cur => state.value ?? const AppSettings();

  Future<void> setOnboardingDone(bool v) =>
      _write('onboarding_done', '$v', _cur.copyWith(onboardingDone: v));
  Future<void> setAnimations(bool v) =>
      _write('animations_enabled', '$v', _cur.copyWith(animationsEnabled: v));
  Future<void> setSound(bool v) =>
      _write('sound_enabled', '$v', _cur.copyWith(soundEnabled: v));
  Future<void> setCloudSync(bool v) =>
      _write('cloud_sync_enabled', '$v', _cur.copyWith(cloudSyncEnabled: v));

  /// Records the parent account that explicitly approved automatic metadata +
  /// photo/video backup. Consent is tied to that account, not just this device.
  Future<void> enableAutomaticBackup(String ownerId) async {
    await ref
        .read(settingsRepositoryProvider)
        .set('cloud_backup_owner_id', ownerId);
    await _write(
      'cloud_sync_enabled',
      'true',
      _cur.copyWith(cloudSyncEnabled: true, cloudBackupOwnerId: ownerId),
    );
  }

  Future<void> setTheme(String v) =>
      _write('theme', v, _cur.copyWith(theme: v));

  /// After "Clear local app data": back to defaults.
  void resetToDefaults() => state = const AsyncData(AppSettings());
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// -------------------------------------------------------------- parent gate
/// True after the grown-up check was solved. Settings re-locks it every time it is opened.
/// A child barrier, NOT authentication.
class ParentGateState extends Notifier<bool> {
  @override
  bool build() => false;
  void pass() => state = true;
  void lock() => state = false;
}

final parentGateProvider =
    NotifierProvider<ParentGateState, bool>(ParentGateState.new);

// --------------------------------------------------------------------- auth
final authUserProvider = StreamProvider<User?>((ref) async* {
  final client = SupabaseService.client;
  if (client == null) {
    yield null;
    return;
  }
  yield client.auth.currentUser;
  await for (final s in client.auth.onAuthStateChange) {
    yield s.session?.user;
  }
});

// --------------------------------------------------------------------- sync
enum SyncStatus {
  disabled,
  signedOut,
  offline,
  synced,
  syncing,
  backupPending,
  failed
}

class SyncState {
  const SyncState(
      {this.status = SyncStatus.disabled,
      this.message = '',
      this.progress,
      this.pending = 0,
      this.failedBackupIds = const [],
      this.lastSyncedAt});
  final SyncStatus status;
  final String message;
  final double? progress; // 0..1 while backing up
  final int pending;
  final List<String> failedBackupIds;
  final DateTime? lastSyncedAt;

  SyncState copyWith(
          {SyncStatus? status,
          String? message,
          double? progress,
          bool clearProgress = false,
          int? pending,
          List<String>? failedBackupIds,
          DateTime? lastSyncedAt}) =>
      SyncState(
        status: status ?? this.status,
        message: message ?? this.message,
        progress: clearProgress ? null : (progress ?? this.progress),
        pending: pending ?? this.pending,
        failedBackupIds: failedBackupIds ?? this.failedBackupIds,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

class SyncController extends Notifier<SyncState> {
  BackupToken? _token;
  bool _automaticBackupRunning = false;
  bool _automaticBackupQueued = false;

  @override
  SyncState build() => const SyncState();

  SyncService get _svc => ref.read(syncServiceProvider);

  Future<void> refreshStatus() async {
    final settings = ref.read(settingsProvider).value;
    final enabled = settings?.cloudSyncEnabled ?? false;
    final user = SupabaseService.client?.auth.currentUser;
    final pending = await _svc.pendingCount();
    if (!enabled) {
      state = state.copyWith(
          status: SyncStatus.disabled,
          message: 'Automatic cloud backup is not enabled.',
          pending: pending);
    } else if (!SupabaseService.isReady || user == null) {
      state = state.copyWith(
          status: SyncStatus.signedOut,
          message: 'Sign in as a parent to sync.',
          pending: pending);
    } else if (settings?.cloudBackupOwnerId != user.id) {
      state = state.copyWith(
          status: SyncStatus.disabled,
          message: 'Enable automatic backup for this parent account.',
          pending: pending);
    } else if (state.status != SyncStatus.syncing) {
      state = state.copyWith(
        status: pending > 0 ? SyncStatus.backupPending : SyncStatus.synced,
        message: pending > 0
            ? '$pending changes waiting to sync.'
            : 'Everything is up to date.',
        pending: pending,
      );
    }
  }

  /// Sync metadata and upload every unbacked-up photo/video after the parent has
  /// explicitly enabled automatic backup for the currently signed-in account.
  /// Called at app startup and after local data changes.
  Future<void> autoSyncAndBackup() async {
    final settings = ref.read(settingsProvider).value;
    final user = SupabaseService.client?.auth.currentUser;
    if (settings?.cloudSyncEnabled != true ||
        user == null ||
        settings?.cloudBackupOwnerId != user.id) return;

    if (_automaticBackupRunning || state.status == SyncStatus.syncing) {
      _automaticBackupQueued = true;
      return;
    }

    _automaticBackupRunning = true;
    try {
      await syncNow();
      if (state.status != SyncStatus.synced) return;

      final unbacked = await ref.read(mediaRepositoryProvider).notBackedUp();
      if (unbacked.isNotEmpty) await backup();
    } catch (_) {
      state = state.copyWith(
        status: SyncStatus.failed,
        message:
            'Automatic cloud backup could not finish. It will try again after your next change or app restart.',
        clearProgress: true,
      );
    } finally {
      _automaticBackupRunning = false;
      if (_automaticBackupQueued) {
        _automaticBackupQueued = false;
        Future<void>.delayed(
            const Duration(milliseconds: 350), autoSyncAndBackup);
      }
    }
  }

  Future<void> syncNow() async {
    if (state.status == SyncStatus.syncing) return;
    state = state.copyWith(
        status: SyncStatus.syncing, message: 'Syncing…', clearProgress: true);
    final r =
        await _svc.syncNow(onStep: (s) => state = state.copyWith(message: s));
    final pending = await _svc.pendingCount();
    if (r.ok) {
      state = state.copyWith(
          status: SyncStatus.synced,
          message: 'Synced. Sent ${r.pushed}, received ${r.pulled}.',
          pending: pending,
          lastSyncedAt: DateTime.now());
      ref.read(dataVersionProvider.notifier).bump();
    } else {
      state = state.copyWith(
          status: r.offline ? SyncStatus.offline : SyncStatus.failed,
          message: r.error!,
          pending: pending);
    }
  }

  /// Explicit, parent-approved photo backup. [ids] null = every photo not yet backed up.
  Future<BackupReport?> backup({List<String>? ids}) async {
    if (state.status == SyncStatus.syncing) return null;
    final settings = ref.read(settingsProvider).value;
    final user = SupabaseService.client?.auth.currentUser;
    if (settings?.cloudSyncEnabled != true ||
        user == null ||
        settings?.cloudBackupOwnerId != user.id) {
      state = state.copyWith(
          status: SyncStatus.disabled,
          message:
              'A parent must enable automatic backup for this account first.');
      return null;
    }
    final media = ref.read(mediaRepositoryProvider);
    final items =
        ids == null ? await media.notBackedUp() : await media.byIds(ids);
    if (items.isEmpty) {
      state = state.copyWith(message: 'Everything is already backed up.');
      return const BackupReport();
    }
    _token = BackupToken();
    state = state.copyWith(
        status: SyncStatus.syncing,
        message: 'Backing up ${items.length} photos…',
        progress: 0,
        failedBackupIds: const []);
    final report = await _svc.backup(items,
        token: _token,
        onProgress: (d, t) => state = state.copyWith(
            progress: t == 0 ? 1 : d / t, message: 'Backing up $d of $t…'));
    _token = null;
    final failed = report.failedIds;
    if (report.error != null) {
      state = state.copyWith(
          status: SyncStatus.failed,
          message: report.error!,
          clearProgress: true);
    } else if (report.cancelled) {
      state = state.copyWith(
          status: SyncStatus.backupPending,
          message: 'Backup stopped. ${report.uploaded} saved.',
          clearProgress: true,
          failedBackupIds: failed);
    } else if (failed.isNotEmpty) {
      state = state.copyWith(
          status: SyncStatus.failed,
          message:
              '${failed.length} photos could not be backed up. You can retry.',
          clearProgress: true,
          failedBackupIds: failed);
    } else {
      state = state.copyWith(
          status: SyncStatus.synced,
          message:
              'Backed up ${report.uploaded} photos${report.tooLarge > 0 ? ' (${report.tooLarge} too large to upload)' : ''}.',
          clearProgress: true);
      await syncNow(); // push the new storage paths
    }
    return report;
  }

  Future<void> retryFailedBackup() => backup(ids: state.failedBackupIds);
  void cancelBackup() => _token?.cancel();
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
