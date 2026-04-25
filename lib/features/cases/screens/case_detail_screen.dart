import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/case_provider.dart';
import '../../evidence/providers/evidence_provider.dart';

class CaseDetailScreen extends ConsumerWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseAsync = ref.watch(caseProvider(caseId));
    final evidenceAsync = ref.watch(evidenceProvider(caseId));

    return Scaffold(
      appBar: AppBar(
        title: caseAsync.when(
          data: (c) => Text(c.name),
          loading: () => const Text('Case'),
          error: (_, __) => const Text('Case'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.slideshow),
            tooltip: 'Presentations',
            onPressed: () =>
                context.go('/cases/$caseId/presentations'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('/cases/$caseId/evidence/upload'),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Evidence'),
      ),
      body: evidenceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (evidence) {
          if (evidence.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No evidence yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Upload PDFs, videos, or images'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go('/cases/$caseId/evidence/upload'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Evidence'),
                  ),
                ],
              ),
            );
          }

          final shared = evidence.where((e) => e.isShared).toList();
          final mine = evidence.where((e) => !e.isShared).toList();

          return CustomScrollView(
            slivers: [
              if (shared.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Shared with Team',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EvidenceTile(
                      evidence: shared[i],
                      caseId: caseId,
                      ref: ref,
                    ),
                    childCount: shared.length,
                  ),
                ),
              ],
              if (mine.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'My Evidence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EvidenceTile(
                      evidence: mine[i],
                      caseId: caseId,
                      ref: ref,
                    ),
                    childCount: mine.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.evidence,
    required this.caseId,
    required this.ref,
  });

  final dynamic evidence;
  final String caseId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final icon = switch (e.type.name) {
      'video' => Icons.videocam_outlined,
      'image' => Icons.image_outlined,
      _ => Icons.picture_as_pdf_outlined,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(e.name),
        subtitle: Row(
          children: [
            Chip(
              label: Text(e.typeLabel),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            if (e.isShared)
              Chip(
                label: const Text('Shared'),
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'share') {
              await ref
                  .read(evidenceNotifierProvider.notifier)
                  .toggleShared(e.id, !e.isShared);
              ref.invalidate(evidenceProvider(caseId));
            } else if (value == 'delete') {
              await ref
                  .read(evidenceNotifierProvider.notifier)
                  .deleteEvidence(e);
              ref.invalidate(evidenceProvider(caseId));
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'share',
              child: Text(e.isShared ? 'Unshare' : 'Share with Team'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        onTap: () => context.go('/cases/$caseId/evidence/${e.id}'),
      ),
    );
  }
}
