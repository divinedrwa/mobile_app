import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingMaintenanceProvider);

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
          'Outstanding bills',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _errorView(),
          data: (items) => items.isEmpty ? _emptyState() : _content(items),
        ),
      ),
      bottomNavigationBar: null,
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
      (acc, m) => acc + (m.remainingDue > 0 ? m.remainingDue : m.amount),
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
        ? const [Color(0xFFEF4444), Color(0xFFB91C1C)]
        : const [Color(0xFFF97316), Color(0xFFC2410C)];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
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
                child: const Icon(
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: DesignColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
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
}

/// Single bill card — visually richer than the hub's list tile so this
/// screen feels distinct. Carries a coloured urgency rail along the left
/// edge that turns red when overdue, amber when due soon.
class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.item,
    required this.inr,
    required this.onTap,
  });

  final MaintenanceDueModel item;
  final NumberFormat inr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = item.isOverdue || item.dueDate.isBefore(DateTime.now());
    final accent = overdue ? DesignColors.error : DesignColors.warning;
    final relative = _relativeDateLabel(item.dueDate, overdue: overdue);
    final amount = item.remainingDue > 0 ? item.remainingDue : item.amount;
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
                            Text(
                              'Due ${dateFmt.format(item.dueDate)}',
                              style: DesignTypography.caption.copyWith(
                                color: DesignColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
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
