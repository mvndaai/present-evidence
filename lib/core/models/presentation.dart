class Presentation {
  final String id;
  final String caseId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const Presentation({
    required this.id,
    required this.caseId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Presentation.fromMap(Map<String, dynamic> map) => Presentation(
        id: map['id'] as String,
        caseId: map['case_id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'case_id': caseId,
        'name': name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  Presentation copyWith({String? name}) => Presentation(
        id: id,
        caseId: caseId,
        name: name ?? this.name,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

/// A single item inside a presentation (either raw evidence or a highlight).
class PresentationItem {
  final String id;
  final String presentationId;
  final int orderIndex;
  final String? evidenceId;
  final String? highlightId;

  /// Private presenter notes – not shown to audience.
  final String? presenterNotes;

  /// Public comment shown between this item and the next.
  final String? publicComment;

  const PresentationItem({
    required this.id,
    required this.presentationId,
    required this.orderIndex,
    this.evidenceId,
    this.highlightId,
    this.presenterNotes,
    this.publicComment,
  });

  factory PresentationItem.fromMap(Map<String, dynamic> map) => PresentationItem(
        id: map['id'] as String,
        presentationId: map['presentation_id'] as String,
        orderIndex: map['order_index'] as int,
        evidenceId: map['evidence_id'] as String?,
        highlightId: map['highlight_id'] as String?,
        presenterNotes: map['presenter_notes'] as String?,
        publicComment: map['public_comment'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'presentation_id': presentationId,
        'order_index': orderIndex,
        'evidence_id': evidenceId,
        'highlight_id': highlightId,
        'presenter_notes': presenterNotes,
        'public_comment': publicComment,
      };

  PresentationItem copyWith({
    int? orderIndex,
    String? presenterNotes,
    String? publicComment,
    bool clearNotes = false,
    bool clearComment = false,
  }) =>
      PresentationItem(
        id: id,
        presentationId: presentationId,
        orderIndex: orderIndex ?? this.orderIndex,
        evidenceId: evidenceId,
        highlightId: highlightId,
        presenterNotes: clearNotes ? null : (presenterNotes ?? this.presenterNotes),
        publicComment: clearComment ? null : (publicComment ?? this.publicComment),
      );
}
