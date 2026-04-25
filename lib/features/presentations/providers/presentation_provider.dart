import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/presentation.dart';
import '../../../core/services/presentation_service.dart';
import '../../auth/providers/auth_provider.dart';

final presentationsProvider =
    FutureProvider.autoDispose.family<List<Presentation>, String>(
  (ref, caseId) =>
      ref.watch(presentationServiceProvider).fetchPresentations(caseId),
);

final presentationProvider =
    FutureProvider.autoDispose.family<Presentation, String>(
  (ref, presentationId) =>
      ref.watch(presentationServiceProvider).fetchPresentation(presentationId),
);

final presentationItemsProvider =
    FutureProvider.autoDispose.family<List<PresentationItem>, String>(
  (ref, presentationId) =>
      ref.watch(presentationServiceProvider).fetchItems(presentationId),
);

class PresentationNotifier extends StateNotifier<AsyncValue<void>> {
  PresentationNotifier(this._service) : super(const AsyncValue.data(null));

  final PresentationService _service;

  Future<Presentation?> createPresentation({
    required String caseId,
    required String name,
    required String createdBy,
  }) async {
    state = const AsyncValue.loading();
    try {
      final p = await _service.createPresentation(
        caseId: caseId,
        name: name,
        createdBy: createdBy,
      );
      state = const AsyncValue.data(null);
      return p;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deletePresentation(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.deletePresentation(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<PresentationItem?> addItem(PresentationItem item) async {
    state = const AsyncValue.loading();
    try {
      final i = await _service.addItem(item);
      state = const AsyncValue.data(null);
      return i;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<PresentationItem?> updateItem(PresentationItem item) async {
    state = const AsyncValue.loading();
    try {
      final i = await _service.updateItem(item);
      state = const AsyncValue.data(null);
      return i;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteItem(String itemId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteItem(itemId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reorderItems(List<PresentationItem> items) async {
    state = const AsyncValue.loading();
    try {
      await _service.reorderItems(items);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final presentationNotifierProvider =
    StateNotifierProvider<PresentationNotifier, AsyncValue<void>>((ref) {
  return PresentationNotifier(ref.watch(presentationServiceProvider));
});
