import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/evidence.dart';
import '../../../core/services/evidence_service.dart';
import '../../auth/providers/auth_provider.dart';

final evidenceProvider =
    FutureProvider.autoDispose.family<List<Evidence>, String>(
  (ref, caseId) async {
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    return ref.watch(evidenceServiceProvider).fetchEvidence(caseId, user.id);
  },
);

final evidenceItemProvider =
    FutureProvider.autoDispose.family<Evidence, String>(
  (ref, evidenceId) =>
      ref.watch(evidenceServiceProvider).fetchEvidenceById(evidenceId),
);

final evidenceUrlProvider =
    FutureProvider.autoDispose.family<String, Evidence>(
  (ref, evidence) =>
      ref.watch(evidenceServiceProvider).getViewUrl(evidence),
);

class EvidenceNotifier extends StateNotifier<AsyncValue<void>> {
  EvidenceNotifier(this._service) : super(const AsyncValue.data(null));

  final EvidenceService _service;

  Future<Evidence?> upload({
    required String caseId,
    required String uploadedBy,
    required dynamic file,
    required String name,
    required EvidenceType type,
    required String mimeType,
    bool isShared = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final evidence = await _service.uploadEvidence(
        caseId: caseId,
        uploadedBy: uploadedBy,
        file: file,
        name: name,
        type: type,
        mimeType: mimeType,
        isShared: isShared,
      );
      state = const AsyncValue.data(null);
      return evidence;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> toggleShared(String evidenceId, bool isShared) async {
    state = const AsyncValue.loading();
    try {
      await _service.toggleShared(evidenceId, isShared);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteEvidence(Evidence evidence) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteEvidence(evidence);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final evidenceNotifierProvider =
    StateNotifierProvider<EvidenceNotifier, AsyncValue<void>>((ref) {
  return EvidenceNotifier(ref.watch(evidenceServiceProvider));
});
