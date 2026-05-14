import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/complaint_provider.dart';
import '../widgets/list_skeleton.dart';

/// Lists complaints from GET /residents/my-complaints (replaces former mock screen).
class MyComplaintsScreen extends ConsumerWidget {
  const MyComplaintsScreen({super.key});

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return DesignColors.success;
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'OPEN':
      default:
        return DesignColors.primary;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'In progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'OPEN':
        return 'Open';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myComplaintsProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: context.text.primary),
        ),
        title: Text(
          'My Complaints',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.text.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New complaint',
            onPressed: () => context.push('/resident/complaint'),
            icon: const Icon(Icons.add_circle_outline, color: DesignColors.primary),
          ),
        ],
      ),
      body: async.when(
        loading: () => const ListSkeleton(),
        error: (err, _) => Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.report_problem_outlined,
            title: 'Could not load complaints',
            message: err.toString(),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(myComplaintsProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.check_circle_outline_rounded,
              title: 'No complaints filed',
              subtitle: 'That\'s a good sign! If something comes up, you can file a complaint from the home screen.',
              iconColor: DesignColors.success,
              actionLabel: 'File a complaint',
              onAction: () => context.push('/resident/complaint'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myComplaintsProvider);
              await ref.read(myComplaintsProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                context.spacing.s16,
                context.spacing.s16,
                context.spacing.s16,
                context.spacing.s32,
              ),
              children: [
                const EnterpriseInfoBanner(
                  icon: Icons.assignment_outlined,
                  title: 'Track service issues clearly',
                  message:
                      'Review what has been filed, what is being worked on, and what has already been resolved.',
                  tone: EnterpriseTone.info,
                ),
                SizedBox(height: context.spacing.s24),
                EnterpriseSectionHeader(
                  title: 'Complaint history',
                  subtitle:
                      '${items.length} ${items.length == 1 ? 'issue' : 'issues'} recorded for your home',
                ),
                SizedBox(height: context.spacing.s12),
                for (int index = 0; index < items.length; index++)
                  _ComplaintCard(
                    item: items[index],
                    color: _statusColor(items[index].status),
                    statusLabel: _statusLabel(items[index].status),
                  ).animate().fadeIn(
                        duration: 250.ms,
                        delay: DesignAnimations.staggerFor(index),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.item,
    required this.color,
    required this.statusLabel,
  });

  final dynamic item;
  final Color color;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.report_problem_outlined, color: color),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    item.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(item.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.sm),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
