import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/highlight_service.dart';
import '../../auth/providers/auth_provider.dart';

final highlightsProvider =
    FutureProvider.autoDispose.family<List<Highlight>, String>(
  (ref, evidenceId) =>
      ref.watch(highlightServiceProvider).fetchHighlights(evidenceId),
);

final caseHighlightsProvider =
    FutureProvider.autoDispose.family<List<Highlight>, String>(
  (ref, caseId) =>
      ref.watch(highlightServiceProvider).fetchHighlightsForCase(caseId),
);

class HighlightNotifier extends StateNotifier<AsyncValue<void>> {
  HighlightNotifier(this._service) : super(const AsyncValue.data(null));

  final HighlightService _service;

  Future<Highlight?> createHighlight(Highlight highlight) async {
    state = const AsyncValue.loading();
    try {
      final h = await _service.createHighlight(highlight);
      state = const AsyncValue.data(null);
      return h;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Highlight?> updateHighlight(Highlight highlight) async {
    state = const AsyncValue.loading();
    try {
      final h = await _service.updateHighlight(highlight);
      state = const AsyncValue.data(null);
      return h;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> deleteHighlight(String highlightId) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteHighlight(highlightId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final highlightNotifierProvider =
    StateNotifierProvider<HighlightNotifier, AsyncValue<void>>((ref) {
  return HighlightNotifier(ref.watch(highlightServiceProvider));
});
