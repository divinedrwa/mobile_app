import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../widgets/list_skeleton.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/maintenance_provider.dart';

/// Some gateways or proxies wrap JSON as `{ "data": { ... } }` — normalize for the UI.
Map<String, dynamic> _normalizeDashboardPayload(Map<String, dynamic> raw) {
  final nested = raw['data'];
  if (nested is Map) {
    return Map<String, dynamic>.from(nested);
  }
  return raw;
}

/// Pick a sensible default billing cycle (matches current calendar month if present).
String? _pickDefaultBillingCycleId(List<Map<String, dynamic>> cycles) {
  if (cycles.isEmpty) return null;
  final now = DateTime.now();
  final key =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
  for (final c in cycles) {
    if (c['cycleKey']?.toString() == key) {
      return c['id']?.toString();
    }
  }
  for (final c in cycles.reversed) {
    if (c['status']?.toString() == 'OPEN') {
      return c['id']?.toString();
    }
  }
  return cycles.last['id']?.toString();
}

String? _pickDefaultFinancialYearId(List<Map<String, dynamic>> fys) {
  if (fys.isEmpty) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final fy in fys) {
    final s = DateTime.tryParse(fy['startDate']?.toString() ?? '');
    final e = DateTime.tryParse(fy['endDate']?.toString() ?? '');
    if (s == null || e == null) continue;
    final ds = DateTime(s.year, s.month, s.day);
    final de = DateTime(e.year, e.month, e.day);
    if (!today.isBefore(ds) && !today.isAfter(de)) {
      return fy['id']?.toString();
    }
  }
  return fys.first['id']?.toString();
}

({int month, int year})? _monthYearFromCycleKey(String cycleKey) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(cycleKey.trim());
  if (m == null) return null;
  final y = int.tryParse(m.group(1)!);
  final mo = int.tryParse(m.group(2)!);
  if (y == null || mo == null || mo < 1 || mo > 12) return null;
  return (month: mo, year: y);
}

/// Maintenance Financial Dashboard Screen
class MaintenancePaymentScreen extends ConsumerStatefulWidget {
  const MaintenancePaymentScreen({super.key, this.initialTab});

  final int? initialTab;

  @override
  ConsumerState<MaintenancePaymentScreen> createState() =>
      _MaintenancePaymentScreenState();
}

