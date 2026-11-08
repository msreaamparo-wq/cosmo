import 'dart:async';

import '../repositories/achievement_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/settings_repository.dart';

class AchievementDef {
  const AchievementDef(this.code, this.title, this.description, this.emoji);
  final String code, title, description, emoji;
}

const achievementDefs = <AchievementDef>[
  AchievementDef('first_memory', 'First Memory',
      'You added your very first picture.', '⭐'),
  AchievementDef(
      'first_planet', 'First Planet', 'You created your first planet.', '🪐'),
  AchievementDef('first_favorite', 'First Favorite',
      'You picked your first favorite star.', '🌟'),
  AchievementDef('five_memories', 'Five Memories Saved',
      'Five memories are now in your universe.', '🌙'),
  AchievementDef('memory_collector', 'Memory Collector',
      'Twenty-five memories saved. What a collection!', '🚀'),
  AchievementDef('universe_explorer', 'Universe Explorer',
      'You tried Space Show, Discovery and Constellations.', '🔭'),
];

/// Unlocks achievements from REAL app activity only. No streaks, timers or competition.
class AchievementService {
  AchievementService(
      this._achievements, this._media, this._settings, this._planetCount);
  final AchievementRepository _achievements;
  final MediaRepository _media;
  final SettingsRepository _settings;
  final Future<int> Function() _planetCount;

  final _controller = StreamController<AchievementDef>.broadcast();
  Stream<AchievementDef> get unlocks => _controller.stream;

  Future<void> visit(String feature) async {
    await _settings.set('visited_$feature', 'true');
    await evaluate();
  }

  Future<void> evaluate() async {
    try {
      final stats = await _media.stats();
      final planets = await _planetCount();
      final visited = await Future.wait([
        _settings.get('visited_slideshow'),
        _settings.get('visited_discovery'),
        _settings.get('visited_constellation'),
      ]);
      final met = <String, bool>{
        'first_memory': stats.memories >= 1,
        'first_planet': planets >= 1,
        'first_favorite': stats.favorites >= 1,
        'five_memories': stats.memories >= 5,
        'memory_collector': stats.memories >= 25,
        'universe_explorer': visited.every((v) => v == 'true'),
      };
      for (final def in achievementDefs) {
        if (met[def.code] == true && await _achievements.unlock(def.code)) {
          _controller.add(def);
        }
      }
    } catch (_) {
      // Achievements are a nicety: never let them break the action that triggered them.
    }
  }

  void dispose() => _controller.close();
}
