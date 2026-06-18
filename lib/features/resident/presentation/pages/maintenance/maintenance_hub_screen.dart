import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../data/models/billing_cycle_current_model.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/payment_methods_provider.dart';
import '../../../data/providers/upi_payment_provider.dart';
import 'invoice_download_helper.dart';
import '../../widgets/maintenance/late_fee_reminder_card.dart';
import '../../widgets/maintenance/maintenance_hero_card.dart';
import '../../widgets/maintenance/maintenance_hub_skeleton.dart';
import '../../widgets/maintenance/maintenance_quick_actions.dart';
import '../../widgets/maintenance/maintenance_stat_group.dart';
import '../../widgets/maintenance/recent_payment_row.dart';
import '../../widgets/maintenance/where_money_goes_card.dart';

/// Resident-facing maintenance landing screen.
///
/// One scroll, rich overview:
///   1. Hero status banner (paid / due / overdue) driven by the billing cycle
///   2. Four stat chips (this cycle / credit / pending bills / due date)
///   3. Quick-action shortcuts
///   4. Payment-health card (on-time streak, computed from history)
///   5. Recent payments (with inline receipt download)
///   6. Late-fee reminder (when a fee applies after grace)
///   7. "Where your money goes" expense donut (real category breakdown)
///   8. Trust & transparency + raise-an-issue shortcuts
///   9. Sticky "Pay now" bar when there's an outstanding balance
class MaintenanceHubScreen extends ConsumerStatefulWidget {
  const MaintenanceHubScreen({super.key});

  @override
  ConsumerState<MaintenanceHubScreen> createState() =>
      _MaintenanceHubScreenState();
}

