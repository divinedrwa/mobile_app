import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/banner_image_url.dart';
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
    final photoUrl = resolveBannerImageUrl(complaint.photoUrl);

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
          if (photoUrl != null) ...[
            SizedBox(height: context.spacing.s16),
            EnterpriseSectionHeader(
              title: 'Photo',
              subtitle: 'Attached when you filed this complaint',
            ),
            SizedBox(height: context.spacing.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(context.radius.md),
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
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
          if (complaint.adminNotes != null &&
              complaint.adminNotes!.trim().isNotEmpty) ...[
            SizedBox(height: context.spacing.s16),
            EnterpriseSectionHeader(
              title: 'Admin response',
              subtitle: 'Notes from the society office',
            ),
            SizedBox(height: context.spacing.s8),
            EnterprisePanel(
              child: Text(
                complaint.adminNotes!.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.text.primary,
                      height: 1.5,
                    ),
              ),
            ),
          ],
          SizedBox(height: context.spacing.s16),
          EnterpriseSectionHeader(
            title: 'SLA timeline',
            subtitle: 'Expected response milestones for this complaint',
          ),
          SizedBox(height: context.spacing.s8),
          _SlaTimeline(events: complaint.slaTimeline),
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

class _SlaTimeline extends StatelessWidget {
  const _SlaTimeline({required this.events});

  final List<ComplaintSlaTimelineEvent> events;

  Color _dotColor(String state) {
    switch (state) {
      case 'done':
        return DesignColors.success;
      case 'active':
        return DesignColors.warning;
      case 'breached':
        return DesignColors.error;
      default:
        return DesignColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EnterpriseInfoBanner(
        icon: Icons.timeline_outlined,
        title: 'Timeline pending',
        message: 'SLA milestones will appear once the complaint is processed.',
        tone: EnterpriseTone.info,
      );
    }

    final dateFmt = DateFormat('dd MMM, hh:mm a');
    return EnterprisePanel(
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _dotColor(events[i].state),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < events.length - 1)
                      Container(
                        width: 2,
                        height: 42,
                        color: DesignColors.borderLight,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          events[i].label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.text.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFmt.format(events[i].at.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.text.secondary,
                          ),
                        ),
                        if (events[i].detail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            events[i].detail!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.text.tertiary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
