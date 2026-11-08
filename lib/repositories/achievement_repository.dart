import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';
import '../database/pending_sync.dart';

class AchievementRepository {
  AchievementRepository(this._local);
  final LocalDatabase _local;

  Future<Map<String, DateTime>> unlocked() async {
    final db = await _local.database;
    final rows = await db.query('achievements');
    return {
      for (final r in rows)
        r['achievement_code']! as String:
            DateTime.fromMillisecondsSinceEpoch(r['unlocked_at']! as int),
    };
  }

  /// Returns true only when this call newly unlocked [code].
  Future<bool> unlock(String code) async {
    final db = await _local.database;
    final id = await db.insert(
      'achievements',
      {
        'achievement_code': code,
        'unlocked_at': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (id == 0) return false;
    await enqueueSync(db, 'achievement', code);
    return true;
  }
}
