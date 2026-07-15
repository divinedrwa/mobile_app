import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../data/providers/admin_providers.dart';
import '../../../../resident/data/resident_data_refresh.dart';
import '../../../../resident/presentation/widgets/maintenance/maintenance_stat_chip.dart';
import '../../../../resident/presentation/widgets/maintenance/payment_list_tile.dart';
import 'widgets/admin_maintenance_collapsible_group.dart';
import 'widgets/admin_maintenance_payment_actions_sheet.dart';
import 'widgets/admin_maintenance_edit_villa_row_sheet.dart';

part 'parts/admin_maintenance_hub_lifecycle.part.dart';
part 'parts/admin_maintenance_hub_selectors.part.dart';
part 'parts/admin_maintenance_hub_hero.part.dart';
part 'parts/admin_maintenance_hub_residents.part.dart';

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
  bool _sendingReminders = false;
  final Set<String> _selectedVillaIds = {};
  bool _selectionInitialised = false;

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
      ref.invalidate(adminMaintenanceDashboardProvider);
    }
  }

  Future<void> _refresh() async {
    final fyId = ref.read(adminMaintenanceFilterProvider).financialYearId;
    ref.invalidate(adminCollectionFinancialYearsProvider);
    if (fyId != null && fyId.isNotEmpty) {
      ref.invalidate(adminCollectionCyclesForFYProvider(fyId));
    }
    ref.invalidate(adminMaintenanceDashboardProvider);
    _selectionInitialised = false;
    try {
      await ref.read(adminMaintenanceDashboardProvider.future);
    } catch (e) {
      debugPrint('AdminMaintenanceHubScreen._refresh failed: $e');
    }
  }


  /// Lets hub `part` extensions update local UI state.
  void mutateHubUi(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminMaintenanceFilterProvider);
    final dashboardAsync = ref.watch(adminMaintenanceDashboardProvider);
    final periodLabel = DateFormat('MMMM y').format(DateTime(filter.year, filter.month));

    // ── Auto-select FY ──────────────────────────────────────────────
    ref.listen(adminCollectionFinancialYearsProvider, (prev, next) {
      next.whenData((fys) {
        final cur = ref.read(adminMaintenanceFilterProvider);
        if (fys.isEmpty || cur.financialYearId != null) return;
        final id = _pickDefaultFinancialYearId(fys);
        if (id == null || id.isEmpty) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final c2 = ref.read(adminMaintenanceFilterProvider);
          if (c2.financialYearId != null) return;
          ref.read(adminMaintenanceFilterProvider.notifier).state =
              c2.copyWith(financialYearId: id);
        });
      });
    });

    // ── Auto-select cycle once FY cycles load ──
    final fyListenId = filter.financialYearId;
    if (fyListenId != null && fyListenId.isNotEmpty) {
      ref.listen(adminCollectionCyclesForFYProvider(fyListenId), (prev, next) {
        next.whenData((cycles) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final cur = ref.read(adminMaintenanceFilterProvider);
            if (cur.financialYearId != fyListenId) return;
            if (cur.maintenanceCollectionCycleId != null &&
                cycles.any((c) =>
                    c['id']?.toString() ==
                    cur.maintenanceCollectionCycleId)) {
              return;
            }
            final chosen = _pickDefaultCycle(cycles);
            if (chosen == null) return;
            final pm =
                (chosen['periodMonth'] as num?)?.toInt() ?? cur.month;
            final py =
                (chosen['periodYear'] as num?)?.toInt() ?? cur.year;
            ref.read(adminMaintenanceFilterProvider.notifier).state =
                cur.copyWith(
              maintenanceCollectionCycleId: chosen['id']?.toString(),
              month: pm,
              year: py,
              clearBillingCycleId: true,
            );
          });
        });
      });
    }

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
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
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
            _fyAndCycleSelector(filter),
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
}
