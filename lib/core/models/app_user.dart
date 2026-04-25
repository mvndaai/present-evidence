class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: map['display_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
  }) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
      );
}
