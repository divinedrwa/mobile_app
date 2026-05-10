import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../widgets/maintenance/breakdown_row.dart';
import '../../widgets/maintenance/maintenance_status_card.dart';

/// Detail view for a single billing cycle.
///
/// Combines two existing providers — pending dues and payment history —
/// because the same `cycleId` shows up in one or the other depending on
/// state. Looking up by id from the union saves a dedicated network call
/// and means the screen stays in sync with whatever the hub already
/// loaded; tapping a row in either list opens this screen instantly with
/// the correct data while a fresh fetch happens in the background.
class CycleDetailScreen extends ConsumerStatefulWidget {
  const CycleDetailScreen({super.key, required this.cycleId});

  final String cycleId;

  @override
  ConsumerState<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends ConsumerState<CycleDetailScreen> {
  Future<void> _refresh() async {
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    Future<void> swallow<T>(Future<T> f) =>
        f.then((_) {}).catchError((Object _) {});
    await Future.wait<void>([
      swallow(ref.read(pendingMaintenanceProvider.future)),
      swallow(ref.read(maintenanceHistoryProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingMaintenanceProvider);
    final historyAsync = ref.watch(maintenanceHistoryProvider);

    final cycle = _findCycle(
      pendingAsync.valueOrNull ?? const [],
      historyAsync.valueOrNull ?? const [],
    );

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back, color: DesignColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          cycle?.title.isNotEmpty == true
              ? cycle!.title
              : 'Cycle details',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: cycle == null
            ? _loading(pendingAsync, historyAsync)
            : _content(cycle),
      ),
    );
  }

  // ---- content ----

  Widget _loading(
    AsyncValue<List<MaintenanceDueModel>> pendingAsync,
    AsyncValue<List<MaintenanceDueModel>> historyAsync,
  ) {
    if (pendingAsync.isLoading || historyAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.search_off_outlined,
                size: 32,
                color: DesignColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Cycle not found',
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'It may have been archived or moved. Pull to refresh, or go back.',
                textAlign: TextAlign.center,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(MaintenanceDueModel cycle) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y');
    final isPaid = cycle.status.toUpperCase() == 'PAID';
    final isPartial = cycle.status.toUpperCase() == 'PARTIAL';
    final overdue = cycle.isOverdue ||
        (cycle.dueDate.isBefore(DateTime.now()) && !isPaid);
    final remaining = cycle.remainingDue > 0
        ? cycle.remainingDue
        : (isPaid ? 0.0 : cycle.amount);

    final kind = isPaid
        ? MaintenanceStatusKind.paid
        : (overdue ? MaintenanceStatusKind.overdue : MaintenanceStatusKind.due);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        MaintenanceStatusCard(
          kind: kind,
          title: isPaid
              ? 'Paid'
              : (overdue ? 'Overdue' : 'Outstanding'),
          subtitle: 'Cycle ${cycle.cycleKey}',
          amountLabel: isPaid ? 'Paid' : 'Outstanding',
          amountValue: inr.format(isPaid
              ? (cycle.cashPaidAmount > 0
                  ? cycle.cashPaidAmount
                  : cycle.paidAmount)
              : remaining),
          dueDate: cycle.paidAt != null
              ? 'Paid on ${dateFmt.format(cycle.paidAt!)}'
              : 'Due ${dateFmt.format(cycle.dueDate)}',
          actionLabel: null,
          onAction: null,
        ),
        const SizedBox(height: AppSpacing.xl),
        // Money breakdown — same numbers the residents page uses, framed
        // for the resident's view (cash + credit applied = total covered).
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Breakdown',
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              BreakdownRow(
                label: 'Expected for this cycle',
                value: inr.format(cycle.expectedAmount > 0
                    ? cycle.expectedAmount
                    : cycle.amount),
                icon: Icons.receipt_outlined,
              ),
              const Divider(height: 1, color: DesignColors.divider),
              BreakdownRow(
                label: 'Cash paid',
                value: inr.format(cycle.cashPaidAmount),
                valueColor: cycle.cashPaidAmount > 0
                    ? DesignColors.success
                    : DesignColors.textPrimary,
                icon: Icons.payments_outlined,
              ),
              if (cycle.creditApplied > 0) ...[
                const Divider(height: 1, color: DesignColors.divider),
                BreakdownRow(
                  label: 'Advance credit applied',
                  value: '+ ${inr.format(cycle.creditApplied)}',
                  valueColor: DesignColors.primary,
                  icon: Icons.savings_outlined,
                ),
              ],
              if (cycle.previousDue > 0) ...[
                const Divider(height: 1, color: DesignColors.divider),
                BreakdownRow(
                  label: 'Previous outstanding',
                  value: inr.format(cycle.previousDue),
                  valueColor: DesignColors.warning,
                  icon: Icons.history_toggle_off,
                ),
              ],
              const Divider(height: 1, color: DesignColors.divider),
              BreakdownRow(
                label: isPaid ? 'Total paid' : 'Outstanding now',
                value: inr.format(isPaid
                    ? (cycle.cashPaidAmount + cycle.creditApplied)
                    : remaining),
                valueColor: isPaid
                    ? DesignColors.success
                    : (overdue ? DesignColors.error : DesignColors.textPrimary),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Per-cycle status badge row to give residents a quick read on
        // partial vs full coverage without re-reading the breakdown.
        _statusFootnote(cycle, isPaid: isPaid, isPartial: isPartial, overdue: overdue),
      ],
    );
  }

  Widget _statusFootnote(
    MaintenanceDueModel cycle, {
    required bool isPaid,
    required bool isPartial,
    required bool overdue,
  }) {
    String message;
    Color tone;
    IconData icon;
    if (isPaid) {
      message = 'This cycle is fully settled. Receipt available below.';
      tone = DesignColors.success;
      icon = Icons.check_circle;
    } else if (isPartial) {
      message =
          'Partial payment received — pay the outstanding amount to settle this cycle.';
      tone = DesignColors.primary;
      icon = Icons.adjust;
    } else if (overdue) {
      message =
          'Payment is overdue. Late fees may apply per society rules.';
      tone = DesignColors.error;
      icon = Icons.warning_amber_rounded;
    } else {
      message =
          'Pay before the due date to keep the cycle in good standing.';
      tone = DesignColors.warning;
      icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  MaintenanceDueModel? _findCycle(
    List<MaintenanceDueModel> pending,
    List<MaintenanceDueModel> history,
  ) {
    for (final m in pending) {
      if (m.cycleId == widget.cycleId) return m;
    }
    for (final m in history) {
      if (m.cycleId == widget.cycleId) return m;
    }
    return null;
  }
}
