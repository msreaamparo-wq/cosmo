enum MediaType { image, video }

/// A LOCAL media record (a copy kept inside COSMOS' private storage, or a browser blob on web).
/// Separate from any cloud object: a row here never means the file was uploaded.
class MediaModel {
  const MediaModel({
    required this.id,
    required this.localUri,
    required this.mediaType,
    required this.importedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fileName,
    this.mimeType,
    this.capturedAt, // null when unknown. Never fabricated.
    this.fileSize,
    this.isFavorite = false,
    this.isAvailable = true,
    this.cloudPath,
    this.backedUpAt,
  });

  final String id;
  final String
      localUri; // file path (Android) | 'web:<id>' (browser) | 'cloud://<id>' (not on this device)
  final MediaType mediaType;
  final DateTime importedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fileName;
  final String? mimeType;
  final DateTime? capturedAt;
  final int? fileSize;
  final bool isFavorite;
  final bool isAvailable;
  final String? cloudPath;
  final DateTime? backedUpAt;

  bool get isVideo => mediaType == MediaType.video;
  bool get isBackedUp => cloudPath != null;

  factory MediaModel.fromMap(Map<String, Object?> m) {
    DateTime? ts(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    final created =
        DateTime.fromMillisecondsSinceEpoch(m['created_at']! as int);
    return MediaModel(
      id: m['id']! as String,
      localUri: m['local_uri']! as String,
      mediaType: (m['media_type']! as String) == 'video'
          ? MediaType.video
          : MediaType.image,
      fileName: m['file_name'] as String?,
      mimeType: m['mime_type'] as String?,
      capturedAt: ts(m['captured_at']),
      fileSize: m['file_size'] as int?,
      isFavorite: (m['is_favorite']! as int) == 1,
      isAvailable: (m['is_available']! as int) == 1,
      importedAt: ts(m['imported_at']) ?? created,
      createdAt: created,
      updatedAt: ts(m['updated_at']) ?? created,
      cloudPath: m['cloud_path'] as String?,
      backedUpAt: ts(m['backed_up_at']),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'local_uri': localUri,
        'file_name': fileName,
        'media_type': mediaType.name,
        'mime_type': mimeType,
        'captured_at': capturedAt?.millisecondsSinceEpoch,
        'file_size': fileSize,
        'is_favorite': isFavorite ? 1 : 0,
        'is_available': isAvailable ? 1 : 0,
        'imported_at': importedAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'cloud_path': cloudPath,
        'backed_up_at': backedUpAt?.millisecondsSinceEpoch,
      };
}
