import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/presentation.dart';
import 'supabase_service.dart';

class PresentationService {
  PresentationService(this._client);
  final SupabaseClient _client;

  Future<List<Presentation>> fetchPresentations(String caseId) async {
    final rows = await _client
        .from('presentations')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Presentation.fromMap(r)).toList();
  }

  Future<Presentation> fetchPresentation(String id) async {
    final row = await _client
        .from('presentations')
        .select()
        .eq('id', id)
        .single();
    return Presentation.fromMap(row);
  }

  Future<Presentation> createPresentation({
    required String caseId,
    required String name,
    required String createdBy,
  }) async {
    const uuid = Uuid();
    final row = await _client
        .from('presentations')
        .insert({
          'id': uuid.v4(),
          'case_id': caseId,
          'name': name,
          'created_by': createdBy,
        })
        .select()
        .single();
    return Presentation.fromMap(row);
  }

  Future<void> updatePresentation(String id, String name) async {
    await _client.from('presentations').update({'name': name}).eq('id', id);
  }

  Future<void> deletePresentation(String id) async {
    await _client.from('presentations').delete().eq('id', id);
  }

  // ---------- Items ----------

  Future<List<PresentationItem>> fetchItems(String presentationId) async {
    final rows = await _client
        .from('presentation_items')
        .select()
        .eq('presentation_id', presentationId)
        .order('order_index');
    return (rows as List).map((r) => PresentationItem.fromMap(r)).toList();
  }

  Future<PresentationItem> addItem(PresentationItem item) async {
    const uuid = Uuid();
    final map = item.toMap();
    map['id'] = uuid.v4();
    final row = await _client
        .from('presentation_items')
        .insert(map)
        .select()
        .single();
    return PresentationItem.fromMap(row);
  }

  Future<PresentationItem> updateItem(PresentationItem item) async {
    final row = await _client
        .from('presentation_items')
        .update(item.toMap())
        .eq('id', item.id)
        .select()
        .single();
    return PresentationItem.fromMap(row);
  }

  Future<void> deleteItem(String itemId) async {
    await _client.from('presentation_items').delete().eq('id', itemId);
  }

  /// Reorder all items by writing new order_index values.
  Future<void> reorderItems(List<PresentationItem> items) async {
    for (var i = 0; i < items.length; i++) {
      await _client
          .from('presentation_items')
          .update({'order_index': i})
          .eq('id', items[i].id);
    }
  }
}

final presentationServiceProvider = Provider<PresentationService>((ref) {
  return PresentationService(ref.watch(supabaseClientProvider));
});
