import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/evidence.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

class EvidenceService {
  EvidenceService(this._client, this._storage);
  final SupabaseClient _client;
  final StorageService _storage;

  Future<List<Evidence>> fetchEvidence(String caseId, String userId) async {
    // Shared evidence OR uploaded by the current user
    final rows = await _client
        .from('evidence')
        .select()
        .eq('case_id', caseId)
        .or('is_shared.eq.true,uploaded_by.eq.$userId')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Evidence.fromMap(r)).toList();
  }

  Future<Evidence> fetchEvidenceById(String evidenceId) async {
    final row = await _client
        .from('evidence')
        .select()
        .eq('id', evidenceId)
        .single();
    return Evidence.fromMap(row);
  }

  /// Upload a file to storage and register the evidence record.
  Future<Evidence> uploadEvidence({
    required String caseId,
    required String uploadedBy,
    required File file,
    required String name,
    required EvidenceType type,
    required String mimeType,
    bool isShared = false,
  }) async {
    const uuid = Uuid();
    final id = uuid.v4();
    final ext = _extensionForType(type, mimeType);
    final storagePath = 'cases/$caseId/evidence/$id$ext';

    final path = await _storage.uploadFile(file, storagePath);

    final row = await _client
        .from('evidence')
        .insert({
          'id': id,
          'case_id': caseId,
          'uploaded_by': uploadedBy,
          'name': name,
          'type': type.name,
          'storage_path': path,
          'is_shared': isShared,
          'file_size_bytes': await file.length(),
          'mime_type': mimeType,
        })
        .select()
        .single();
    return Evidence.fromMap(row);
  }

  Future<void> toggleShared(String evidenceId, bool isShared) async {
    await _client
        .from('evidence')
        .update({'is_shared': isShared})
        .eq('id', evidenceId);
  }

  Future<void> deleteEvidence(Evidence evidence) async {
    await _storage.deleteFile(evidence.storagePath);
    await _client.from('evidence').delete().eq('id', evidence.id);
  }

  /// Generate a signed URL for viewing the evidence.
  Future<String> getViewUrl(Evidence evidence) {
    return _storage.getSignedUrl(evidence.storagePath);
  }

  String _extensionForType(EvidenceType type, String mimeType) {
    if (type == EvidenceType.pdf) return '.pdf';
    if (type == EvidenceType.video) {
      if (mimeType.contains('mp4')) return '.mp4';
      if (mimeType.contains('mov')) return '.mov';
      if (mimeType.contains('avi')) return '.avi';
      return '.video';
    }
    if (mimeType.contains('jpeg') || mimeType.contains('jpg')) return '.jpg';
    if (mimeType.contains('png')) return '.png';
    if (mimeType.contains('webp')) return '.webp';
    return '.img';
  }
}

final evidenceServiceProvider = Provider<EvidenceService>((ref) {
  return EvidenceService(
    ref.watch(supabaseClientProvider),
    ref.watch(storageServiceProvider),
  );
});