class _MaintenancePaymentScreenState
    extends ConsumerState<MaintenancePaymentScreen> {
  bool _appliedInitialQueryFilter = false;
  final Set<String> _expandedOutstandingVillas = {};
  final Set<int> _expandedShortfallMonths = {};

  // ── Overview "All residents" search + status filter ──
  final TextEditingController _residentSearchCtrl = TextEditingController();
  String _residentQuery = '';
  String _residentStatusFilter = 'ALL'; // ALL | PAID | PARTIAL | UNPAID | OVERDUE
  bool _advanceExpanded = false; // "Advance payments" collapsed by default

  @override
  void dispose() {
    _residentSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialQueryFilter) return;

    final uri = GoRouterState.of(context).uri;
    final q = uri.queryParameters;
    final monthRaw = int.tryParse(q['month'] ?? '');
    final yearRaw = int.tryParse(q['year'] ?? '');
    final hasValidMonthYear = monthRaw != null &&
        yearRaw != null &&
        monthRaw >= 1 &&
        monthRaw <= 12 &&
        yearRaw >= 2000 &&
        yearRaw <= 2100;

    final cycleIdParam = q['cycleId'];
    final collectionCycleId = (cycleIdParam != null && cycleIdParam.isNotEmpty)
        ? cycleIdParam
        : null;
    final fyParam = q['financialYearId'];
    final financialYearId =
        (fyParam != null && fyParam.isNotEmpty) ? fyParam : null;
    final billingCycleParam = q['billingCycleId'];
    final billingCycleId =
        (billingCycleParam != null && billingCycleParam.isNotEmpty)
            ? billingCycleParam
            : null;

    final hasBillingParams = hasValidMonthYear ||
        financialYearId != null ||
        billingCycleId != null ||
        collectionCycleId != null;

    if (!hasBillingParams) {
      _appliedInitialQueryFilter = true;
      return;
    }

    _appliedInitialQueryFilter = true;

    if (billingCycleId != null &&
        financialYearId == null &&
        !hasValidMonthYear) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyDeepLinkBillingCycleOnly(billingCycleId, collectionCycleId);
      });
      return;
    }

    final stub = DateTime.now();
    final int month;
    final int year;
    if (hasValidMonthYear) {
      month = monthRaw;
      year = yearRaw;
    } else {
      month = stub.month;
      year = stub.year;
    }

    final current = ref.read(maintenanceDashboardFilterProvider);
    final effectiveBillingCycleId = billingCycleId;
    final effectiveFinancialYearId = financialYearId;

    if (current.month == month &&
        current.year == year &&
        current.maintenanceCollectionCycleId == collectionCycleId &&
        current.financialYearId == effectiveFinancialYearId &&
        current.billingCycleId == effectiveBillingCycleId) {
      if (effectiveFinancialYearId != null) {
        ref.invalidate(
          billingCyclesForFinancialYearProvider(effectiveFinancialYearId),
        );
      }
      return;
    }

    ref.read(maintenanceDashboardFilterProvider.notifier).state = current
        .copyWith(
          month: month,
          year: year,
          maintenanceCollectionCycleId: collectionCycleId,
          clearCollectionCycleId: collectionCycleId == null,
          financialYearId: effectiveFinancialYearId,
          clearFinancialYearId: effectiveFinancialYearId == null,
          billingCycleId: effectiveBillingCycleId,
          clearBillingCycleId: effectiveBillingCycleId == null,
        );
    ref.invalidate(maintenanceDashboardProvider);
    if (effectiveFinancialYearId != null) {
      ref.invalidate(
        billingCyclesForFinancialYearProvider(effectiveFinancialYearId),
      );
    }
  }

  Future<void> _applyDeepLinkBillingCycleOnly(
    String billingCycleId,
    String? collectionCycleId,
  ) async {
    if (!mounted) return;
    try {
      final ctx = await ref
          .read(maintenanceRepositoryProvider)
          .getBillingCycleContext(billingCycleId);
      if (!mounted || ctx == null) return;
      final fyMap = ctx['financialYear'];
      final bcMap = ctx['billingCycle'];
      if (fyMap is! Map || bcMap is! Map) return;
      final fyId = fyMap['id']?.toString();
      final key = bcMap['cycleKey']?.toString() ?? '';
      final my = _monthYearFromCycleKey(key);
      if (fyId == null || fyId.isEmpty || my == null) return;

      final cur = ref.read(maintenanceDashboardFilterProvider);
      ref.read(maintenanceDashboardFilterProvider.notifier).state =
          cur.copyWith(
        month: my.month,
        year: my.year,
        maintenanceCollectionCycleId: collectionCycleId,
        clearCollectionCycleId: collectionCycleId == null,
        financialYearId: fyId,
        clearFinancialYearId: false,
        billingCycleId: billingCycleId,
        clearBillingCycleId: false,
      );
      ref.invalidate(maintenanceDashboardProvider);
      ref.invalidate(billingCyclesForFinancialYearProvider(fyId));
    } catch (_) {}
  }

  Future<void> _pullRefreshMaintenance() async {
    ref.invalidate(maintenanceDashboardProvider);
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    ref.invalidate(billingFinancialYearsProvider);
    ref.invalidate(outstandingDuesProvider);
    // Year review & Shortfall read these per-calendar-year; invalidate the whole
    // family so a failed breakdown can recover via pull-to-refresh.
    ref.invalidate(yearlyBreakdownForYearProvider);
    final fy = ref.read(maintenanceDashboardFilterProvider).financialYearId;
    if (fy != null && fy.isNotEmpty) {
      ref.invalidate(billingCyclesForFinancialYearProvider(fy));
    }
    ref.invalidate(residentBillingCycleProvider);
    try {
      await ref.read(maintenanceDashboardProvider.future);
    } catch (_) {}
    try {
      await ref.read(pendingMaintenanceProvider.future);
    } catch (_) {}
    try {
      await ref.read(maintenanceHistoryProvider.future);
    } catch (_) {}
  }

  void _ensureBillingCycleMatchesFilter(
    String fyId,
    List<Map<String, dynamic>> cycles,
  ) {
    if (cycles.isEmpty) return;
    final cur = ref.read(maintenanceDashboardFilterProvider);
    if (cur.financialYearId != fyId) return;

    final byId = <String, Map<String, dynamic>>{
      for (final c in cycles)
        if (c['id'] != null) c['id'].toString(): c,
    };

    final Map<String, dynamic> chosen;
    final sel = cur.billingCycleId;
    if (sel != null && byId.containsKey(sel)) {
      chosen = byId[sel]!;
    } else {
      final def = _pickDefaultBillingCycleId(cycles);
      if (def != null && byId.containsKey(def)) {
        chosen = byId[def]!;
      } else {
        chosen = cycles.last;
      }
    }

    final key = chosen['cycleKey']?.toString() ?? '';
    final my = _monthYearFromCycleKey(key);
    if (my == null) return;

    final idStr = chosen['id']?.toString();
    if (cur.billingCycleId == idStr &&
        cur.month == my.month &&
        cur.year == my.year) {
      return;
    }

    ref.read(maintenanceDashboardFilterProvider.notifier).state =
        cur.copyWith(
          billingCycleId: idStr,
          month: my.month,
          year: my.year,
          clearBillingCycleId: false,
          clearFinancialYearId: false,
          financialYearId: fyId,
          clearCollectionCycleId: true,
        );
    ref.invalidate(maintenanceDashboardProvider);
  }

  Widget _wrapTabWithRefresh(Widget scrollable) {
    return RefreshIndicator(
      color: DesignColors.primary,
      displacement: 44,
      onRefresh: _pullRefreshMaintenance,
      child: scrollable,
    );
  }

  /// Shimmer placeholder shown while the dashboard loads / a new period is
  /// fetched — far less jarring than a full-screen spinner.
  Widget _buildDashboardSkeleton() {
    Widget box(double h, {double? w, double r = 12}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: context.surface.elevated,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return Shimmer.fromColors(
      baseColor: context.surface.elevated,
      highlightColor: context.surface.defaultSurface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Filter row (FY pill + month chips)
          Row(
            children: [
              box(32, w: 92, r: 16),
              const SizedBox(width: 8),
              box(32, w: 60, r: 16),
              const SizedBox(width: 8),
              box(32, w: 60, r: 16),
            ],
          ),
          const SizedBox(height: 18),
          box(150, w: double.infinity, r: 18), // collections hero
          const SizedBox(height: 16),
          box(190, w: double.infinity, r: 16), // where-money chart
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            box(66, w: double.infinity, r: 14), // resident rows
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(maintenanceDashboardProvider);
    final filter = ref.watch(maintenanceDashboardFilterProvider);
    final tabs = const ['Overview', 'Year review', 'Outstanding', 'Shortfall'];
    final periodLabel =
        '${DateFormat('MMMM').format(DateTime(filter.year, filter.month))} ${filter.year}';

    ref.listen(billingFinancialYearsProvider, (prev, next) {
      next.whenData((fys) {
        final cur = ref.read(maintenanceDashboardFilterProvider);
        if (fys.isEmpty || cur.financialYearId != null) return;
        final id = _pickDefaultFinancialYearId(fys);
        if (id == null || id.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final c2 = ref.read(maintenanceDashboardFilterProvider);
          if (c2.financialYearId != null) return;
          ref.read(maintenanceDashboardFilterProvider.notifier).state =
              c2.copyWith(financialYearId: id);
        });
      });
    });

    final fyListenId = filter.financialYearId;
    if (fyListenId != null && fyListenId.isNotEmpty) {
      ref.listen(billingCyclesForFinancialYearProvider(fyListenId), (prev, next) {
        next.whenData((body) {
          final raw = body['cycles'];
          final cycles = raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureBillingCycleMatchesFilter(fyListenId, cycles);
          });
        });
      });
    }

    final initTab = (widget.initialTab != null &&
            widget.initialTab! >= 0 &&
            widget.initialTab! < tabs.length)
        ? widget.initialTab!
        : 0;

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initTab,
      child: Scaffold(
        backgroundColor: context.surface.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: context.surface.defaultSurface,
          surfaceTintColor: context.surface.defaultSurface,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintenance & payments',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                periodLabel,
                style: DesignTypography.bodySmall.copyWith(
                  color: context.text.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: _buildAppBarActions(),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: DesignColors.primary,
            unselectedLabelColor: context.text.secondary,
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
          loading: () => _buildDashboardSkeleton(),
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
                                color: context.text.primary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () => _pullRefreshMaintenance(),
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
            final residents = ((root['residents'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .where((r) => r['isExcluded'] != true)
                .toList();
            final residentsSummary = Map<String, dynamic>.from(
              (root['residentsSummary'] ?? root['summary'] ?? const {}) as Map,
            );
            final expenses = Map<String, dynamic>.from(
              (root['monthlyExpenseBreakdown'] ?? const {}) as Map,
            );
            // When FY mode is active but no billing cycle is selected,
            // show a prompt instead of default/empty data.
            final hasFyWithoutCycle = filter.financialYearId != null &&
                filter.financialYearId!.isNotEmpty &&
                (filter.billingCycleId == null ||
                    filter.billingCycleId!.isEmpty);

            final selectCyclePlaceholder = _wrapTabWithRefresh(
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesignColors.primary.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_month_outlined,
                          size: 48,
                          color: DesignColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select a billing cycle',
                        style: DesignTypography.headingM.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a billing month from the dropdown above to view maintenance data for that period.',
                        textAlign: TextAlign.center,
                        style: DesignTypography.bodySmall.copyWith(
                          color: context.text.secondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final pages = <Widget>[
              if (hasFyWithoutCycle)
                selectCyclePlaceholder
              else
                _buildOverviewTab(
                  context,
                  userSummary,
                  residentsSummary,
                  expenses,
                  residents,
                  periodLabel,
                ),

              // Year review tab
              _buildYearReviewTab(context, filter),

              // Outstanding tab (admin only)
              _buildOutstandingTab(context),

              // Shortfall tab
              _buildShortfallTab(context),
            ];

            // Block rendering until financial-year list has resolved so
            // the UI doesn't flash default/zero values while the filter
            // bar spinner is still running.
            final fyList = ref.watch(billingFinancialYearsProvider);

            if (fyList.isLoading) {
              return _buildDashboardSkeleton();
            }

            final hasNoFinancialYears = fyList.whenOrNull(
              data: (fys) => fys.isEmpty,
            ) ?? false;

            if (hasNoFinancialYears) {
              return _buildNoRecordsFullPage();
            }

            return Builder(
              builder: (ctx) {
                final tabCtrl = DefaultTabController.of(ctx);
                return AnimatedBuilder(
                  animation: tabCtrl,
                  builder: (ctx2, _) {
                    final tabIdx = tabCtrl.index;
                    // Outstanding tab (now index 2) doesn't use the FY filter bar.
                    final hideFilterBar = tabIdx == 2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideFilterBar)
                          // Pinned above the scroll; elevation makes content
                          // read as scrolling beneath a sticky header.
                          Material(
                            color: context.surface.defaultSurface,
                            elevation: 3,
                            shadowColor:
                                context.text.primary.withValues(alpha: 0.18),
                            child: _buildStickyFilterBar(
                                ctx2, filter, root,
                                hidesCycleDropdown: tabIdx >= 1),
                          ),
                        Expanded(child: TabBarView(children: pages)),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        tooltip: 'Refresh',
        icon: Icon(Icons.refresh_rounded, color: context.text.secondary),
        onPressed: _pullRefreshMaintenance,
      ),
    ];
  }

  Widget _buildStickyFilterBar(
    BuildContext context,
    MaintenanceDashboardFilter filter,
    Map<String, dynamic> dashboard, {
    bool hidesCycleDropdown = false,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.surface.border),
    );
    final fyAsync = ref.watch(billingFinancialYearsProvider);

    return Material(
      color: context.surface.defaultSurface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: fyAsync.when(
          loading: () => const ShimmerWrap(
            child: ShimmerBox(height: 48, borderRadius: 12),
          ),
          error: (err, stack) => _noFinancialYearMessage(),
          data: (fys) {
            if (fys.isEmpty) {
              return _noFinancialYearMessage();
            }
            return _financialYearBillingCyclePickers(
              filter,
              fys,
              border,
              hidesCycleDropdown: hidesCycleDropdown,
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoRecordsFullPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: DesignColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No records available',
              style: DesignTypography.headingM.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Financial year has not been created yet. Records will appear here once your society admin sets up billing.',
              textAlign: TextAlign.center,
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noFinancialYearMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.surface.border),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.text.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No records available. Financial year has not been created yet.',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialYearBillingCyclePickers(
    MaintenanceDashboardFilter filter,
    List<Map<String, dynamic>> financialYears,
    OutlineInputBorder border, {
    bool hidesCycleDropdown = false,
  }) {
    final fyId = filter.financialYearId;
    final cyclesAsync = fyId != null && fyId.isNotEmpty
        ? ref.watch(billingCyclesForFinancialYearProvider(fyId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('maint-fy-${filter.financialYearId}'),
          initialValue: filter.financialYearId != null &&
                  financialYears.any(
                    (fy) => fy['id']?.toString() == filter.financialYearId,
                  )
              ? filter.financialYearId
              : null,
          style: DesignTypography.bodyMedium.copyWith(
            color: context.text.primary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.surface.elevated,
            labelText: 'Financial year',
            labelStyle: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
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
          dropdownColor: context.surface.defaultSurface,
          items: financialYears
              .map(
                (fy) => DropdownMenuItem(
                  value: fy['id']?.toString(),
                  child: Text(fy['label']?.toString() ?? 'Year'),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final cur = ref.read(maintenanceDashboardFilterProvider);
            ref.read(maintenanceDashboardFilterProvider.notifier).state =
                cur.copyWith(
              financialYearId: id,
              clearBillingCycleId: true,
              clearCollectionCycleId: true,
            );
            ref.invalidate(billingCyclesForFinancialYearProvider(id));
            ref.invalidate(maintenanceDashboardProvider);
          },
        ),
        if (!hidesCycleDropdown) ...[
          const SizedBox(height: 10),
          if (cyclesAsync == null)
            Text(
              'Choose a financial year to load billing months.',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                fontSize: 11,
              ),
            )
          else
            cyclesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                userFacingMessage(e, 'Could not load billing cycles'),
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.error,
                  fontSize: 11,
                ),
              ),
              data: (body) {
                final raw = body['cycles'];
                final cycles = raw is List
                    ? raw
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList()
                    : <Map<String, dynamic>>[];
                if (cycles.isEmpty) {
                  return Text(
                    'No billing cycles exist for this financial year yet.',
                    style: DesignTypography.bodySmall.copyWith(
                      color: context.text.secondary,
                      fontSize: 11,
                    ),
                  );
                }
                final selectedId =
                    filter.billingCycleId != null &&
                            cycles.any(
                              (c) => c['id']?.toString() == filter.billingCycleId,
                            )
                        ? filter.billingCycleId
                        : null;
                return _cycleChipStrip(cycles, fyId, selectedId);
              },
            ),
        ],
      ],
    );
  }

  /// Horizontal, tappable month chips for the financial year's billing cycles
  /// — replaces the old cycle dropdown for faster, more scannable switching.
  Widget _cycleChipStrip(
    List<Map<String, dynamic>> cycles,
    String? fyId,
    String? selectedId,
  ) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in cycles) ...[
              _cycleChip(c, fyId, selectedId),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cycleChip(
    Map<String, dynamic> c,
    String? fyId,
    String? selectedId,
  ) {
    final id = c['id']?.toString();
    final key = c['cycleKey']?.toString() ?? '';
    final my = _monthYearFromCycleKey(key);
    final label = my != null
        ? DateFormat("MMM ''yy").format(DateTime(my.year, my.month))
        : key;
    final selected = id != null && id == selectedId;
    final isOpen = (c['status']?.toString() ?? '').toUpperCase() == 'OPEN';

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: DesignTypography.labelSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : context.text.secondary,
      ),
      backgroundColor: context.surface.elevated,
      selectedColor: DesignColors.primary,
      side: BorderSide(
        color: selected ? DesignColors.primary : context.surface.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      avatar: (isOpen && !selected)
          ? Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: DesignColors.success,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onSelected: (_) {
        if (id == null || my == null) return;
        _selectCycle(id, fyId, my.month, my.year);
      },
    );
  }

  void _selectCycle(String id, String? fyId, int month, int year) {
    final cur = ref.read(maintenanceDashboardFilterProvider);
    ref.read(maintenanceDashboardFilterProvider.notifier).state = cur.copyWith(
      billingCycleId: id,
      month: month,
      year: year,
      clearBillingCycleId: false,
      clearFinancialYearId: false,
      financialYearId: fyId,
      clearCollectionCycleId: true,
    );
    ref.invalidate(maintenanceDashboardProvider);
  }

  /// Hand off to the vetted dues/pay flow (which computes the authoritative
  /// amount) and refresh balances on return.
  void _goToDues() {
    context.push('/resident/maintenance/dues').then((_) {
      if (!mounted) return;
      ref.invalidate(maintenanceDashboardProvider);
      ref.invalidate(pendingMaintenanceProvider);
      ref.invalidate(outstandingDuesProvider);
    });
  }

  /// Error + retry state for the FY-scoped tabs (Year review, Shortfall) when a
  /// `yearlyBreakdownForYearProvider` fetch fails. Wrapped in a scrollable so
  /// pull-to-refresh works; Retry re-runs every year breakdown.
  Widget _yearDataErrorState(Object error) {
    return _wrapTabWithRefresh(
      ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: DesignColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load cycle data',
                      style: DesignTypography.headingM
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userFacingMessage(error, 'Could not load year breakdown.'),
                      textAlign: TextAlign.center,
                      style: DesignTypography.bodySmall
                          .copyWith(color: context.text.secondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(yearlyBreakdownForYearProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearReviewTab(
    BuildContext context,
    MaintenanceDashboardFilter filter,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final fyId = filter.financialYearId;
    final cyclesAsync = fyId != null && fyId.isNotEmpty
        ? ref.watch(billingCyclesForFinancialYearProvider(fyId))
        : null;

    if (cyclesAsync == null) {
      return _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.calendar_today_outlined,
            title: 'Select a financial year',
            subtitle: 'Choose a financial year from the dropdown above.',
          ),
        ),
      );
    }

    return cyclesAsync.when(
      loading: () => const ListSkeleton(itemHeight: 100),
      error: (e, _) => _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.error_outline,
            title: 'Failed to load cycles',
            subtitle: e.toString(),
          ),
        ),
      ),
      data: (body) {
        final rawCycles = body['cycles'];
        final cycles = rawCycles is List
            ? rawCycles
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        // Determine which calendar years the FY's cycles span.
        final neededYears = <int>{};
        for (final c in cycles) {
          final my = _monthYearFromCycleKey(c['cycleKey']?.toString() ?? '');
          if (my != null) neededYears.add(my.year);
        }

        // Fetch yearlyBreakdown for each calendar year and merge
        // into a single lookup keyed by "YYYY-MM".
        final breakdownByKey = <String, Map<String, dynamic>>{};
        bool allYearsLoaded = true;
        Object? yearLoadError;
        for (final yr in neededYears) {
          final yrAsync = ref.watch(yearlyBreakdownForYearProvider(yr));
          yrAsync.whenData((rows) {
            for (final row in rows) {
              final m = (row['month'] as num?)?.toInt() ?? 0;
              final y = (row['year'] as num?)?.toInt() ?? 0;
              if (m > 0 && y > 0) {
                breakdownByKey['$y-${m.toString().padLeft(2, '0')}'] = row;
              }
            }
          });
          if (yrAsync is AsyncError) {
            yearLoadError ??= yrAsync.error;
          } else if (yrAsync is! AsyncData) {
            allYearsLoaded = false;
          }
        }

        // A failed year breakdown surfaces an error with retry — otherwise the
        // loading guard below would spin forever (it never sees AsyncData).
        if (yearLoadError != null) {
          return _yearDataErrorState(yearLoadError);
        }

        // Show loading if year breakdowns haven't arrived yet.
        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const ListSkeleton(itemHeight: 100);
        }

        // Build cycle rows with financial data.
        final cycleRows = <Map<String, dynamic>>[];
        for (final c in cycles) {
          final cycleKey = c['cycleKey']?.toString() ?? '';
          final my = _monthYearFromCycleKey(cycleKey);
          final breakdown = breakdownByKey[cycleKey];
          final cycleAmount = (c['amount'] as num?)?.toDouble() ?? 0;

          double mExp, mColl, mExpense;
          int paidC, unpaidC;
          if (breakdown != null &&
              ((breakdown['totalExpected'] as num?)?.toDouble() ?? 0) > 0) {
            mExp = (breakdown['totalExpected'] as num?)?.toDouble() ?? 0;
            mColl = (breakdown['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown['totalExpense'] as num?)?.toDouble() ?? 0;
            paidC = (breakdown['paidCount'] as num?)?.toInt() ?? 0;
            unpaidC = (breakdown['unpaidCount'] as num?)?.toInt() ?? 0;
          } else {
            paidC = (breakdown?['paidCount'] as num?)?.toInt() ?? 0;
            unpaidC = (breakdown?['unpaidCount'] as num?)?.toInt() ?? 0;
            // `cycleAmount` is the per-villa charge, not a society-wide total —
            // scale it by the billed-villa count so Expected and the collection
            // rate stay on the same scale as Collected. When the count is
            // unknown, leave Expected at 0 rather than show a per-villa figure
            // against society-wide collections (which inflates the rate).
            final villaCount = paidC + unpaidC;
            mExp = villaCount > 0 ? cycleAmount * villaCount : 0;
            mColl = (breakdown?['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown?['totalExpense'] as num?)?.toDouble() ?? 0;
          }

          // Extract expense breakdown by category
          final rawBreakdown = breakdown?['expenseBreakdown'];
          final expenseBreakdown = <String, double>{};
          if (rawBreakdown is Map) {
            for (final entry in rawBreakdown.entries) {
              final val = (entry.value as num?)?.toDouble() ?? 0;
              if (val > 0) expenseBreakdown[entry.key.toString()] = val;
            }
          }

          cycleRows.add({
            'month': my?.month ?? 0,
            'year': my?.year ?? 0,
            'cycleKey': cycleKey,
            'amount': cycleAmount,
            'totalExpected': mExp,
            'totalCollected': mColl,
            'totalExpense': mExpense,
            'paidCount': paidC,
            'unpaidCount': unpaidC,
            'expenseBreakdown': expenseBreakdown,
          });
        }

        // Aggregate totals
        double totalExpected = 0;
        double totalCollected = 0;
        double totalExpense = 0;
        for (final row in cycleRows) {
          totalExpected += (row['totalExpected'] as num?)?.toDouble() ?? 0;
          totalCollected += (row['totalCollected'] as num?)?.toDouble() ?? 0;
          totalExpense += (row['totalExpense'] as num?)?.toDouble() ?? 0;
        }
        final totalPending =
            (totalExpected - totalCollected).clamp(0.0, double.infinity);
        final collectionRate =
            totalExpected > 0 ? (totalCollected / totalExpected * 100) : 0.0;
        final rateColor = collectionRate >= 80
            ? DesignColors.success
            : collectionRate >= 50
                ? DesignColors.warning
                : DesignColors.error;

        return _wrapTabWithRefresh(
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Year summary card ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.surface.defaultSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.surface.border),
                    boxShadow: [
                      BoxShadow(
                        color: context.text.primary.withValues(alpha: 0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Year review',
                              style: DesignTypography.labelSmall.copyWith(
                                color: context.text.secondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: DesignColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cycleRows.length} cycle${cycleRows.length == 1 ? '' : 's'}',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: DesignColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _collectionRing(collectionRate, rateColor),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Collected',
                                    style: DesignTypography.labelSmall.copyWith(
                                      color: context.text.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    inr.format(totalCollected),
                                    style: DesignTypography.headingL.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: context.text.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  _targetChip(totalExpected, inr),
                                ],
                              ),
                              const SizedBox(width: 16),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: context.surface.border,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _collectionStatRow(
                                      icon: Icons.schedule_rounded,
                                      color: DesignColors.warning,
                                      label: 'Pending',
                                      value: inr.format(totalPending),
                                      valueColor: totalPending > 0.005
                                          ? DesignColors.warning
                                          : context.text.primary,
                                    ),
                                    Divider(
                                      height: 1,
                                      color: context.surface.border
                                          .withValues(alpha: 0.6),
                                    ),
                                    _collectionStatRow(
                                      icon: Icons.south_rounded,
                                      color: const Color(0xFF3B82F6),
                                      label: 'Expenses',
                                      value: inr.format(totalExpense),
                                      valueColor: context.text.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Billing cycles list ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Billing cycles',
                  style: DesignTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (cycleRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: context.surface.defaultSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.surface.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 40,
                          color: context.text.secondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No billing cycles in this year',
                          style: DesignTypography.bodySmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...cycleRows.map((row) {
                  final m = (row['month'] as num?)?.toInt() ?? 1;
                  final yr = (row['year'] as num?)?.toInt() ?? filter.year;
                  final mExp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
                  final mColl = (row['totalCollected'] as num?)?.toDouble() ?? 0;
                  final mPending = (mExp - mColl).clamp(0.0, double.infinity);
                  final mExpense = (row['totalExpense'] as num?)?.toDouble() ?? 0;
                  final mNet = mColl - mExpense;
                  final mNetColor =
                      mNet >= 0 ? DesignColors.success : DesignColors.error;
                  final paidC = (row['paidCount'] as num?)?.toInt() ?? 0;
                  final unpaidC = (row['unpaidCount'] as num?)?.toInt() ?? 0;
                  final mRate = mExp > 0 ? (mColl / mExp * 100) : 0.0;
                  final mRateColor = mRate >= 80
                      ? DesignColors.success
                      : mRate >= 50
                          ? DesignColors.warning
                          : DesignColors.error;
                  final isCurrentMonth =
                      m == DateTime.now().month && yr == DateTime.now().year;
                  final breakdown =
                      (row['expenseBreakdown'] as Map<String, double>?) ??
                          const <String, double>{};

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: GestureDetector(
                      onTap: () => _showExpenseBreakdownSheet(
                        context,
                        month: m,
                        year: yr,
                        totalExpense: mExpense,
                        breakdown: breakdown,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.surface.defaultSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentMonth
                                ? DesignColors.primary.withValues(alpha: 0.5)
                                : context.surface.border,
                            width: isCurrentMonth ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy')
                                        .format(DateTime(yr, m)),
                                    style: DesignTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (isCurrentMonth) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: DesignColors.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: DesignTypography.labelSmall.copyWith(
                                          color: DesignColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    '$paidC paid · $unpaidC unpaid',
                                    style: DesignTypography.labelSmall.copyWith(
                                      color: context.text.secondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: context.text.secondary
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _cycleReviewStat(
                                      'Expected', inr.format(mExp), DesignColors.primary),
                                  _cycleReviewStat(
                                      'Collected', inr.format(mColl), DesignColors.success),
                                  _cycleReviewStat(
                                      'Pending', inr.format(mPending), DesignColors.error),
                                  _cycleReviewStat(
                                      'Expenses', inr.format(mExpense), const Color(0xFF546E7A)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        value: (mRate / 100).clamp(0.0, 1.0),
                                        color: mRateColor,
                                        backgroundColor: context.surface.elevated,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${mRate.toStringAsFixed(0)}%',
                                    style: DesignTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: mRateColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Net for this cycle = collected − expenses.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: mNetColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      mNet >= 0
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                      size: 14,
                                      color: mNetColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Net (collected − expenses)',
                                      style:
                                          DesignTypography.labelSmall.copyWith(
                                        color: context.text.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${mNet >= 0 ? '+' : ''}${inr.format(mNet)}',
                                      style:
                                          DesignTypography.labelSmall.copyWith(
                                        color: mNetColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
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
      },
    );
  }


  Widget _cycleReviewStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 12,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Expense breakdown bottom sheet ──

  static const _categoryIcons = <String, IconData>{
    'Electricity': Icons.bolt_rounded,
    'Water': Icons.water_drop_rounded,
    'Garbage Collection': Icons.delete_rounded,
    'Security Salary': Icons.shield_rounded,
    'Housekeeping Salary': Icons.cleaning_services_rounded,
    'Maintenance Staff': Icons.engineering_rounded,
    'Gardening': Icons.yard_rounded,
    'Pest Control': Icons.bug_report_rounded,
    'Lift Maintenance': Icons.elevator_rounded,
    'Generator Maintenance': Icons.power_rounded,
    'Pump Maintenance': Icons.plumbing_rounded,
    'Common Area Repair': Icons.handyman_rounded,
    'Legal Fees': Icons.gavel_rounded,
    'Insurance': Icons.health_and_safety_rounded,
    'Taxes': Icons.receipt_long_rounded,
    'Bank Charges': Icons.account_balance_rounded,
    'Software Subscription': Icons.computer_rounded,
  };

  static const _categoryColors = <String, Color>{
    'Electricity': Color(0xFFF59E0B),
    'Water': Color(0xFF3B82F6),
    'Garbage Collection': Color(0xFF10B981),
    'Security Salary': Color(0xFF8B5CF6),
    'Housekeeping Salary': Color(0xFFEC4899),
    'Maintenance Staff': Color(0xFF6366F1),
    'Gardening': Color(0xFF22C55E),
    'Pest Control': Color(0xFFEF4444),
    'Lift Maintenance': Color(0xFF14B8A6),
    'Generator Maintenance': Color(0xFFF97316),
    'Pump Maintenance': Color(0xFF06B6D4),
    'Common Area Repair': Color(0xFF78716C),
    'Legal Fees': Color(0xFF64748B),
    'Insurance': Color(0xFF0EA5E9),
    'Taxes': Color(0xFFA855F7),
    'Bank Charges': Color(0xFF84CC16),
    'Software Subscription': Color(0xFF2563EB),
  };

  static const _fallbackColors = [
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  /// Palette color for an expense category (stable per name, falls back to the
  /// rotating palette; the synthetic "Other" bucket is neutral grey).
  Color _expenseColor(String category, int index) {
    if (category == 'Other') return context.text.tertiary;
    return _categoryColors[category] ??
        _fallbackColors[index % _fallbackColors.length];
  }

  /// Donut of the expense breakdown ("where your money goes") with the period
  /// total in the centre — same data as the category list beneath it.
  Widget _expenseDonut(
    List<MapEntry<String, double>> entries,
    double total,
    NumberFormat inr,
  ) {
    if (entries.isEmpty || total <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _expenseColor(entries[i].key, i),
                    radius: 13,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontSize: 10,
                ),
              ),
              Text(
                inr.format(total),
                style: DesignTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.text.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExpenseBreakdownSheet(
    BuildContext context, {
    required int month,
    required int year,
    required double totalExpense,
    required Map<String, double> breakdown,
  }) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));

    // Sort categories by amount descending
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.surface.defaultSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF546E7A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF546E7A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense breakdown',
                          style: DesignTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          monthLabel,
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF546E7A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inr.format(totalExpense),
                      style: DesignTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF546E7A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: context.text.secondary
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No expense data for this month',
                          style: DesignTypography.bodySmall.copyWith(
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Category bars
                ...sorted.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value.key;
                  final amount = entry.value.value;
                  final pct =
                      totalExpense > 0 ? (amount / totalExpense * 100) : 0.0;
                  final icon = _categoryIcons[cat] ??
                      Icons.category_rounded;
                  final color = _categoryColors[cat] ??
                      _fallbackColors[idx % _fallbackColors.length];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 16, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      cat,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DesignTypography.bodySmall
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    inr.format(amount),
                                    style: DesignTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        minHeight: 5,
                                        value: (pct / 100).clamp(0.0, 1.0),
                                        color: color,
                                        backgroundColor:
                                            color.withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${pct.toStringAsFixed(0)}%',
                                    style: DesignTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      color: context.text.secondary,
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
                }),
              ],
            ],
          ),
        ),
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
                color: context.surface.elevated,
                shape: BoxShape.circle,
                border: Border.all(color: context.surface.border),
              ),
              child: Icon(icon, size: 40, color: context.text.secondary),
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
                color: context.text.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildOverviewTab(
    BuildContext context,
    Map<String, dynamic> userSummary,
    Map<String, dynamic> residentsSummary,
    Map<String, dynamic> expenses,
    List<Map<String, dynamic>> residents,
    String periodLabel,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    double dn(String key) =>
        (userSummary[key] as num?)?.toDouble() ?? 0;

    // Only the current personal balance is surfaced here now — the full ledger
    // lives on the My payments tab + the dues screen (see slim strip below).
    final remaining = dn('remainingDue');

    // Society-level summary numbers
    final totalResidents =
        (residentsSummary['totalResidents'] as num?)?.toInt() ?? residents.length;
    final paidCount = (residentsSummary['paidCount'] as num?)?.toInt() ??
        residents.where((r) => (r['status']?.toString() ?? '').toUpperCase() == 'PAID').length;
    final unpaidCount = (residentsSummary['unpaidCount'] as num?)?.toInt() ??
        (totalResidents - paidCount);
    final partialCount = (residentsSummary['partialCount'] as num?)?.toInt() ?? 0;
    final overdueCount = (residentsSummary['overdueCount'] as num?)?.toInt() ?? 0;
    final totalCollected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final totalExpected =
        (residentsSummary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final totalPending =
        (residentsSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final totalExpense =
        (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final net = totalCollected - totalExpense;

    // Sort residents: unpaid/overdue first, then paid
    final sortedResidents = [...residents]..sort((a, b) {
      const order = {'OVERDUE': 0, 'PARTIAL': 1, 'UNPAID': 2, 'PENDING': 3, 'PAID': 4};
      final sa = order[(a['status']?.toString() ?? 'UNPAID').toUpperCase()] ?? 2;
      final sb = order[(b['status']?.toString() ?? 'UNPAID').toUpperCase()] ?? 2;
      if (sa != sb) return sa.compareTo(sb);
      final aa = (a['paidTowardCycle'] as num?)?.toDouble() ?? 0;
      final ab = (b['paidTowardCycle'] as num?)?.toDouble() ?? 0;
      return ab.compareTo(aa);
    });

    // Apply the All-residents search + status filter for the list below.
    final q = _residentQuery.trim().toLowerCase();
    final visibleResidents = sortedResidents.where((r) {
      final st = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
      final matchStatus = _residentStatusFilter == 'ALL' ||
          (_residentStatusFilter == 'UNPAID' &&
              (st == 'UNPAID' || st == 'PENDING')) ||
          st == _residentStatusFilter;
      if (!matchStatus) return false;
      if (q.isEmpty) return true;
      final name =
          '${r['name'] ?? r['ownerName'] ?? ''}'.toLowerCase();
      final unit =
          '${r['flatNumber'] ?? r['villaNumber'] ?? ''}'.toLowerCase();
      return name.contains(q) || unit.contains(q);
    }).toList();

    // Pin the logged-in user's own villa to the top of the list.
    final myVilla = ref
        .watch(authProvider.select((s) => s.user?.villaNumber))
        ?.trim()
        .toLowerCase();
    if (myVilla != null && myVilla.isNotEmpty) {
      final meIdx = visibleResidents.indexWhere((r) =>
          '${r['villaNumber'] ?? r['flatNumber'] ?? ''}'
              .trim()
              .toLowerCase() ==
          myVilla);
      if (meIdx > 0) {
        visibleResidents.insert(0, visibleResidents.removeAt(meIdx));
      }
    }

    return _wrapTabWithRefresh(
      CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
          // ── Your dues (compact) ──
          // Full personal ledger lives on the My payments tab + dues screen;
          // here we surface only the actionable balance, and only when owed.
          if (remaining > 0.005)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: DesignColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _goToDues,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: DesignColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your dues',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: context.text.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                inr.format(remaining),
                                style: DesignTypography.headingM.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DesignColors.warning,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: _goToDues,
                          style: FilledButton.styleFrom(
                            backgroundColor: DesignColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Pay',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Collections (society summary) ──
          _collectionsHeroCard(
            periodLabel: periodLabel,
            totalExpected: totalExpected,
            totalCollected: totalCollected,
            totalPending: totalPending,
            totalExpense: totalExpense,
            net: net,
            paidCount: paidCount,
            partialCount: partialCount,
            unpaidCount: unpaidCount,
            overdueCount: overdueCount,
            inr: inr,
          ),

          // ── Advance payments ──
          Builder(
            builder: (_) {
              final advanceResidents = <Map<String, dynamic>>[];
              for (final r in residents) {
                final paid = (r['paidTowardCycle'] as num?)?.toDouble() ?? 0;
                final exp = (r['amount'] as num?)?.toDouble() ?? 0;
                final adv = paid - exp;
                if (adv > 0.005) {
                  advanceResidents.add({...r, '_advance': adv});
                }
              }
              if (advanceResidents.isEmpty) return const SizedBox.shrink();

              advanceResidents.sort((a, b) =>
                  ((b['_advance'] as double)).compareTo(a['_advance'] as double));
              final totalAdv = advanceResidents.fold<double>(
                  0, (sum, r) => sum + (r['_advance'] as double));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _collapsibleSectionHeader(
                    'Advance payments',
                    '${advanceResidents.length} members',
                    expanded: _advanceExpanded,
                    onTap: () => setState(
                        () => _advanceExpanded = !_advanceExpanded),
                  ),
                  if (_advanceExpanded)
                    Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.surface.defaultSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.surface.border),
                        boxShadow: [
                          BoxShadow(
                            color: context.text.primary
                                .withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Total advance header
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.fromLTRB(18, 14, 18, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.06),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.trending_up_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total advance collected',
                                        style: DesignTypography.labelSmall
                                            .copyWith(
                                          color: context.text.secondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        inr.format(totalAdv),
                                        style: DesignTypography.headingM
                                            .copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF2563EB),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${advanceResidents.length}',
                                    style: DesignTypography.labelSmall
                                        .copyWith(
                                      color: const Color(0xFF2563EB),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Individual advance entries
                          ...advanceResidents.map((r) {
                            final name =
                                '${r['name'] ?? r['ownerName'] ?? 'Unknown'}'
                                    .trim();
                            final unit =
                                '${r['flatNumber'] ?? r['villaNumber'] ?? '-'}';
                            final paid =
                                (r['paidTowardCycle'] as num?)?.toDouble() ??
                                    0;
                            final exp =
                                (r['amount'] as num?)?.toDouble() ?? 0;
                            final adv = r['_advance'] as double;

                            return Container(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 10, 18, 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: context.surface.border
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      unit,
                                      style: DesignTypography.labelSmall
                                          .copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2563EB),
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: DesignTypography.bodySmall
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Expected ${inr.format(exp)} · Paid ${inr.format(paid)}',
                                          style: DesignTypography.labelSmall
                                              .copyWith(
                                            color:
                                                context.text.tertiary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: DesignColors.success
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: DesignColors.success
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Text(
                                      '+${inr.format(adv)}',
                                      style: DesignTypography.labelSmall
                                          .copyWith(
                                        color: DesignColors.success,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Expense by category ──
          Builder(
            builder: (_) {
              final raw = expenses['categoryBreakdown'];
              if (raw is! Map) return const SizedBox.shrink();
              final entries = <MapEntry<String, double>>[];
              raw.forEach((k, v) {
                final key = k.toString();
                final val = (v is num)
                    ? v.toDouble()
                    : double.tryParse(v.toString()) ?? 0;
                if (val > 0) entries.add(MapEntry(key, val));
              });
              if (entries.isEmpty) return const SizedBox.shrink();
              entries.sort((a, b) => b.value.compareTo(a.value));
              // Reconcile the printed total with the rows shown: if the
              // backend total exceeds the categorized sum, surface the
              // remainder as "Other" so the column always adds up.
              final entriesSum =
                  entries.fold<double>(0, (s, e) => s + e.value);
              final displayTotal =
                  totalExpense > entriesSum ? totalExpense : entriesSum;
              if (displayTotal - entriesSum > 0.5) {
                entries.add(MapEntry('Other', displayTotal - entriesSum));
              }
              // Per-home share — what each home effectively funds this period.
              final perHome =
                  totalResidents > 0 ? displayTotal / totalResidents : 0.0;
              final expenseSubtitle = perHome > 0
                  ? '≈ ${inr.format(perHome)}/home'
                  : periodLabel;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Where your money goes', expenseSubtitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.surface.defaultSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.surface.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Donut (centre shows the total) + a compact
                            // top-5 legend; full breakdown via the link below.
                            _expenseDonut(entries, displayTotal, inr),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0;
                                      i < entries.length && i < 5;
                                      i++)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 9),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: _expenseColor(
                                                  entries[i].key, i),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              entries[i].key.replaceAll('_', ' '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: DesignTypography.labelSmall
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: context.text.secondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            inr.format(entries[i].value),
                                            style: DesignTypography.labelSmall
                                                .copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: context.text.primary,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(entries[i].value / displayTotal * 100).toStringAsFixed(0)}%',
                                            style: DesignTypography.labelSmall
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: context.text.tertiary,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (entries.length > 5)
                                    Text(
                                      '+${entries.length - 5} more',
                                      style: DesignTypography.labelSmall.copyWith(
                                        color: context.text.tertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hide society expenses link from tenants.
                  if (!ref.watch(authProvider
                      .select((s) => s.user?.isTenant ?? false))) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () {
                          final f = ref.read(maintenanceDashboardFilterProvider);
                          context.push('/resident/expenses?month=${f.month}&year=${f.year}');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.surface.defaultSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.surface.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: DesignColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'View all society expenses',
                                  style: DesignTypography.bodySmall.copyWith(
                                    color: DesignColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: DesignColors.primary.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // ── All residents ──
          if (sortedResidents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'All residents',
                      style: DesignTypography.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.text.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$paidCount / $totalResidents paid',
                      style: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _residentsFilterBar(),
          ],
            ]),
          ),
          // Lazily built so large societies don't construct every tile up front.
          if (visibleResidents.isNotEmpty)
            SliverList.builder(
              itemCount: visibleResidents.length,
              itemBuilder: (ctx, i) {
                final r = visibleResidents[i];
                final unit = '${r['villaNumber'] ?? r['flatNumber'] ?? ''}'
                    .trim()
                    .toLowerCase();
                final isMe =
                    myVilla != null && myVilla.isNotEmpty && unit == myVilla;
                return _residentPaymentTile(r, inr, isMe: isMe);
              },
            )
          else if (sortedResidents.isNotEmpty)
            SliverToBoxAdapter(child: _residentsNoMatch()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _collapsibleSectionHeader(
    String title,
    String subtitle, {
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: DesignTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.text.primary,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: DesignTypography.caption.copyWith(
                  color: context.text.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: context.text.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: context.text.primary,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: DesignTypography.caption.copyWith(
                color: context.text.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────── Collections hero card ─────────────────────

  Widget _collectionsHeroCard({
    required String periodLabel,
    required double totalExpected,
    required double totalCollected,
    required double totalPending,
    required double totalExpense,
    required double net,
    required int paidCount,
    required int partialCount,
    required int unpaidCount,
    required int overdueCount,
    required NumberFormat inr,
  }) {
    final rate =
        totalExpected > 0 ? (totalCollected / totalExpected * 100) : 0.0;
    final rateColor = rate >= 80
        ? DesignColors.success
        : rate >= 50
            ? DesignColors.warning
            : DesignColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Collections', periodLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.surface.defaultSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.surface.border),
              boxShadow: [
                BoxShadow(
                  color: context.text.primary.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status filter chips, top-right — tap to filter residents.
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusCountPill('PAID', '$paidCount', 'Paid',
                              DesignColors.success),
                          if (partialCount > 0)
                            _statusCountPill('PARTIAL', '$partialCount',
                                'Partial', DesignColors.warning),
                          _statusCountPill('UNPAID', '$unpaidCount', 'Unpaid',
                              DesignColors.error),
                          if (overdueCount > 0)
                            _statusCountPill('OVERDUE', '$overdueCount',
                                'Overdue', DesignColors.error),
                        ],
                      ),
                      const SizedBox(height: 16),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left — ring + collected / expected
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _collectionRing(rate, rateColor),
                                const SizedBox(height: 14),
                                Text(
                                  'Collected',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: context.text.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inr.format(totalCollected),
                                  style: DesignTypography.headingL.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: context.text.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _targetChip(totalExpected, inr),
                              ],
                            ),
                            const SizedBox(width: 16),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: context.surface.border,
                            ),
                            const SizedBox(width: 16),
                            // Right — icon stat rows
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _collectionStatRow(
                                    icon: Icons.schedule_rounded,
                                    color: DesignColors.warning,
                                    label: 'Pending',
                                    value: inr.format(totalPending),
                                    valueColor: totalPending > 0.005
                                        ? DesignColors.warning
                                        : context.text.primary,
                                    onTap: () => setState(() =>
                                        _residentStatusFilter = 'UNPAID'),
                                  ),
                                  Divider(
                                    height: 1,
                                    color: context.surface.border
                                        .withValues(alpha: 0.6),
                                  ),
                                  _collectionStatRow(
                                    icon: Icons.south_rounded,
                                    color: const Color(0xFF3B82F6),
                                    label: 'Expenses',
                                    value: inr.format(totalExpense),
                                    valueColor: context.text.primary,
                                    onTap: _openExpenses,
                                  ),
                                  Divider(
                                    height: 1,
                                    color: context.surface.border
                                        .withValues(alpha: 0.6),
                                  ),
                                  _collectionStatRow(
                                    icon: net >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color: net >= 0
                                        ? DesignColors.success
                                        : DesignColors.error,
                                    label: 'Net',
                                    value:
                                        '${net >= 0 ? '+' : ''}${inr.format(net)}',
                                    valueColor: net >= 0
                                        ? DesignColors.success
                                        : DesignColors.error,
                                    onTap: _openExpenses,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _collectionsBanner(net, inr),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One row in the Collections card's right column: tinted icon + label +
  /// coloured value + chevron (the chevron only shows when tappable).
  /// Small tinted "Target ₹X" chip — surfaces the expected-collection figure
  /// next to a collected amount so it doesn't disappear under the hero number.
  Widget _targetChip(double expected, NumberFormat inr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.adjust_rounded, size: 13, color: context.text.secondary),
          const SizedBox(width: 5),
          Text(
            'Target ',
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            inr.format(expected),
            style: DesignTypography.labelSmall.copyWith(
              color: context.text.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectionStatRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.text.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.text.tertiary),
            ],
          ],
        ),
      ),
    );
  }

  /// Contextual footer banner — celebrates a surplus or flags a shortfall.
  Widget _collectionsBanner(double net, NumberFormat inr) {
    final ahead = net >= -0.005;
    final color = ahead ? DesignColors.success : DesignColors.warning;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              ahead ? Icons.bar_chart_rounded : Icons.warning_amber_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ahead
                  ? "Great job! You're ahead by ${inr.format(net)}"
                  : 'Shortfall of ${inr.format(net.abs())} this period',
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExpenses() {
    final f = ref.read(maintenanceDashboardFilterProvider);
    context.push('/resident/expenses?month=${f.month}&year=${f.year}');
  }

  Widget _collectionRing(double rate, Color color) {
    final pct = (rate / 100).clamp(0.0, 1.0);
    const d = 92.0;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: d,
            height: d,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 9,
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.surface.elevated),
            ),
          ),
          SizedBox(
            width: d,
            height: d,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: DesignTypography.headingL.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Collected',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCountPill(
    String filterValue,
    String count,
    String label,
    Color color,
  ) {
    final active = _residentStatusFilter == filterValue;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _residentStatusFilter = active ? 'ALL' : filterValue;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              count,
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: DesignTypography.labelSmall.copyWith(
                color: active ? Colors.white70 : context.text.secondary,
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Residents search + filter ─────────────────────

  Widget _residentsFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _residentSearchCtrl,
        onChanged: (v) => setState(() => _residentQuery = v),
        textInputAction: TextInputAction.search,
        style: DesignTypography.bodySmall.copyWith(color: context.text.primary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: context.surface.elevated,
          hintText: 'Search resident or unit',
          hintStyle: DesignTypography.bodySmall.copyWith(
            color: context.text.tertiary,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: context.text.tertiary),
          suffixIcon: _residentQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: context.text.tertiary),
                  onPressed: () {
                    _residentSearchCtrl.clear();
                    setState(() => _residentQuery = '');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DesignColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _residentsNoMatch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: context.text.tertiary),
            const SizedBox(height: 10),
            Text(
              'No residents match',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                _residentSearchCtrl.clear();
                setState(() {
                  _residentQuery = '';
                  _residentStatusFilter = 'ALL';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _residentPaymentTile(Map<String, dynamic> r, NumberFormat inr,
      {bool isMe = false}) {
    final rawStatus = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
    final isPaid = rawStatus == 'PAID';
    final expectedAmount = (r['amount'] as num?)?.toDouble() ?? 0;
    final actualPaid = (r['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    final displayName =
        '${r['name'] ?? r['ownerName'] ?? 'Unknown'}'.trim();
    final unit = '${r['flatNumber'] ?? r['villaNumber'] ?? '-'}';
    final statusText = switch (rawStatus) {
      'PARTIAL' => 'Partial',
      'OVERDUE' => 'Overdue',
      'PAID' => 'Paid',
      _ => 'Unpaid',
    };
    final accent = switch (rawStatus) {
      'PARTIAL' => DesignColors.warning,
      'OVERDUE' => DesignColors.error,
      'PAID' => DesignColors.success,
      _ => DesignColors.error,
    };
    final extra = actualPaid - expectedAmount;
    final hasExtra = extra > 0.005 && isPaid;
    // Lead with what's owed when nothing has been paid yet — a bare ₹0 reads as
    // "no charge" rather than "unpaid".
    final hasNoPayment = actualPaid <= 0.005;
    final displayAmount = hasNoPayment ? expectedAmount : actualPaid;
    final progress = expectedAmount > 0
        ? (actualPaid / expectedAmount).clamp(0.0, 1.0)
        : (isPaid ? 1.0 : 0.0);
    final caption = hasExtra
        ? 'Paid ${inr.format(actualPaid)} · Extra +${inr.format(extra)}'
        : isPaid
            ? 'Paid in full'
            : actualPaid > 0.005
                ? 'Paid ${inr.format(actualPaid)} of ${inr.format(expectedAmount)} · Due ${inr.format(expectedAmount - actualPaid)}'
                : 'Due ${inr.format(expectedAmount)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? DesignColors.primary.withValues(alpha: 0.5)
                : context.surface.border,
            width: isMe ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                children: [
                  // Unit avatar, tinted by status
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DesignTypography.labelSmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + unit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DesignTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: DesignColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'You',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: DesignColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.tertiary,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Amount + status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr.format(displayAmount),
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isPaid
                              ? DesignColors.success
                              : hasNoPayment
                                  ? accent
                                  : context.text.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: DesignTypography.labelSmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Thin paid-vs-expected bar flush to the card's bottom edge.
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: context.surface.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Outstanding tab ─────────────────────────

  Widget _buildOutstandingTab(BuildContext context) {
    final outstanding = ref.watch(outstandingDuesProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return outstanding.when(
      loading: () => const ListSkeleton(itemHeight: 100),
      error: (e, _) => _wrapTabWithRefresh(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DesignColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load outstanding dues',
                  style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: DesignTypography.bodySmall.copyWith(color: context.text.secondary),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(outstandingDuesProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        final villas = (data['villas'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        final totalOutstanding = (data['totalOutstanding'] as num?)?.toDouble() ?? 0;
        final villasWithDuesCount = (data['villasWithDuesCount'] as num?)?.toInt() ?? 0;
        final totalPendingCycles = (data['totalPendingCycles'] as num?)?.toInt() ?? 0;

        if (villas.isEmpty) {
          return _wrapTabWithRefresh(
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DesignColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, size: 52, color: DesignColors.success),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All dues cleared!',
                      style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every villa is up to date on maintenance payments.',
                      textAlign: TextAlign.center,
                      style: DesignTypography.bodySmall.copyWith(
                        color: context.text.secondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _wrapTabWithRefresh(
          ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            itemCount: villas.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _outstandingSummaryBanner(
                  totalOutstanding, villasWithDuesCount, totalPendingCycles, inr,
                );
              }
              return _outstandingVillaCard(villas[i - 1], inr);
            },
          ),
        );
      },
    );
  }

  Widget _outstandingSummaryBanner(
    double totalOutstanding,
    int villasWithDuesCount,
    int totalPendingCycles,
    NumberFormat inr,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.surface.border),
          boxShadow: [
            BoxShadow(
              color: context.text.primary.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 20, color: DesignColors.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total outstanding',
                        style: DesignTypography.labelSmall.copyWith(
                          color: context.text.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inr.format(totalOutstanding),
                        style: DesignTypography.headingL.copyWith(
                          color: DesignColors.error,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _outstandingChip(
                  Icons.home_outlined,
                  '$villasWithDuesCount ${villasWithDuesCount == 1 ? 'villa' : 'villas'}',
                ),
                const SizedBox(width: 8),
                _outstandingChip(
                  Icons.calendar_month_outlined,
                  '$totalPendingCycles ${totalPendingCycles == 1 ? 'month' : 'months'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outstandingChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignColors.error.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.error.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outstandingVillaCard(Map<String, dynamic> villa, NumberFormat inr) {
    final villaId = villa['villaId']?.toString() ?? '';
    final villaNumber = villa['villaNumber']?.toString() ?? '-';
    final ownerName = (villa['ownerName']?.toString() ?? '').trim();
    final totalOutstanding = (villa['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final pendingCycles = (villa['pendingCycles'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final isExpanded = _expandedOutstandingVillas.contains(villaId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: DesignColors.error.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedOutstandingVillas.remove(villaId);
                  } else {
                    _expandedOutstandingVillas.add(villaId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DesignColors.error,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName.isEmpty ? villaNumber : ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ownerName.isEmpty ? '' : villaNumber,
                            style: DesignTypography.labelSmall.copyWith(
                              color: context.text.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          inr.format(totalOutstanding),
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DesignColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${pendingCycles.length} ${pendingCycles.length == 1 ? 'month' : 'months'}',
                            style: DesignTypography.labelSmall.copyWith(
                              color: DesignColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: context.text.secondary,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded cycle rows
            if (isExpanded) ...[
              Divider(height: 1, thickness: 1, color: context.surface.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Column(
                  children: pendingCycles
                      .map((cycle) => _outstandingCycleRow(cycle, inr))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _outstandingCycleRow(Map<String, dynamic> cycle, NumberFormat inr) {
    final cycleTitle = cycle['cycleTitle']?.toString() ?? '';
    final remainingDue = (cycle['remainingDue'] as num?)?.toDouble() ?? 0;
    final isOverdue = cycle['isOverdue'] == true;
    final status = cycle['status']?.toString() ?? '';
    final accent = isOverdue ? DesignColors.error : DesignColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.error_outline_rounded : Icons.schedule_rounded,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cycleTitle,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            if (isOverdue || status == 'OVERDUE')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OVERDUE',
                    style: DesignTypography.labelSmall.copyWith(
                      color: DesignColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 8.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            Text(
              inr.format(remainingDue),
              style: DesignTypography.bodySmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Shortfall tab ──────────────────────────

  /// Uses the same data source as Year Review (billing cycles + yearlyBreakdown)
  /// to compute month-wise net position: collected − expenses.
  /// Shows only deficit months (where expenses > collected) and the total.
  Widget _buildShortfallTab(BuildContext context) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    final filter = ref.watch(maintenanceDashboardFilterProvider);

    final fyId = filter.financialYearId;
    final cyclesAsync = fyId != null && fyId.isNotEmpty
        ? ref.watch(billingCyclesForFinancialYearProvider(fyId))
        : null;

    if (cyclesAsync == null) {
      return _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.calendar_today_outlined,
            title: 'Select a financial year',
            subtitle: 'Choose a financial year from the dropdown above to view shortfall data.',
          ),
        ),
      );
    }

    return cyclesAsync.when(
      loading: () => const ListSkeleton(itemHeight: 100),
      error: (e, _) => _wrapTabWithRefresh(
        Center(
          child: _emptyState(
            icon: Icons.error_outline,
            title: 'Failed to load data',
            subtitle: e.toString(),
          ),
        ),
      ),
      data: (body) {
        final rawCycles = body['cycles'];
        final cycles = rawCycles is List
            ? rawCycles.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        // Determine calendar years spanned by this FY's cycles
        final neededYears = <int>{};
        for (final c in cycles) {
          final my = _monthYearFromCycleKey(c['cycleKey']?.toString() ?? '');
          if (my != null) neededYears.add(my.year);
        }

        // Fetch yearlyBreakdown for each calendar year
        final breakdownByKey = <String, Map<String, dynamic>>{};
        bool allYearsLoaded = true;
        Object? yearLoadError;
        for (final yr in neededYears) {
          final yrAsync = ref.watch(yearlyBreakdownForYearProvider(yr));
          yrAsync.whenData((rows) {
            for (final row in rows) {
              final m = (row['month'] as num?)?.toInt() ?? 0;
              final y = (row['year'] as num?)?.toInt() ?? 0;
              if (m > 0 && y > 0) {
                breakdownByKey['$y-${m.toString().padLeft(2, '0')}'] = row;
              }
            }
          });
          if (yrAsync is AsyncError) {
            yearLoadError ??= yrAsync.error;
          } else if (yrAsync is! AsyncData) {
            allYearsLoaded = false;
          }
        }

        // A failed year breakdown surfaces an error with retry — otherwise the
        // loading guard below would spin forever (it never sees AsyncData).
        if (yearLoadError != null) {
          return _yearDataErrorState(yearLoadError);
        }

        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const ListSkeleton(itemHeight: 100);
        }

        // Build per-cycle rows with financial data
        // Mirrors Year Review's totalExpected validation: use
        // breakdown values only when totalExpected > 0, otherwise
        // fall back to the cycle's configured amount.
        final allRows = <Map<String, dynamic>>[];
        for (final c in cycles) {
          final cycleKey = c['cycleKey']?.toString() ?? '';
          final my = _monthYearFromCycleKey(cycleKey);
          final breakdown = breakdownByKey[cycleKey];
          final cycleAmount = (c['amount'] as num?)?.toDouble() ?? 0;

          double mExp, mColl, mExpense;
          if (breakdown != null &&
              ((breakdown['totalExpected'] as num?)?.toDouble() ?? 0) > 0) {
            mExp = (breakdown['totalExpected'] as num?)?.toDouble() ?? 0;
            mColl = (breakdown['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown['totalExpense'] as num?)?.toDouble() ?? 0;
          } else {
            // `cycleAmount` is the per-villa charge — scale by billed-villa
            // count so Expected matches the society-wide Collected scale.
            final paidC = (breakdown?['paidCount'] as num?)?.toInt() ?? 0;
            final unpaidC = (breakdown?['unpaidCount'] as num?)?.toInt() ?? 0;
            final villaCount = paidC + unpaidC;
            mExp = villaCount > 0 ? cycleAmount * villaCount : 0;
            mColl = (breakdown?['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown?['totalExpense'] as num?)?.toDouble() ?? 0;
          }
          final net = mColl - mExpense;

          // Extract expense breakdown by category
          final rawBreakdown = breakdown?['expenseBreakdown'];
          final expenseBreakdown = <String, double>{};
          if (rawBreakdown is Map) {
            for (final entry in rawBreakdown.entries) {
              final val = (entry.value as num?)?.toDouble() ?? 0;
              if (val > 0) expenseBreakdown[entry.key.toString()] = val;
            }
          }

          allRows.add({
            'month': my?.month ?? 0,
            'year': my?.year ?? 0,
            'cycleKey': cycleKey,
            'totalExpected': mExp,
            'totalCollected': mColl,
            'totalExpense': mExpense,
            'net': net,
            'expenseBreakdown': expenseBreakdown,
          });
        }

        // Filter to deficit months only (where expenses > collected)
        final deficitRows = allRows.where((r) => ((r['net'] as num?)?.toDouble() ?? 0) < 0).toList();

        // Aggregated totals across ALL months
        double totalExpected = 0;
        double totalCollected = 0;
        double totalExpense = 0;
        for (final row in allRows) {
          totalExpected += (row['totalExpected'] as num?)?.toDouble() ?? 0;
          totalCollected += (row['totalCollected'] as num?)?.toDouble() ?? 0;
          totalExpense += (row['totalExpense'] as num?)?.toDouble() ?? 0;
        }

        // Total shortfall = sum of |net| for deficit months only
        final totalShortfall = deficitRows.fold<double>(
          0, (sum, r) => sum + ((r['net'] as num?)?.toDouble() ?? 0).abs(),
        );

        return _wrapTabWithRefresh(
          ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── FY-level summary card ──
              _shortfallSummaryCard(
                totalExpected: totalExpected,
                totalCollected: totalCollected,
                totalExpense: totalExpense,
                totalShortfall: totalShortfall,
                deficitCount: deficitRows.length,
                totalCycles: allRows.length,
                inr: inr,
              ),

              const SizedBox(height: 18),

              if (deficitRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesignColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 48, color: DesignColors.success),
                      ),
                      const SizedBox(height: 16),
                      Text('No deficit months',
                        style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collections covered expenses in every billing cycle this year.',
                        textAlign: TextAlign.center,
                        style: DesignTypography.bodySmall.copyWith(color: context.text.secondary, height: 1.4),
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Deficit months',
                    style: DesignTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in deficitRows) _shortfallMonthCard(row, inr),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _shortfallSummaryCard({
    required double totalExpected,
    required double totalCollected,
    required double totalExpense,
    required double totalShortfall,
    required int deficitCount,
    required int totalCycles,
    required NumberFormat inr,
  }) {
    final hasDeficit = deficitCount > 0;
    final heroColor = hasDeficit ? DesignColors.warning : DesignColors.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.surface.border),
          boxShadow: [
            BoxShadow(
              color: context.text.primary.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Shortfall',
                    style: DesignTypography.labelSmall.copyWith(
                      color: context.text.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalCycles cycle${totalCycles == 1 ? '' : 's'}',
                      style: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                hasDeficit ? inr.format(totalShortfall) : inr.format(0),
                style: DesignTypography.headingL.copyWith(
                  color: heroColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasDeficit
                    ? 'Extra paid by admin across $deficitCount deficit month${deficitCount == 1 ? '' : 's'}'
                    : 'Collections covered all expenses',
                style: DesignTypography.labelSmall.copyWith(
                  color: context.text.tertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 2),
              _collectionStatRow(
                icon: Icons.adjust_rounded,
                color: DesignColors.primary,
                label: 'Expected',
                value: inr.format(totalExpected),
                valueColor: context.text.primary,
              ),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              _collectionStatRow(
                icon: Icons.check_circle_outline_rounded,
                color: DesignColors.success,
                label: 'Collected',
                value: inr.format(totalCollected),
                valueColor: DesignColors.success,
              ),
              Divider(
                height: 1,
                color: context.surface.border.withValues(alpha: 0.6),
              ),
              _collectionStatRow(
                icon: Icons.south_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Expenses',
                value: inr.format(totalExpense),
                valueColor: context.text.primary,
              ),
              if (hasDeficit) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: DesignColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Shortfall = sum of (expenses − collected) for months where expenses exceeded collections'
                    '${deficitCount > 1 ? ' · Avg ${inr.format(totalShortfall / deficitCount)}/mo' : ''}',
                    style: DesignTypography.labelSmall.copyWith(
                      color: DesignColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortfallMonthCard(Map<String, dynamic> row, NumberFormat inr) {
    final m = (row['month'] as num?)?.toInt() ?? 1;
    final yr = (row['year'] as num?)?.toInt() ?? DateTime.now().year;
    final mColl = (row['totalCollected'] as num?)?.toDouble() ?? 0;
    final mExpense = (row['totalExpense'] as num?)?.toDouble() ?? 0;
    final mExp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
    final net = (row['net'] as num?)?.toDouble() ?? 0;
    final shortfall = net.abs();
    final breakdown = (row['expenseBreakdown'] as Map<String, double>?) ?? const <String, double>{};
    final isExpanded = _expandedShortfallMonths.contains(m * 100 + yr);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.surface.border),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() {
                final key = m * 100 + yr;
                if (isExpanded) { _expandedShortfallMonths.remove(key); }
                else { _expandedShortfallMonths.add(key); }
              }),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime(yr, m)),
                          style: DesignTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '−${inr.format(shortfall)}',
                            style: DesignTypography.bodySmall.copyWith(
                              color: const Color(0xFFDC2626), fontWeight: FontWeight.w800, fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18, color: context.text.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _cycleReviewStat('Expected', inr.format(mExp), DesignColors.primary),
                        _cycleReviewStat('Collected', inr.format(mColl), DesignColors.success),
                        _cycleReviewStat('Expenses', inr.format(mExpense), DesignColors.error),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Expanded expense breakdown
            if (isExpanded && breakdown.isNotEmpty) ...[
              Divider(height: 1, thickness: 1, color: context.surface.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense breakdown', style: DesignTypography.labelSmall.copyWith(
                      color: context.text.secondary, fontWeight: FontWeight.w700, fontSize: 10,
                      letterSpacing: 0.3,
                    )),
                    const SizedBox(height: 6),
                    for (final entry in breakdown.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key, style: DesignTypography.bodySmall.copyWith(
                              color: context.text.secondary, fontWeight: FontWeight.w500, fontSize: 12,
                            ))),
                            Text(inr.format(entry.value), style: DesignTypography.bodySmall.copyWith(
                              color: context.text.primary, fontWeight: FontWeight.w600, fontSize: 12,
                            )),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Shortfall (admin paid)', style: DesignTypography.bodySmall.copyWith(
                            color: const Color(0xFF9A3412), fontWeight: FontWeight.w700,
                          )),
                          Text(inr.format(shortfall), style: DesignTypography.bodySmall.copyWith(
                            color: const Color(0xFF9A3412), fontWeight: FontWeight.w800,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}
