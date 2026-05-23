import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/admin_search_field.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/special_project_model.dart';
import '../../../data/providers/special_project_provider.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

class AdminSpecialProjectsScreen extends ConsumerStatefulWidget {
  const AdminSpecialProjectsScreen({super.key});

  @override
  ConsumerState<AdminSpecialProjectsScreen> createState() =>
      _AdminSpecialProjectsScreenState();
}

class _AdminSpecialProjectsScreenState
    extends ConsumerState<AdminSpecialProjectsScreen> {
  String _statusFilter = '';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
  }

  List<SpecialProjectModel> _applyFilters(List<SpecialProjectModel> projects) {
    var result = projects;
    if (_statusFilter.isNotEmpty) {
      result = result.where((p) => p.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              (p.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(adminSpecialProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Special Projects',
            style: DesignTypography.headingM
                .copyWith(color: DesignColors.textPrimary)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/resident/admin-special-projects/create'),
        backgroundColor: DesignColors.primary,
        foregroundColor: DesignColors.surface,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('New Project', style: DesignTypography.label),
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
          final filtered = _applyFilters(projects);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: DesignColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 100),
              children: [
                _buildHeroCard(projects),
                const SizedBox(height: AppSpacing.lg),
                _buildFilterChips(),
                const SizedBox(height: AppSpacing.md),
                AdminSearchField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  hint: 'Search projects…',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                    child: EmptyStateWidget(
                      icon: Icons.construction_rounded,
                      title: 'No projects yet',
                      subtitle: _statusFilter.isNotEmpty || _searchQuery.isNotEmpty
                          ? 'Try adjusting your filters'
                          : 'Create your first special project',
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

  Widget _buildHeroCard(List<SpecialProjectModel> projects) {
    final active = projects.where((p) => p.status == 'ACTIVE').length;
    final completed = projects.where((p) => p.status == 'COMPLETED').length;
    final cancelled = projects.where((p) => p.status == 'CANCELLED').length;
    final totalTarget = projects
        .where((p) => p.status == 'ACTIVE')
        .fold(0.0, (sum, p) => sum + p.targetAmount);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: DesignColors.primaryGradient,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: DesignElevation.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$active Active Project${active == 1 ? '' : 's'}',
            style: DesignTypography.headingXL.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${_inr.format(totalTarget)} total target',
            style: DesignTypography.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _heroPill('Active', active, DesignColors.surface),
              const SizedBox(width: AppSpacing.sm),
              _heroPill('Completed', completed, DesignColors.surface),
              const SizedBox(width: AppSpacing.sm),
              _heroPill('Cancelled', cancelled, DesignColors.surface),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String label, int count, Color textColor) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      child: Text(
        '$count $label',
        style: DesignTypography.labelSmall.copyWith(color: textColor),
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
    final tone = switch (project.status) {
      'COMPLETED' => EnterpriseTone.success,
      'CANCELLED' => EnterpriseTone.danger,
      _ => EnterpriseTone.neutral,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: EnterprisePanel(
        tone: tone,
        onTap: () =>
            context.push('/resident/admin-special-projects/${project.id}'),
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
                _infoChip(Icons.home_rounded,
                    '${project.contributionCount} villas'),
                _infoChip(Icons.calendar_today_rounded,
                    DateFormat('dd MMM yy').format(project.createdAt)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignRadius.full),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: DesignColors.borderLight,
                valueColor:
                    AlwaysStoppedAnimation(progress >= 100
                        ? DesignColors.primary
                        : DesignColors.primaryLight),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _finStat('Collected', _inr.format(project.totalCollected),
                    DesignColors.primary),
                const SizedBox(width: AppSpacing.lg),
                _finStat('Spent', _inr.format(project.totalExpenses),
                    DesignColors.warning),
                const SizedBox(width: AppSpacing.lg),
                _finStat('Outstanding', _inr.format(project.outstanding),
                    DesignColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _finStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: DesignTypography.label.copyWith(color: color)),
          Text(label,
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary)),
        ],
      ),
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
      child: Text(
        status,
        style: DesignTypography.labelSmall.copyWith(color: fg),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ShimmerWrap(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ShimmerBox(height: 130, borderRadius: DesignRadius.xl),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 40),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBox(height: 44),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 160),
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
