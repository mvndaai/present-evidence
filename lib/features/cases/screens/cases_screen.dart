import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/case_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/case.dart';

class CasesScreen extends ConsumerWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Teams',
            onPressed: () => context.go('/teams'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCaseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Case'),
      ),
      body: casesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cases) {
          if (cases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No cases yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create your first case to get started'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateCaseDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Case'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              final c = cases[index];
              return _CaseCard(
                legalCase: c,
                onTap: () => context.go('/cases/${c.id}'),
                onDelete: () async {
                  final confirm = await _confirmDelete(context);
                  if (!confirm) return;
                  await ref
                      .read(caseNotifierProvider.notifier)
                      .deleteCase(c.id);
                  ref.invalidate(casesProvider);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Case'),
            content: const Text(
                'Are you sure? This will delete all evidence and presentations.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showCreateCaseDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Case Name',
                hintText: 'e.g. State v. Smith 2024',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
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
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(dialogContext).pop();
              final user = await ref.read(currentUserProvider.future);
              if (user == null) return;
              final c = await ref.read(caseNotifierProvider.notifier).createCase(
                    name: name,
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    createdBy: user.id,
                  );
              ref.invalidate(casesProvider);
              if (c != null && context.mounted) {
                context.go('/cases/${c.id}');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({
    required this.legalCase,
    required this.onTap,
    required this.onDelete,
  });

  final Case legalCase;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      legalCase.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (legalCase.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        legalCase.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Theme.of(context).colorScheme.error,
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
