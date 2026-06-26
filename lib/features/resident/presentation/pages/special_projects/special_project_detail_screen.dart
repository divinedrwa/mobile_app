import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/screen_skeletons.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/special_project_model.dart';
import '../../../data/providers/special_project_provider.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

class SpecialProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const SpecialProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(residentSpecialProjectDetailProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Project Details',
            style: DesignTypography.headingM
                .copyWith(color: DesignColors.textPrimary)),
      ),
      body: detailAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Failed to load',
            subtitle: e.toString(),
            iconColor: DesignColors.error,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(
                residentSpecialProjectDetailProvider(projectId)),
          ),
        ),
        data: (data) {
          final projectJson =
              data['project'] as Map<String, dynamic>? ?? {};
          final project = SpecialProjectModel.fromJson(projectJson);
          final contribJson =
              data['myContribution'] as Map<String, dynamic>?;
          final myContrib = contribJson != null
              ? ProjectContributionModel.fromJson(contribJson)
              : null;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                  residentSpecialProjectDetailProvider(projectId));
            },
            color: DesignColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                _buildHeader(project),
                const SizedBox(height: AppSpacing.lg),
                _buildFinancialHero(project),
                if (myContrib != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildMyContribution(myContrib),
                  if (myContrib.payments.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildPaymentHistory(myContrib.payments),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildAllContributions(project),
                const SizedBox(height: AppSpacing.lg),
                _buildExpenses(ref),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header Card ──

  Widget _buildHeader(SpecialProjectModel project) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project.title,
              style: DesignTypography.headingL
                  .copyWith(color: DesignColors.textPrimary)),
          if (project.description != null &&
              project.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(project.description!,
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(_typeLabel(project.type), DesignColors.info),
              _statusBadge(project.status),
              _chip('Created ${_dateFmt.format(project.createdAt)}',
                  DesignColors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  // ── Financial Hero ──

  Widget _buildFinancialHero(SpecialProjectModel project) {
    final progress = project.collectionPercent;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: DesignColors.primaryGradient,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: DesignElevation.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _heroStat('Target', _inr.format(project.targetAmount)),
              _heroStat('Collected', _inr.format(project.totalCollected)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _heroStat('Spent', _inr.format(project.totalExpenses)),
              _heroStat('Balance', _inr.format(project.balance)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignRadius.full),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$progress% collected',
            style: DesignTypography.captionSmall
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: DesignTypography.captionSmall
                  .copyWith(color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: DesignTypography.label
                  .copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  // ── My Contribution ──

  Widget _buildMyContribution(ProjectContributionModel contrib) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(
            color: DesignColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: DesignElevation.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 18, color: DesignColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('My Contribution',
                  style: DesignTypography.label
                      .copyWith(color: DesignColors.textPrimary)),
              const Spacer(),
              _contribStatusBadge(contrib.status, large: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _contribStat('Amount', _inr.format(contrib.amount),
                  DesignColors.textPrimary),
              _contribStat('Paid', _inr.format(contrib.paidAmount),
                  DesignColors.primary),
              _contribStat(
                  'Due',
                  _inr.format(contrib.outstanding),
                  contrib.outstanding > 0
                      ? DesignColors.error
                      : DesignColors.textTertiary),
            ],
          ),
          if (contrib.dueDate != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: DesignColors.textTertiary),
                const SizedBox(width: AppSpacing.xs),
                Text('Due: ${_dateFmt.format(contrib.dueDate!)}',
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textTertiary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _contribStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: DesignTypography.label.copyWith(color: color)),
        ],
      ),
    );
  }

  // ── Payment History ──

  Widget _buildPaymentHistory(List<ProjectPaymentModel> payments) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Payment History',
              style: DesignTypography.label
                  .copyWith(color: DesignColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          ...payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DesignColors.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(DesignRadius.md),
                      ),
                      child: Icon(Icons.check_circle_rounded,
                          color: DesignColors.primary, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_inr.format(p.amount),
                              style: DesignTypography.label
                                  .copyWith(color: DesignColors.textPrimary)),
                          Row(
                            children: [
                              _methodBadge(p.method),
                              const SizedBox(width: AppSpacing.sm),
                              Text(_dateFmt.format(p.paidAt),
                                  style: DesignTypography.captionSmall
                                      .copyWith(
                                          color: DesignColors.textTertiary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (p.reference != null && p.reference!.isNotEmpty)
                      Text(p.reference!,
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textTertiary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _methodBadge(String method) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: DesignColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignRadius.sm),
      ),
      child: Text(
        method.replaceAll('_', ' '),
        style: DesignTypography.captionSmall
            .copyWith(color: DesignColors.info),
      ),
    );
  }

  // ── All Contributions (transparency) ──

  Widget _buildAllContributions(SpecialProjectModel project) {
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_rounded,
                  size: 18, color: DesignColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Text('All Contributions',
                  style: DesignTypography.label
                      .copyWith(color: DesignColors.textPrimary)),
              const Spacer(),
              Text('${project.contributionCount} villas',
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: DesignColors.surfaceSoft,
              borderRadius: BorderRadius.circular(DesignRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: DesignColors.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${project.contributionCount} villas contributing to this project',
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Expenses (read-only) ──

  Widget _buildExpenses(WidgetRef ref) {
    final expensesAsync =
        ref.watch(residentSpecialProjectExpensesProvider(projectId));

    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project Expenses',
              style: DesignTypography.label
                  .copyWith(color: DesignColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          expensesAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: PickerSkeleton(itemCount: 3)),
            error: (e, _) => Text('Failed to load expenses',
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.error)),
            data: (expenses) {
              if (expenses.isEmpty) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('No expenses recorded',
                        style: DesignTypography.bodySmall
                            .copyWith(color: DesignColors.textTertiary)),
                  ),
                );
              }
              return Column(
                children: expenses
                    .map((e) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: DesignColors.warning
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      DesignRadius.md),
                                ),
                                child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: DesignColors.warning,
                                    size: 18),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.description,
                                        style: DesignTypography.label
                                            .copyWith(
                                                color: DesignColors
                                                    .textPrimary)),
                                    Text(
                                      '${e.vendor ?? ''}'
                                      '${e.vendor != null ? ' • ' : ''}'
                                      '${_dateFmt.format(e.expenseDate)}',
                                      style: DesignTypography.captionSmall
                                          .copyWith(
                                              color: DesignColors
                                                  .textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(_inr.format(e.amount),
                                  style: DesignTypography.label
                                      .copyWith(
                                          color: DesignColors.warning)),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

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

  Widget _contribStatusBadge(String status, {bool large = false}) {
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
      padding: EdgeInsets.symmetric(
          horizontal: large ? AppSpacing.md : AppSpacing.sm,
          vertical: large ? AppSpacing.xs : 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(DesignRadius.full)),
      child: Text(label,
          style: (large ? DesignTypography.labelSmall : DesignTypography.captionSmall)
              .copyWith(color: fg)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignRadius.sm),
      ),
      child: Text(label,
          style: DesignTypography.captionSmall.copyWith(color: color)),
    );
  }

  Widget _buildSkeleton() {
    return ShimmerWrap(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          ShimmerBox(height: 120),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 160),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 120),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 80),
          SizedBox(height: AppSpacing.lg),
          ShimmerBox(height: 100),
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
