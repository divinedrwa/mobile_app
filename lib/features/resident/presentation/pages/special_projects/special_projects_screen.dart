import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/special_project_model.dart';
import '../../../data/providers/special_project_provider.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

class SpecialProjectsScreen extends ConsumerStatefulWidget {
  const SpecialProjectsScreen({super.key});

  @override
  ConsumerState<SpecialProjectsScreen> createState() =>
      _SpecialProjectsScreenState();
}

class _SpecialProjectsScreenState
    extends ConsumerState<SpecialProjectsScreen> {
  String _statusFilter = '';

  Future<void> _refresh() async {
    await ref.read(residentSpecialProjectsProvider.notifier).fetchProjects();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(residentSpecialProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Special Projects',
            style: DesignTypography.headingM
                .copyWith(color: DesignColors.textPrimary)),
      ),
      body: projectsAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: e.toString(),
            iconColor: DesignColors.error,
            actionLabel: 'Retry',
            onAction: _refresh,
          ),
        ),
        data: (projects) {
          final filtered = _statusFilter.isEmpty
              ? projects
              : projects
                  .where((p) => p.status == _statusFilter)
                  .toList();

          final activeCount =
              projects.where((p) => p.status == 'ACTIVE').length;
          final totalOutstanding = projects
              .where((p) => p.status == 'ACTIVE' && p.myContribution != null)
              .fold(0.0, (sum, p) => sum + p.myContribution!.outstanding);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: DesignColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // Summary pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: DesignColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(DesignRadius.full),
                    border: Border.all(
                        color: DesignColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.construction_rounded,
                          size: 16, color: DesignColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$activeCount active',
                        style: DesignTypography.label
                            .copyWith(color: DesignColors.primary),
                      ),
                      if (totalOutstanding > 0) ...[
                        Text(' • ',
                            style: DesignTypography.label
                                .copyWith(color: DesignColors.textTertiary)),
                        Text(
                          '${_inr.format(totalOutstanding)} outstanding',
                          style: DesignTypography.label
                              .copyWith(color: DesignColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildFilterChips(),
                const SizedBox(height: AppSpacing.lg),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                    child: EmptyStateWidget(
                      icon: Icons.construction_rounded,
                      title: 'No projects',
                      subtitle: _statusFilter.isNotEmpty
                          ? 'No ${_statusFilter.toLowerCase()} projects found'
                          : 'No special projects in your society yet',
                    ),
                  )
                else
                  ...List.generate(filtered.length, (i) {
                    return _buildProjectCard(filtered[i])
                        .animate()
                        .fadeIn(
                          duration: DesignAnimations.durationEntrance,
                          delay: DesignAnimations.staggerFor(i),
                        )
                        .slideY(
                          begin: DesignAnimations.slideSubtle,
                          end: 0,
                          duration: DesignAnimations.durationEntrance,
                          delay: DesignAnimations.staggerFor(i),
                          curve: DesignAnimations.curveEntrance,
                        );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = [
      ('', 'All'),
      ('ACTIVE', 'Active'),
      ('COMPLETED', 'Completed'),
      ('CANCELLED', 'Cancelled'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _statusFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(f.$2),
              selected: selected,
              onSelected: (_) => setState(() => _statusFilter = f.$1),
              selectedColor: DesignColors.primary.withValues(alpha: 0.15),
              labelStyle: DesignTypography.label.copyWith(
                color: selected
                    ? DesignColors.primary
                    : DesignColors.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignRadius.full),
                side: BorderSide(
                  color: selected
                      ? DesignColors.primary
                      : DesignColors.borderLight,
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectCard(SpecialProjectModel project) {
    final progress = project.collectionPercent;
    final contrib = project.myContribution;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: EnterprisePanel(
        onTap: () =>
            context.push('/resident/special-projects/${project.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: DesignTypography.headingM
                        .copyWith(color: DesignColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _statusBadge(project.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _infoChip(Icons.category_rounded, _typeLabel(project.type)),
                _infoChip(Icons.people_rounded,
                    '${project.contributionCount} contributing'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignRadius.full),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: DesignColors.borderLight,
                valueColor: AlwaysStoppedAnimation(
                    progress >= 100
                        ? DesignColors.primary
                        : DesignColors.primaryLight),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_inr.format(project.totalCollected)} / ${_inr.format(project.targetAmount)} ($progress%)',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary),
            ),
            // My Contribution
            if (contrib != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Divider(height: 1, color: DesignColors.divider),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Contribution',
                            style: DesignTypography.captionSmall
                                .copyWith(color: DesignColors.textTertiary)),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Text(
                              '${_inr.format(contrib.paidAmount)} / ${_inr.format(contrib.amount)}',
                              style: DesignTypography.label
                                  .copyWith(color: DesignColors.textPrimary),
                            ),
                            if (contrib.outstanding > 0) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '${_inr.format(contrib.outstanding)} due',
                                style: DesignTypography.captionSmall
                                    .copyWith(color: DesignColors.error),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _contribStatusBadge(contrib.status),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (bg, fg) = switch (status) {
      'ACTIVE' => (
          DesignColors.primary.withValues(alpha: 0.12),
          DesignColors.primaryDark
        ),
      'COMPLETED' => (
          DesignColors.info.withValues(alpha: 0.12),
          DesignColors.info
        ),
      'CANCELLED' => (
          DesignColors.error.withValues(alpha: 0.12),
          DesignColors.error
        ),
      _ => (
          DesignColors.textTertiary.withValues(alpha: 0.12),
          DesignColors.textSecondary
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(DesignRadius.full)),
      child: Text(status,
          style: DesignTypography.labelSmall.copyWith(color: fg)),
    );
  }

  Widget _contribStatusBadge(String status) {
    final (bg, fg, label) = switch (status) {
      'PAID' => (
          DesignColors.primary.withValues(alpha: 0.12),
          DesignColors.primaryDark,
          'Paid'
        ),
      'PARTIALLY_PAID' => (
          DesignColors.warning.withValues(alpha: 0.12),
          DesignColors.warning,
          'Partial'
        ),
      _ => (
          DesignColors.error.withValues(alpha: 0.12),
          DesignColors.error,
          'Unpaid'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(DesignRadius.full)),
      child: Text(label,
          style: DesignTypography.captionSmall.copyWith(color: fg)),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(DesignRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DesignColors.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Text(label,
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ShimmerWrap(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ShimmerBox(height: 44, borderRadius: DesignRadius.full),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 40),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 180),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'REPAIR' => 'Repair',
        'UPGRADE' => 'Upgrade',
        'PURCHASE' => 'Purchase',
        'EVENT' => 'Event',
        _ => 'Other',
      };
}
