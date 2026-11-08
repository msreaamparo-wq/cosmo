import 'package:sqflite/sqflite.dart';

/// Records that a local row must be pushed to the cloud (only acted on when the parent enabled sync).
/// One pending row per record; the newest operation wins.
Future<void> enqueueSync(DatabaseExecutor ex, String entity, String entityId,
    [String op = 'upsert']) {
  return ex.insert(
    'pending_sync',
    {
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'attempts': 0,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
