import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/complaint_list_item.dart';
import '../../data/providers/complaint_provider.dart';

/// Resident complaint detail from GET /residents/complaints/:id.
class ComplaintDetailScreen extends ConsumerWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});

  final String complaintId;

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
      case 'CLOSED':
        return DesignColors.success;
      case 'IN_PROGRESS':
        return DesignColors.warning;
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
      case 'CLOSED':
        return 'Closed';
      case 'OPEN':
        return 'Open';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(complaintDetailProvider(complaintId));

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: context.text.primary),
        ),
        title: Text(
          'Complaint details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: context.text.primary,
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const DetailSkeleton(heroHeight: 120),
        error: (e, _) => Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.report_problem_outlined,
            title: 'Could not load complaint',
            message: e.toString(),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(complaintDetailProvider(complaintId)),
          ),
        ),
        data: (complaint) => _Body(complaint: complaint),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.complaint});

  final ComplaintListItem complaint;

  @override
  Widget build(BuildContext context) {
    final color = ComplaintDetailScreen._statusColor(complaint.status);
    final statusLabel = ComplaintDetailScreen._statusLabel(complaint.status);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EnterprisePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        complaint.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.text.primary,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                SizedBox(height: context.spacing.s12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(context, Icons.category_outlined, complaint.category),
                    if (complaint.priority != null &&
                        complaint.priority!.isNotEmpty)
                      _chip(context, Icons.flag_outlined, complaint.priority!),
                    _chip(
                      context,
                      Icons.schedule_outlined,
                      'Filed ${dateFmt.format(complaint.createdAt.toLocal())}',
                    ),
                    if (complaint.resolvedAt != null)
                      _chip(
                        context,
                        Icons.check_circle_outline,
                        'Resolved ${dateFmt.format(complaint.resolvedAt!.toLocal())}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.s16),
          EnterpriseSectionHeader(
            title: 'Description',
            subtitle: 'What you reported to the society office',
          ),
          SizedBox(height: context.spacing.s8),
          EnterprisePanel(
            child: Text(
              complaint.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.text.primary,
                    height: 1.5,
                  ),
            ),
          ),
          SizedBox(height: context.spacing.s16),
          const EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'Status updates',
            message:
                'You will receive a push notification when an admin updates this complaint.',
            tone: EnterpriseTone.info,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.text.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.text.secondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
