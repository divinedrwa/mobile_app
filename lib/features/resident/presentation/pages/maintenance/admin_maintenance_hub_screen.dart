import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../widgets/maintenance/maintenance_stat_chip.dart';
import '../../widgets/maintenance/payment_list_tile.dart';

/// Admin-facing maintenance overview.
///
/// Three things admins do most on mobile, in order of frequency:
///   1. Glance at "did the money come in this month?"
///   2. Spot which residents still owe and chase them.
///   3. Mark a cash payment one of them just handed over.
///
/// This screen optimises for those three. Cycle/FY generation, bank
/// reconciliation, and bulk reports stay on the existing detailed screen
/// — there's an "Open detailed view" link at the top right that jumps
/// straight to it. We deliberately don't try to replicate the 3.5k-line
/// finance screen here; this is the daily-driver hub on top.
class AdminMaintenanceHubScreen extends ConsumerStatefulWidget {
  const AdminMaintenanceHubScreen({super.key});

  @override
  ConsumerState<AdminMaintenanceHubScreen> createState() =>
      _AdminMaintenanceHubScreenState();
}

class _AdminMaintenanceHubScreenState
    extends ConsumerState<AdminMaintenanceHubScreen>
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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(maintenanceDashboardProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(maintenanceDashboardProvider);
    try {
      await ref.read(maintenanceDashboardProvider.future);
    } catch (_) {/* surfaced inline */}
  }

  void _shiftMonth(int delta) {
    final cur = ref.read(maintenanceDashboardFilterProvider);
    final shifted = DateTime(cur.year, cur.month + delta, 1);
    ref.read(maintenanceDashboardFilterProvider.notifier).state = cur.copyWith(
      month: shifted.month,
      year: shifted.year,
      // Period changes invalidate any sticky cycle id from the prior month.
      clearCollectionCycleId: true,
      clearBillingCycleId: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(maintenanceDashboardFilterProvider);
    final dashboardAsync = ref.watch(maintenanceDashboardProvider);
    final periodLabel = DateFormat('MMMM y').format(DateTime(filter.year, filter.month));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Society maintenance',
              style: DesignTypography.headingM.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              periodLabel,
              style: DesignTypography.caption.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Detailed finance view',
            icon: const Icon(Icons.tune, color: DesignColors.textSecondary),
            onPressed: () => context.push('/resident/maintenance-payment'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: [
            _periodNav(filter, periodLabel),
            const SizedBox(height: AppSpacing.lg),
            dashboardAsync.when(
              loading: () => _heroSkeleton(),
              error: (_, _) => _errorTile('Couldn\'t load this month\'s overview'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _snapshotHero(data),
                  const SizedBox(height: AppSpacing.lg),
                  _statRow(data),
                  const SizedBox(height: AppSpacing.lg),
                  _quickActions(),
                  const SizedBox(height: AppSpacing.xl),
                  _residentsSection(data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- period nav ----

  Widget _periodNav(MaintenanceDashboardFilter filter, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left, color: DesignColors.textSecondary),
            onPressed: () => _shiftMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right, color: DesignColors.textSecondary),
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
    );
  }

  // ---- hero ----

  Widget _snapshotHero(Map<String, dynamic> data) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final summary = (data['summary'] as Map?) ?? const {};
    final fund = (data['fund'] as Map?) ?? const {};

    final expected = (summary['totalExpected'] as num?)?.toDouble() ?? 0;
    final collected = (summary['collected'] as num?)?.toDouble() ?? 0;
    final cycleCash = (summary['cycleCashCollected'] as num?)?.toDouble() ?? collected;
    final balance = (fund['currentFundBalance'] as num?)?.toDouble() ?? 0;
    final rate = expected > 0 ? (collected / expected).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignColors.primaryLight, DesignColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLLECTED THIS CYCLE',
            style: DesignTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                inr.format(cycleCash),
                style: DesignTypography.headingXL.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${inr.format(expected)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(rate * 100).round()}% of expected',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Fund balance ${inr.format(balance)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  Widget _heroSkeleton() => Container(
        height: 160,
        decoration: BoxDecoration(
          color: DesignColors.surfaceSoft,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: const Center(
          child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );

  // ---- stat row ----

  Widget _statRow(Map<String, dynamic> data) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final summary = (data['summary'] as Map?) ?? const {};
    final fund = (data['fund'] as Map?) ?? const {};
    final paid = (summary['paidCount'] as num?)?.toInt() ?? 0;
    final pending = (summary['unpaidCount'] as num?)?.toInt() ?? 0;
    final credit = (fund['totalAdvanceCredit'] as num?)?.toDouble() ?? 0;

    return Row(
      children: [
        Expanded(
          child: MaintenanceStatChip(
            label: 'Paid',
            value: '$paid',
            tone: MaintenanceStatTone.success,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MaintenanceStatChip(
            label: 'Pending',
            value: '$pending',
            tone: pending > 0 ? MaintenanceStatTone.warning : MaintenanceStatTone.neutral,
            icon: Icons.pending_actions_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MaintenanceStatChip(
            label: 'Credit pool',
            value: inr.format(credit),
            tone: credit > 0 ? MaintenanceStatTone.info : MaintenanceStatTone.neutral,
            icon: Icons.savings_outlined,
          ),
        ),
      ],
    );
  }

  // ---- quick actions ----

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.notifications_active_outlined,
            label: 'Send reminders',
            tone: DesignColors.primary,
            onPressed: _onSendReminders,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.tune,
            label: 'Detailed view',
            tone: DesignColors.textSecondary,
            onPressed: () => context.push('/resident/maintenance-payment'),
          ),
        ),
      ],
    );
  }

  Future<void> _onSendReminders() async {
    final repo = ref.read(maintenanceRepositoryProvider);
    final filter = ref.read(maintenanceDashboardFilterProvider);
    try {
      final result = await repo.sendDuesReminders(
        month: filter.month,
        year: filter.year,
        maintenanceCollectionCycleId: filter.maintenanceCollectionCycleId,
      );
      if (!mounted) return;
      final notified = (result['notified'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.primary,
          content: Text(
            notified > 0
                ? 'Reminded $notified resident${notified == 1 ? "" : "s"}'
                : 'No residents to remind for this period',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.error,
          content: Text('Couldn\'t send reminders: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---- residents list ----

  Widget _residentsSection(Map<String, dynamic> data) {
    final residents = ((data['residents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (residents.isEmpty) {
      return _emptyResidents();
    }

    final paid = <Map<String, dynamic>>[];
    final partial = <Map<String, dynamic>>[];
    final pending = <Map<String, dynamic>>[];
    final overdue = <Map<String, dynamic>>[];
    for (final r in residents) {
      final s = (r['status']?.toString() ?? 'PENDING').toUpperCase();
      if (s == 'PAID') {
        paid.add(r);
      } else if (s == 'PARTIAL') {
        partial.add(r);
      } else if (s == 'OVERDUE') {
        overdue.add(r);
      } else {
        pending.add(r);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Residents',
            style: DesignTypography.headingM.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (overdue.isNotEmpty)
          _statusGroup(label: 'Overdue', residents: overdue, status: PaymentTileStatus.overdue),
        if (pending.isNotEmpty)
          _statusGroup(label: 'Pending', residents: pending, status: PaymentTileStatus.pending),
        if (partial.isNotEmpty)
          _statusGroup(label: 'Partial', residents: partial, status: PaymentTileStatus.partial),
        if (paid.isNotEmpty)
          _statusGroup(label: 'Paid', residents: paid, status: PaymentTileStatus.paid),
      ],
    );
  }

  Widget _statusGroup({
    required String label,
    required List<Map<String, dynamic>> residents,
    required PaymentTileStatus status,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _CollapsibleGroup(
        label: label,
        count: residents.length,
        child: Column(
          children: [
            for (final r in residents) ...[
              _residentRow(r, status),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _residentRow(Map<String, dynamic> r, PaymentTileStatus status) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villaNumber = r['villaNumber']?.toString() ?? '—';
    final ownerName = r['ownerName']?.toString() ?? 'Unknown';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final paidToward = (r['paidTowardCycle'] as num?)?.toDouble();
    final advanceCredit = (r['advanceCredit'] as num?)?.toDouble() ?? 0;
    final dueDate = DateTime.tryParse(r['dueDate']?.toString() ?? '');
    final paidAt = DateTime.tryParse(r['paidAt']?.toString() ?? '');

    final actionable = status == PaymentTileStatus.pending ||
        status == PaymentTileStatus.overdue ||
        status == PaymentTileStatus.partial;

    String subtitle;
    if (paidToward != null && paidToward > 0) {
      subtitle = '$ownerName · ${inr.format(paidToward)} of ${inr.format(amount)}';
    } else {
      subtitle = ownerName;
    }
    if (advanceCredit > 0) {
      subtitle += ' · Credit: ${inr.format(advanceCredit)}';
    }

    return PaymentListTile(
      title: 'Villa $villaNumber',
      subtitle: subtitle,
      amount: amount,
      status: status,
      dueDate: status == PaymentTileStatus.paid ? null : dueDate,
      paidDate: status == PaymentTileStatus.paid ? paidAt : null,
      actionLabel: actionable ? 'Mark paid' : null,
      onAction: actionable ? () => _openMarkCashSheet(r) : null,
    );
  }

  Future<void> _openMarkCashSheet(Map<String, dynamic> resident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarkCashSheet(resident: resident),
    );
    // Refresh after a successful mark-cash to reflect the new status.
    ref.invalidate(maintenanceDashboardProvider);
  }

  Widget _emptyResidents() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: DesignColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 32,
              color: DesignColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No residents in this period',
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generate snapshots for the cycle from the detailed finance view to populate this list.',
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorTile(String label) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: DesignColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$label. Pull down to retry.',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tone, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleGroup extends StatefulWidget {
  const _CollapsibleGroup({
    required this.label,
    required this.count,
    required this.child,
  });

  final String label;
  final int count;
  final Widget child;

  @override
  State<_CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<_CollapsibleGroup> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: DesignTypography.bodyMedium.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DesignColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down, color: DesignColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: widget.child,
            ),
            crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet for marking a payment against a single resident.
/// Posts to `/maintenance-management/mark-paid` via the existing repository.
class _MarkCashSheet extends ConsumerStatefulWidget {
  const _MarkCashSheet({required this.resident});

  final Map<String, dynamic> resident;

  @override
  ConsumerState<_MarkCashSheet> createState() => _MarkCashSheetState();
}

const _paymentModes = <String, String>{
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CHEQUE': 'Cheque',
};

class _MarkCashSheetState extends ConsumerState<_MarkCashSheet> {
  final _amountCtl = TextEditingController();
  final _remarksCtl = TextEditingController();
  String _paymentMode = 'CASH';
  bool _busy = false;
  String? _error;

  double get _advanceCredit =>
      (widget.resident['advanceCredit'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    final amount = (widget.resident['amount'] as num?)?.toDouble() ?? 0;
    final paidToward =
        (widget.resident['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    final remaining = (amount - paidToward).clamp(0, double.infinity);
    if (remaining > 0) {
      _amountCtl.text = remaining.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _remarksCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inr =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villa = widget.resident['villaNumber']?.toString() ?? '—';
    final owner = widget.resident['ownerName']?.toString() ?? 'Unknown';
    final amount = (widget.resident['amount'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DesignRadius.xl)),
        ),
        child: SingleChildScrollView(
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Record payment',
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Villa $villa · $owner · expected ${inr.format(amount)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              if (_advanceCredit > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                    borderRadius: BorderRadius.circular(DesignRadius.sm),
                  ),
                  child: Text(
                    'Advance credit available: ${inr.format(_advanceCredit)}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _amountCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment mode',
                  border: OutlineInputBorder(),
                ),
                items: _paymentModes.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _paymentMode = v);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _remarksCtl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'e.g. cash handed over at gate',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: DesignTypography.bodySmall
                      .copyWith(color: DesignColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (_advanceCredit > 0) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _submitApplyCredit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF166534),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DesignRadius.md),
                      ),
                    ),
                    child: Text(
                      'Apply credit only (no cash)',
                      style: DesignTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Confirm payment',
                              style: DesignTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(maintenanceDashboardFilterProvider);
      await ref.read(maintenanceRepositoryProvider).markPaidCash(
            villaId: villaId,
            month: filter.month,
            year: filter.year,
            amount: amount,
            paymentMode: _paymentMode,
            remarks: _remarksCtl.text.trim().isEmpty
                ? null
                : _remarksCtl.text.trim(),
            maintenanceCollectionCycleId:
                filter.maintenanceCollectionCycleId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            'Recorded ₹${amount.toStringAsFixed(0)} for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t record payment: $e';
      });
    }
  }

  Future<void> _submitApplyCredit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(maintenanceDashboardFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      final result =
          await ref.read(maintenanceRepositoryProvider).applyCredit(
                villaId: villaId,
                maintenanceCollectionCycleId: cycleId,
              );
      if (!mounted) return;
      Navigator.of(context).pop();
      final applied = result['creditApplied'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            '₹${(applied as num).toStringAsFixed(0)} credit applied for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t apply credit: $e';
      });
    }
  }
}
