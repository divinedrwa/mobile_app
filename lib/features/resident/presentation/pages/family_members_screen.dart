import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/family_member_model.dart';
import '../../data/providers/family_member_provider.dart';
import '../widgets/list_skeleton.dart';
import 'add_family_member_screen.dart';

/// Family Members Screen
class FamilyMembersScreen extends ConsumerWidget {
  const FamilyMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersState = ref.watch(familyMemberProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Members')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(familyMemberProvider.notifier).fetchFamilyMembers(),
        child: membersState.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.family_restroom_rounded,
            title: 'Could not load family members',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(familyMemberProvider.notifier).fetchFamilyMembers(),
          ),
        )]),
        data: (members) {
          if (members.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [EmptyStateWidget(
              icon: Icons.family_restroom_rounded,
              title: 'No family members yet',
              subtitle:
                  'Add household members so their details are available across resident features.',
            )]);
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              context.spacing.s16,
              context.spacing.s12,
              context.spacing.s16,
              context.spacing.s32,
            ),
            children: [
              EnterprisePanel(
                tone: EnterpriseTone.info,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage everyone linked to your home',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.text.primary,
                          ),
                    ),
                    SizedBox(height: context.spacing.s8),
                    Text(
                      'Keep resident access, contact numbers, and household records accurate for society operations.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.text.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.s24),
              EnterpriseSectionHeader(
                title: 'Household directory',
                subtitle:
                    '${members.length} ${members.length == 1 ? 'member' : 'members'} on file',
              ),
              SizedBox(height: context.spacing.s12),
              for (int index = 0; index < members.length; index++)
                _FamilyMemberCard(
                  member: members[index],
                  onDelete: () => _showDeleteDialog(context, ref, members[index]),
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddFamilyMemberScreen(member: members[index]),
                      ),
                    );
                  },
                ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms),
            ],
          );
        },
      )),
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
              final error = await ref
                  .read(familyMemberProvider.notifier)
                  .deleteFamilyMember(member.id!);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    error ?? '${member.name} removed',
                  ),
                  backgroundColor: error == null
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

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  final FamilyMemberModel member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final phone = member.phone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: context.surface.elevated,
              child: Text(
                member.name.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.brand.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    member.relationship,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                  if (hasPhone) ...[
                    SizedBox(height: context.spacing.s4),
                    Text(
                      phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.text.secondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Member actions',
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                } else {
                  onEdit();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
