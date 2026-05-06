import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/billing_cycle_current_model.dart';
import '../../data/models/maintenance_due_model.dart';
import '../../data/providers/maintenance_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Some gateways or proxies wrap JSON as `{ "data": { ... } }` — normalize for the UI.
Map<String, dynamic> _normalizeDashboardPayload(Map<String, dynamic> raw) {
  final nested = raw['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return raw;
}

/// Maintenance Financial Dashboard Screen
class MaintenancePaymentScreen extends ConsumerStatefulWidget {
  const MaintenancePaymentScreen({super.key});

  @override
  ConsumerState<MaintenancePaymentScreen> createState() =>
      _MaintenancePaymentScreenState();
}

enum _HistoryFilterMode { monthly, yearly }

enum _ResidentStatusFilter { all, paid, unpaid }

class _MaintenancePaymentScreenState
    extends ConsumerState<MaintenancePaymentScreen> {
  _HistoryFilterMode _historyFilterMode = _HistoryFilterMode.monthly;
  _ResidentStatusFilter _residentStatusFilter = _ResidentStatusFilter.all;
  bool _appliedInitialQueryFilter = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialQueryFilter) return;
    _appliedInitialQueryFilter = true;

    final uri = GoRouterState.of(context).uri;
    final month = int.tryParse(uri.queryParameters['month'] ?? '');
    final year = int.tryParse(uri.queryParameters['year'] ?? '');
    if (month == null || year == null) return;
    if (month < 1 || month > 12 || year < 2000 || year > 2100) return;

    final current = ref.read(maintenanceDashboardFilterProvider);
    if (current.month == month && current.year == year) return;
    ref.read(maintenanceDashboardFilterProvider.notifier).state =
        current.copyWith(month: month, year: year);
    ref.invalidate(maintenanceDashboardProvider);
  }

  Future<void> _pullRefreshMaintenance() async {
    ref.invalidate(maintenanceDashboardProvider);
    ref.invalidate(pendingMaintenanceProvider);
    try {
      await ref.read(maintenanceDashboardProvider.future);
    } catch (_) {}
    try {
      await ref.read(pendingMaintenanceProvider.future);
    } catch (_) {}
  }

  Widget _wrapTabWithRefresh(Widget scrollable) {
    return RefreshIndicator(
      color: DesignColors.primary,
      displacement: 44,
      onRefresh: _pullRefreshMaintenance,
      child: scrollable,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(maintenanceDashboardProvider);
    final billingCycleAsync = ref.watch(residentBillingCycleProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRole.admin;
    final filter = ref.watch(maintenanceDashboardFilterProvider);
    const tabs = ['All Residents', 'My Payments', 'My Dues'];
    final periodLabel =
        '${DateFormat('MMMM').format(DateTime(2000, filter.month))} ${filter.year}';

    return DefaultTabController(
      length: tabs.length,
      initialIndex: 0,
      child: Scaffold(
        backgroundColor: DesignColors.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: DesignColors.surface,
          surfaceTintColor: DesignColors.surface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin ? 'Maintenance finance' : 'Maintenance & payments',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                periodLabel,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: DesignColors.primary,
            unselectedLabelColor: DesignColors.textSecondary,
            indicatorColor: DesignColors.primary,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: dashboardState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => LayoutBuilder(
            builder: (context, constraints) {
              final h =
                  MediaQuery.sizeOf(context).height - kToolbarHeight - 140;
              return RefreshIndicator(
                color: DesignColors.primary,
                onRefresh: _pullRefreshMaintenance,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    SizedBox(
                      height: h.clamp(220, 560),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 52,
                              color: DesignColors.error,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              userFacingMessage(
                                error,
                                'Failed to load maintenance data',
                              ),
                              textAlign: TextAlign.center,
                              style: DesignTypography.bodySmall.copyWith(
                                height: 1.4,
                                color: DesignColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () {
                                ref.invalidate(maintenanceDashboardProvider);
                                ref.invalidate(pendingMaintenanceProvider);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          data: (dashboard) {
            final root = _normalizeDashboardPayload(dashboard);
            final userSummary = Map<String, dynamic>.from(
              (root['userSummary'] ?? root['summary'] ?? const {}) as Map,
            );
            final paymentHistory = ((root['paymentHistory'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .map((e) {
                  final paymentDate = DateTime.tryParse(
                    e['paymentDate']?.toString() ?? '',
                  );
                  final month = (e['month'] as num?)?.toInt() ?? 0;
                  final year = (e['year'] as num?)?.toInt() ?? 0;
                  final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                  return {
                    ...e,
                    'label': (month >= 1 && month <= 12)
                        ? '${DateFormat('MMM').format(DateTime(year, month))} $year'
                        : '$year',
                    'subtitle': paymentDate == null
                        ? 'Payment date unavailable'
                        : 'Paid on ${DateFormat('dd MMM yyyy').format(paymentDate.toLocal())}',
                    'amount': amount,
                  };
                })
                .toList();
            final pendingDues = ((root['pendingDues'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final residents = ((root['residents'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final residentsSummary = Map<String, dynamic>.from(
              (root['residentsSummary'] ?? root['summary'] ?? const {}) as Map,
            );
            final expenses = Map<String, dynamic>.from(
              (root['monthlyExpenseBreakdown'] ?? const {}) as Map,
            );

            final overviewStrip = _buildTopOverviewStrip(
              periodLabel: periodLabel,
              residentsSummary: residentsSummary,
              userSummary: userSummary,
              expenses: expenses,
              isAdmin: isAdmin,
              billingCycle: billingCycleAsync.valueOrNull,
            );

            final pages = <Widget>[
              _buildResidentsTab(
                context,
                residents,
                residentsSummary,
                overviewStrip,
              ),
              _buildPaymentHistoryTab(
                context,
                paymentHistory,
                overviewStrip,
              ),
              _buildPendingDuesTab(
                context,
                pendingDues,
                overviewStrip,
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: DesignColors.surface,
                  elevation: 0,
                  child: _buildStickyFilterBar(context, filter, isAdmin, root),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: DesignColors.borderLight.withValues(alpha: 0.6),
                ),
                Expanded(child: TabBarView(children: pages)),
              ],
            );
          },
        ),
        bottomNavigationBar: isAdmin
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ref.watch(pendingMaintenanceProvider).when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (pending) =>
                            _legacyPayColumn(context, pending),
                      ),
                ),
              ),
      ),
    );
  }

  Widget _buildStickyFilterBar(
    BuildContext context,
    MaintenanceDashboardFilter filter,
    bool isAdmin,
    Map<String, dynamic> dashboard,
  ) {
    final years = List<int>.generate(6, (index) => DateTime.now().year - index);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: DesignColors.borderLight),
    );
    return Material(
      color: DesignColors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('maint-month-${filter.month}'),
                    initialValue: filter.month,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: DesignColors.surfaceSoft,
                      labelText: 'Month',
                      labelStyle: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                      border: border,
                      enabledBorder: border,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: DesignColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    dropdownColor: DesignColors.surface,
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat('MMMM').format(DateTime(2024, index + 1)),
                        ),
                      ),
                    ),
                    onChanged: (m) {
                      if (m == null) return;
                      ref
                          .read(maintenanceDashboardFilterProvider.notifier)
                          .state = filter.copyWith(
                        month: m,
                      );
                      ref.invalidate(maintenanceDashboardProvider);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('maint-year-${filter.year}'),
                    initialValue: filter.year,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: DesignColors.surfaceSoft,
                      labelText: 'Year',
                      labelStyle: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                      border: border,
                      enabledBorder: border,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: DesignColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    dropdownColor: DesignColors.surface,
                    items: years
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (y) {
                      if (y == null) return;
                      ref
                          .read(maintenanceDashboardFilterProvider.notifier)
                          .state = filter.copyWith(
                        year: y,
                      );
                      ref.invalidate(maintenanceDashboardProvider);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    foregroundColor: DesignColors.textPrimary,
                    backgroundColor: DesignColors.surfaceSoft,
                  ),
                  tooltip: 'Download report PDF',
                  onPressed: () =>
                      _downloadPdfReport(context, dashboard, filter),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    backgroundColor: DesignColors.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  tooltip: 'Society collections vs expenses',
                  onPressed: () => _openFinancialOverview(context, dashboard),
                  icon: const Icon(Icons.insights_outlined, size: 22),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send reminders',
                    onPressed: () => _sendReminders(context, filter),
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 22,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyPayColumn(
    BuildContext context,
    List<MaintenanceDueModel> pending,
  ) {
    if (pending.isEmpty) return const SizedBox.shrink();
    final totalDue = pending.fold<double>(0, (sum, item) => sum + item.amount);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your unit · items under My Dues (legacy ledger)',
          textAlign: TextAlign.center,
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _showPaymentDialog(context, ref, pending, totalDue),
          icon: const Icon(Icons.payments_outlined),
          label: Text('Pay ₹${totalDue.toStringAsFixed(0)}'),
        ),
      ],
    );
  }

  Widget _buildTopOverviewStrip({
    required String periodLabel,
    required Map<String, dynamic> residentsSummary,
    required Map<String, dynamic> userSummary,
    required Map<String, dynamic> expenses,
    required bool isAdmin,
    BillingCycleCurrent? billingCycle,
  }) {
    final totalResidents =
        (residentsSummary['totalResidents'] as num?)?.toInt() ?? 0;
    final paidCount = (residentsSummary['paidCount'] as num?)?.toInt() ?? 0;
    final unpaidCount = (residentsSummary['unpaidCount'] as num?)?.toInt() ?? 0;
    final collected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final totalExpense = (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final myPending = (userSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final snapshotHint = isAdmin
        ? 'Counts and money are society-wide. “My balance due” is your own unit if linked.'
        : 'Society-wide totals. “My balance due” is your residents only (see My Dues).';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: DesignColors.surface,
        elevation: 0,
        shadowColor: DesignColors.textPrimary.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DesignColors.borderLight),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 18,
                    color: DesignColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Society snapshot · $periodLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: snapshotHint,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _snapshotChip(
                    label: 'Residents',
                    value: '$totalResidents',
                    color: DesignColors.primary,
                  ),
                  _snapshotChip(
                    label: 'Paid',
                    value: '$paidCount',
                    color: DesignColors.success,
                  ),
                  _snapshotChip(
                    label: 'Unpaid',
                    value: '$unpaidCount',
                    color: DesignColors.error,
                  ),
                  _snapshotChip(
                    label: 'Collected',
                    value: inr.format(collected),
                    color: DesignColors.success,
                  ),
                  _snapshotChip(
                    label: 'Expenses',
                    value: inr.format(totalExpense),
                    color: DesignColors.textSecondary,
                  ),
                  _snapshotChip(
                    label: 'My due',
                    value: inr.format(myPending),
                    color: DesignColors.error,
                  ),
                ],
              ),
              if (!isAdmin && billingCycle != null && billingCycle.hasCycle) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _snapshotChip(
                      label: 'Expected',
                      value: inr.format(billingCycle.expectedAmount ?? billingCycle.amount ?? 0),
                      color: DesignColors.primary,
                    ),
                    _snapshotChip(
                      label: 'Paid',
                      value: inr.format(billingCycle.paidAmount ?? 0),
                      color: DesignColors.success,
                    ),
                    _snapshotChip(
                      label: 'Delta',
                      value: inr.format(billingCycle.deltaAmount ?? 0),
                      color: (billingCycle.deltaAmount ?? 0) >= 0
                          ? DesignColors.success
                          : DesignColors.error,
                    ),
                    _snapshotChip(
                      label: 'Available credit',
                      value: inr.format(billingCycle.availableCredit ?? 0),
                      color: DesignColors.success,
                    ),
                    _snapshotChip(
                      label: 'Remaining due',
                      value: inr.format(billingCycle.remainingDue ?? billingCycle.totalDue ?? 0),
                      color: DesignColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Credit will auto-adjust in the next cycle. Any remaining due carries forward until settled.',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need manual adjustment? Contact office/admin to record a manual settlement.',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _snapshotChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.15,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DesignTypography.bodySmall.copyWith(
                fontSize: 10,
                height: 1.1,
                color: DesignColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContextBanner({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: DesignColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: DesignColors.borderLight.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: DesignColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: DesignColors.textPrimary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                      height: 1.3,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryTab(
    BuildContext context,
    List<Map<String, dynamic>> history,
    Widget overviewStrip,
  ) {
    final sorted = [...history]
      ..sort((a, b) {
        final ad =
            DateTime.tryParse(a['paymentDate']?.toString() ?? '') ??
            DateTime(2000);
        final bd =
            DateTime.tryParse(b['paymentDate']?.toString() ?? '') ??
            DateTime(2000);
        return bd.compareTo(ad);
      });
    final filtered = _historyFilterMode == _HistoryFilterMode.monthly
        ? sorted
        : _aggregateYearly(sorted);
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          overviewStrip,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_HistoryFilterMode>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return DesignColors.primary.withValues(alpha: 0.14);
                  }
                  return DesignColors.surfaceSoft;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return DesignColors.primary;
                  }
                  return DesignColors.textSecondary;
                }),
              ),
              segments: const [
                ButtonSegment(
                  value: _HistoryFilterMode.monthly,
                  label: Text('Monthly'),
                ),
                ButtonSegment(
                  value: _HistoryFilterMode.yearly,
                  label: Text('Yearly'),
                ),
              ],
              selected: {_historyFilterMode},
              onSelectionChanged: (selected) {
                setState(() => _historyFilterMode = selected.first);
              },
            ),
          ),
          if (filtered.isEmpty)
            SizedBox(
              height: 280,
              child: Center(
                child: _emptyState(
                  icon: Icons.payments_outlined,
                  title: 'No payments on file for you',
                  subtitle:
                      'After you pay maintenance (or the office records it), entries will show here month by month.',
                ),
              ),
            )
          else
            ...filtered.map((item) {
              final amount = (item['amount'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Material(
                  color: DesignColors.surface,
                  elevation: 0,
                  shadowColor: DesignColors.textPrimary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: DesignColors.borderLight),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showPaymentHistoryDetails(context, item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: DesignColors.success.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: DesignColors.success,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label']?.toString() ?? '-',
                                  style: DesignTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['subtitle']?.toString() ?? '',
                                  style: DesignTypography.bodySmall.copyWith(
                                    color: DesignColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                inr.format(amount),
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DesignColors.success,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Paid',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: DesignColors.success,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DesignColors.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: DesignColors.borderLight),
              ),
              child: Icon(icon, size: 40, color: DesignColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTypography.headingM.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDuesTab(
    BuildContext context,
    List<Map<String, dynamic>> pending,
    Widget overviewStrip,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          overviewStrip,
          _tabContextBanner(
            icon: Icons.person_outline,
            title: 'Your maintenance only',
            body:
                'Each row is for your registered resident account. The full society list is under All Residents.',
          ),
          if (pending.isEmpty)
            SizedBox(
              height: 260,
              child: Center(
                child: _emptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'No pending dues for you',
                  subtitle:
                      'When your unit has open months, they show here and in My balance due in the snapshot.',
                ),
              ),
            )
          else
            ...pending.map((d) {
              final due = DateTime.tryParse(
                d['dueDate']?.toString() ?? '',
              )?.toLocal();
              final overdue =
                  (d['isOverdue'] == true) ||
                  (due != null && due.isBefore(DateTime.now()));
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              final accent = overdue
                  ? DesignColors.error
                  : DesignColors.warning;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Material(
                  color: DesignColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(
                                  DateTime(
                                    (d['year'] as num?)?.toInt() ??
                                        DateTime.now().year,
                                    (d['month'] as num?)?.toInt() ??
                                        DateTime.now().month,
                                  ),
                                ),
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                due == null
                                    ? 'Due date unavailable'
                                    : 'Due ${DateFormat('dd MMM yyyy').format(due)}',
                                style: DesignTypography.bodySmall.copyWith(
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                              if (overdue) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'OVERDUE',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: DesignColors.error,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          inr.format(amount),
                          style: DesignTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildResidentsTab(
    BuildContext context,
    List<Map<String, dynamic>> residents,
    Map<String, dynamic> summary,
    Widget overviewStrip,
  ) {
    if (residents.isEmpty) {
      return _buildResidentsEmptyState(
        summary,
        overviewStrip,
      );
    }
    final filtered = residents.where((r) {
      final status = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
      switch (_residentStatusFilter) {
        case _ResidentStatusFilter.paid:
          return status == 'PAID';
        case _ResidentStatusFilter.unpaid:
          return status != 'PAID';
        case _ResidentStatusFilter.all:
          return true;
      }
    }).toList();
    final totalResidents =
        (summary['totalResidents'] as num?)?.toInt() ?? residents.length;
    final paidCount =
        (summary['paidCount'] as num?)?.toInt() ??
        residents
            .where(
              (r) => (r['status']?.toString() ?? '').toUpperCase() == 'PAID',
            )
            .length;
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          overviewStrip,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tabContextBanner(
                  icon: Icons.apartment_outlined,
                  title: 'Whole society',
                  body:
                      'Every resident entry for the month you chose. For only your unit, open My Payments or My Dues.',
                ),
                Text(
                  'All Residents',
                  style: DesignTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$totalResidents residents · $paidCount paid · ${totalResidents - paidCount} unpaid this period',
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<_ResidentStatusFilter>(
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((s) {
                      if (s.contains(WidgetState.selected)) {
                        return DesignColors.primary.withValues(alpha: 0.14);
                      }
                      return DesignColors.surfaceSoft;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((s) {
                      if (s.contains(WidgetState.selected)) {
                        return DesignColors.primary;
                      }
                      return DesignColors.textSecondary;
                    }),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _ResidentStatusFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: _ResidentStatusFilter.paid,
                      label: Text('Paid'),
                    ),
                    ButtonSegment(
                      value: _ResidentStatusFilter.unpaid,
                      label: Text('Unpaid'),
                    ),
                  ],
                  selected: {_residentStatusFilter},
                  onSelectionChanged: (selected) {
                    setState(() => _residentStatusFilter = selected.first);
                  },
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: _emptyState(
                      icon: Icons.filter_alt_outlined,
                      title: 'No residents in this filter',
                      subtitle:
                          'Try switching to All or another payment status.',
                    ),
                  ),
              ],
            ),
          ),
          if (filtered.isNotEmpty)
            ...filtered.map((r) {
              final rawStatus = (r['status']?.toString() ?? 'UNPAID')
                  .toUpperCase();
              final paid = rawStatus == 'PAID';
              final statusText = paid ? 'Paid' : 'Unpaid';
              final amount = (r['amount'] as num?)?.toDouble() ?? 0;
              final accent = paid ? DesignColors.success : DesignColors.error;
              final displayName = '${r['name'] ?? r['ownerName'] ?? 'Unknown'}'
                  .trim();
              final unit = '${r['flatNumber'] ?? r['villaNumber'] ?? '-'}';

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Material(
                  color: DesignColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: DesignColors.borderLight),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 52,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: accent.withValues(alpha: 0.14),
                            child: Icon(
                              paid
                                  ? Icons.check_rounded
                                  : Icons.pending_outlined,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DesignTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Unit $unit · Maintenance',
                                  style: DesignTypography.bodySmall.copyWith(
                                    color: DesignColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                inr.format(amount),
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  statusText,
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildResidentsEmptyState(
    Map<String, dynamic> summary,
    Widget overviewStrip,
  ) {
    final expected =
        (summary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final collected = (summary['totalCollected'] as num?)?.toDouble() ?? 0;
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          overviewStrip,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _tabContextBanner(
                  icon: Icons.apartment_outlined,
                  title: 'Whole society',
                  body:
                      'When resident entries exist for this month, they appear below. Use My Payments or My Dues for your unit only.',
                ),
                const SizedBox(height: 8),
                _emptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'No residents listed for this period',
                  subtitle:
                      'Try a different month/year above, or ask your secretary to add units and maintenance.',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        'Expected',
                        inr.format(expected),
                        DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        'Collected',
                        inr.format(collected),
                        DesignColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: DesignTypography.headingM.copyWith(color: color),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms);
  }

  List<Map<String, dynamic>> _aggregateYearly(
    List<Map<String, dynamic>> monthly,
  ) {
    final map = <int, double>{};
    for (final item in monthly) {
      final year = (item['year'] as num?)?.toInt() ?? 0;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      map[year] = (map[year] ?? 0) + amount;
    }
    final years = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return years
        .map(
          (y) => {
            'label': '$y',
            'subtitle': 'Yearly total',
            'amount': map[y] ?? 0,
          },
        )
        .toList();
  }

  void _openFinancialOverview(
    BuildContext context,
    Map<String, dynamic> dashboard,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionExpenseOverviewScreen(dashboard: dashboard),
      ),
    );
  }

  void _showPaymentHistoryDetails(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = amount;
    const pendingAmount = 0.0;
    final paymentMode = item['paymentMode']?.toString() ?? '—';
    final notes = item['notes']?.toString();
    final paymentDate = DateTime.tryParse(
      item['paymentDate']?.toString() ?? '',
    );
    const status = 'PAID';
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: DesignColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['label']?.toString() ?? 'Payment details',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item['subtitle']?.toString() ?? '',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DesignColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: DesignColors.success.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount received',
                      style: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inr.format(amount),
                      style: DesignTypography.headingL.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DesignColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('Status', status, valueColor: DesignColors.success),
              _detailRow(
                'Payment date',
                paymentDate == null
                    ? '—'
                    : DateFormat('dd MMM yyyy').format(paymentDate.toLocal()),
              ),
              _detailRow('Paid amount', inr.format(paidAmount)),
              _detailRow('Pending amount', inr.format(pendingAmount)),
              _detailRow('Method', paymentMode),
              _detailRow(
                'Notes',
                (notes == null || notes.isEmpty) ? '—' : notes,
                multiline: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? DesignColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReminders(
    BuildContext context,
    MaintenanceDashboardFilter filter,
  ) async {
    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .sendDuesReminders(month: filter.month, year: filter.year);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due reminders sent successfully'),
          backgroundColor: DesignColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: DesignColors.error,
        ),
      );
    }
  }

  Future<void> _downloadPdfReport(
    BuildContext context,
    Map<String, dynamic> dashboard,
    MaintenanceDashboardFilter filter,
  ) async {
    try {
      final user = ref.read(authProvider).user;
      final isAdmin = user?.role == UserRole.admin;
      final bytes = await ref
          .read(maintenanceRepositoryProvider)
          .downloadMaintenanceReportPdf(
            month: filter.month,
            year: filter.year,
            isAdmin: isAdmin,
          );
      if (bytes.isEmpty) throw Exception('Empty report received');
      await _sharePdfBytes(
        Uint8List.fromList(bytes),
        filename:
            'maintenance_report_${filter.year}_${filter.month.toString().padLeft(2, '0')}.pdf',
      );
      return;
    } catch (_) {
      // Fallback to local PDF generation if backend export is unavailable.
    }

    final pdf = pw.Document();
    final summary = Map<String, dynamic>.from(
      (dashboard['summary'] ?? dashboard['userSummary'] ?? const {}) as Map,
    );
    final pending =
        ((dashboard['globalPendingDues'] ??
                    dashboard['pendingDues'] ??
                    const [])
                as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Maintenance Financial Report (${filter.month}/${filter.year})',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: [
              _pdfRow(
                'Total Paid',
                '₹${(summary['totalPaid'] ?? summary['collected'] ?? 0)}',
              ),
              _pdfRow(
                'Total Pending',
                '₹${(summary['totalPending'] ?? summary['pendingAmount'] ?? 0)}',
              ),
              _pdfRow(
                'Collection Rate',
                '${summary['collectionRate'] ?? '-'}%',
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Pending Dues',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Unit'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Month/Year'),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Amount'),
                  ),
                ],
              ),
              ...pending
                  .take(50)
                  .map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${e['villaNumber'] ?? '-'}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${e['month'] ?? '-'} / ${e['year'] ?? '-'}',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '₹${((e['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
    await _sharePdfBytes(
      Uint8List.fromList(await pdf.save()),
      filename:
          'maintenance_report_${filter.year}_${filter.month.toString().padLeft(2, '0')}.pdf',
    );
  }

  Future<void> _sharePdfBytes(
    Uint8List data, {
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(data);
    await Share.shareXFiles([XFile(file.path)], text: 'Maintenance report');
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    List<MaintenanceDueModel> pending,
    double amount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Pay ₹${amount.toStringAsFixed(0)} for maintenance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool allSuccess = true;
              for (final due in pending) {
                final ok = await ref
                    .read(maintenancePaymentProvider.notifier)
                    .pay(
                      villaId: due.villaId,
                      month: due.month,
                      year: due.year,
                      amount: due.amount,
                      paymentMode: 'ONLINE',
                    );
                if (!ok) {
                  allSuccess = false;
                  break;
                }
              }
              ref.invalidate(residentBillingCycleProvider);
              ref.invalidate(pendingMaintenanceProvider);
              ref.invalidate(maintenanceDashboardProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    allSuccess
                        ? 'Payment recorded successfully'
                        : 'Payment failed. Please try again.',
                  ),
                  backgroundColor: allSuccess
                      ? DesignColors.success
                      : DesignColors.error,
                ),
              );
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }
}

pw.TableRow _pdfRow(String key, String value) {
  return pw.TableRow(
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(key)),
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value)),
    ],
  );
}

enum _OverviewMode { monthly, yearly }

class CollectionExpenseOverviewScreen extends StatefulWidget {
  const CollectionExpenseOverviewScreen({super.key, required this.dashboard});

  final Map<String, dynamic> dashboard;

  @override
  State<CollectionExpenseOverviewScreen> createState() =>
      _CollectionExpenseOverviewScreenState();
}

class _CollectionExpenseOverviewScreenState
    extends State<CollectionExpenseOverviewScreen> {
  _OverviewMode _mode = _OverviewMode.monthly;

  Iterable<MapEntry<String, double>> _categoryEntries(
    Map<String, dynamic> expenses,
  ) {
    final raw = expenses['categoryBreakdown'];
    if (raw is! Map) return const Iterable<MapEntry<String, double>>.empty();
    final out = <MapEntry<String, double>>[];
    raw.forEach((k, v) {
      final key = k.toString();
      final val = (v is num)
          ? v.toDouble()
          : double.tryParse(v.toString()) ?? 0;
      if (val > 0) out.add(MapEntry(key, val));
    });
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  Widget _statTile({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: DesignColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            inr.format(value),
            style: DesignTypography.headingM.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonBlock({
    required double collected,
    required double expense,
    required double net,
  }) {
    final base = (collected + expense) <= 0 ? 1.0 : (collected + expense);
    final collPct = (collected / base).clamp(0.0, 1.0);
    final expPct = (expense / base).clamp(0.0, 1.0);
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    Widget bar(String label, double pct, Color color, String amount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: DesignTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ),
              Text(
                amount,
                style: DesignTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: pct,
              color: color,
              backgroundColor: DesignColors.surfaceSoft,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection vs expense',
            style: DesignTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Green shows inflow; neutral shows society spending.',
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          bar(
            'Maintenance collected',
            collPct,
            DesignColors.success,
            inr.format(collected),
          ),
          const SizedBox(height: 14),
          bar(
            'Monthly expenses',
            expPct,
            DesignColors.textSecondary,
            inr.format(expense),
          ),
          const SizedBox(height: 16),
          Divider(color: DesignColors.borderLight.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Net position',
                style: DesignTypography.label.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                inr.format(net),
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w800,
                  color: net >= 0 ? DesignColors.success : DesignColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = Map<String, dynamic>.from(
      (widget.dashboard['filter'] ?? const {}) as Map,
    );
    final month = (filter['month'] as num?)?.toInt() ?? DateTime.now().month;
    final year = (filter['year'] as num?)?.toInt() ?? DateTime.now().year;
    final periodLabel =
        '${DateFormat('MMMM').format(DateTime(2000, month))} $year';

    final residentsSummary = Map<String, dynamic>.from(
      (widget.dashboard['residentsSummary'] ?? const {}) as Map,
    );
    final expenses = Map<String, dynamic>.from(
      (widget.dashboard['monthlyExpenseBreakdown'] ?? const {}) as Map,
    );
    final yearlyBreakdown =
        ((widget.dashboard['yearlyBreakdown'] ?? const []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final expected =
        (residentsSummary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final collected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final pending = (residentsSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final totalExpense = (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final net = collected - totalExpense;

    final yearlyCollected = yearlyBreakdown.fold<double>(
      0,
      (sum, row) => sum + ((row['totalCollected'] as num?)?.toDouble() ?? 0),
    );
    final yearlyExpense = yearlyBreakdown.fold<double>(
      0,
      (sum, row) => sum + ((row['totalExpense'] as num?)?.toDouble() ?? 0),
    );
    final yearlyNet = yearlyCollected - yearlyExpense;

    final categories = _categoryEntries(expenses).take(8).toList();
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: DesignColors.surface,
        surfaceTintColor: DesignColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collection & expenses',
              style: DesignTypography.headingM.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              periodLabel,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_OverviewMode>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return DesignColors.primary.withValues(alpha: 0.14);
                }
                return DesignColors.surfaceSoft;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.selected)) {
                  return DesignColors.primary;
                }
                return DesignColors.textSecondary;
              }),
            ),
            segments: const [
              ButtonSegment(
                value: _OverviewMode.monthly,
                label: Text('This period'),
              ),
              ButtonSegment(
                value: _OverviewMode.yearly,
                label: Text('Year roll-up'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selected) {
              setState(() => _mode = selected.first);
            },
          ),
          const SizedBox(height: 18),
          if (_mode == _OverviewMode.monthly) ...[
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    label: 'Expected',
                    value: expected,
                    color: DesignColors.primary,
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statTile(
                    label: 'Collected',
                    value: collected,
                    color: DesignColors.success,
                    icon: Icons.savings_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    label: 'Pending',
                    value: pending,
                    color: DesignColors.error,
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statTile(
                    label: 'Expenses',
                    value: totalExpense,
                    color: DesignColors.textSecondary,
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _comparisonBlock(
              collected: collected,
              expense: totalExpense,
              net: net,
            ),
          ] else ...[
            _comparisonBlock(
              collected: yearlyCollected,
              expense: yearlyExpense,
              net: yearlyNet,
            ),
            const SizedBox(height: 8),
            Text(
              'Sums every month in $year for a quick annual read.',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ],
          if (_mode == _OverviewMode.monthly && categories.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'Expense by category',
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...categories.map((e) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DesignColors.borderLight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key.replaceAll('_', ' '),
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      inr.format(e.value),
                      style: DesignTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 22),
          Text(
            'Month-by-month',
            style: DesignTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paid counts and cash movement across the year.',
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (yearlyBreakdown.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DesignColors.borderLight),
              ),
              child: Text(
                'No breakdown yet for this year.',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
            )
          else
            ...yearlyBreakdown.map((row) {
              final m = (row['month'] as num?)?.toInt() ?? 1;
              final paidC = (row['paidCount'] as num?)?.toInt() ?? 0;
              final unpaidC = (row['unpaidCount'] as num?)?.toInt() ?? 0;
              final monthCollected =
                  (row['totalCollected'] as num?)?.toDouble() ?? 0;
              final monthExpense =
                  (row['totalExpense'] as num?)?.toDouble() ?? 0;
              final monthNet = monthCollected - monthExpense;
              final netColor = monthNet >= 0
                  ? DesignColors.success
                  : DesignColors.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: DesignColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: DesignColors.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('MMMM').format(DateTime(2024, m)),
                              style: DesignTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: netColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Net ${inr.format(monthNet)}',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: netColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$paidC paid · $unpaidC unpaid',
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _miniFoot(
                                'Collected',
                                monthCollected,
                                DesignColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _miniFoot(
                                'Expense',
                                monthExpense,
                                DesignColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _miniFoot(String label, double value, Color c) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DesignTypography.labelSmall.copyWith(
            color: DesignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          inr.format(value),
          style: DesignTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ],
    );
  }
}
