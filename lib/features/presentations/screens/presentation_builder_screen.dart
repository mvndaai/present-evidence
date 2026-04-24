import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/evidence.dart';
import '../../../core/models/highlight.dart';
import '../../../core/models/presentation.dart';
import '../providers/presentation_provider.dart';
import '../../evidence/providers/evidence_provider.dart';
import '../../highlights/providers/highlight_provider.dart';
import '../../auth/providers/auth_provider.dart';

class PresentationBuilderScreen extends ConsumerStatefulWidget {
  const PresentationBuilderScreen({
    super.key,
    required this.presentationId,
    required this.caseId,
  });

  final String presentationId;
  final String caseId;

  @override
  ConsumerState<PresentationBuilderScreen> createState() =>
      _PresentationBuilderScreenState();
}

class _PresentationBuilderScreenState
    extends ConsumerState<PresentationBuilderScreen> {
  List<PresentationItem>? _localItems;

  @override
  Widget build(BuildContext context) {
    final itemsAsync =
        ref.watch(presentationItemsProvider(widget.presentationId));
    final evidenceAsync = ref.watch(evidenceProvider(widget.caseId));
    final highlightsAsync =
        ref.watch(caseHighlightsProvider(widget.caseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Presentation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Present Locally',
            onPressed: () => context.go(
              '/cases/${widget.caseId}/presentations/${widget.presentationId}/present/local',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cast_outlined),
            tooltip: 'Present Remotely',
            onPressed: () => context.go(
              '/cases/${widget.caseId}/presentations/${widget.presentationId}/present/remote',
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: current items in order
          Expanded(
            flex: 3,
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                _localItems ??= List.from(items);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Slide Order',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: _localItems!.isEmpty
                          ? const Center(
                              child: Text(
                                  'Add evidence or highlights from the right panel'))
                          : ReorderableListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _localItems!.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (newIndex > oldIndex) newIndex--;
                                  final item =
                                      _localItems!.removeAt(oldIndex);
                                  _localItems!.insert(newIndex, item);
                                });
                                _saveOrder();
                              },
                              itemBuilder: (context, index) {
                                final item = _localItems![index];
                                return _SlideItemCard(
                                  key: ValueKey(item.id),
                                  item: item,
                                  index: index,
                                  onDelete: () async {
                                    await ref
                                        .read(presentationNotifierProvider
                                            .notifier)
                                        .deleteItem(item.id);
                                    setState(() =>
                                        _localItems!.removeAt(index));
                                  },
                                  onEditNotes: () =>
                                      _editItemNotes(context, item, index),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

          const VerticalDivider(width: 1),

          // Right: available evidence + highlights to add
          Expanded(
            flex: 2,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Evidence'),
                      Tab(text: 'Highlights'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Evidence tab
                        evidenceAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('Error: $e')),
                          data: (evidence) => ListView.builder(
                            itemCount: evidence.length,
                            itemBuilder: (ctx, i) {
                              final ev = evidence[i];
                              return ListTile(
                                leading: Icon(_iconForEvidence(ev)),
                                title: Text(ev.name,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(ev.typeLabel),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () =>
                                      _addEvidenceItem(ev),
                                ),
                              );
                            },
                          ),
                        ),

                        // Highlights tab
                        highlightsAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('Error: $e')),
                          data: (highlights) => ListView.builder(
                            itemCount: highlights.length,
                            itemBuilder: (ctx, i) {
                              final h = highlights[i];
                              return ListTile(
                                leading: const Icon(
                                    Icons.bookmark_outline),
                                title: Text(h.name,
                                    style: const TextStyle(fontSize: 13)),
                                subtitle: Text(h.typeLabel),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () =>
                                      _addHighlightItem(h),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForEvidence(Evidence ev) {
    switch (ev.type) {
      case EvidenceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case EvidenceType.video:
        return Icons.videocam_outlined;
      case EvidenceType.image:
        return Icons.image_outlined;
    }
  }

  Future<void> _addEvidenceItem(Evidence evidence) async {
    final item = PresentationItem(
      id: const Uuid().v4(),
      presentationId: widget.presentationId,
      orderIndex: _localItems?.length ?? 0,
      evidenceId: evidence.id,
    );
    final saved = await ref
        .read(presentationNotifierProvider.notifier)
        .addItem(item);
    if (saved != null) {
      setState(() => _localItems = [...?_localItems, saved]);
    }
  }

  Future<void> _addHighlightItem(Highlight highlight) async {
    final item = PresentationItem(
      id: const Uuid().v4(),
      presentationId: widget.presentationId,
      orderIndex: _localItems?.length ?? 0,
      highlightId: highlight.id,
    );
    final saved = await ref
        .read(presentationNotifierProvider.notifier)
        .addItem(item);
    if (saved != null) {
      setState(() => _localItems = [...?_localItems, saved]);
    }
  }

  Future<void> _saveOrder() async {
    if (_localItems == null) return;
    final reordered = _localItems!
        .asMap()
        .entries
        .map((e) => e.value.copyWith(orderIndex: e.key))
        .toList();
    await ref
        .read(presentationNotifierProvider.notifier)
        .reorderItems(reordered);
  }

  void _editItemNotes(
      BuildContext context, PresentationItem item, int index) {
    final notesController =
        TextEditingController(text: item.presenterNotes);
    final commentController =
        TextEditingController(text: item.publicComment);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Slide Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Presenter Notes (private)',
                hintText: 'These are only visible to you',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Public Comment',
                hintText: 'Shown between this and the next slide',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final updated = item.copyWith(
                presenterNotes: notesController.text.isEmpty
                    ? null
                    : notesController.text,
                publicComment: commentController.text.isEmpty
                    ? null
                    : commentController.text,
                clearNotes: notesController.text.isEmpty,
                clearComment: commentController.text.isEmpty,
              );
              await ref
                  .read(presentationNotifierProvider.notifier)
                  .updateItem(updated);
              setState(() => _localItems![index] = updated);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SlideItemCard extends ConsumerWidget {
  const _SlideItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onDelete,
    required this.onEditNotes,
  });

  final PresentationItem item;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onEditNotes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHighlight = item.highlightId != null;
    final label = isHighlight
        ? 'Highlight'
        : 'Evidence';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Row(
          children: [
            Icon(
              isHighlight ? Icons.bookmark : Icons.attachment,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.presenterNotes != null)
              Text(
                '📝 ${item.presenterNotes}',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            if (item.publicComment != null)
              Text(
                '💬 ${item.publicComment}',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.notes_outlined),
              onPressed: onEditNotes,
              tooltip: 'Edit Notes',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}
