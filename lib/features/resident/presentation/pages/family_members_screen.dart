import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/family_member_model.dart';
import '../../data/providers/family_member_provider.dart';
import 'add_family_member_screen.dart';

/// Family Members Screen
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersState = ref.watch(familyMemberProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Members')),
      body: membersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref
                    .read(familyMemberProvider.notifier)
                    .fetchFamilyMembers(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: DesignColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    member.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: DesignColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  member.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.relationship),
                    if (member.phone != null)
                      Text(
                        member.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: DesignColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteDialog(context, ref, member);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddFamilyMemberScreen(member: member),
                        ),
                      );
                    }
                  },
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFamilyMemberScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Member'),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    FamilyMemberModel member,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member?'),
        content: Text('Remove ${member.name} from family members?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (member.id == null || member.id!.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to remove this member'),
                    backgroundColor: DesignColors.error,
                  ),
                );
                return;
              }
              final ok = await ref
                  .read(familyMemberProvider.notifier)
                  .deleteFamilyMember(member.id!);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? '${member.name} removed' : 'Failed to remove member',
                  ),
                  backgroundColor: ok
                      ? DesignColors.success
                      : DesignColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
