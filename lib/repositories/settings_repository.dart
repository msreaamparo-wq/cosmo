import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';

/// Key/value settings, persisted locally (survives restarts and browser refresh).
class SettingsRepository {
  SettingsRepository(this._local);
  final LocalDatabase _local;

  Future<String?> get(String key) async {
    final db = await _local.database;
    final r = await db.query('settings_kv',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isEmpty ? null : r.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    final db = await _local.database;
    await db.insert(
      'settings_kv',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> all() async {
    final db = await _local.database;
    final rows = await db.query('settings_kv');
    return {for (final r in rows) r['key']! as String: r['value']! as String};
  }
}
