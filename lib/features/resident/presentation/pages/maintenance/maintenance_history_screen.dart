import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../widgets/maintenance/payment_list_tile.dart';

/// Full payment history with year filter + month grouping.
///
/// We deliberately group by calendar month (`year-month` of `paidAt` or
/// `dueDate` if not paid) rather than by financial year cycle: residents
/// scan their personal records by "what did I pay in March?", not by FY
/// cycle keys. The FY filter at the top still scopes everything inside.
class MaintenanceHistoryScreen extends ConsumerStatefulWidget {
  const MaintenanceHistoryScreen({super.key});

  @override
  ConsumerState<MaintenanceHistoryScreen> createState() =>
      _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState
    extends ConsumerState<MaintenanceHistoryScreen> {
  /// Active filter — "All" plus distinct fiscal-year labels found in the
  /// fetched data. Initialized to `_allFilter` so first paint shows
  /// everything; the user can narrow once they see the dropdown options.
  String _filter = _allFilter;
  static const _allFilter = '__all__';

  Future<void> _refresh() async {
    ref.invalidate(maintenanceHistoryProvider);
    try {
      await ref.read(maintenanceHistoryProvider.future);
    } catch (_) {/* surfaced inline */}
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(maintenanceHistoryProvider);

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
          'Payment history',
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
          error: (e, _) => _errorView(e),
          data: (items) => _content(items),
        ),
      ),
    );
  }

  Widget _content(List<MaintenanceDueModel> raw) {
    // Group by calendar month for the visible buckets.
    final fyOptions = _fiscalYearOptions(raw);
    final filtered = _filter == _allFilter
        ? raw
        : raw.where((m) => _fyLabelForCycle(m) == _filter).toList();

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (fyOptions.isNotEmpty) _filterRow(fyOptions),
          const SizedBox(height: AppSpacing.xxl),
          _emptyState(),
        ],
      );
    }

    final byMonth = _groupByMonth(filtered);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        if (fyOptions.isNotEmpty) _filterRow(fyOptions),
        const SizedBox(height: AppSpacing.lg),
        for (final entry in byMonth.entries) ...[
          _monthHeader(entry.key, entry.value),
          const SizedBox(height: AppSpacing.sm),
          for (final m in entry.value) ...[
            PaymentListTile(
              title: m.title.isNotEmpty
                  ? m.title
                  : DateFormat('MMMM y').format(DateTime(m.year, m.month)),
              subtitle: 'Cycle ${m.cycleKey}',
              amount: _displayAmount(m),
              status: _status(m),
              dueDate: m.paidAt == null ? m.dueDate : null,
              paidDate: m.paidAt,
              onTap: () => _open(m),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  // ---- helpers ----

  Widget _filterRow(List<String> fyOptions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _filterChip(label: 'All', active: _filter == _allFilter, onTap: () {
            setState(() => _filter = _allFilter);
          }),
          const SizedBox(width: AppSpacing.sm),
          for (final fy in fyOptions) ...[
            _filterChip(
              label: fy,
              active: _filter == fy,
              onTap: () => setState(() => _filter = fy),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? DesignColors.primary : DesignColors.surface,
          border: Border.all(
            color: active ? DesignColors.primary : DesignColors.borderLight,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: DesignTypography.bodySmall.copyWith(
            color: active ? Colors.white : DesignColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _monthHeader(String monthKey, List<MaintenanceDueModel> items) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = items.fold<double>(0, (a, b) => a + _displayAmount(b));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            monthKey,
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            inr.format(total),
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
              Icons.receipt_long_outlined,
              size: 32,
              color: DesignColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No payments yet',
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Once you pay a maintenance bill, the receipt will appear here.',
            textAlign: TextAlign.center,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(Object e) {
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
                    'Couldn\'t load history',
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

  // ---- data shaping ----

  Map<String, List<MaintenanceDueModel>> _groupByMonth(
    List<MaintenanceDueModel> items,
  ) {
    final fmt = DateFormat('MMMM y');
    items.sort((a, b) {
      final ad = a.paidAt ?? a.dueDate;
      final bd = b.paidAt ?? b.dueDate;
      return bd.compareTo(ad);
    });
    final out = <String, List<MaintenanceDueModel>>{};
    for (final m in items) {
      final d = m.paidAt ?? m.dueDate;
      final key = fmt.format(d);
      out.putIfAbsent(key, () => []).add(m);
    }
    return out;
  }

  List<String> _fiscalYearOptions(List<MaintenanceDueModel> items) {
    final s = <String>{};
    for (final m in items) {
      final fy = _fyLabelForCycle(m);
      if (fy.isNotEmpty) s.add(fy);
    }
    final list = s.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Best-effort FY label derived from `cycleKey` (`YYYY-MM`). Indian
  /// financial year runs Apr→Mar so a March cycle belongs to FY of the
  /// preceding April. Falls back to `m.year` if cycleKey is missing.
  String _fyLabelForCycle(MaintenanceDueModel m) {
    final raw = m.cycleKey.isNotEmpty
        ? m.cycleKey
        : '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
    final parts = raw.split('-');
    if (parts.length < 2) return '';
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    if (y == null || mo == null) return '';
    final fyStart = mo >= 4 ? y : y - 1;
    final fyEnd = (fyStart + 1) % 100;
    return 'FY $fyStart–${fyEnd.toString().padLeft(2, '0')}';
  }

  PaymentTileStatus _status(MaintenanceDueModel m) {
    final upper = m.status.toUpperCase();
    if (upper == 'PAID') return PaymentTileStatus.paid;
    if (upper == 'PARTIAL') return PaymentTileStatus.partial;
    if (m.isOverdue || m.dueDate.isBefore(DateTime.now())) {
      return PaymentTileStatus.overdue;
    }
    return PaymentTileStatus.pending;
  }

  double _displayAmount(MaintenanceDueModel m) {
    final paid = m.cashPaidAmount > 0 ? m.cashPaidAmount : m.paidAmount;
    if (paid > 0) return paid;
    return m.amount;
  }

  void _open(MaintenanceDueModel m) {
    if (m.cycleId.isEmpty) return;
    context.push('/resident/maintenance/cycle/${m.cycleId}');
  }
}
