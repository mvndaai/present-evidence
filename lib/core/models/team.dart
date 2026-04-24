import 'app_user.dart';

enum TeamMemberRole { admin, member }

class Team {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        id: map['id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  Team copyWith({String? name}) => Team(
        id: id,
        name: name ?? this.name,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

class TeamMember {
  final String teamId;
  final String userId;
  final TeamMemberRole role;
  final DateTime joinedAt;
  final AppUser? user;

  const TeamMember({
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.user,
  });

  factory TeamMember.fromMap(Map<String, dynamic> map) => TeamMember(
        teamId: map['team_id'] as String,
        userId: map['user_id'] as String,
        role: map['role'] == 'admin'
            ? TeamMemberRole.admin
            : TeamMemberRole.member,
        joinedAt: DateTime.parse(map['joined_at'] as String),
        user: map['users'] != null
            ? AppUser.fromMap(map['users'] as Map<String, dynamic>)
            : null,
      );

  bool get isAdmin => role == TeamMemberRole.admin;
}
