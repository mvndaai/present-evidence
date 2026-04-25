import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/team.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamService {
  TeamService(this._client);
  final SupabaseClient _client;

  Future<List<Team>> fetchTeams(String userId) async {
    // Get teams the user belongs to
    final memberRows = await _client
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId);
    final teamIds =
        (memberRows as List).map((r) => r['team_id'] as String).toList();

    if (teamIds.isEmpty) return [];

    final rows = await _client
        .from('teams')
        .select()
        .inFilter('id', teamIds)
        .order('created_at');
    return (rows as List).map((r) => Team.fromMap(r)).toList();
  }

  Future<Team> createTeam(String name, String creatorId) async {
    final row = await _client
        .from('teams')
        .insert({'name': name, 'created_by': creatorId})
        .select()
        .single();
    final team = Team.fromMap(row);

    // Creator is automatically an admin member
    await _client.from('team_members').insert({
      'team_id': team.id,
      'user_id': creatorId,
      'role': 'admin',
    });

    return team;
  }

  Future<void> updateTeam(String teamId, String name) async {
    await _client.from('teams').update({'name': name}).eq('id', teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    await _client.from('teams').delete().eq('id', teamId);
  }

  Future<List<TeamMember>> fetchMembers(String teamId) async {
    final rows = await _client
        .from('team_members')
        .select('*, users(*)')
        .eq('team_id', teamId);
    return (rows as List).map((r) => TeamMember.fromMap(r)).toList();
  }

  Future<void> addMember(
      String teamId, String userId, TeamMemberRole role) async {
    await _client.from('team_members').insert({
      'team_id': teamId,
      'user_id': userId,
      'role': role == TeamMemberRole.admin ? 'admin' : 'member',
    });
  }

  Future<void> updateMemberRole(
      String teamId, String userId, TeamMemberRole role) async {
    await _client
        .from('team_members')
        .update({'role': role == TeamMemberRole.admin ? 'admin' : 'member'})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  Future<void> removeMember(String teamId, String userId) async {
    await _client
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  Future<bool> isAdmin(String teamId, String userId) async {
    final row = await _client
        .from('team_members')
        .select('role')
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null && row['role'] == 'admin';
  }
}

final teamServiceProvider = Provider<TeamService>((ref) {
  return TeamService(ref.watch(supabaseClientProvider));
});
