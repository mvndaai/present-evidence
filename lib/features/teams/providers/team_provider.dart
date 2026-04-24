import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/team.dart';
import '../../../core/services/team_service.dart';
import '../../auth/providers/auth_provider.dart';

final teamsProvider = FutureProvider.autoDispose<List<Team>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(teamServiceProvider).fetchTeams(user.id);
});

final teamMembersProvider =
    FutureProvider.autoDispose.family<List<TeamMember>, String>(
  (ref, teamId) => ref.watch(teamServiceProvider).fetchMembers(teamId),
);

class TeamNotifier extends StateNotifier<AsyncValue<void>> {
  TeamNotifier(this._service) : super(const AsyncValue.data(null));

  final TeamService _service;

  Future<Team?> createTeam(String name, String creatorId) async {
    state = const AsyncValue.loading();
    try {
      final team = await _service.createTeam(name, creatorId);
      state = const AsyncValue.data(null);
      return team;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateTeam(String teamId, String name) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateTeam(teamId, name);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTeam(String teamId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteTeam(teamId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMember(
      String teamId, String userId, TeamMemberRole role) async {
    state = const AsyncValue.loading();
    try {
      await _service.addMember(teamId, userId, role);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removeMember(String teamId, String userId) async {
    state = const AsyncValue.loading();
    try {
      await _service.removeMember(teamId, userId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMemberRole(
      String teamId, String userId, TeamMemberRole role) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateMemberRole(teamId, userId, role);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final teamNotifierProvider =
    StateNotifierProvider<TeamNotifier, AsyncValue<void>>((ref) {
  return TeamNotifier(ref.watch(teamServiceProvider));
});