class _MaintenanceHubScreenState extends ConsumerState<MaintenanceHubScreen>
    with WidgetsBindingObserver {
  final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM y');

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
    // Refresh when the app returns to the foreground so a payment confirmed
    // in a gateway tab is reflected without a manual pull.
    if (state == AppLifecycleState.resumed) _invalidateAll();
  }

  String? _downloadingCycleId;

  // ---- receipt download ----

  Future<void> _downloadReceipt(MaintenanceDueModel m) async {
    if (_downloadingCycleId != null) return;
    await downloadOrViewInvoice(
      context: context,
      ref: ref,
      m: m,
      setBusy: (busy) {
        if (mounted) {
          setState(() => _downloadingCycleId = busy ? m.cycleId : null);
        }
      },
    );
  }

  // ---- refresh ----

  void _invalidateAll() {
    ref.invalidate(residentBillingCycleProvider);
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    ref.invalidate(outstandingDuesProvider);
    ref.invalidate(residentExpenseBreakdownProvider);
    ref.invalidate(upiConfigProvider);
  }

  Future<void> _refresh() async {
    _invalidateAll();
    Future<void> swallow<T>(Future<T> f) =>
        f.then((_) {}).catchError((Object _) {});
    await Future.wait<void>([
      swallow(ref.read(residentBillingCycleProvider.future)),
      swallow(ref.read(pendingMaintenanceProvider.future)),
      swallow(ref.read(maintenanceHistoryProvider.future)),
      swallow(ref.read(residentExpenseBreakdownProvider.future)),
    ]);
  }

  // ---- payment routing ----

  bool get _hasPaymentMethods {
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull;
    if (methods != null && methods.isNotEmpty) return true;
    final config = ref.watch(upiConfigProvider).valueOrNull;
    final vpa = config?['upiVpa']?.toString() ?? '';
    return vpa.isNotEmpty;
  }

  void _pushPayment(Map<String, String> params) {
    final query = '?${Uri(queryParameters: params).query}';
    final methods = ref.read(paymentMethodsListProvider).valueOrNull;
    final route = methods != null && methods.isNotEmpty
        ? '/resident/maintenance/pay$query'
        : '/resident/maintenance/upi-pay$query';
    context.push<bool>(route).then((paid) {
      if (paid == true && mounted) _refresh();
    });
  }

  void _payAll(List<MaintenanceDueModel> pending, double total) {
    if (pending.isEmpty) return;
    final oldest = pending.first;
    final months = pending
        .map((m) => DateFormat('MMM yyyy').format(DateTime(m.year, m.month)))
        .toList();
    _pushPayment({
      'amount': total.toStringAsFixed(0),
      'month': '${oldest.month}',
      'year': '${oldest.year}',
      'payAll': 'true',
      if (oldest.cycleId.isNotEmpty) 'cycleId': oldest.cycleId,
      'remark': months.length == 1
          ? 'Maintenance ${months.first}'
          : 'Maintenance: ${months.join(', ')}',
    });
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final cycleAsync = ref.watch(residentBillingCycleProvider);
    final pendingAsync = ref.watch(pendingMaintenanceProvider);
    final historyAsync = ref.watch(maintenanceHistoryProvider);

    final isInitialLoad = cycleAsync.isLoading &&
        pendingAsync.isLoading &&
        historyAsync.isLoading;

    final pending = pendingAsync.valueOrNull ?? const <MaintenanceDueModel>[];
    final history = historyAsync.valueOrNull ?? const <MaintenanceDueModel>[];
    final actionable =
        pending.where((e) => e.remainingDue > 0).toList(growable: false);
    final payableTotal =
        actionable.fold<double>(0, (acc, e) => acc + e.remainingDue);

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
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg + 4,
                  AppSpacing.sm,
                  AppSpacing.lg + 4,
                  payableTotal > 0.5 && _hasPaymentMethods ? 110 : AppSpacing.xl,
                ),
                children: [
                  _buildHero(cycleAsync, pending, history),
                  const SizedBox(height: AppSpacing.md),
                  MaintenanceStatGroup(
                    cycle: cycleAsync.valueOrNull,
                    pendingCount: actionable.length,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildQuickActions(actionable, history.length),
                  const SizedBox(height: AppSpacing.lg),
                  _buildHealthCard(historyAsync),
                  _buildRecentSection(historyAsync),
                  _buildLateFeeCard(cycleAsync.valueOrNull, payableTotal),
                  const WhereMoneyGoesCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTrustCard(history),
                  const SizedBox(height: AppSpacing.md),
                  _buildIssueCard(),
                ],
              ),
            ),
      bottomNavigationBar:
          _buildStickyPayBar(actionable, payableTotal),
    );
  }

  // ---- HERO ----

  Widget _buildHero(
    AsyncValue<BillingCycleCurrent> cycleAsync,
    List<MaintenanceDueModel> pending,
    List<MaintenanceDueModel> history,
  ) {
    final viewDetails = _viewDetailsAction(pending, history);
    return cycleAsync.when(
      loading: () => _heroSkeleton(),
      error: (e, _) => _heroError(),
      data: (cycle) {
        if (cycle.maintenanceBillingExcluded) {
          return const MaintenanceHeroCard(
            kind: MaintenanceHeroKind.excluded,
            title: 'Maintenance not billed to you',
            subtitle:
                'Your villa\'s primary contact is billed. You can still view receipts here.',
          );
        }

        final totalActionable = pending
            .where((e) => e.remainingDue > 0)
            .fold<double>(0, (acc, e) => acc + e.remainingDue);
        final hasDues = totalActionable > 0.5;
        final windowText = _cycleWindowText(cycle);

        if (!hasDues && cycle.isPaid) {
          final paid = (cycle.paidAmount ?? 0) > 0
              ? cycle.paidAmount!
              : (cycle.expectedAmount ?? cycle.totalDue ?? 0);
          return MaintenanceHeroCard(
            kind: MaintenanceHeroKind.paid,
            badgeLabel: 'Paid',
            title: cycle.title ?? 'Maintenance',
            subtitle: 'You\'re all set! This cycle is fully paid.',
            primaryLabel: 'Amount paid',
            primaryValue: _inr.format(paid),
            secondaryLabel: 'Next due on',
            onViewDetails: viewDetails,
            secondaryValue: cycle.dueDateUtc != null
                ? _dateFmt.format(cycle.dueDateUtc!)
                : null,
            windowText: windowText,
          );
        }

        if (!hasDues) {
          return MaintenanceHeroCard(
            kind: MaintenanceHeroKind.upcoming,
            title: cycle.title ?? 'No dues right now',
            subtitle: 'Nothing is due — we\'ll notify you when the next cycle opens.',
            secondaryLabel: 'Next window opens',
            secondaryValue: cycle.paymentStartUtc != null
                ? _dateFmt.format(cycle.paymentStartUtc!)
                : null,
            windowText: windowText,
          );
        }

        final isOverdue = cycle.dueDateUtc != null &&
            cycle.dueDateUtc!.isBefore(DateTime.now());
        return MaintenanceHeroCard(
          kind: isOverdue
              ? MaintenanceHeroKind.overdue
              : MaintenanceHeroKind.due,
          badgeLabel: isOverdue ? 'Overdue' : 'Due',
          title: cycle.title ?? 'Maintenance',
          subtitle: isOverdue
              ? 'Payment is past due — please clear it soon.'
              : 'You have an outstanding maintenance balance.',
          primaryLabel: 'Amount due',
          primaryValue: _inr.format(totalActionable),
          secondaryLabel: isOverdue ? 'Was due on' : 'Due on',
          secondaryValue: cycle.dueDateUtc != null
              ? _dateFmt.format(cycle.dueDateUtc!)
              : null,
          windowText: windowText,
          onViewDetails: viewDetails,
        );
      },
    );
  }

  String? _cycleWindowText(BillingCycleCurrent cycle) {
    final start = cycle.paymentStartUtc;
    final end = cycle.paymentEndUtc;
    if (start == null || end == null) return null;
    final fmt = DateFormat('d MMM');
    return 'Cycle window: ${fmt.format(start)} – ${_dateFmt.format(end)}';
  }

  /// Target for the hero's "View details" link. Kept distinct from the
  /// "My dues" shortcut: a single outstanding bill (or the latest paid one)
  /// opens its cycle breakdown; multiple outstanding bills open the dues list;
  /// nothing to show hides the link.
  VoidCallback? _viewDetailsAction(
    List<MaintenanceDueModel> pending,
    List<MaintenanceDueModel> history,
  ) {
    final actionable =
        pending.where((e) => e.remainingDue > 0 && e.cycleId.isNotEmpty).toList();
    if (actionable.length == 1) {
      final id = actionable.first.cycleId;
      return () => context.push('/resident/maintenance/cycle/$id');
    }
    if (actionable.length > 1) {
      return () => context.push('/resident/maintenance/dues');
    }
    // Paid / no dues: open the most recent paid cycle's breakdown.
    final paid = history
        .where((m) => m.status.toUpperCase() == 'PAID' && m.cycleId.isNotEmpty)
        .toList()
      ..sort((a, b) =>
          (b.paidAt ?? b.dueDate).compareTo(a.paidAt ?? a.dueDate));
    if (paid.isNotEmpty) {
      final id = paid.first.cycleId;
      return () => context.push('/resident/maintenance/cycle/$id');
    }
    return null;
  }

  Widget _heroSkeleton() => Container(
        height: 170,
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

  Widget _heroError() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: DesignColors.error.withValues(alpha: 0.06),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: DesignColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Couldn\'t load your cycle. Pull down to retry.',
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.textPrimary),
              ),
            ),
          ],
        ),
      );


  // ---- QUICK ACTIONS ----

  Widget _buildQuickActions(
      List<MaintenanceDueModel> actionable, int paymentsCount) {
    // "Pay now" is intentionally omitted — the sticky bottom bar is the pay
    // CTA when there's a balance. "More" (the advanced finance tabs) is hidden
    // too; everything residents need lives on this hub. Each remaining tile
    // points at a distinct screen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Quick actions'),
        const SizedBox(height: AppSpacing.sm),
        MaintenanceQuickActions(
          actions: [
            MaintenanceQuickAction(
              icon: Icons.receipt_long_outlined,
              label: 'My dues',
              tone: DesignColors.error,
              subLabel: actionable.isEmpty
                  ? 'No pending'
                  : '${actionable.length} pending',
              subTone: actionable.isEmpty
                  ? DesignColors.success
                  : DesignColors.error,
              onTap: () => context.push('/resident/maintenance/dues'),
            ),
            MaintenanceQuickAction(
              icon: Icons.history,
              label: 'My payments',
              tone: DesignColors.primary,
              subLabel: paymentsCount > 0 ? '$paymentsCount paid' : 'None yet',
              onTap: () => context.push('/resident/maintenance/history'),
            ),
            MaintenanceQuickAction(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Society expenses',
              tone: const Color(0xFF8B5CF6),
              subLabel: 'View reports',
              onTap: () => context.push('/resident/expenses'),
            ),
          ],
        ),
      ],
    );
  }

  // ---- PAYMENT HEALTH (computed achievement) ----

  Widget _buildHealthCard(AsyncValue<List<MaintenanceDueModel>> historyAsync) {
    final history = historyAsync.valueOrNull;
    if (history == null) return const SizedBox.shrink();

    // Consider only settled bills; on-time = paid on or before the due date.
    final paid = history
        .where((m) => m.status.toUpperCase() == 'PAID' && m.paidAt != null)
        .toList(growable: false);
    if (paid.isEmpty) return const SizedBox.shrink();

    final name = ref.watch(authProvider.select((s) => s.user?.name)) ?? '';
    final firstName = name.trim().split(RegExp(r'\s+')).first;

    // On-time timing is only meaningful when paidAt reflects when the resident
    // actually paid. When several bills share a single paidAt date, they were
    // bulk-recorded by an admin after the fact — the timing is unreliable, so
    // we show a neutral "all settled" rather than a misleading "0 on time".
    final paidDates = paid
        .map((m) => DateTime(m.paidAt!.year, m.paidAt!.month, m.paidAt!.day))
        .toSet();
    final timingReliable = paid.length < 2 || paidDates.length > 1;

    final int stars;
    final IconData? badgeIcon; // shown instead of stars when timing unreliable
    final String headline;
    final String detail;

    if (!timingReliable) {
      stars = 0;
      badgeIcon = Icons.verified_rounded;
      headline = firstName.isEmpty
          ? 'You\'re all settled'
          : 'You\'re all settled, $firstName!';
      detail = 'You\'ve paid all ${paid.length} of your bills.';
    } else {
      final onTime = paid
          .where((m) => !m.paidAt!.isAfter(_endOfDay(m.dueDate)))
          .length;
      final rate = onTime / paid.length;
      stars = rate >= 0.9 ? 3 : (rate >= 0.6 ? 2 : 1);
      badgeIcon = null;
      headline = firstName.isEmpty
          ? 'Nice work!'
          : (rate >= 0.9 ? 'Great going, $firstName!' : 'Keep it up, $firstName!');
      detail = paid.length == onTime
          ? 'You\'ve paid all $onTime of your bills on time.'
          : 'You\'ve paid $onTime of your last ${paid.length} bills on time.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          border: Border.all(color: DesignColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: DesignTypography.bodyMedium.copyWith(
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: DesignTypography.caption.copyWith(
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (badgeIcon != null)
              Icon(badgeIcon, size: 22, color: const Color(0xFF16A34A))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  // ---- RECENT PAYMENTS ----

  Widget _buildRecentSection(
      AsyncValue<List<MaintenanceDueModel>> historyAsync) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('Recent payments'),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    context.push('/resident/maintenance/history'),
                child: Text(
                  'View all',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          historyAsync.when(
            loading: () => _listSkeleton(3),
            error: (_, _) => _miniError('Couldn\'t load payments'),
            data: (items) {
              final paid = items
                  .where((m) => m.status.toUpperCase() == 'PAID')
                  .toList()
                ..sort((a, b) {
                  final ad = a.paidAt ?? a.dueDate;
                  final bd = b.paidAt ?? b.dueDate;
                  return bd.compareTo(ad);
                });
              final recent = paid.take(4).toList();
              if (recent.isEmpty) {
                return _emptyTile(
                  icon: Icons.receipt_outlined,
                  tone: DesignColors.textTertiary,
                  text: 'No payments yet. Once you pay, it shows up here.',
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                  border: Border.all(color: DesignColors.borderLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1,
                            thickness: 1,
                            color: DesignColors.borderLight),
                      RecentPaymentRow(
                        item: recent[i],
                        inr: _inr,
                        downloading:
                            _downloadingCycleId == recent[i].cycleId,
                        onTap: () => _openCycle(recent[i]),
                        onDownload: recent[i].cycleId.isNotEmpty
                            ? () => _downloadReceipt(recent[i])
                            : null,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openCycle(MaintenanceDueModel m) {
    if (m.cycleId.isEmpty) return;
    context.push('/resident/maintenance/cycle/${m.cycleId}');
  }

  // ---- LATE FEE ----

  Widget _buildLateFeeCard(BillingCycleCurrent? cycle, double payableTotal) {
    if (cycle == null || payableTotal <= 0.5) return const SizedBox.shrink();
    final fee = cycle.lateFee ?? 0;
    final byDate = cycle.dueDateUtc;
    if (fee <= 0 || byDate == null) return const SizedBox.shrink();
    // Only warn while we're still before the deadline.
    if (byDate.isBefore(DateTime.now())) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: LateFeeReminderCard(
        feeText: _inr.format(fee),
        byDate: byDate,
        dateFmt: _dateFmt,
        cycleId: cycle.cycleId ?? '',
      ),
    );
  }

  // ---- TRUST & TRANSPARENCY ----

  Widget _buildTrustCard(List<MaintenanceDueModel> history) {
    final society =
        ref.watch(authProvider.select((s) => s.user?.societyName)) ?? '';
    // Best-effort freshness: most recent recorded payment date.
    DateTime? latest;
    for (final m in history) {
      final d = m.paidAt;
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    final updated = latest != null ? _relativeTime(latest) : 'recently';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_outlined,
                size: 18, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trust & transparency',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Payments are gateway-verified. Records updated $updated'
                  '${society.isNotEmpty ? ' · maintained by $society' : ''}.',
                  style: DesignTypography.caption.copyWith(
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- RAISE AN ISSUE ----

  Widget _buildIssueCard() {
    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        onTap: () => context.push('/resident/complaint'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DesignColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    size: 18, color: DesignColors.warning),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have an issue with a bill?',
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Raise a query and we\'ll resolve it quickly.',
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: DesignColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---- STICKY PAY BAR ----

  Widget? _buildStickyPayBar(
      List<MaintenanceDueModel> actionable, double payableTotal) {
    if (payableTotal <= 0.5 || !_hasPaymentMethods) return null;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '100% secure payments',
                      style: DesignTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'UPI · Cards · Netbanking · Wallets',
                      style: DesignTypography.captionSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => _payAll(actionable, payableTotal),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF15803D),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.md),
                  ),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
                child: Text('Pay ${_inr.format(payableTotal)}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- shared bits ----

  Widget _sectionTitle(String title) => Text(
        title,
        style: DesignTypography.headingM.copyWith(
          color: DesignColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      );

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat('d MMM y').format(t);
  }

  Widget _listSkeleton(int count) => Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: DesignColors.surfaceSoft,
                borderRadius: BorderRadius.circular(DesignRadius.lg),
              ),
            ),
            if (i < count - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );

  Widget _miniError(String text) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: DesignColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.18)),
        ),
        child: Text(
          '$text. Pull down to retry.',
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.error),
        ),
      );

  Widget _emptyTile({
    required IconData icon,
    required Color tone,
    required String text,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
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
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.textSecondary),
            ),
          ],
        ),
      );
}
