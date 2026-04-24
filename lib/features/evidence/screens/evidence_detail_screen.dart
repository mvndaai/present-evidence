import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/evidence.dart';
import '../providers/evidence_provider.dart';
import '../../highlights/providers/highlight_provider.dart';
import '../widgets/evidence_viewer_widget.dart';

class EvidenceDetailScreen extends ConsumerWidget {
  const EvidenceDetailScreen({super.key, required this.evidenceId});

  final String evidenceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidenceAsync = ref.watch(evidenceItemProvider(evidenceId));

    return evidenceAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (evidence) => _EvidenceDetailView(evidence: evidence),
    );
  }
}

class _EvidenceDetailView extends ConsumerWidget {
  const _EvidenceDetailView({required this.evidence});

  final Evidence evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(highlightsProvider(evidence.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(evidence.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add Highlight',
            onPressed: () => context.go(
              '/cases/${evidence.caseId}/evidence/${evidence.id}/highlight',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: EvidenceViewerWidget(evidence: evidence),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Highlights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go(
                    '/cases/${evidence.caseId}/evidence/${evidence.id}/highlight',
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: highlightsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (highlights) {
                if (highlights.isEmpty) {
                  return const Center(
                    child: Text('No highlights yet'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: highlights.length,
                  itemBuilder: (context, index) {
                    final h = highlights[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(h.name),
                      subtitle: Text(h.typeLabel),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => context.go(
                              '/cases/${evidence.caseId}/evidence/${evidence.id}/highlight?highlightId=${h.id}',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () async {
                              await ref
                                  .read(highlightNotifierProvider.notifier)
                                  .deleteHighlight(h.id);
                              ref.invalidate(
                                  highlightsProvider(evidence.id));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
