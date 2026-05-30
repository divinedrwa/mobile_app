import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
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
  const MaintenancePaymentScreen({super.key});

  @override
  ConsumerState<MaintenancePaymentScreen> createState() =>
      _MaintenancePaymentScreenState();
}

class _MaintenancePaymentScreenState
    extends ConsumerState<MaintenancePaymentScreen> {
  bool _appliedInitialQueryFilter = false;
  final Set<String> _expandedOutstandingVillas = {};
  final Set<int> _expandedShortfallMonths = {};

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

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(maintenanceDashboardProvider);
    final filter = ref.watch(maintenanceDashboardFilterProvider);
    final user = ref.watch(authProvider.select((s) => s.user));
    final isAdmin = user?.role.isAdminLike ?? false;
    final tabs = isAdmin
        ? const ['Overview', 'My payments', 'Year review', 'Outstanding', 'Shortfall']
        : const ['Overview', 'My payments', 'Year review', 'Outstanding'];
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
                'Maintenance & payments',
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
          actions: _buildAppBarActions(
            dashboardState.valueOrNull,
            filter,
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
            // Collect FY billing cycle keys (e.g. "2025-04") to filter
            // paymentHistory to only the selected financial year.
            final fyCycleKeys = <String>{};
            if (filter.financialYearId != null &&
                filter.financialYearId!.isNotEmpty) {
              final cyclesData = ref
                  .read(billingCyclesForFinancialYearProvider(
                      filter.financialYearId!))
                  .valueOrNull;
              if (cyclesData != null) {
                final raw = cyclesData['cycles'];
                if (raw is List) {
                  for (final c in raw) {
                    if (c is Map) {
                      final key = c['cycleKey']?.toString() ?? '';
                      if (key.isNotEmpty) fyCycleKeys.add(key);
                    }
                  }
                }
              }
            }

            final paymentHistory = ((root['paymentHistory'] ?? const []) as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .where((e) {
                  // If we have FY cycle keys, only include entries
                  // whose month/year match one of the FY's cycles.
                  if (fyCycleKeys.isEmpty) return true;
                  final m = (e['month'] as num?)?.toInt() ?? 0;
                  final y = (e['year'] as num?)?.toInt() ?? 0;
                  final key = '$y-${m.toString().padLeft(2, '0')}';
                  return fyCycleKeys.contains(key);
                })
                .map((e) {
                  final paymentDate = DateTime.tryParse(
                    e['paymentDate']?.toString() ?? '',
                  );
                  final status = (e['status']?.toString() ?? 'PAID')
                      .toUpperCase();
                  final month = (e['month'] as num?)?.toInt() ?? 0;
                  final year = (e['year'] as num?)?.toInt() ?? 0;
                  final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                  final expected =
                      (e['expectedAmount'] as num?)?.toDouble() ?? amount;
                  final creditApplied =
                      (e['creditApplied'] as num?)?.toDouble() ?? 0;
                  final remainingDue =
                      (e['remainingDue'] as num?)?.toDouble() ?? 0;
                  final subtitle = switch (status) {
                    'AUTO_SETTLED' =>
                      'Adjusted from previous credit${creditApplied > 0 ? ' · ₹${creditApplied.toStringAsFixed(0)} used' : ''}',
                    'PARTIAL' =>
                      'Paid ₹${amount.toStringAsFixed(0)} of ₹${expected.toStringAsFixed(0)}',
                    'OVERDUE' || 'PENDING' =>
                      '₹${remainingDue.toStringAsFixed(0)} still due',
                    _ =>
                      paymentDate == null
                          ? 'Payment date unavailable'
                          : 'Paid on ${DateFormat('dd MMM yyyy').format(paymentDate.toLocal())}',
                  };
                  return {
                    ...e,
                    'label': (month >= 1 && month <= 12)
                        ? '${DateFormat('MMM').format(DateTime(year, month))} $year'
                        : '$year',
                    'subtitle': subtitle,
                    'amount': amount,
                    'status': status,
                  };
                })
                .toList();
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
            final overviewStrip = _buildTopOverviewStrip(
              periodLabel: periodLabel,
              residentsSummary: residentsSummary,
              userSummary: userSummary,
              expenses: expenses,
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
                          color: DesignColors.textSecondary,
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
                  overviewStrip,
                  periodLabel,
                ),

              if (hasFyWithoutCycle)
                _wrapTabWithRefresh(
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
                              Icons.event_busy_rounded,
                              size: 48,
                              color: DesignColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No billing cycles in this year',
                            style: DesignTypography.headingM.copyWith(
                              color: DesignColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Payment records will appear once billing cycles are created for the selected financial year.',
                            textAlign: TextAlign.center,
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildPaymentHistoryTab(
                    context,
                    paymentHistory,
                    overviewStrip,
                    filter,
                ),

              // Year review tab
              _buildYearReviewTab(context, filter),

              // Outstanding tab (admin only)
              _buildOutstandingTab(context),

              // Shortfall tab (admin only)
              if (isAdmin) _buildShortfallTab(context),
            ];

            // Block rendering until financial-year list has resolved so
            // the UI doesn't flash default/zero values while the filter
            // bar spinner is still running.
            final fyList = ref.watch(billingFinancialYearsProvider);

            if (fyList.isLoading) {
              return const Center(child: CircularProgressIndicator());
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
                    final hideFilterBar = tabIdx == 3;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!hideFilterBar) ...[
                          Material(
                            color: DesignColors.surface,
                            elevation: 0,
                            child: _buildStickyFilterBar(
                                ctx2, filter, root,
                                hidesCycleDropdown: tabIdx >= 1),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color:
                                DesignColors.borderLight.withValues(alpha: 0.6),
                          ),
                        ],
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

  List<Widget> _buildAppBarActions(
    Map<String, dynamic>? dashboard,
    MaintenanceDashboardFilter filter,
  ) {
    return [
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded, color: DesignColors.textSecondary),
        onPressed: _pullRefreshMaintenance,
      ),
      IconButton(
        tooltip: 'Download PDF',
        icon: const Icon(Icons.picture_as_pdf_outlined, color: DesignColors.textSecondary),
        onPressed: dashboard == null
            ? null
            : () => _downloadPdfReport(context, dashboard, filter),
      ),
      IconButton(
        tooltip: 'Analytics',
        icon: const Icon(Icons.insights_outlined, color: DesignColors.textSecondary),
        onPressed: dashboard == null
            ? null
            : () => _openFinancialOverview(context, dashboard),
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
      borderSide: const BorderSide(color: DesignColors.borderLight),
    );
    final fyAsync = ref.watch(billingFinancialYearsProvider);

    return Material(
      color: DesignColors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: fyAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                color: DesignColors.textSecondary,
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
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: DesignColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No records available. Financial year has not been created yet.',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
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

    String cycleMenuLabel(Map<String, dynamic> c) {
      final key = c['cycleKey']?.toString() ?? '';
      final my = _monthYearFromCycleKey(key);
      final period = my != null
          ? DateFormat('MMMM yyyy').format(DateTime(my.year, my.month))
          : key;
      final st = c['status']?.toString() ?? '';
      return st.isEmpty ? period : '$period · $st';
    }

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
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: DesignColors.surfaceSoft,
            labelText: 'Financial year',
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
                color: DesignColors.textSecondary,
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
                      color: DesignColors.textSecondary,
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
                return DropdownButtonFormField<String>(
                  key: ValueKey('maint-cycle-$selectedId'),
                  initialValue: selectedId,
                  style: DesignTypography.bodyMedium.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: DesignColors.surfaceSoft,
                    labelText: 'Billing month (cycle)',
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
                  items: cycles
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id']?.toString(),
                          child: Text(cycleMenuLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final c = cycles.firstWhere(
                      (x) => x['id']?.toString() == id,
                    );
                    final key = c['cycleKey']?.toString() ?? '';
                    final my = _monthYearFromCycleKey(key);
                    if (my == null) return;
                    final cur = ref.read(maintenanceDashboardFilterProvider);
                    ref.read(maintenanceDashboardFilterProvider.notifier).state =
                        cur.copyWith(
                      billingCycleId: id,
                      month: my.month,
                      year: my.year,
                      clearBillingCycleId: false,
                      clearFinancialYearId: false,
                      financialYearId: fyId,
                      clearCollectionCycleId: true,
                    );
                    ref.invalidate(maintenanceDashboardProvider);
                  },
                );
              },
            ),
        ],
      ],
    );
  }

  Widget _buildTopOverviewStrip({
    required String periodLabel,
    required Map<String, dynamic> residentsSummary,
    required Map<String, dynamic> userSummary,
    required Map<String, dynamic> expenses,
  }) {
    final expected =
        (residentsSummary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final collected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final pending =
        (residentsSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final totalExpense = (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final collectionRate = expected > 0 ? (collected / expected * 100) : 0.0;
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final rateColor = collectionRate >= 80
        ? DesignColors.success
        : collectionRate >= 50
            ? DesignColors.warning
            : DesignColors.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 4-stat inline row
            Row(
              children: [
                _compactStat('Expected', inr.format(expected), DesignColors.primary),
                _compactStat('Collected', inr.format(collected), DesignColors.success),
                _compactStat('Pending', inr.format(pending), DesignColors.error),
                _compactStat('Expenses', inr.format(totalExpense), const Color(0xFF546E7A)),
              ],
            ),
            const SizedBox(height: 10),
            // Compact collection progress bar
            Row(
              children: [
                Text(
                  'Collection',
                  style: DesignTypography.labelSmall.copyWith(
                    color: DesignColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: (collectionRate / 100).clamp(0.0, 1.0),
                      color: rateColor,
                      backgroundColor: DesignColors.surfaceSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${collectionRate.toStringAsFixed(0)}%',
                  style: DesignTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: rateColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 13,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTab(
    BuildContext context,
    List<Map<String, dynamic>> history,
    Widget overviewStrip,
    MaintenanceDashboardFilter filter,
  ) {
    // Sort by year desc, month desc
    final sorted = [...history]..sort((a, b) {
      final ya = (a['year'] as num?)?.toInt() ?? 0;
      final yb = (b['year'] as num?)?.toInt() ?? 0;
      if (ya != yb) return yb.compareTo(ya);
      final ma = (a['month'] as num?)?.toInt() ?? 0;
      final mb = (b['month'] as num?)?.toInt() ?? 0;
      return mb.compareTo(ma);
    });
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    // Compute yearly totals
    double totalPaid = 0;
    double totalExpected = 0;
    double totalAdvance = 0;
    double totalPending = 0;
    int paidCycles = 0;
    int pendingCycles = 0;
    for (final item in sorted) {
      // Use paidAmount (total applied = cash + credit + online) as primary.
      // Fallback chain: paidAmount → cashPaidAmount → amount.
      // cashPaidAmount alone is 0 for auto-settled/credit cycles.
      final paidAmt = (item['paidAmount'] as num?)?.toDouble() ?? 0;
      final cashAmt = (item['cashPaidAmount'] as num?)?.toDouble() ?? 0;
      final paid = paidAmt > 0
          ? paidAmt
          : (cashAmt > 0
              ? cashAmt
              : ((item['amount'] as num?)?.toDouble() ?? 0));
      final expected = (item['expectedAmount'] as num?)?.toDouble() ?? paid;
      final remaining = (item['remainingDue'] as num?)?.toDouble() ?? 0;
      final status = (item['status']?.toString() ?? '').toUpperCase();
      totalPaid += paid;
      totalExpected += expected;
      if (paid > expected + 0.005) totalAdvance += (paid - expected);
      totalPending += remaining;
      if (status == 'PAID' || status == 'AUTO_SETTLED') {
        paidCycles++;
      } else {
        pendingCycles++;
      }
    }

    final completionRate =
        sorted.isEmpty ? 0.0 : paidCycles / sorted.length;

    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ── Year summary hero ──
          if (sorted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF334155),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your annual summary',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  inr.format(totalPaid),
                                  style: DesignTypography.headingL.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontSize: 28,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'total paid',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: pendingCycles > 0
                                  ? DesignColors.warning.withValues(alpha: 0.2)
                                  : DesignColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$paidCycles / ${sorted.length} paid',
                              style: DesignTypography.labelSmall.copyWith(
                                color: pendingCycles > 0
                                    ? DesignColors.warning
                                    : DesignColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: completionRate,
                              minHeight: 5,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                completionRate >= 1.0
                                    ? DesignColors.success
                                    : DesignColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      child: Row(
                        children: [
                          _darkMiniStat(
                              'Expected', inr.format(totalExpected)),
                          const SizedBox(width: 16),
                          _darkMiniStat(
                            'Pending',
                            inr.format(totalPending),
                            color: totalPending > 0.005
                                ? DesignColors.warning
                                : null,
                          ),
                          if (totalAdvance > 0.005) ...[
                            const SizedBox(width: 16),
                            _darkMiniStat(
                              'Advance',
                              '+${inr.format(totalAdvance)}',
                              color: DesignColors.success,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Cycle-wise breakdown header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                Text(
                  'Cycle-wise breakdown',
                  style: DesignTypography.label.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (sorted.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${sorted.length} ${sorted.length == 1 ? 'cycle' : 'cycles'}',
                      style: DesignTypography.labelSmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (sorted.isEmpty)
            SizedBox(
              height: 240,
              child: Center(
                child: _emptyState(
                  icon: Icons.payments_outlined,
                  title: 'No payments on file',
                  subtitle:
                      'Select a financial year to see your payment history.',
                ),
              ),
            )
          else
            // Timeline-style cycle list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: DesignColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.textPrimary.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < sorted.length; i++)
                      _paymentCycleRow(sorted[i], inr, i == sorted.length - 1),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paymentCycleRow(
    Map<String, dynamic> item,
    NumberFormat inr,
    bool isLast,
  ) {
    final month = (item['month'] as num?)?.toInt() ?? 0;
    final year = (item['year'] as num?)?.toInt() ?? 0;
    // Use paidAmount (total applied = cash + credit) as primary display.
    // cashPaidAmount alone is 0 for auto-settled/credit cycles.
    final paidAmt = (item['paidAmount'] as num?)?.toDouble() ?? 0;
    final cashPaidRaw = (item['cashPaidAmount'] as num?)?.toDouble() ?? 0;
    final cashPaid = paidAmt > 0
        ? paidAmt
        : (cashPaidRaw > 0
            ? cashPaidRaw
            : ((item['amount'] as num?)?.toDouble() ?? 0));
    final expected =
        (item['expectedAmount'] as num?)?.toDouble() ?? cashPaid;
    final creditApplied =
        (item['creditApplied'] as num?)?.toDouble() ?? 0;
    final remaining = (item['remainingDue'] as num?)?.toDouble() ?? 0;
    final status =
        (item['status']?.toString() ?? 'PAID').toUpperCase();
    final advance =
        cashPaid > expected + 0.005 ? cashPaid - expected : 0.0;

    final accent = switch (status) {
      'AUTO_SETTLED' => DesignColors.primary,
      'PARTIAL' => DesignColors.warning,
      'OVERDUE' => DesignColors.error,
      'PENDING' => DesignColors.warning,
      _ => DesignColors.success,
    };
    final statusLabel = switch (status) {
      'AUTO_SETTLED' => 'Credit',
      'PARTIAL' => 'Partial',
      'OVERDUE' => 'Overdue',
      'PENDING' => 'Due',
      _ => 'Paid',
    };
    final periodLabel = (month >= 1 && month <= 12)
        ? DateFormat('MMM yyyy').format(DateTime(year, month))
        : '$year';

    return InkWell(
      onTap: () => _showPaymentHistoryDetails(context, item),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: DesignColors.borderLight.withValues(alpha: 0.6),
                  ),
                ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Period + expected
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: DesignTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Expected ${inr.format(expected)}',
                        style: DesignTypography.labelSmall.copyWith(
                          color: DesignColors.textTertiary,
                          fontWeight: FontWeight.w500,
                          fontSize: 10.5,
                        ),
                      ),
                      if (advance > 0.005) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                DesignColors.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${inr.format(advance)}',
                            style: DesignTypography.labelSmall.copyWith(
                              color: DesignColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                      if (remaining > 0.005 && advance <= 0.005) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                DesignColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Due ${inr.format(remaining)}',
                            style: DesignTypography.labelSmall.copyWith(
                              color: DesignColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                      if (creditApplied > 0.005) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                DesignColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Credit ${inr.format(creditApplied)}',
                            style: DesignTypography.labelSmall.copyWith(
                              color: DesignColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Amount + status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  inr.format(cashPaid),
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
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
    );
  }

  Widget _darkMiniStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: Colors.white38,
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? Colors.white70,
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
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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
          if (yrAsync is! AsyncData) allYearsLoaded = false;
        }

        // Show loading if year breakdowns haven't arrived yet.
        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
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
            mExp = cycleAmount;
            mColl = (breakdown?['totalCollected'] as num?)?.toDouble() ?? 0;
            mExpense = (breakdown?['totalExpense'] as num?)?.toDouble() ?? 0;
            paidC = (breakdown?['paidCount'] as num?)?.toInt() ?? 0;
            unpaidC = (breakdown?['unpaidCount'] as num?)?.toInt() ?? 0;
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.analytics_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Year review',
                              style: DesignTypography.labelSmall.copyWith(
                                color: Colors.white60,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cycleRows.length} cycle${cycleRows.length == 1 ? '' : 's'}',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _yearReviewStat(
                                'Expected', inr.format(totalExpected), Colors.white),
                            _yearReviewStat('Collected', inr.format(totalCollected),
                                const Color(0xFF4ADE80)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _yearReviewStat('Pending', inr.format(totalPending),
                                const Color(0xFFFBBF24)),
                            _yearReviewStat('Expenses', inr.format(totalExpense),
                                const Color(0xFF94A3B8)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Collection rate',
                              style: DesignTypography.labelSmall.copyWith(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: (collectionRate / 100).clamp(0.0, 1.0),
                                  color: rateColor,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${collectionRate.toStringAsFixed(0)}%',
                              style: DesignTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: rateColor,
                              ),
                            ),
                          ],
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
                      color: DesignColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DesignColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 40,
                          color: DesignColors.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No billing cycles in this year',
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.textSecondary,
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
                          color: DesignColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentMonth
                                ? DesignColors.primary.withValues(alpha: 0.5)
                                : DesignColors.borderLight,
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
                                      color: DesignColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: DesignColors.textSecondary
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
                                        backgroundColor: DesignColors.surfaceSoft,
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

  Widget _yearReviewStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
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
              color: DesignColors.textSecondary,
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
      backgroundColor: DesignColors.surface,
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
                            color: DesignColors.textSecondary,
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
                          color: DesignColors.textSecondary
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No expense data for this month',
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.textSecondary,
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
                                      color: DesignColors.textSecondary,
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


  Widget _buildOverviewTab(
    BuildContext context,
    Map<String, dynamic> userSummary,
    Map<String, dynamic> residentsSummary,
    Map<String, dynamic> expenses,
    List<Map<String, dynamic>> residents,
    Widget overviewStrip,
    String periodLabel,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    double dn(String key) =>
        (userSummary[key] as num?)?.toDouble() ?? 0;

    final expected = dn('expectedAmount');
    final cashPaid = dn('cashPaidAmount');
    final creditApplied = dn('creditApplied');
    final paidApplied = dn('paidAmount');
    final remaining = dn('remainingDue');
    final carry = dn('carryForwardBalance');
    final previous = dn('previousDue');

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

    return _wrapTabWithRefresh(
      ListView(
        padding: const EdgeInsets.only(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          overviewStrip,

          // ── Your ledger ──
          _sectionHeader('Your ledger', periodLabel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: DesignColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: DesignColors.textPrimary.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Hero amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      color: remaining > 0.005
                          ? DesignColors.warning.withValues(alpha: 0.06)
                          : DesignColors.success.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              remaining > 0.005 ? 'Due this period' : 'All settled',
                              style: DesignTypography.labelSmall.copyWith(
                                color: remaining > 0.005
                                    ? DesignColors.warning
                                    : DesignColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inr.format(remaining > 0.005 ? remaining : paidApplied),
                              style: DesignTypography.headingL.copyWith(
                                fontWeight: FontWeight.w800,
                                color: remaining > 0.005
                                    ? DesignColors.warning
                                    : DesignColors.success,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: remaining > 0.005
                                ? DesignColors.warning.withValues(alpha: 0.12)
                                : DesignColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            remaining > 0.005 ? 'Pending' : 'Paid',
                            style: DesignTypography.labelSmall.copyWith(
                              color: remaining > 0.005
                                  ? DesignColors.warning
                                  : DesignColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      children: [
                        _ledgerRow('Expected', inr.format(expected)),
                        _ledgerRow('Cash paid', inr.format(cashPaid),
                            valueColor: cashPaid > 0.005
                                ? DesignColors.success
                                : null),
                        if (creditApplied > 0.005)
                          _ledgerRow('Credit applied', inr.format(creditApplied),
                              valueColor: DesignColors.success),
                        _ledgerRow('Total applied', inr.format(paidApplied),
                            valueColor: DesignColors.success),
                        if (remaining > 0.005)
                          _ledgerRow('Remaining', inr.format(remaining),
                              valueColor: DesignColors.warning),
                        if (previous.abs() > 0.005 || carry.abs() > 0.005) ...[
                          const Divider(height: 20),
                          if (previous.abs() > 0.005)
                            _ledgerRow('Prior balance', inr.format(previous),
                                subtle: true),
                          if (carry.abs() > 0.005)
                            _ledgerRow('Carry-forward', inr.format(carry),
                                subtle: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                  _sectionHeader(
                      'Advance payments', '${advanceResidents.length} members'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: DesignColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: DesignColors.textPrimary
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
                                          color: DesignColors.textSecondary,
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
                                    color: DesignColors.borderLight
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
                                                DesignColors.textTertiary,
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Expense by category', periodLabel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DesignColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < entries.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: DesignColors.textSecondary
                                          .withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      entries[i]
                                          .key
                                          .replaceAll('_', ' '),
                                      style: DesignTypography.bodySmall
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    inr.format(entries[i].value),
                                    style: DesignTypography.bodySmall
                                        .copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF546E7A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < entries.length - 1)
                              Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: DesignColors.borderLight
                                    .withValues(alpha: 0.6),
                              ),
                          ],
                          // Total row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF546E7A)
                                  .withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Total expenses',
                                  style: DesignTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  inr.format(totalExpense),
                                  style: DesignTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF546E7A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hide society expenses link from tenants.
                  if (!(ref.read(authProvider).user?.isTenant ?? false)) ...[
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
                            color: DesignColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DesignColors.borderLight),
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

          // ── Society summary ──
          _sectionHeader('Society summary', periodLabel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: DesignColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: DesignColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: DesignColors.textPrimary.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resident status chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _summaryChip(
                          '$totalResidents',
                          'Residents',
                          DesignColors.primary,
                        ),
                        _summaryChip(
                          '$paidCount',
                          'Paid',
                          DesignColors.success,
                        ),
                        _summaryChip(
                          '$unpaidCount',
                          'Unpaid',
                          unpaidCount > 0
                              ? DesignColors.error
                              : DesignColors.textSecondary,
                        ),
                        if (partialCount > 0)
                          _summaryChip(
                            '$partialCount',
                            'Partial',
                            DesignColors.warning,
                          ),
                        if (overdueCount > 0)
                          _summaryChip(
                            '$overdueCount',
                            'Overdue',
                            DesignColors.error,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _ledgerRow('Expected', inr.format(totalExpected)),
                    _ledgerRow('Collected', inr.format(totalCollected),
                        valueColor: DesignColors.success),
                    _ledgerRow('Pending', inr.format(totalPending),
                        valueColor: totalPending > 0.005
                            ? DesignColors.warning
                            : DesignColors.textPrimary),
                    _ledgerRow('Expenses', inr.format(totalExpense)),
                    _ledgerRow(
                      'Net position',
                      '${net >= 0 ? '+' : ''}${inr.format(net)}',
                      valueColor: net >= 0
                          ? DesignColors.success
                          : DesignColors.error,
                    ),
                  ],
                ),
              ),
            ),
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
                        color: DesignColors.textPrimary,
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
            ...sortedResidents.map(
              (r) => _residentPaymentTile(r, inr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: DesignTypography.label.copyWith(
              fontWeight: FontWeight.w800,
              color: DesignColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _residentPaymentTile(Map<String, dynamic> r, NumberFormat inr) {
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
    final hasShortfall = actualPaid > 0.005 && !isPaid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // Left accent bar
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + unit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Unit $unit',
                          style: DesignTypography.labelSmall.copyWith(
                            color: DesignColors.textSecondary,
                            fontWeight: FontWeight.w500,
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
                        inr.format(actualPaid),
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isPaid ? DesignColors.success : DesignColors.textPrimary,
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
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2),
                          ),
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
            // Breakdown row — when paid extra or has partial payment
            if (hasExtra || hasShortfall)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(30, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasExtra
                        ? DesignColors.success.withValues(alpha: 0.05)
                        : DesignColors.warning.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasExtra
                          ? DesignColors.success.withValues(alpha: 0.12)
                          : DesignColors.warning.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    hasExtra
                        ? 'Expected ${inr.format(expectedAmount)} · Paid ${inr.format(actualPaid)} · Extra +${inr.format(extra)}'
                        : 'Expected ${inr.format(expectedAmount)} · Paid ${inr.format(actualPaid)} · Due ${inr.format(expectedAmount - actualPaid)}',
                    style: DesignTypography.labelSmall.copyWith(
                      color: hasExtra
                          ? DesignColors.success
                          : DesignColors.warning,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ledgerRow(
    String label,
    String value, {
    Color? valueColor,
    bool subtle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: subtle
                    ? DesignColors.textTertiary
                    : DesignColors.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: DesignTypography.bodySmall.copyWith(
              color: valueColor ??
                  (subtle
                      ? DesignColors.textTertiary
                      : DesignColors.textPrimary),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _openFinancialOverview(
    BuildContext context,
    Map<String, dynamic> dashboard,
  ) {
    final fyId =
        ref.read(maintenanceDashboardFilterProvider).financialYearId;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionExpenseOverviewScreen(
          dashboard: dashboard,
          financialYearId: fyId,
        ),
      ),
    );
  }

  void _showPaymentHistoryDetails(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final amount = (item['amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (item['paidAmount'] as num?)?.toDouble() ?? amount;
    final creditApplied = (item['creditApplied'] as num?)?.toDouble() ?? 0;
    final expectedAmount =
        (item['expectedAmount'] as num?)?.toDouble() ?? paidAmount;
    final pendingAmount = (item['remainingDue'] as num?)?.toDouble() ?? 0;
    final carryForwardBalance =
        (item['carryForwardBalance'] as num?)?.toDouble() ?? 0;
    final paymentMode = item['paymentMode']?.toString() ?? '—';
    final notes = item['notes']?.toString();
    final paymentDate = DateTime.tryParse(
      item['paymentDate']?.toString() ?? '',
    );
    final status = (item['status']?.toString() ?? 'PAID').toUpperCase();
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: DesignColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SingleChildScrollView(
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
              Builder(builder: (_) {
                final isSettled = status == 'PAID' || status == 'AUTO_SETTLED';
                final heroAmount = paidAmount > 0 ? paidAmount : expectedAmount;
                final heroLabel = isSettled ? 'Amount settled' : 'Expected amount';
                final heroColor = isSettled
                    ? DesignColors.success
                    : (status == 'OVERDUE'
                        ? DesignColors.error
                        : DesignColors.warning);
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: heroColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: heroColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heroLabel,
                        style: DesignTypography.labelSmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inr.format(heroAmount),
                        style: DesignTypography.headingL.copyWith(
                          fontWeight: FontWeight.w800,
                          color: heroColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              _detailRow(
                'Status',
                status.replaceAll('_', ' '),
                valueColor: status == 'OVERDUE'
                    ? DesignColors.error
                    : status == 'PARTIAL' || status == 'PENDING'
                    ? DesignColors.warning
                    : DesignColors.success,
              ),
              _detailRow(
                'Payment date',
                paymentDate == null
                    ? '—'
                    : DateFormat('dd MMM yyyy').format(paymentDate.toLocal()),
              ),
              _detailRow('Expected amount', inr.format(expectedAmount)),
              _detailRow('Cash received', inr.format(amount)),
              _detailRow('Applied to cycle', inr.format(paidAmount)),
              if (creditApplied > 0.005)
                _detailRow('Credit used', inr.format(creditApplied)),
              _detailRow('Pending amount', inr.format(pendingAmount)),
              _detailRow(
                'Carry forward',
                inr.format(carryForwardBalance),
                valueColor: carryForwardBalance < 0
                    ? DesignColors.error
                    : DesignColors.textPrimary,
              ),
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

  Future<void> _downloadPdfReport(
    BuildContext context,
    Map<String, dynamic> dashboard,
    MaintenanceDashboardFilter filter,
  ) async {
    try {
      final bytes = await ref
          .read(maintenanceRepositoryProvider)
          .downloadMaintenanceReportPdf(
            month: filter.month,
            year: filter.year,
          );
      if (bytes.isEmpty) throw Exception('Empty report received');
      final suffix =
          filter.maintenanceCollectionCycleId != null &&
              filter.maintenanceCollectionCycleId!.isNotEmpty
          ? '_${filter.maintenanceCollectionCycleId!.length >= 8 ? filter.maintenanceCollectionCycleId!.substring(0, 8) : filter.maintenanceCollectionCycleId}'
          : '';
      await _sharePdfBytes(
        Uint8List.fromList(bytes),
        filename:
            'maintenance_report_${filter.year}_${filter.month.toString().padLeft(2, '0')}$suffix.pdf',
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

  // ───────────────────────── Outstanding tab ─────────────────────────

  Widget _buildOutstandingTab(BuildContext context) {
    final outstanding = ref.watch(outstandingDuesProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return outstanding.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
                  style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
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
                        color: DesignColors.textSecondary,
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
          gradient: LinearGradient(
            colors: [
              DesignColors.error.withValues(alpha: 0.08),
              DesignColors.error.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Outstanding',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.error.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              inr.format(totalOutstanding),
              style: DesignTypography.headingL.copyWith(
                color: DesignColors.error,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
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
          color: DesignColors.surface,
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
                              color: DesignColors.textSecondary,
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
                      color: DesignColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded cycle rows
            if (isExpanded) ...[
              Divider(height: 1, thickness: 1, color: DesignColors.borderLight.withValues(alpha: 0.5)),
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
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(strokeWidth: 2)),
      ),
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
          if (yrAsync is! AsyncData) allYearsLoaded = false;
        }

        if (!allYearsLoaded && neededYears.isNotEmpty) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(strokeWidth: 2)),
          );
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
            mExp = cycleAmount;
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
                        style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary, height: 1.4),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Admin shortfall',
                      style: DesignTypography.labelSmall.copyWith(
                        color: Colors.white60, fontWeight: FontWeight.w600, letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalCycles cycle${totalCycles == 1 ? '' : 's'}',
                      style: DesignTypography.labelSmall.copyWith(
                        color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Hero shortfall amount
              Text(
                deficitCount > 0 ? inr.format(totalShortfall) : inr.format(0),
                style: DesignTypography.headingL.copyWith(
                  color: deficitCount > 0 ? const Color(0xFFFB923C) : const Color(0xFF4ADE80),
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deficitCount > 0
                    ? 'Extra amount paid by admin across $deficitCount deficit month${deficitCount == 1 ? '' : 's'}'
                    : 'No shortfall — collections covered all expenses',
                style: DesignTypography.labelSmall.copyWith(
                  color: Colors.white54, fontWeight: FontWeight.w500, fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _yearReviewStat('Expected', inr.format(totalExpected), const Color(0xFF94A3B8)),
                  _yearReviewStat('Collected', inr.format(totalCollected), const Color(0xFF4ADE80)),
                  _yearReviewStat('Expenses', inr.format(totalExpense), const Color(0xFFF87171)),
                ],
              ),
              if (deficitCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Shortfall = sum of (expenses − collected) for each month where expenses exceeded collections'
                    '${deficitCount > 1 ? ' · Avg ${inr.format(totalShortfall / deficitCount)}/mo' : ''}',
                    style: DesignTypography.labelSmall.copyWith(
                      color: const Color(0xFFFBBF24), fontWeight: FontWeight.w600, fontSize: 11,
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
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.borderLight),
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
                          size: 18, color: DesignColors.textSecondary,
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
              Divider(height: 1, thickness: 1, color: DesignColors.borderLight.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expense breakdown', style: DesignTypography.labelSmall.copyWith(
                      color: DesignColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 10,
                      letterSpacing: 0.3,
                    )),
                    const SizedBox(height: 6),
                    for (final entry in breakdown.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key, style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12,
                            ))),
                            Text(inr.format(entry.value), style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12,
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

pw.TableRow _pdfRow(String key, String value) {
  return pw.TableRow(
    children: [
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(key)),
      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(value)),
    ],
  );
}

enum _OverviewMode { monthly, yearly }

class CollectionExpenseOverviewScreen extends ConsumerStatefulWidget {
  const CollectionExpenseOverviewScreen({
    super.key,
    required this.dashboard,
    this.financialYearId,
  });

  final Map<String, dynamic> dashboard;
  final String? financialYearId;

  @override
  ConsumerState<CollectionExpenseOverviewScreen> createState() =>
      _CollectionExpenseOverviewScreenState();
}

class _CollectionExpenseOverviewScreenState
    extends ConsumerState<CollectionExpenseOverviewScreen> {
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
    // Only months where a billing cycle actually exists (calendar-year fallback).
    final dashboardYearlyBreakdown =
        ((widget.dashboard['yearlyBreakdown'] ?? const []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((row) {
              final exp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
              final paid = (row['paidCount'] as num?)?.toInt() ?? 0;
              final unpaid = (row['unpaidCount'] as num?)?.toInt() ?? 0;
              return exp > 0 || (paid + unpaid) > 0;
            })
            .toList();

    final expected =
        (residentsSummary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final collected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final pending = (residentsSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final totalExpense = (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final net = collected - totalExpense;
    final collectionRate = expected > 0 ? (collected / expected * 100) : 0.0;

    // ----- FY-aware yearly breakdown -----
    final fyId = widget.financialYearId;
    final hasFyId = fyId != null && fyId.isNotEmpty;
    List<Map<String, dynamic>> yearlyBreakdown = dashboardYearlyBreakdown;
    bool fyLoading = false;
    String? fyLabel;

    if (hasFyId && _mode == _OverviewMode.yearly) {
      // Look up FY label.
      final fysAsync = ref.watch(billingFinancialYearsProvider);
      fysAsync.whenData((fys) {
        for (final fy in fys) {
          if (fy['id']?.toString() == fyId) {
            fyLabel = fy['label']?.toString();
            break;
          }
        }
      });

      // Get cycles for this FY.
      final cyclesAsync =
          ref.watch(billingCyclesForFinancialYearProvider(fyId));
      cyclesAsync.when(
        loading: () {
          fyLoading = true;
        },
        error: (_, __) {},
        data: (body) {
          final rawCycles = body['cycles'];
          final cycles = rawCycles is List
              ? rawCycles
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

          // Determine which calendar years the FY spans.
          final neededYears = <int>{};
          final fyCycleKeys = <String>{};
          for (final c in cycles) {
            final ck = c['cycleKey']?.toString() ?? '';
            fyCycleKeys.add(ck);
            final my = _monthYearFromCycleKey(ck);
            if (my != null) neededYears.add(my.year);
          }

          // Fetch yearlyBreakdown for each calendar year and merge.
          final breakdownByKey = <String, Map<String, dynamic>>{};
          bool allYearsLoaded = true;
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
            if (yrAsync is! AsyncData) allYearsLoaded = false;
          }

          if (!allYearsLoaded && neededYears.isNotEmpty) {
            fyLoading = true;
          } else {
            // Build FY-filtered breakdown rows.
            final fyRows = <Map<String, dynamic>>[];
            for (final ck in fyCycleKeys) {
              final row = breakdownByKey[ck];
              if (row != null) {
                fyRows.add(row);
              } else {
                // Create stub from cycle data.
                final my = _monthYearFromCycleKey(ck);
                if (my != null) {
                  fyRows.add({
                    'month': my.month,
                    'year': my.year,
                    'totalExpected': 0,
                    'totalCollected': 0,
                    'totalExpense': 0,
                    'paidCount': 0,
                    'unpaidCount': 0,
                  });
                }
              }
            }
            // Filter to non-empty rows.
            yearlyBreakdown = fyRows.where((row) {
              final exp = (row['totalExpected'] as num?)?.toDouble() ?? 0;
              final paid = (row['paidCount'] as num?)?.toInt() ?? 0;
              final unpaid = (row['unpaidCount'] as num?)?.toInt() ?? 0;
              return exp > 0 || (paid + unpaid) > 0;
            }).toList();
          }
        },
      );
    }

    final yearlyExpected = yearlyBreakdown.fold<double>(
      0,
      (sum, row) => sum + ((row['totalExpected'] as num?)?.toDouble() ?? 0),
    );
    final yearlyCollected = yearlyBreakdown.fold<double>(
      0,
      (sum, row) => sum + ((row['totalCollected'] as num?)?.toDouble() ?? 0),
    );
    final yearlyExpense = yearlyBreakdown.fold<double>(
      0,
      (sum, row) => sum + ((row['totalExpense'] as num?)?.toDouble() ?? 0),
    );
    final yearlyPending = yearlyExpected - yearlyCollected;
    final yearlyNet = yearlyCollected - yearlyExpense;
    final yearlyCollRate =
        yearlyExpected > 0 ? (yearlyCollected / yearlyExpected * 100) : 0.0;

    final categories = _categoryEntries(expenses).take(8).toList();
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    Widget compactStats({
      required double exp,
      required double coll,
      required double pend,
      required double expn,
      required double rate,
    }) {
      final rateColor = rate >= 80
          ? DesignColors.success
          : rate >= 50
              ? DesignColors.warning
              : DesignColors.error;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.borderLight),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _inlineStat('Expected', inr.format(exp), DesignColors.primary),
                _inlineStat('Collected', inr.format(coll), DesignColors.success),
                _inlineStat('Pending', inr.format(pend), DesignColors.error),
                _inlineStat(
                    'Expenses', inr.format(expn), const Color(0xFF546E7A)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Collection',
                  style: DesignTypography.labelSmall.copyWith(
                    color: DesignColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: (rate / 100).clamp(0.0, 1.0),
                      color: rateColor,
                      backgroundColor: DesignColors.surfaceSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: DesignTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: rateColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
              _mode == _OverviewMode.yearly && fyLabel != null
                  ? fyLabel!
                  : periodLabel,
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
          const SizedBox(height: 14),
          if (_mode == _OverviewMode.monthly) ...[
            compactStats(
              exp: expected,
              coll: collected,
              pend: pending,
              expn: totalExpense,
              rate: collectionRate,
            ),
            const SizedBox(height: 14),
            _comparisonBlock(
              collected: collected,
              expense: totalExpense,
              net: net,
            ),
          ] else if (fyLoading) ...[
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ] else ...[
            compactStats(
              exp: yearlyExpected,
              coll: yearlyCollected,
              pend: yearlyPending > 0 ? yearlyPending : 0,
              expn: yearlyExpense,
              rate: yearlyCollRate,
            ),
            const SizedBox(height: 14),
            _comparisonBlock(
              collected: yearlyCollected,
              expense: yearlyExpense,
              net: yearlyNet,
            ),
          ],
          if (_mode == _OverviewMode.monthly && categories.isNotEmpty) ...[
            const SizedBox(height: 18),
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
          // Billing cycle breakdown
          const SizedBox(height: 18),
          Text(
            'Billing cycles',
            style: DesignTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${yearlyBreakdown.length} cycle${yearlyBreakdown.length == 1 ? '' : 's'} in ${fyLabel ?? 'selected year'}',
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
                'No billing cycles created for this year yet.',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
            )
          else
            ...yearlyBreakdown.map((row) {
              final m = (row['month'] as num?)?.toInt() ?? 1;
              final rowYear = (row['year'] as num?)?.toInt() ?? year;
              final paidC = (row['paidCount'] as num?)?.toInt() ?? 0;
              final unpaidC = (row['unpaidCount'] as num?)?.toInt() ?? 0;
              final mExp =
                  (row['totalExpected'] as num?)?.toDouble() ?? 0;
              final mColl =
                  (row['totalCollected'] as num?)?.toDouble() ?? 0;
              final mExpense =
                  (row['totalExpense'] as num?)?.toDouble() ?? 0;
              final mPending = mExp - mColl;
              final monthNet = mColl - mExpense;
              final netColor = monthNet >= 0
                  ? DesignColors.success
                  : DesignColors.error;
              final mRate = mExp > 0 ? (mColl / mExp * 100) : 0.0;
              final mRateColor = mRate >= 80
                  ? DesignColors.success
                  : mRate >= 50
                      ? DesignColors.warning
                      : DesignColors.error;
              final isCurrentPeriod =
                  m == month && rowYear == year;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentPeriod
                          ? DesignColors.primary.withValues(alpha: 0.5)
                          : DesignColors.borderLight,
                      width: isCurrentPeriod ? 1.5 : 1,
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
                              hasFyId
                                  ? DateFormat('MMMM yyyy')
                                      .format(DateTime(rowYear, m))
                                  : DateFormat('MMMM')
                                      .format(DateTime(rowYear, m)),
                              style: DesignTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (isCurrentPeriod) ...[
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
                                  style:
                                      DesignTypography.labelSmall.copyWith(
                                    color: DesignColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: netColor.withValues(alpha: 0.1),
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
                        // Compact 4-value row
                        Row(
                          children: [
                            _miniFoot('Expected', mExp, DesignColors.primary),
                            const SizedBox(width: 8),
                            _miniFoot('Collected', mColl, DesignColors.success),
                            const SizedBox(width: 8),
                            _miniFoot(
                                'Pending',
                                mPending > 0 ? mPending : 0,
                                DesignColors.error),
                            const SizedBox(width: 8),
                            _miniFoot('Expense', mExpense,
                                const Color(0xFF546E7A)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Collection progress + counts
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  minHeight: 5,
                                  value: (mRate / 100).clamp(0.0, 1.0),
                                  color: mRateColor,
                                  backgroundColor: DesignColors.surfaceSoft,
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
                            const SizedBox(width: 10),
                            Text(
                              '$paidC paid · $unpaidC unpaid',
                              style: DesignTypography.labelSmall.copyWith(
                                color: DesignColors.textSecondary,
                                fontSize: 10,
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

  Widget _inlineStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 13,
              letterSpacing: -0.3,
            ),
          ),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            inr.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: c,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
