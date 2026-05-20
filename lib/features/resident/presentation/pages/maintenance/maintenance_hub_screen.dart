import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/billing_cycle_current_model.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/upi_payment_provider.dart';
import '../../widgets/maintenance/maintenance_hub_skeleton.dart';
import '../../widgets/maintenance/maintenance_stat_chip.dart';
import '../../widgets/maintenance/maintenance_status_card.dart';
import '../../widgets/maintenance/payment_list_tile.dart';
/// Resident-facing maintenance landing screen.
///
/// One scroll, three sections:
///   1. Hero status card driven by [residentBillingCycleProvider]
///   2. Stat chips (this month due / advance credit / pending count)
///   3. Pending dues + recent activity lists
///
/// Why a fresh screen instead of trimming the existing
/// `MaintenancePaymentScreen` (3.5k lines, mixed admin+resident):
///   - The admin needs different surfaces (society totals, all residents,
///     cycle generation). Sharing one screen forced both views to compromise.
///   - Most of the resident's time is spent on the "anything to act on?"
///     question; that deserves a dedicated above-the-fold answer.
///
/// The admin path keeps using [MaintenancePaymentScreen]; this screen is
/// only mounted for residents (see route mounting in `app_router.dart`).
class MaintenanceHubScreen extends ConsumerStatefulWidget {
  const MaintenanceHubScreen({super.key});

  @override
  ConsumerState<MaintenanceHubScreen> createState() => _MaintenanceHubScreenState();
}

