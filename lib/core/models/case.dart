class Case {
  final String id;
  final String name;
  final String? description;
  final String? teamId;
  final String createdBy;
  final DateTime createdAt;

  const Case({
    required this.id,
    required this.name,
    this.description,
    this.teamId,
    required this.createdBy,
    required this.createdAt,
  });

  factory Case.fromMap(Map<String, dynamic> map) => Case(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        teamId: map['team_id'] as String?,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'team_id': teamId,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  Case copyWith({
    String? name,
    String? description,
    String? teamId,
  }) =>
      Case(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        teamId: teamId ?? this.teamId,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
