import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/payment_methods_provider.dart';
import '../../../data/providers/upi_payment_provider.dart';
import 'invoice_download_helper.dart';
import '../../widgets/list_skeleton.dart';

/// Dedicated screen for the resident's outstanding bills.
///
/// Visual language is intentionally different from the hub:
///   - The hub is a dashboard (chips + lists), all states share equal weight.
///   - This screen is action-focused — one big "total to pay" hero, then
///     each bill as a card with relative-time urgency framing
///     ("3 days late", "Due in 4 days") instead of a raw date.
///
/// The primary CTA is a sticky bottom button. Empty state is a calm
/// success illustration, not the same minimal text the hub uses, so the
/// resident immediately knows which screen they're on.
class MyDuesScreen extends ConsumerStatefulWidget {
  const MyDuesScreen({super.key});

  @override
  ConsumerState<MyDuesScreen> createState() => _MyDuesScreenState();
}

class _MyDuesScreenState extends ConsumerState<MyDuesScreen>
    with WidgetsBindingObserver {
  String? _downloadingCycleId;

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
      ref.invalidate(pendingMaintenanceProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(pendingMaintenanceProvider);
    try {
      await ref.read(pendingMaintenanceProvider.future);
    } catch (_) {/* surfaced inline */}
  }

  /// True if at least one payment method is available (UPI VPA, bank, etc.).
  bool get _hasPaymentMethods {
    // Check new payment methods API first
    final methods = ref.watch(paymentMethodsListProvider).valueOrNull;
    if (methods != null && methods.isNotEmpty) return true;
    // Fallback: check legacy UPI config
    final config = ref.watch(upiConfigProvider).valueOrNull;
    final vpa = config?['upiVpa']?.toString() ?? '';
    return vpa.isNotEmpty;
  }

  void _navigateToPayment({
    required double amount,
    required int month,
    required int year,
    String? cycleId,
    String? remark,
    bool payAllPending = false,
  }) {
    final params = <String, String>{
      'amount': amount.toStringAsFixed(0),
      'month': '$month',
      'year': '$year',
    };
    if (payAllPending) params['payAll'] = 'true';
    if (cycleId != null && cycleId.isNotEmpty) params['cycleId'] = cycleId;
    if (remark != null && remark.isNotEmpty) params['remark'] = remark;
    final query = '?${Uri(queryParameters: params).query}';

    final methods = ref.read(paymentMethodsListProvider).valueOrNull;
    final route = methods != null && methods.isNotEmpty
        ? '/resident/maintenance/pay$query'
        : '/resident/maintenance/upi-pay$query';
    context.push<bool>(route).then((paid) {
      if (paid == true && mounted) {
        ref.invalidate(pendingMaintenanceProvider);
        ref.invalidate(outstandingDuesProvider);
        _refresh();
      }
    });
  }

  /// Build a human-readable remark for a single cycle.
  String _singleCycleRemark(MaintenanceDueModel m) {
    if (m.title.isNotEmpty) return m.title;
    return 'Maintenance ${DateFormat('MMM yyyy').format(DateTime(m.year, m.month))}';
  }

  /// Build a remark listing all months when paying multiple cycles.
  String _allCyclesRemark(List<MaintenanceDueModel> items) {
    if (items.length == 1) return _singleCycleRemark(items.first);
    final months = items
        .map((m) => DateFormat('MMM yyyy').format(DateTime(m.year, m.month)))
        .toList();
    return 'Maintenance: ${months.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingMaintenanceProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surface.defaultSurface,
        leading: IconButton(
          tooltip: 'Go back',
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Outstanding bills',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
            ),
            Text(
              'Pay your maintenance dues',
              style: TextStyle(fontSize: 12, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: async.when(
          loading: () => const ListSkeleton(itemHeight: 120),
          error: (_, _) => _errorView(),
          data: (items) => items.isEmpty ? _emptyState() : _content(items),
        ),
      ),
      bottomNavigationBar: async.whenOrNull(
        data: (items) {
          if (items.isEmpty || !_hasPaymentMethods) return null;
          final total = items.fold<double>(0, (acc, m) => acc + m.remainingDue);
          if (total <= 0) return null;
          final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
          // For "Pay All", use the oldest pending bill's month/year
          final oldest = items.first;
          return Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              border: Border(top: BorderSide(color: DesignColors.borderLight)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _navigateToPayment(
                    amount: total,
                    month: oldest.month,
                    year: oldest.year,
                    cycleId: oldest.cycleId,
                    remark: _allCyclesRemark(items),
                    payAllPending: true,
                  ),
                  icon: const Icon(Icons.currency_rupee, size: 18),
                  label: Text(
                    'Pay all ${inr.format(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- content ----

  Widget _content(List<MaintenanceDueModel> rawItems) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Sort: overdue first (most-overdue at top), then upcoming by nearest
    // due date. Residents triage by urgency, not by cycle order.
    final items = [...rawItems]
      ..sort((a, b) {
        final ad = a.dueDate;
        final bd = b.dueDate;
        return ad.compareTo(bd);
      });

    final total = items.fold<double>(
      0,
      (acc, m) => acc + m.remainingDue,
    );
    final hasOverdue = items.any((m) => _isOverdue(m));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxxl,
      ),
      children: [
        _heroTotal(total: total, hasOverdue: hasOverdue, count: items.length),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                '${items.length} bill${items.length == 1 ? "" : "s"}',
                style: DesignTypography.bodyMedium.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Sorted by urgency',
                style: DesignTypography.caption.copyWith(
                  color: DesignColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < items.length; i++) ...[
          _DueCard(
            item: items[i],
            inr: inr,
            onTap: () => _open(items[i]),
            showPay: _hasPaymentMethods,
            onPay: () => _navigateToPayment(
              amount: items[i].remainingDue,
              month: items[i].month,
              year: items[i].year,
              cycleId: items[i].cycleId,
              remark: _singleCycleRemark(items[i]),
            ),
            downloading: _downloadingCycleId == items[i].cycleId,
            onDownload: items[i].cycleId.isNotEmpty
                ? () => _downloadInvoice(items[i])
                : null,
          ).animate(delay: Duration(milliseconds: 60 * i)).fadeIn(duration: 220.ms).slideX(
                begin: 0.04,
                end: 0,
                duration: 240.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _heroTotal({
    required double total,
    required bool hasOverdue,
    required int count,
  }) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final gradient = hasOverdue
        ? [DesignColors.error, Color(0xFFB91C1C)]
        : const [Color(0xFFF97316), Color(0xFFC2410C)];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                hasOverdue ? 'Action needed' : 'Outstanding',
                style: DesignTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'TOTAL TO PAY',
            style: DesignTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            inr.format(total),
            style: DesignTypography.headingXL.copyWith(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count bill${count == 1 ? "" : "s"} pending'
            '${hasOverdue ? " · some past due" : ""}',
            style: DesignTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(
          begin: 0.04,
          end: 0,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 44,
                  color: DesignColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'You\'re all settled',
                style: DesignTypography.headingM.copyWith(
                  color: const Color(0xFF14532D),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No outstanding maintenance bills right now. We\'ll let you know when the next cycle opens.',
                textAlign: TextAlign.center,
                style: DesignTypography.bodySmall.copyWith(
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: DesignColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: DesignColors.error),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Couldn\'t load your bills',
                    style: TextStyle(
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
        ),
      ],
    );
  }

  // ---- helpers ----

  bool _isOverdue(MaintenanceDueModel m) =>
      m.isOverdue || m.dueDate.isBefore(DateTime.now());

  void _open(MaintenanceDueModel m) {
    if (m.cycleId.isEmpty) return;
    context.push('/resident/maintenance/cycle/${m.cycleId}');
  }

  Future<void> _downloadInvoice(MaintenanceDueModel m) async {
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
}

/// Single bill card — visually richer than the hub's list tile so this
/// screen feels distinct. Carries a coloured urgency rail along the left
/// edge that turns red when overdue, amber when due soon.
class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.item,
    required this.inr,
    required this.onTap,
    this.showPay = false,
    this.onPay,
    this.downloading = false,
    this.onDownload,
  });

  final MaintenanceDueModel item;
  final NumberFormat inr;
  final VoidCallback onTap;
  final bool showPay;
  final VoidCallback? onPay;
  final bool downloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue || item.dueDate.isBefore(DateTime.now());
    final accent = overdue ? DesignColors.error : DesignColors.warning;
    final relative = _relativeDateLabel(item.dueDate, overdue: overdue);
    final amount = item.remainingDue;
    final dateFmt = DateFormat('d MMM y');

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(DesignRadius.lg),
                      bottomLeft: Radius.circular(DesignRadius.lg),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title.isNotEmpty
                                    ? item.title
                                    : DateFormat('MMMM y')
                                        .format(DateTime(item.year, item.month)),
                                style: DesignTypography.bodyMedium.copyWith(
                                  color: DesignColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              inr.format(amount),
                              style: DesignTypography.bodyMedium.copyWith(
                                color: DesignColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cycle ${item.cycleKey}',
                          style: DesignTypography.caption.copyWith(
                            color: DesignColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                relative,
                                style: DesignTypography.caption.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Due ${dateFmt.format(item.dueDate)}',
                                style: DesignTypography.caption.copyWith(
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                            ),
                            if (showPay && onPay != null)
                              SizedBox(
                                height: 30,
                                child: FilledButton(
                                  onPressed: onPay,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: DesignColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('Pay'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (onDownload != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      tooltip: 'Download invoice',
                      onPressed: downloading ? null : onDownload,
                      icon: downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.download_rounded,
                              size: 22, color: DesignColors.primary),
                    ),
                  )
                else if (!showPay)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: DesignColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeDateLabel(DateTime due, {required bool overdue}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    if (overdue) {
      if (diff == 0) return 'Due today';
      final days = diff.abs();
      return '$days day${days == 1 ? "" : "s"} late';
    }
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return 'Due in $diff days';
  }
}