class _MaintenanceHubScreenState extends ConsumerState<MaintenanceHubScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the app comes back to the foreground so a payment
    // confirmed in the gateway tab is reflected without a manual pull.
    if (state == AppLifecycleState.resumed) {
      _invalidateAll();
    }
  }

  void _invalidateAll() {
    ref.invalidate(residentBillingCycleProvider);
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    ref.invalidate(upiConfigProvider);
  }

  Future<void> _refresh() async {
    _invalidateAll();
    // Swallow per-future errors so a transient network blip on one
    // endpoint doesn't cancel the spinner before the others land. The
    // AsyncValue rendering paths surface the actual error inline.
    Future<void> swallow<T>(Future<T> f) =>
        f.then((_) {}).catchError((Object _) {});
    await Future.wait<void>([
      swallow(ref.read(residentBillingCycleProvider.future)),
      swallow(ref.read(pendingMaintenanceProvider.future)),
      swallow(ref.read(maintenanceHistoryProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(residentBillingCycleProvider);
    final pendingAsync = ref.watch(pendingMaintenanceProvider);
    final historyAsync = ref.watch(maintenanceHistoryProvider);

    // Show the full-page shimmer skeleton on initial load.
    final isInitialLoad = cycleAsync.isLoading &&
        pendingAsync.isLoading &&
        historyAsync.isLoading;

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Maintenance',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'View all history',
            icon: const Icon(Icons.history, color: DesignColors.textSecondary),
            onPressed: () => context.push('/resident/maintenance/history'),
          ),
        ],
      ),
      body: isInitialLoad
          ? const MaintenanceHubSkeleton()
          : RefreshIndicator(
              color: DesignColors.primary,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg + 4, // 20px
                  AppSpacing.sm,
                  AppSpacing.lg + 4,
                  AppSpacing.xl,
                ),
                children: [
                  _buildHero(cycleAsync, pendingAsync.valueOrNull ?? const []),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatRow(cycleAsync, pendingAsync.valueOrNull ?? const []),
                  const SizedBox(height: AppSpacing.lg),
                  _buildShortcutRow(pendingAsync.valueOrNull ?? const []),
                  const SizedBox(height: AppSpacing.lg + 4), // 20px before sections
                  _buildPendingSection(pendingAsync),
                  const SizedBox(height: AppSpacing.lg + 4),
                  _buildRecentSection(historyAsync),
                ],
              ),
            ),
    );
  }

  // ---- HERO ----

  Widget _buildHero(
    AsyncValue<BillingCycleCurrent> cycleAsync,
    List<MaintenanceDueModel> pending,
  ) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM y');

    return cycleAsync.when(
      loading: () => _heroSkeleton(),
      error: (e, _) => _heroError(e),
      data: (cycle) {
        if (cycle.maintenanceBillingExcluded) {
          return const MaintenanceStatusCard(
            kind: MaintenanceStatusKind.excluded,
            title: 'Maintenance not billed to you',
            subtitle:
                'Your villa\'s primary contact is billed for maintenance. You can view receipts and history here.',
          );
        }

        // Roll up everything the resident actually owes right now: the
        // current cycle's remaining due plus any prior overdue cycles.
        // Filter out the current cycle from pending to avoid double-counting
        // (the pending list already includes the current cycle when unpaid).
        final currentCycleId = cycle.cycleId;
        final priorPendingTotal = pending
            .where((e) =>
                currentCycleId == null ||
                currentCycleId.isEmpty ||
                e.cycleId != currentCycleId)
            .fold<double>(
              0,
              (acc, e) => acc + e.remainingDue,
            );
        final cycleDue = cycle.remainingDue ?? 0;
        final totalActionable = (cycleDue + priorPendingTotal).clamp(0, double.infinity).toDouble();
        final hasDues = totalActionable > 0.5;

        if (!hasDues && cycle.isPaid) {
          return MaintenanceStatusCard(
            kind: MaintenanceStatusKind.paid,
            title: cycle.title ?? 'All caught up',
            subtitle: 'Maintenance for the current cycle is fully paid.',
            amountLabel: 'Paid',
            amountValue: inr.format(cycle.paidAmount ?? cycle.expectedAmount ?? 0),
            dueDate: cycle.paymentEndUtc != null
                ? 'Cycle window ends ${dateFmt.format(cycle.paymentEndUtc!)}'
                : null,
          );
        }

        if (!hasDues) {
          return MaintenanceStatusCard(
            kind: MaintenanceStatusKind.upcoming,
            title: cycle.title ?? 'No dues right now',
            subtitle: 'Nothing is due — we\'ll notify you when the next cycle opens.',
            dueDate: cycle.paymentStartUtc != null
                ? 'Next window opens ${dateFmt.format(cycle.paymentStartUtc!)}'
                : null,
          );
        }

        final isOverdue = cycle.dueDateUtc != null && cycle.dueDateUtc!.isBefore(DateTime.now());
        final kind = isOverdue ? MaintenanceStatusKind.overdue : MaintenanceStatusKind.due;
        return MaintenanceStatusCard(
          kind: kind,
          title: isOverdue ? 'Payment overdue' : 'Payment due',
          subtitle: cycle.title ?? 'Outstanding maintenance balance',
          amountLabel: 'Total to pay',
          amountValue: inr.format(totalActionable),
          dueDate: cycle.dueDateUtc != null
              ? '${isOverdue ? 'Was due' : 'Due'} ${dateFmt.format(cycle.dueDateUtc!)}'
              : null,
          actionLabel: 'View details',
          onAction: () {
            final firstPending = pending.isNotEmpty ? pending.first : null;
            if (firstPending != null && firstPending.cycleId.isNotEmpty) {
              context.push('/resident/maintenance/cycle/${firstPending.cycleId}');
            } else {
              context.push('/resident/maintenance/dues');
            }
          },
        );
      },
    );
  }

  Widget _heroSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _heroError(Object e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.error.withValues(alpha: 0.06),
        border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: DesignColors.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Couldn\'t load your cycle',
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pull down to retry, or check your connection.',
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---- SHORTCUT ROW ----

  /// Two large-tap nav cards that route to the dedicated Dues / History
  /// screens. The hub keeps preview lists below; users who want focus on
  /// one task tap through here. Visually contrasts against the chip row
  /// (primary-tinted left, neutral right) so the eye sees them as
  /// "go somewhere" rather than "summary stat".
  Widget _buildShortcutRow(List<MaintenanceDueModel> pending) {
    final pendingCount = pending.where((p) => p.remainingDue > 0).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ShortcutCard(
                icon: Icons.receipt_long_outlined,
                label: 'My dues',
                tone: DesignColors.error,
                countBadge: pendingCount > 0 ? '$pendingCount' : null,
                onTap: () => context.push('/resident/maintenance/dues'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ShortcutCard(
                icon: Icons.history,
                label: 'My payments',
                tone: DesignColors.primary,
                onTap: () => context.push('/resident/maintenance/history'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ShortcutCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Society expenses',
                tone: DesignColors.textSecondary,
                onTap: () => context.push('/resident/expenses'),
              ),
            ),
            // Show "Pay via UPI" shortcut when VPA is configured
            if (_hasUpiVpa) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ShortcutCard(
                  icon: Icons.currency_rupee,
                  label: 'Pay via UPI',
                  tone: const Color(0xFF16A34A),
                  onTap: () {
                    final cycle = ref.read(residentBillingCycleProvider).valueOrNull;
                    final amount = cycle?.remainingDue?.toDouble();
                    final cycleId = cycle?.cycleId;
                    final now = DateTime.now();
                    final params = <String, String>{};
                    if (amount != null && amount > 0) params['amount'] = amount.toStringAsFixed(0);
                    params['month'] = '${now.month}';
                    params['year'] = '${now.year}';
                    if (cycleId != null && cycleId.isNotEmpty) params['cycleId'] = cycleId;
                    final query = '?${Uri(queryParameters: params).query}';
                    context.push('/resident/maintenance/upi-pay$query');
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  bool get _hasUpiVpa {
    final config = ref.watch(upiConfigProvider).valueOrNull;
    final vpa = config?['upiVpa']?.toString() ?? '';
    return vpa.isNotEmpty;
  }

  // ---- STAT ROW ----

  Widget _buildStatRow(
    AsyncValue<BillingCycleCurrent> cycleAsync,
    List<MaintenanceDueModel> pending,
  ) {
    final cycle = cycleAsync.valueOrNull;
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final thisMonth = (cycle?.totalDue ?? cycle?.remainingDue ?? 0).toDouble();
    final credit = (cycle?.availableCredit ?? 0).toDouble();
    final pendingCount = pending.where((p) => p.remainingDue > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MaintenanceStatChip(
                label: 'This cycle',
                value: inr.format(thisMonth),
                tone: thisMonth > 0
                    ? MaintenanceStatTone.warning
                    : MaintenanceStatTone.success,
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MaintenanceStatChip(
                label: 'Your credit',
                value: inr.format(credit),
                tone: credit > 0
                    ? MaintenanceStatTone.info
                    : MaintenanceStatTone.neutral,
                icon: Icons.savings_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MaintenanceStatChip(
                label: 'Pending bills',
                value: '$pendingCount',
                tone: pendingCount > 0
                    ? MaintenanceStatTone.warning
                    : MaintenanceStatTone.success,
                icon: Icons.pending_actions_outlined,
              ),
            ),
          ],
        ),
        if (credit > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Advance credit will auto-apply to your next bill',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: DesignColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  // ---- PENDING DUES ----

  Widget _buildPendingSection(AsyncValue<List<MaintenanceDueModel>> async) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        async.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Pending bills'),
              const SizedBox(height: AppSpacing.md),
              _listSkeleton(2),
            ],
          ),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Pending bills'),
              const SizedBox(height: AppSpacing.md),
              _listError('Pending bills'),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Pending bills'),
                  const SizedBox(height: AppSpacing.md),
                  _emptyTile(
                    icon: Icons.task_alt_outlined,
                    tone: DesignColors.success,
                    text: 'No pending bills. You\'re all caught up.',
                  ),
                ],
              );
            }
            // Cap the preview at 3 — anything more belongs on the dedicated
            // Dues screen, otherwise the hub becomes a long scroll on
            // residents with backlog. The trailing "View all" link makes
            // the rest reachable in one tap.
            const previewCount = 3;
            final preview = items.take(previewCount).toList();
            final hidden = items.length - preview.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Pending bills',
                  trailing: items.length > previewCount
                      ? TextButton(
                          onPressed: () => context.push('/resident/maintenance/dues'),
                          child: Text(
                            'View all (${items.length})',
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final m in preview) ...[
                  PaymentListTile(
                    title: m.title.isNotEmpty
                        ? m.title
                        : DateFormat('MMMM y').format(DateTime(m.year, m.month)),
                    subtitle: 'Cycle ${m.cycleKey}',
                    amount: m.remainingDue,
                    status: _pendingStatus(m),
                    dueDate: m.dueDate,
                    actionLabel: 'View',
                    onAction: () => _openCycleDetail(m),
                    onTap: () => _openCycleDetail(m),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (hidden > 0) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => context.push('/resident/maintenance/dues'),
                    style: TextButton.styleFrom(
                      foregroundColor: DesignColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'See $hidden more bill${hidden == 1 ? "" : "s"} →',
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ---- RECENT ACTIVITY ----

  Widget _buildRecentSection(AsyncValue<List<MaintenanceDueModel>> async) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Recent payments',
          trailing: TextButton(
            onPressed: () => context.push('/resident/maintenance/history'),
            child: Text(
              'View all',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        async.when(
          loading: () => _listSkeleton(3),
          error: (e, _) => _listError('Recent payments'),
          data: (items) {
            final paid = items.where((m) => m.status.toUpperCase() == 'PAID').toList()
              ..sort((a, b) {
                final ad = a.paidAt ?? a.dueDate;
                final bd = b.paidAt ?? b.dueDate;
                return bd.compareTo(ad);
              });
            final recent = paid.take(5).toList();
            if (recent.isEmpty) {
              return _emptyTile(
                icon: Icons.receipt_outlined,
                tone: DesignColors.textTertiary,
                text: 'No payments yet. Once you pay, it shows up here.',
              );
            }
            return Column(
              children: [
                for (final m in recent) ...[
                  PaymentListTile(
                    title: m.title.isNotEmpty
                        ? m.title
                        : DateFormat('MMMM y').format(DateTime(m.year, m.month)),
                    subtitle: _paymentBreakdown(m, inr),
                    amount: m.cashPaidAmount > 0 ? m.cashPaidAmount : m.paidAmount,
                    status: PaymentTileStatus.paid,
                    paidDate: m.paidAt,
                    onTap: () => _openCycleDetail(m),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ---- helpers ----

  PaymentTileStatus _pendingStatus(MaintenanceDueModel m) {
    final upper = m.status.toUpperCase();
    if (upper == 'PAID') return PaymentTileStatus.paid;
    if (upper == 'PARTIAL') return PaymentTileStatus.partial;
    if (m.isOverdue || m.dueDate.isBefore(DateTime.now())) {
      return PaymentTileStatus.overdue;
    }
    return PaymentTileStatus.pending;
  }

  String _paymentBreakdown(MaintenanceDueModel m, NumberFormat inr) {
    final paid = m.cashPaidAmount > 0 ? m.cashPaidAmount : m.paidAmount;
    final expected = m.expectedAmount;
    final diff = paid - expected;

    final parts = <String>['Expected ${inr.format(expected)}'];

    if (diff > 0.5) {
      parts.add('Advance ${inr.format(diff)}');
    } else if (diff < -0.5) {
      parts.add('Short ${inr.format(-diff)}');
    }

    return parts.join(' · ');
  }

  void _openCycleDetail(MaintenanceDueModel m) {
    if (m.cycleId.isEmpty) return;
    context.push('/resident/maintenance/cycle/${m.cycleId}');
  }

  Widget _listSkeleton(int count) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          Container(
            height: 84,
            decoration: BoxDecoration(
              color: DesignColors.surfaceSoft,
              borderRadius: BorderRadius.circular(DesignRadius.lg),
            ),
          ),
          if (i < count - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _listError(String label) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.error.withValues(alpha: 0.18)),
      ),
      child: Text(
        'Couldn\'t load $label. Pull down to retry.',
        style: DesignTypography.bodySmall.copyWith(
          color: DesignColors.error,
        ),
      ),
    );
  }

  Widget _emptyTile({
    required IconData icon,
    required Color tone,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone, size: 24),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Two-column "go somewhere" card. Distinct from the chip row — these
/// look like a button, scale on press, and lead to a focused screen.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.countBadge,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
  final String? countBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: Icon(icon, color: tone, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (countBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    countBadge!,
                    style: DesignTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right, color: DesignColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
