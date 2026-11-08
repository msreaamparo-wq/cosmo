import 'package:flutter/foundation.dart';

import '../models/media_model.dart';
import '../repositories/media_repository.dart';

/// Incremental (paged) loading so large galleries never load everything at once.
class MediaPager extends ChangeNotifier {
  MediaPager(this._repo, this._options, {this.pageSize = 60});

  final MediaRepository _repo;
  final int pageSize;
  MediaQueryOptions _options;

  final List<MediaModel> items = [];
  int total = 0;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  int _gen = 0; // discards results from superseded loads
  bool _disposed = false;

  MediaQueryOptions get options => _options;

  Future<void> setOptions(MediaQueryOptions o) {
    _options = o;
    return reload();
  }

  Future<void> reload() async {
    final gen = ++_gen;
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait([
        _repo.page(_options, offset: 0, limit: pageSize),
        _repo.count(_options)
      ]);
      if (gen != _gen) return;
      items
        ..clear()
        ..addAll(results[0] as List<MediaModel>);
      total = results[1] as int;
      hasMore = items.length < total;
    } catch (e) {
      if (gen != _gen) return;
      error = e;
    }
    loading = false;
    _notify();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final gen = _gen;
    loading = true;
    _notify();
    try {
      final more =
          await _repo.page(_options, offset: items.length, limit: pageSize);
      if (gen != _gen) return;
      items.addAll(more);
      hasMore = items.length < total && more.isNotEmpty;
    } catch (e) {
      if (gen != _gen) return;
      error = e;
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
