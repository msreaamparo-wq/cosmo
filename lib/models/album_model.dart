/// A "planet". Metadata only; media is linked through album_media (many-to-many).
class AlbumModel {
  const AlbumModel({
    required this.id,
    required this.name,
    required this.planetTheme,
    required this.planetColor,
    required this.createdAt,
    required this.updatedAt,
    this.sticker,
    this.description,
    this.coverMediaId,
    this.mediaCount = 0,
  });

  final String id;
  final String name;
  final String planetTheme; // rings | stripes | craters | plain
  final String planetColor; // '#RRGGBB'
  final String? sticker; // emoji icon
  final String? description;
  final String? coverMediaId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int mediaCount; // derived, not stored

  AlbumModel copyWithName(String newName) => AlbumModel(
        id: id,
        name: newName,
        planetTheme: planetTheme,
        planetColor: planetColor,
        sticker: sticker,
        description: description,
        coverMediaId: coverMediaId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        mediaCount: mediaCount,
      );

  factory AlbumModel.fromMap(Map<String, Object?> m) => AlbumModel(
        id: m['id']! as String,
        name: m['name']! as String,
        planetTheme: m['planet_theme']! as String,
        planetColor: m['planet_color']! as String,
        sticker: m['sticker'] as String?,
        description: m['description'] as String?,
        coverMediaId: m['cover_media_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at']! as int),
        mediaCount: (m['media_count'] as int?) ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'planet_theme': planetTheme,
        'planet_color': planetColor,
        'sticker': sticker,
        'description': description,
        'cover_media_id': coverMediaId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };
}
