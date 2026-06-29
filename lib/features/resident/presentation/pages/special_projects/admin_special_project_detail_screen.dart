import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../data/models/special_project_model.dart';
import '../../../data/providers/special_project_provider.dart';
import '../../../data/repositories/special_project_repository.dart';

final _inr = NumberFormat.currency(
    locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
final _dateFmt = DateFormat('dd MMM yyyy');

class AdminSpecialProjectDetailScreen extends ConsumerStatefulWidget {
  const AdminSpecialProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<AdminSpecialProjectDetailScreen> createState() =>
      _AdminSpecialProjectDetailScreenState();
}

class _AdminSpecialProjectDetailScreenState
    extends ConsumerState<AdminSpecialProjectDetailScreen> {
  String _contribFilter = '';

  Future<void> _refresh() async {
    ref.invalidate(adminSpecialProjectDetailProvider(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(adminSpecialProjectDetailProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Project Details',
            style: DesignTypography.headingM
                .copyWith(color: DesignColors.textPrimary)),
        actions: [
          detailAsync.whenOrNull(
                data: (data) {
                  final project = SpecialProjectModel.fromJson(
                      data['project'] as Map<String, dynamic>);
                  if (project.status != 'ACTIVE') return const SizedBox();
                  return PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showEditSheet(project);
                      if (v == 'delete') _confirmDelete(project);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit Project')),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete Project',
                              style: TextStyle(color: DesignColors.error))),
                    ],
                  );
                },
              ) ??
              const SizedBox(),
        ],
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
            onAction: _refresh,
          ),
        ),
        data: (data) {
          final project = SpecialProjectModel.fromJson(
              data['project'] as Map<String, dynamic>);
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final rawContribs =
              (data['project'] as Map<String, dynamic>)['contributions']
                      as List? ??
                  [];
          final contributions = rawContribs
              .whereType<Map>()
              .map((r) =>
                  ProjectContributionModel.fromJson(Map<String, dynamic>.from(r)))
              .toList();
          final rawExpenses =
              (data['project'] as Map<String, dynamic>)['expenses'] as List? ??
                  [];
          final expenses = rawExpenses
              .whereType<Map>()
              .map((r) =>
                  ProjectExpenseModel.fromJson(Map<String, dynamic>.from(r)))
              .toList();

          final paidCount =
              (summary['paidCount'] as int?) ?? contributions.where((c) => c.status == 'PAID').length;
          final totalContribs =
              (summary['contributionCount'] as int?) ?? contributions.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: DesignColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                _buildHeader(project),
                const SizedBox(height: AppSpacing.lg),
                _buildFinancialSummary(project, paidCount, totalContribs),
                if (project.status == 'ACTIVE') ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatusActions(project),
                ],
                const SizedBox(height: AppSpacing.xl),
                _buildContributionsSection(
                    project, contributions),
                const SizedBox(height: AppSpacing.xl),
                _buildExpensesSection(project, expenses),
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

  // ── Financial Summary ──

  Widget _buildFinancialSummary(
      SpecialProjectModel project, int paidCount, int totalContribs) {
    final progress = project.collectionPercent;
    return EnterprisePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Financial Summary',
              style: DesignTypography.label
                  .copyWith(color: DesignColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _finBox('Target', _inr.format(project.targetAmount),
                  DesignColors.textPrimary),
              _finBox('Collected', _inr.format(project.totalCollected),
                  DesignColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _finBox(
                  'Spent', _inr.format(project.totalExpenses), DesignColors.warning),
              _finBox('Balance', _inr.format(project.balance),
                  project.balance >= 0 ? DesignColors.primary : DesignColors.error),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignRadius.full),
            child: LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: DesignColors.borderLight,
              valueColor: AlwaysStoppedAnimation(
                  progress >= 100 ? DesignColors.primary : DesignColors.primaryLight),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$paidCount paid / $totalContribs total • $progress% collected',
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _finBox(String label, String value, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
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
        ),
      ),
    );
  }

  // ── Status Actions ──

  Widget _buildStatusActions(SpecialProjectModel project) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmStatus(project, 'COMPLETED'),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Complete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DesignColors.primary,
              side: BorderSide(color: DesignColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmStatus(project, 'CANCELLED'),
            icon: const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DesignColors.error,
              side: BorderSide(color: DesignColors.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.md)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Contributions Section ──

  Widget _buildContributionsSection(
      SpecialProjectModel project,
      List<ProjectContributionModel> contributions) {
    final filtered = _contribFilter.isEmpty
        ? contributions
        : contributions
            .where((c) => c.status == _contribFilter)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Contributions (${contributions.length})',
                style: DesignTypography.headingM
                    .copyWith(color: DesignColors.textPrimary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('', 'All'),
              const SizedBox(width: AppSpacing.sm),
              _filterChip('PAID', 'Paid'),
              const SizedBox(width: AppSpacing.sm),
              _filterChip('PARTIALLY_PAID', 'Partial'),
              const SizedBox(width: AppSpacing.sm),
              _filterChip('UNPAID', 'Unpaid'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (filtered.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text('No contributions match this filter',
                  style: TextStyle(color: DesignColors.textTertiary)),
            ),
          )
        else
          ...filtered.map((c) => _buildContributionCard(project, c)),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _contribFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _contribFilter = value),
      selectedColor: DesignColors.primary.withValues(alpha: 0.15),
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: selected ? DesignColors.primary : DesignColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignRadius.full),
        side: BorderSide(
          color: selected ? DesignColors.primary : DesignColors.borderLight,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildContributionCard(
      SpecialProjectModel project, ProjectContributionModel contrib) {
    final tone = switch (contrib.status) {
      'PAID' => EnterpriseTone.success,
      'PARTIALLY_PAID' => EnterpriseTone.warning,
      _ => EnterpriseTone.neutral,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: EnterprisePanel(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home_rounded,
                    size: 18, color: DesignColors.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Villa ${contrib.villaNumber ?? '—'}',
                    style: DesignTypography.label
                        .copyWith(color: DesignColors.textPrimary),
                  ),
                ),
                _contribStatusBadge(contrib.status),
              ],
            ),
            if (contrib.ownerName != null &&
                contrib.ownerName!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(contrib.ownerName!,
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textTertiary)),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  Text('${_inr.format(contrib.paidAmount)} / ${_inr.format(contrib.amount)}',
                      style: DesignTypography.bodySmall
                          .copyWith(color: DesignColors.textSecondary)),
                  if (contrib.outstanding > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text('Due: ${_inr.format(contrib.outstanding)}',
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.error)),
                  ],
                ],
              ),
            ),
            if (project.status == 'ACTIVE' && contrib.status != 'PAID') ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: TextButton.icon(
                  onPressed: () => _showRecordPaymentSheet(project, contrib),
                  icon: const Icon(Icons.payment_rounded, size: 16),
                  label: const Text('Record Payment'),
                  style: TextButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    textStyle: DesignTypography.labelSmall,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
            // Payment History (expandable)
            if (contrib.payments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                tilePadding: const EdgeInsets.only(left: 26),
                childrenPadding: const EdgeInsets.only(
                    left: 26, right: 0, bottom: AppSpacing.sm),
                title: Text(
                  '${contrib.payments.length} payment(s)',
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textTertiary),
                ),
                children: contrib.payments.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: DesignColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_inr.format(p.amount),
                                  style: DesignTypography.label
                                      .copyWith(color: DesignColors.textPrimary)),
                              Text(
                                '${p.method} • ${_dateFmt.format(p.paidAt)}'
                                '${p.reference != null && p.reference!.isNotEmpty ? ' • ${p.reference}' : ''}',
                                style: DesignTypography.captionSmall
                                    .copyWith(color: DesignColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        if (project.status == 'ACTIVE')
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18, color: DesignColors.error),
                            onPressed: () =>
                                _confirmDeletePayment(project, contrib, p),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(AppSpacing.xs),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Expenses Section ──

  Widget _buildExpensesSection(
      SpecialProjectModel project, List<ProjectExpenseModel> expenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Expenses (${expenses.length})',
                  style: DesignTypography.headingM
                      .copyWith(color: DesignColors.textPrimary)),
            ),
            if (project.status == 'ACTIVE')
              TextButton.icon(
                onPressed: () => _showExpenseSheet(project, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: DesignColors.primary,
                  textStyle: DesignTypography.label,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (expenses.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text('No expenses recorded',
                  style: TextStyle(color: DesignColors.textTertiary)),
            ),
          )
        else
          ...expenses.map((exp) => _buildExpenseRow(project, exp)),
      ],
    );
  }

  Widget _buildExpenseRow(SpecialProjectModel project, ProjectExpenseModel expense) {
    return Dismissible(
      key: ValueKey(expense.id),
      direction: project.status == 'ACTIVE'
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppSpacing.lg),
        color: DesignColors.error.withValues(alpha: 0.1),
        child: Icon(Icons.delete_rounded, color: DesignColors.error),
      ),
      confirmDismiss: (_) => _confirmDeleteExpense(expense),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: EnterprisePanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expense.description,
                        style: DesignTypography.label
                            .copyWith(color: DesignColors.textPrimary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${expense.vendor ?? ''}'
                      '${expense.vendor != null ? ' • ' : ''}'
                      '${_dateFmt.format(expense.expenseDate)}',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(_inr.format(expense.amount),
                  style: DesignTypography.label
                      .copyWith(color: DesignColors.warning)),
              if (project.status == 'ACTIVE') ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Icon(Icons.edit_rounded,
                      size: 18, color: DesignColors.textTertiary),
                  onPressed: () => _showExpenseSheet(project, expense),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Sheets ──

  void _showRecordPaymentSheet(
      SpecialProjectModel project, ProjectContributionModel contrib) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordPaymentSheet(
        projectId: project.id,
        contribution: contrib,
        onDone: _refresh,
      ),
    );
  }

  void _showExpenseSheet(
      SpecialProjectModel project, ProjectExpenseModel? expense) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(
        projectId: project.id,
        expense: expense,
        onDone: _refresh,
      ),
    );
  }

  void _showEditSheet(SpecialProjectModel project) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProjectSheet(
        project: project,
        onDone: _refresh,
      ),
    );
  }

  Future<void> _confirmStatus(
      SpecialProjectModel project, String status) async {
    final label = status == 'COMPLETED' ? 'Complete' : 'Cancel';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Project?'),
        content: Text(
            'This will mark "${project.title}" as ${status.toLowerCase()}. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: status == 'COMPLETED'
                  ? DesignColors.primary
                  : DesignColors.error,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SpecialProjectRepository()
          .updateProjectStatus(widget.projectId, status);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project ${status.toLowerCase()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<void> _confirmDelete(SpecialProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
            'This will permanently delete "${project.title}". This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: DesignColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SpecialProjectRepository().deleteProject(widget.projectId);
      if (!mounted) return;
      await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<void> _confirmDeletePayment(SpecialProjectModel project,
      ProjectContributionModel contrib, ProjectPaymentModel payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: Text(
            'Remove ${_inr.format(payment.amount)} payment from Villa ${contrib.villaNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: DesignColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SpecialProjectRepository()
          .deletePayment(project.id, contrib.id, payment.id);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<bool> _confirmDeleteExpense(ProjectExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Remove "${expense.description}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: DesignColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    try {
      await SpecialProjectRepository()
          .deleteExpense(widget.projectId, expense.id);
      if (!mounted) return false;
      await _refresh();
      if (!mounted) return false;
      await ref.read(adminSpecialProjectsProvider.notifier).fetchProjects();
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
      return false;
    }
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
          DesignColors.textTertiary.withValues(alpha: 0.12),
          DesignColors.textSecondary,
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
        children: [
          const ShimmerBox(height: 120),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 200),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 48),
          const SizedBox(height: AppSpacing.xl),
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: ShimmerBox(height: 100),
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

// ── Record Payment Bottom Sheet ──

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.projectId,
    required this.contribution,
    required this.onDone,
  });

  final String projectId;
  final ProjectContributionModel contribution;
  final VoidCallback onDone;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _method = 'CASH';
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SpecialProjectRepository().recordPayment(
        widget.projectId,
        widget.contribution.id,
        {
          'amount': amount,
          'method': _method,
          if (_refCtrl.text.trim().isNotEmpty)
            'reference': _refCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      widget.onDone();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Record Payment',
                style: DesignTypography.headingM
                    .copyWith(color: DesignColors.textPrimary)),
            Text(
              'Villa ${widget.contribution.villaNumber ?? '—'} • Outstanding: ${_inr.format(widget.contribution.outstanding)}',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: DesignComponents.inputDecoration(
                label: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee_rounded,
                    size: 18, color: DesignColors.textTertiary),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: DesignComponents.inputDecoration(label: 'Method'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(
                    value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'CASH'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _refCtrl,
              decoration: DesignComponents.inputDecoration(
                  label: 'Reference', hint: 'Transaction ID (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: DesignComponents.primaryButtonStyle,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Submit Payment',
                        style: DesignTypography.button
                            .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add/Edit Expense Bottom Sheet ──

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet({
    required this.projectId,
    this.expense,
    required this.onDone,
  });

  final String projectId;
  final ProjectExpenseModel? expense;
  final VoidCallback onDone;

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _vendorCtrl;
  DateTime? _date;
  bool _submitting = false;

  bool get _isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _descCtrl =
        TextEditingController(text: widget.expense?.description ?? '');
    _amountCtrl = TextEditingController(
        text: widget.expense != null
            ? widget.expense!.amount.toStringAsFixed(0)
            : '');
    _vendorCtrl =
        TextEditingController(text: widget.expense?.vendor ?? '');
    _date = widget.expense?.expenseDate;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description is required')),
      );
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'description': desc,
        'amount': amount,
        if (_vendorCtrl.text.trim().isNotEmpty)
          'vendor': _vendorCtrl.text.trim(),
        if (_date != null) 'expenseDate': _date!.toUtc().toIso8601String(),
      };
      final repo = SpecialProjectRepository();
      if (_isEdit) {
        await repo.updateExpense(
            widget.projectId, widget.expense!.id, data);
      } else {
        await repo.addExpense(widget.projectId, data);
      }
      if (!mounted) return;
      widget.onDone();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit ? 'Expense updated' : 'Expense added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_isEdit ? 'Edit Expense' : 'Add Expense',
                style: DesignTypography.headingM
                    .copyWith(color: DesignColors.textPrimary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration:
                  DesignComponents.inputDecoration(label: 'Description'),
              autofocus: !_isEdit,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              decoration: DesignComponents.inputDecoration(
                label: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee_rounded,
                    size: 18, color: DesignColors.textTertiary),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendorCtrl,
              decoration: DesignComponents.inputDecoration(
                  label: 'Vendor', hint: 'Optional'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(DesignRadius.md),
              child: InputDecorator(
                decoration:
                    DesignComponents.inputDecoration(label: 'Date'),
                child: Text(
                  _date != null
                      ? _dateFmt.format(_date!)
                      : 'Today',
                  style: DesignTypography.body.copyWith(
                    color: _date != null
                        ? DesignColors.textPrimary
                        : DesignColors.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: DesignComponents.primaryButtonStyle,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Update' : 'Add Expense',
                        style: DesignTypography.button
                            .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Project Bottom Sheet ──

class _EditProjectSheet extends StatefulWidget {
  const _EditProjectSheet({
    required this.project,
    required this.onDone,
  });

  final SpecialProjectModel project;
  final VoidCallback onDone;

  @override
  State<_EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<_EditProjectSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _type;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.project.title);
    _descCtrl =
        TextEditingController(text: widget.project.description ?? '');
    _type = widget.project.type;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await SpecialProjectRepository().updateProject(widget.project.id, {
        'title': title,
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'type': _type,
      });
      if (!mounted) return;
      widget.onDone();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Project',
                style: DesignTypography.headingM
                    .copyWith(color: DesignColors.textPrimary)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: DesignComponents.inputDecoration(label: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: DesignComponents.inputDecoration(label: 'Type'),
              items: const [
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                DropdownMenuItem(value: 'REPAIR', child: Text('Repair')),
                DropdownMenuItem(value: 'UPGRADE', child: Text('Upgrade')),
                DropdownMenuItem(
                    value: 'PURCHASE', child: Text('Purchase')),
                DropdownMenuItem(value: 'EVENT', child: Text('Event')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'OTHER'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration:
                  DesignComponents.inputDecoration(label: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: DesignComponents.primaryButtonStyle,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Save Changes',
                        style: DesignTypography.button
                            .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
