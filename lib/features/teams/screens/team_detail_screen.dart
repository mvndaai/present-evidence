import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/team.dart';
import '../providers/team_provider.dart';
import '../../auth/providers/auth_provider.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider(teamId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Member',
            onPressed: () =>
                _showAddMemberDialog(context, ref, currentUserId),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members found'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentUser = member.userId == currentUserId;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      () {
                        final raw = member.user?.displayName ??
                            member.user?.email ??
                            '?';
                        return raw.isEmpty
                            ? '?'
                            : raw.substring(0, 1).toUpperCase();
                      }(),
                    ),
                  ),
                  title: Text(
                    member.user?.displayName ??
                        member.user?.email ??
                        member.userId,
                  ),
                  subtitle: Text(member.isAdmin ? 'Admin' : 'Member'),
                  trailing: isCurrentUser
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) async {
                            final notifier =
                                ref.read(teamNotifierProvider.notifier);
                            if (value == 'make_admin') {
                              await notifier.updateMemberRole(
                                  teamId,
                                  member.userId,
                                  TeamMemberRole.admin);
                            } else if (value == 'make_member') {
                              await notifier.updateMemberRole(
                                  teamId,
                                  member.userId,
                                  TeamMemberRole.member);
                            } else if (value == 'remove') {
                              await notifier.removeMember(
                                  teamId, member.userId);
                            }
                            ref.invalidate(teamMembersProvider(teamId));
                          },
                          itemBuilder: (ctx) => [
                            if (!member.isAdmin)
                              const PopupMenuItem(
                                value: 'make_admin',
                                child: Text('Make Admin'),
                              ),
                            if (member.isAdmin)
                              const PopupMenuItem(
                                value: 'make_member',
                                child: Text('Make Member'),
                              ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                'Remove',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMemberDialog(
      BuildContext context, WidgetRef ref, String currentUserId) {
    final emailController = TextEditingController();
    TeamMemberRole selectedRole = TeamMemberRole.member;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'User Email or ID',
                  hintText: 'Enter user email',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TeamMemberRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                    value: TeamMemberRole.member,
                    child: Text('Member'),
                  ),
                  DropdownMenuItem(
                    value: TeamMemberRole.admin,
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (r) {
                  if (r != null) setState(() => selectedRole = r);
                },
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
                final input = emailController.text.trim();
                if (input.isEmpty) return;

                // Look up user by email
                final client = Supabase.instance.client;
                final rows = await client
                    .from('users')
                    .select('id')
                    .eq('email', input)
                    .maybeSingle();

                if (!dialogContext.mounted) return;
                if (rows == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('User not found')),
                  );
                  return;
                }
                final userId = rows['id'] as String;
                Navigator.of(dialogContext).pop();
                await ref
                    .read(teamNotifierProvider.notifier)
                    .addMember(teamId, userId, selectedRole);
                ref.invalidate(teamMembersProvider(teamId));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
