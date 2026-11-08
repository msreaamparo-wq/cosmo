import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// Optional cloud. If URL/key are not provided via --dart-define, or Supabase is unreachable
/// at startup, the app simply runs local-only.
abstract final class SupabaseService {
  static bool _ready = false;
  static bool get isReady => _ready;
  static SupabaseClient? get client => _ready ? Supabase.instance.client : null;

  static Future<void> init() async {
    if (!AppConfig.supabaseConfigured) return;
    try {
      await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabasePublishableKey);
      _ready = true;
    } catch (e) {
      debugPrint('Supabase init failed: ${e.runtimeType}');
    }
  }
}
