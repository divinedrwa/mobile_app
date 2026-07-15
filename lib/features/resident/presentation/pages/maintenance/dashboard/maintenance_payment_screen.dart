import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/chart_palette.dart';
import '../../../../../../core/theme/semantic_colors.dart';
import '../../../../../../core/theme/design_tokens.dart';
import '../../../../../../theme/context_extensions.dart';
import '../../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../../core/widgets/shimmer_box.dart';
import '../../../widgets/list_skeleton.dart';
import '../../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../data/providers/expense_provider.dart';
import '../../../../data/providers/maintenance_provider.dart';

import 'maintenance_dashboard_utils.dart';

part 'parts/maintenance_dashboard_lifecycle.part.dart';
part 'parts/maintenance_dashboard_filter.part.dart';
part 'parts/maintenance_dashboard_year_review.part.dart';
part 'parts/maintenance_dashboard_shared.part.dart';
part 'parts/maintenance_dashboard_overview_tab.part.dart';
part 'parts/maintenance_dashboard_overview_dues.part.dart';
part 'parts/maintenance_dashboard_overview_advance.part.dart';
part 'parts/maintenance_dashboard_overview_expenses.part.dart';
part 'parts/maintenance_dashboard_overview_residents_list.part.dart';
part 'parts/maintenance_dashboard_overview_headers.part.dart';
part 'parts/maintenance_dashboard_overview_collections.part.dart';
part 'parts/maintenance_dashboard_overview_residents.part.dart';
part 'parts/maintenance_dashboard_outstanding.part.dart';
part 'parts/maintenance_dashboard_shortfall.part.dart';


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

  /// Lets dashboard `part` extensions update local UI state without calling [setState] directly.
  void mutateDashboardUi(VoidCallback fn) => setState(fn);

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
        final id = pickDefaultFinancialYearId(fys);
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
                            Icon(
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
            final root = normalizeDashboardPayload(dashboard);
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
            final dashPeriod = resolvedDashboardPeriod(root, filter);
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
                        child: Icon(
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
                  dashPeriod.month,
                  dashPeriod.year,
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
}
