import 'dart:ui';

/// A rectangular region expressed as fractional coordinates [0..1]
/// relative to the source content dimensions.
class ZoomRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const ZoomRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory ZoomRegion.fromMap(Map<String, dynamic> map) => ZoomRegion(
        left: (map['left'] as num).toDouble(),
        top: (map['top'] as num).toDouble(),
        right: (map['right'] as num).toDouble(),
        bottom: (map['bottom'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  Rect toRect(Size contentSize) => Rect.fromLTRB(
        left * contentSize.width,
        top * contentSize.height,
        right * contentSize.width,
        bottom * contentSize.height,
      );

  /// Returns the aspect ratio of the zoom region (width / height).
  double get aspectRatio =>
      (right - left).abs() / ((bottom - top).abs().clamp(0.0001, 1.0));

  ZoomRegion copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) =>
      ZoomRegion(
        left: left ?? this.left,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );
}

enum HighlightType {
  /// A rectangular zoom region on an image or a single PDF page.
  imageZoom,

  /// One or more pages of a PDF, optionally with a zoom region.
  pdfPages,

  /// A time-range clip from a video, optionally with a zoom region.
  videoClip,
}

class Highlight {
  final String id;
  final String evidenceId;
  final String name;
  final HighlightType type;

  // Video clip fields
  final Duration? clipStart;
  final Duration? clipEnd;

  // PDF fields
  final int? startPage;
  final int? endPage;

  // Zoom region (applies to all types when set)
  final ZoomRegion? zoomRegion;

  final DateTime createdAt;
  final String createdBy;

  const Highlight({
    required this.id,
    required this.evidenceId,
    required this.name,
    required this.type,
    this.clipStart,
    this.clipEnd,
    this.startPage,
    this.endPage,
    this.zoomRegion,
    required this.createdAt,
    required this.createdBy,
  });

  factory Highlight.fromMap(Map<String, dynamic> map) {
    ZoomRegion? zoom;
    if (map['zoom_region'] != null) {
      zoom = ZoomRegion.fromMap(
          Map<String, dynamic>.from(map['zoom_region'] as Map));
    }
    return Highlight(
      id: map['id'] as String,
      evidenceId: map['evidence_id'] as String,
      name: map['name'] as String,
      type: _parseType(map['type'] as String),
      clipStart: map['clip_start_ms'] != null
          ? Duration(milliseconds: map['clip_start_ms'] as int)
          : null,
      clipEnd: map['clip_end_ms'] != null
          ? Duration(milliseconds: map['clip_end_ms'] as int)
          : null,
      startPage: map['start_page'] as int?,
      endPage: map['end_page'] as int?,
      zoomRegion: zoom,
      createdAt: DateTime.parse(map['created_at'] as String),
      createdBy: map['created_by'] as String,
    );
  }

  static HighlightType _parseType(String t) {
    switch (t) {
      case 'videoClip':
        return HighlightType.videoClip;
      case 'pdfPages':
        return HighlightType.pdfPages;
      default:
        return HighlightType.imageZoom;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'evidence_id': evidenceId,
        'name': name,
        'type': type.name,
        'clip_start_ms': clipStart?.inMilliseconds,
        'clip_end_ms': clipEnd?.inMilliseconds,
        'start_page': startPage,
        'end_page': endPage,
        'zoom_region': zoomRegion?.toMap(),
        'created_at': createdAt.toIso8601String(),
        'created_by': createdBy,
      };

  Highlight copyWith({
    String? name,
    Duration? clipStart,
    Duration? clipEnd,
    int? startPage,
    int? endPage,
    ZoomRegion? zoomRegion,
    bool clearZoom = false,
  }) =>
      Highlight(
        id: id,
        evidenceId: evidenceId,
        name: name ?? this.name,
        type: type,
        clipStart: clipStart ?? this.clipStart,
        clipEnd: clipEnd ?? this.clipEnd,
        startPage: startPage ?? this.startPage,
        endPage: endPage ?? this.endPage,
        zoomRegion: clearZoom ? null : (zoomRegion ?? this.zoomRegion),
        createdAt: createdAt,
        createdBy: createdBy,
      );

  String get typeLabel {
    switch (type) {
      case HighlightType.imageZoom:
        return 'Image Zoom';
      case HighlightType.pdfPages:
        return 'PDF Pages';
      case HighlightType.videoClip:
        return 'Video Clip';
    }
  }
}
