import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/highlight.dart';
import 'supabase_service.dart';

class HighlightService {
  HighlightService(this._client);
  final SupabaseClient _client;

  Future<List<Highlight>> fetchHighlights(String evidenceId) async {
    final rows = await _client
        .from('highlights')
        .select()
        .eq('evidence_id', evidenceId)
        .order('created_at');
    return (rows as List).map((r) => Highlight.fromMap(r)).toList();
  }

  Future<List<Highlight>> fetchHighlightsForCase(String caseId) async {
    // Join via evidence table
    final rows = await _client
        .from('highlights')
        .select('*, evidence!inner(case_id)')
        .eq('evidence.case_id', caseId)
        .order('created_at');
    return (rows as List).map((r) => Highlight.fromMap(r)).toList();
  }

  Future<Highlight> createHighlight(Highlight highlight) async {
    const uuid = Uuid();
    final map = highlight.toMap();
    map['id'] = uuid.v4();
    final row =
        await _client.from('highlights').insert(map).select().single();
    return Highlight.fromMap(row);
  }

  Future<Highlight> updateHighlight(Highlight highlight) async {
    final row = await _client
        .from('highlights')
        .update(highlight.toMap())
        .eq('id', highlight.id)
        .select()
        .single();
    return Highlight.fromMap(row);
  }

  Future<void> deleteHighlight(String highlightId) async {
    await _client.from('highlights').delete().eq('id', highlightId);
  }
}

final highlightServiceProvider = Provider<HighlightService>((ref) {
  return HighlightService(ref.watch(supabaseClientProvider));
});
