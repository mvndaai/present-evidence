import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/team_provider.dart';
import '../../auth/providers/auth_provider.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Team',
            onPressed: () => _showCreateTeamDialog(context, ref),
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (teams) {
          if (teams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No teams yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Create a team to collaborate with colleagues'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateTeamDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Team'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(team.name.isEmpty
                        ? '?'
                        : team.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(team.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/teams/${team.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Team'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Team Name',
            hintText: 'e.g. Defense Team Alpha',
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
              await ref
                  .read(teamNotifierProvider.notifier)
                  .createTeam(name, user.id);
              ref.invalidate(teamsProvider);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
