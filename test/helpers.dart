import 'package:cosmos/database/local_database.dart';
import 'package:cosmos/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh in-memory COSMOS database (real SQLite via FFI), schema v2.
Future<LocalDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: CosmosSchema.version,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        for (final s in CosmosSchema.v2) {
          await d.execute(s);
        }
      },
    ),
  );
  return LocalDatabase.forTest(db);
}
