enum EvidenceType { pdf, video, image }

class Evidence {
  final String id;
  final String caseId;
  final String uploadedBy;
  final String name;
  final EvidenceType type;
  final String storagePath;
  final String? thumbnailPath;
  final bool isShared;
  final int? fileSizeBytes;
  final String? mimeType;
  final DateTime createdAt;

  const Evidence({
    required this.id,
    required this.caseId,
    required this.uploadedBy,
    required this.name,
    required this.type,
    required this.storagePath,
    this.thumbnailPath,
    required this.isShared,
    this.fileSizeBytes,
    this.mimeType,
    required this.createdAt,
  });

  factory Evidence.fromMap(Map<String, dynamic> map) => Evidence(
        id: map['id'] as String,
        caseId: map['case_id'] as String,
        uploadedBy: map['uploaded_by'] as String,
        name: map['name'] as String,
        type: _parseType(map['type'] as String),
        storagePath: map['storage_path'] as String,
        thumbnailPath: map['thumbnail_path'] as String?,
        isShared: map['is_shared'] as bool? ?? false,
        fileSizeBytes: map['file_size_bytes'] as int?,
        mimeType: map['mime_type'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  static EvidenceType _parseType(String type) {
    switch (type) {
      case 'video':
        return EvidenceType.video;
      case 'image':
        return EvidenceType.image;
      default:
        return EvidenceType.pdf;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'uploaded_by': uploadedBy,
        'name': name,
        'type': type.name,
        'storage_path': storagePath,
        'thumbnail_path': thumbnailPath,
        'is_shared': isShared,
        'file_size_bytes': fileSizeBytes,
        'mime_type': mimeType,
        'created_at': createdAt.toIso8601String(),
      };

  Evidence copyWith({
    String? name,
    bool? isShared,
    String? thumbnailPath,
  }) =>
      Evidence(
        id: id,
        caseId: caseId,
        uploadedBy: uploadedBy,
        name: name ?? this.name,
        type: type,
        storagePath: storagePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        isShared: isShared ?? this.isShared,
        fileSizeBytes: fileSizeBytes,
        mimeType: mimeType,
        createdAt: createdAt,
      );

  String get typeLabel {
    switch (type) {
      case EvidenceType.pdf:
        return 'PDF';
      case EvidenceType.video:
        return 'Video';
      case EvidenceType.image:
        return 'Image';
    }
  }
}
