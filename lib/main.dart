import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'database/db_factory.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabaseFactory(); // web: persistent SQLite in IndexedDB; Android: no-op
  await SupabaseService
      .init(); // optional: app runs local-only if not configured/reachable
  runApp(const ProviderScope(child: CosmosApp()));
}
