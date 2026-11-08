import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: SQLite compiled to WebAssembly, persisted in the browser's IndexedDB.
/// Requires `sqlite3.wasm` and `sqflite_sw.js` in /web (run: dart run sqflite_common_ffi_web:setup).
Future<void> initDatabaseFactory() async {
  databaseFactory = databaseFactoryFfiWeb;
}
