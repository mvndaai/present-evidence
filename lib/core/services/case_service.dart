import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/case.dart';
import 'supabase_service.dart';

class CaseService {
  CaseService(this._client);
  final SupabaseClient _client;

  Future<List<Case>> fetchCases(String userId) async {
    final rows = await _client
        .from('cases')
        .select()
        .or('created_by.eq.$userId')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Case.fromMap(r)).toList();
  }

  Future<List<Case>> fetchCasesForTeam(String teamId) async {
    final rows = await _client
        .from('cases')
        .select()
        .eq('team_id', teamId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Case.fromMap(r)).toList();
  }

  Future<Case> fetchCase(String caseId) async {
    final row =
        await _client.from('cases').select().eq('id', caseId).single();
    return Case.fromMap(row);
  }

  Future<Case> createCase({
    required String name,
    String? description,
    String? teamId,
    required String createdBy,
  }) async {
    final row = await _client
        .from('cases')
        .insert({
          'name': name,
          'description': description,
          'team_id': teamId,
          'created_by': createdBy,
        })
        .select()
        .single();
    return Case.fromMap(row);
  }

  Future<void> updateCase(String caseId, {String? name, String? description}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    await _client.from('cases').update(updates).eq('id', caseId);
  }

  Future<void> deleteCase(String caseId) async {
    await _client.from('cases').delete().eq('id', caseId);
  }
}

final caseServiceProvider = Provider<CaseService>((ref) {
  return CaseService(ref.watch(supabaseClientProvider));
});
