import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/presentation_provider.dart';
import '../../auth/providers/auth_provider.dart';

class PresentationsScreen extends ConsumerWidget {
  const PresentationsScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentationsAsync = ref.watch(presentationsProvider(caseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Presentations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Presentation'),
      ),
      body: presentationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (presentations) {
          if (presentations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.slideshow_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No presentations yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Presentation'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: presentations.length,
            itemBuilder: (context, index) {
              final p = presentations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.slideshow),
                  title: Text(p.name),
                  subtitle: Text(
                      'Created ${_formatDate(p.createdAt)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'build') {
                        context.go(
                          '/cases/$caseId/presentations/${p.id}/build',
                        );
                      } else if (value == 'present_local') {
                        context.go(
                          '/cases/$caseId/presentations/${p.id}/present/local',
                        );
                      } else if (value == 'present_remote') {
                        context.go(
                          '/cases/$caseId/presentations/${p.id}/present/remote',
                        );
                      } else if (value == 'delete') {
                        await ref
                            .read(presentationNotifierProvider.notifier)
                            .deletePresentation(p.id);
                        ref.invalidate(presentationsProvider(caseId));
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'build',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'present_local',
                        child: ListTile(
                          leading: Icon(Icons.play_circle_outline),
                          title: Text('Present Locally'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'present_remote',
                        child: ListTile(
                          leading: Icon(Icons.cast_outlined),
                          title: Text('Present Remotely (WebRTC)'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Colors.red),
                          title: Text('Delete',
                              style: TextStyle(color: Colors.red)),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => context.go(
                    '/cases/$caseId/presentations/${p.id}/build',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Presentation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Presentation Name',
            hintText: 'e.g. Opening Arguments',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              final user = await ref.read(currentUserProvider.future);
              if (user == null) return;
              final p = await ref
                  .read(presentationNotifierProvider.notifier)
                  .createPresentation(
                    caseId: caseId,
                    name: name,
                    createdBy: user.id,
                  );
              ref.invalidate(presentationsProvider(caseId));
              if (p != null && context.mounted) {
                context.go(
                  '/cases/$caseId/presentations/${p.id}/build',
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
