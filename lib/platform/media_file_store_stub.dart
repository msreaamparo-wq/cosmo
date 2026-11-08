import '../database/local_database.dart';
import 'media_file_store.dart';

MediaFileStore createStore(LocalDatabase db) =>
    throw UnsupportedError('No MediaFileStore for this platform');
