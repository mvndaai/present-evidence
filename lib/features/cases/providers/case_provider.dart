import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/case.dart';
import '../../../core/services/case_service.dart';
import '../../auth/providers/auth_provider.dart';

final casesProvider = FutureProvider.autoDispose<List<Case>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(caseServiceProvider).fetchCases(user.id);
});

final caseProvider =
    FutureProvider.autoDispose.family<Case, String>((ref, caseId) {
  return ref.watch(caseServiceProvider).fetchCase(caseId);
});

class CaseNotifier extends StateNotifier<AsyncValue<void>> {
  CaseNotifier(this._service) : super(const AsyncValue.data(null));

  final CaseService _service;

  Future<Case?> createCase({
    required String name,
    String? description,
    String? teamId,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final c = await _service.createCase(
        name: name,
        description: description,
        teamId: teamId,
        createdBy: createdBy,
      );
      state = const AsyncValue.data(null);
      return c;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateCase(String caseId,
      {String? name, String? description}) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateCase(caseId, name: name, description: description);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCase(String caseId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteCase(caseId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final caseNotifierProvider =
    StateNotifierProvider<CaseNotifier, AsyncValue<void>>((ref) {
  return CaseNotifier(ref.watch(caseServiceProvider));
});
