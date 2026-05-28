import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/admin_providers.dart';
import '../../../resident/data/resident_data_refresh.dart';
import '../../../resident/presentation/widgets/maintenance/maintenance_stat_chip.dart';
import '../../../resident/presentation/widgets/maintenance/payment_list_tile.dart';

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
    } catch (_) {/* surfaced inline */}
  }

  // ── FY / cycle auto-select helpers ────────────────────────────────

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

  Map<String, dynamic>? _pickDefaultCycle(List<Map<String, dynamic>> cycles) {
    if (cycles.isEmpty) return null;
    final now = DateTime.now();
    for (final c in cycles) {
      final pm = (c['periodMonth'] as num?)?.toInt();
      final py = (c['periodYear'] as num?)?.toInt();
      if (pm == now.month && py == now.year) return c;
    }
    for (final c in cycles) {
      if ((c['status']?.toString() ?? '').toUpperCase() == 'OPEN') return c;
    }
    return cycles.last;
  }

  // ── Selection helpers ─────────────────────────────────────────────

  /// All residents that have pending dues and are not excluded from billing.
  List<Map<String, dynamic>> _pendingResidents(Map<String, dynamic> data) {
    return ((data['residents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['isExcluded'] != true)
        .where((r) {
          final s = (r['status']?.toString() ?? '').toUpperCase();
          return s == 'PENDING' || s == 'OVERDUE' || s == 'PARTIAL';
        })
        .toList();
  }

  void _initSelection(List<Map<String, dynamic>> residents) {
    if (_selectionInitialised) return;
    _selectionInitialised = true;
    _selectedVillaIds
      ..clear()
      ..addAll(
        residents
            .where((r) => r['villaId'] != null)
            .map((r) => r['villaId'].toString()),
      );
  }

  bool _allSelected(List<Map<String, dynamic>> residents) {
    if (residents.isEmpty) return false;
    final allIds = residents
        .where((r) => r['villaId'] != null)
        .map((r) => r['villaId'].toString())
        .toSet();
    return _selectedVillaIds.length == allIds.length;
  }

  void _toggleAll(List<Map<String, dynamic>> residents) {
    setState(() {
      if (_allSelected(residents)) {
        _selectedVillaIds.clear();
      } else {
        _selectedVillaIds
          ..clear()
          ..addAll(
            residents
                .where((r) => r['villaId'] != null)
                .map((r) => r['villaId'].toString()),
          );
      }
    });
  }

  void _toggleVilla(String villaId) {
    setState(() {
      if (_selectedVillaIds.contains(villaId)) {
        _selectedVillaIds.remove(villaId);
      } else {
        _selectedVillaIds.add(villaId);
      }
    });
  }

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
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
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

  // ── FY + cycle selector ───────────────────────────────────────────

  Widget _fyAndCycleSelector(AdminMaintenanceFilter filter) {
    final fysAsync = ref.watch(adminCollectionFinancialYearsProvider);

    return fysAsync.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 48, borderRadius: DesignRadius.lg),
      ),
      error: (_, _) => EnterpriseInfoBanner(
        icon: Icons.error_outline,
        title: 'Load failed',
        message: 'Couldn\'t load financial years',
        tone: EnterpriseTone.danger,
      ),
      data: (fys) {
        if (fys.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'No data',
            message: 'No financial years configured',
            tone: EnterpriseTone.info,
          );
        }

        return Column(
          children: [
            _fyDropdown(fys, filter),
            const SizedBox(height: AppSpacing.sm),
            _cycleChips(filter),
          ],
        );
      },
    );
  }

  Widget _fyDropdown(
    List<Map<String, dynamic>> fys,
    AdminMaintenanceFilter filter,
  ) {
    return EnterprisePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButton<String>(
        value: filter.financialYearId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: DesignColors.textSecondary),
        style: DesignTypography.bodyMedium.copyWith(
          color: DesignColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        items: fys
            .map((fy) => DropdownMenuItem<String>(
                  value: fy['id']?.toString(),
                  child: Text(fy['label']?.toString() ?? 'Untitled'),
                ))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          final cur = ref.read(adminMaintenanceFilterProvider);
          ref.read(adminMaintenanceFilterProvider.notifier).state =
              cur.copyWith(
            financialYearId: id,
            clearCollectionCycleId: true,
            clearBillingCycleId: true,
          );
          _selectionInitialised = false;
        },
      ),
    );
  }

  Widget _cycleChips(AdminMaintenanceFilter filter) {
    final fyId = filter.financialYearId;
    if (fyId == null || fyId.isEmpty) {
      return const SizedBox.shrink();
    }

    final cyclesAsync = ref.watch(adminCollectionCyclesForFYProvider(fyId));

    return cyclesAsync.when(
      loading: () => ShimmerWrap(
        child: SizedBox(
          height: 44,
          child: Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShimmerBox(height: 36, width: 56, borderRadius: DesignRadius.full),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => EnterpriseInfoBanner(
        icon: Icons.error_outline,
        title: 'Load failed',
        message: 'Couldn\'t load billing periods',
        tone: EnterpriseTone.danger,
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'No data',
            message: 'No billing periods for this year',
            tone: EnterpriseTone.info,
          );
        }

        final selectedCycleId = filter.maintenanceCollectionCycleId;

        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cycles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cycle = cycles[index];
              final cycleId = cycle['id']?.toString();
              final isSelected = cycleId == selectedCycleId;

              final pm = (cycle['periodMonth'] as num?)?.toInt();
              final py = (cycle['periodYear'] as num?)?.toInt();
              final chipLabel = pm != null
                  ? DateFormat('MMM').format(DateTime(py ?? 2000, pm))
                  : (cycle['title']?.toString() ?? '?');

              return ChoiceChip(
                label: Text(chipLabel),
                selected: isSelected,
                selectedColor: DesignColors.primary,
                backgroundColor: DesignColors.surface,
                side: BorderSide(
                  color: isSelected
                      ? DesignColors.primary
                      : DesignColors.borderLight,
                ),
                labelStyle: DesignTypography.bodySmall.copyWith(
                  color:
                      isSelected ? Colors.white : DesignColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) {
                  final cur = ref.read(adminMaintenanceFilterProvider);
                  ref
                      .read(adminMaintenanceFilterProvider.notifier)
                      .state = cur.copyWith(
                    maintenanceCollectionCycleId: cycleId,
                    month: pm ?? cur.month,
                    year: py ?? cur.year,
                    clearBillingCycleId: true,
                  );
                  _selectionInitialised = false;
                },
              );
            },
          ),
        );
      },
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

  Widget _heroSkeleton() => ShimmerWrap(
      child: ShimmerBox(height: 160, borderRadius: DesignRadius.xl),
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

  // ---- reminder button (inline in residents section) ----

  Widget _reminderButton(List<Map<String, dynamic>> pendingList) {
    final count = _selectedVillaIds.length;
    final isBulk = _allSelected(pendingList);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          elevation: 0,
        ),
        onPressed: _sendingReminders || count == 0 ? null : _onSendReminders,
        icon: _sendingReminders
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.notifications_active_outlined, size: 18),
        label: Text(
          _sendingReminders
              ? 'Sending...'
              : isBulk
                  ? 'Send reminder to all ($count)'
                  : 'Send reminder to $count selected',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _onSendReminders() async {
    if (_sendingReminders || _selectedVillaIds.isEmpty) return;

    final filter = ref.read(adminMaintenanceFilterProvider);
    final periodLabel =
        DateFormat('MMMM y').format(DateTime(filter.year, filter.month));

    final data = ref.read(adminMaintenanceDashboardProvider).valueOrNull;
    final pendingList = data != null ? _pendingResidents(data) : <Map<String, dynamic>>[];
    final isBulk = _allSelected(pendingList);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Reminders'),
        content: Text(
          isBulk
              ? 'Send payment reminders to all ${_selectedVillaIds.length} residents with pending dues for $periodLabel?'
              : 'Send payment reminders to ${_selectedVillaIds.length} selected resident${_selectedVillaIds.length == 1 ? "" : "s"} for $periodLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingReminders = true);

    final repo = ref.read(adminMaintenanceRepositoryProvider);
    try {
      int totalSent = 0;

      if (isBulk) {
        final result = await repo.sendDuesReminders(
          month: filter.month,
          year: filter.year,
          maintenanceCollectionCycleId: filter.maintenanceCollectionCycleId,
        );
        totalSent = (result['sent'] as num?)?.toInt() ??
            (result['notified'] as num?)?.toInt() ??
            0;
      } else {
        for (final villaId in _selectedVillaIds) {
          try {
            final result = await repo.sendVillaReminder(villaId: villaId);
            totalSent += (result['sent'] as num?)?.toInt() ?? 0;
          } catch (_) {
            // Continue sending to remaining villas.
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.primary,
          content: Text(
            totalSent > 0
                ? 'Reminded $totalSent resident${totalSent == 1 ? "" : "s"}'
                : 'No residents to remind for this period',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(adminMaintenanceDashboardProvider);
      _selectionInitialised = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.error,
          content: Text('Couldn\'t send reminders: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingReminders = false);
    }
  }

  // ---- residents list ----

  Widget _residentsSection(Map<String, dynamic> data) {
    final residents = ((data['residents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['isExcluded'] != true)
        .toList();

    if (residents.isEmpty) {
      return _emptyResidents();
    }

    // Prepare pending residents for selection.
    final pendingList = _pendingResidents(data);
    _initSelection(pendingList);

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

    final hasPending = pendingList.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + select all ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'Residents',
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (hasPending)
                GestureDetector(
                  onTap: () => _toggleAll(pendingList),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _allSelected(pendingList),
                          onChanged: (_) => _toggleAll(pendingList),
                          activeColor: DesignColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Select all',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (overdue.isNotEmpty)
          _statusGroup(label: 'Overdue', residents: overdue, status: PaymentTileStatus.overdue, selectable: true),
        if (pending.isNotEmpty)
          _statusGroup(label: 'Pending', residents: pending, status: PaymentTileStatus.pending, selectable: true),
        if (partial.isNotEmpty)
          _statusGroup(label: 'Partial', residents: partial, status: PaymentTileStatus.partial, selectable: true),
        if (paid.isNotEmpty)
          _statusGroup(label: 'Paid', residents: paid, status: PaymentTileStatus.paid, selectable: false),

        // ── Send reminder button ──
        if (hasPending) ...[
          const SizedBox(height: AppSpacing.lg),
          _reminderButton(pendingList),
        ],
      ],
    );
  }

  Widget _statusGroup({
    required String label,
    required List<Map<String, dynamic>> residents,
    required PaymentTileStatus status,
    bool selectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _CollapsibleGroup(
        label: label,
        count: residents.length,
        child: Column(
          children: [
            for (final r in residents) ...[
              _residentRow(r, status, selectable: selectable),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isAdmin =>
      ref.read(authProvider).user?.role.isAdminLike ?? false;

  Widget _residentRow(
    Map<String, dynamic> r,
    PaymentTileStatus status, {
    bool selectable = false,
  }) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villaNumber = r['villaNumber']?.toString() ?? '—';
    final villaId = r['villaId']?.toString() ?? '';
    final ownerName = r['ownerName']?.toString() ?? 'Unknown';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final paidToward = (r['paidTowardCycle'] as num?)?.toDouble();
    final advanceCredit = (r['advanceCredit'] as num?)?.toDouble() ?? 0;
    final dueDate = DateTime.tryParse(r['dueDate']?.toString() ?? '');
    final paidAt = DateTime.tryParse(r['paidAt']?.toString() ?? '');

    final isAdmin = _isAdmin;
    final actionable = isAdmin &&
        (status == PaymentTileStatus.pending ||
            status == PaymentTileStatus.overdue ||
            status == PaymentTileStatus.partial);

    String subtitle;
    if (paidToward != null && paidToward > 0) {
      subtitle = '$ownerName · ${inr.format(paidToward)} of ${inr.format(amount)}';
    } else {
      subtitle = ownerName;
    }
    if (advanceCredit > 0) {
      subtitle += ' · Credit: ${inr.format(advanceCredit)}';
    }

    final isSelected = selectable && villaId.isNotEmpty && _selectedVillaIds.contains(villaId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (selectable && villaId.isNotEmpty) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleVilla(villaId),
              activeColor: DesignColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: GestureDetector(
            onLongPress: isAdmin ? () => _showRowMenu(r) : null,
            child: PaymentListTile(
              title: 'Villa $villaNumber',
              subtitle: subtitle,
              amount: amount,
              status: status,
              dueDate: status == PaymentTileStatus.paid ? null : dueDate,
              paidDate: status == PaymentTileStatus.paid ? paidAt : null,
              actionLabel: actionable ? 'Actions' : null,
              onAction: actionable ? () => _openMarkCashSheet(r) : null,
            ),
          ),
        ),
      ],
    );
  }

  void _showRowMenu(Map<String, dynamic> resident) {
    final villaId = resident['villaId']?.toString() ?? '';
    final villaNumber = resident['villaNumber']?.toString() ?? '—';
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Villa $villaNumber',
                style: DesignTypography.headingM.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit amounts'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditVillaRowSheet(resident);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Payment history'),
              onTap: () {
                Navigator.pop(ctx);
                if (villaId.isNotEmpty) {
                  context.go('/resident/admin-villa-history/$villaId');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openMarkCashSheet(Map<String, dynamic> resident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentActionsSheet(resident: resident),
    );
    ref.invalidate(adminMaintenanceDashboardProvider);
  }

  Future<void> _openEditVillaRowSheet(Map<String, dynamic> resident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditVillaRowSheet(resident: resident),
    );
    ref.invalidate(adminMaintenanceDashboardProvider);
  }

  Widget _emptyResidents() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No residents in this period',
        subtitle: 'Generate snapshots for the cycle from the detailed finance view to populate this list.',
      ),
    );
  }

  Widget _errorTile(String label) {
    return EnterpriseInfoBanner(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      message: '$label. Pull down to retry.',
      tone: EnterpriseTone.danger,
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
    return EnterprisePanel(
      padding: EdgeInsets.zero,
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

/// Unified payment actions sheet with 3 tabs: Record payment, Add credit, Deduct credit.
class _PaymentActionsSheet extends ConsumerStatefulWidget {
  const _PaymentActionsSheet({required this.resident});

  final Map<String, dynamic> resident;

  @override
  ConsumerState<_PaymentActionsSheet> createState() =>
      _PaymentActionsSheetState();
}

const _paymentModes = <String, String>{
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CHEQUE': 'Cheque',
};

class _PaymentActionsSheetState extends ConsumerState<_PaymentActionsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtl;
  final _amountCtl = TextEditingController();
  final _remarksCtl = TextEditingController();
  final _creditAmountCtl = TextEditingController();
  final _creditRemarksCtl = TextEditingController();
  String _paymentMode = 'CASH';
  bool _busy = false;
  String? _error;

  double get _advanceCredit =>
      (widget.resident['advanceCredit'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 3, vsync: this);
    _tabCtl.addListener(() {
      if (!_tabCtl.indexIsChanging) {
        setState(() => _error = null);
      }
    });
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
    _tabCtl.dispose();
    _amountCtl.dispose();
    _remarksCtl.dispose();
    _creditAmountCtl.dispose();
    _creditRemarksCtl.dispose();
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DesignRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Villa $villa',
                    style: DesignTypography.headingM.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$owner · expected ${inr.format(amount)}'
                    '${_advanceCredit > 0 ? ' · credit ${inr.format(_advanceCredit)}' : ''}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Tabs
            TabBar(
              controller: _tabCtl,
              labelColor: DesignColors.primary,
              unselectedLabelColor: DesignColors.textSecondary,
              indicatorColor: DesignColors.primary,
              labelStyle: DesignTypography.bodySmall
                  .copyWith(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Payment'),
                Tab(text: 'Add credit'),
                Tab(text: 'Deduct credit'),
              ],
            ),
            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabCtl,
                children: [
                  _recordPaymentTab(inr),
                  _creditTab(isAdd: true),
                  _creditTab(isAdd: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordPaymentTab(NumberFormat inr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_advanceCredit > 0) ...[
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
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _amountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _paymentMode,
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
          if (_error != null && _tabCtl.index == 0) ...[
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
                    borderRadius: BorderRadius.circular(DesignRadius.md),
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
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _submitPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: _busy && _tabCtl.index == 0
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
    );
  }

  Widget _creditTab({required bool isAdd}) {
    final tabIndex = isAdd ? 1 : 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdd
                ? 'Add advance credit to this villa\'s account.'
                : 'Deduct credit from this villa\'s balance.',
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          if (!isAdd && _advanceCredit > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Available credit: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(_advanceCredit)}',
              style: DesignTypography.bodySmall.copyWith(
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _creditAmountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              helperText:
                  !isAdd ? 'Cannot exceed available credit' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _creditRemarksCtl,
            decoration: InputDecoration(
              labelText: 'Reason / remarks',
              hintText: isAdd
                  ? 'e.g. overpayment correction'
                  : 'e.g. penalty deduction',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_error != null && _tabCtl.index == tabIndex) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed:
                      _busy ? null : () => _submitCreditAdjustment(isAdd),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isAdd ? DesignColors.primary : DesignColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: _busy && _tabCtl.index == tabIndex
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAdd ? 'Add credit' : 'Deduct credit',
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
    );
  }

  Future<void> _submitPayment() async {
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

      final filter = ref.read(adminMaintenanceFilterProvider);
      final idempotencyKey = 'payment-${const Uuid().v4()}';

      await ref.read(adminMaintenanceRepositoryProvider).markPaidCash(
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
            idempotencyKey: idempotencyKey,
          );
      requestResidentDataRefresh();
      ref.invalidate(adminMaintenanceDashboardProvider);
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

      final filter = ref.read(adminMaintenanceFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      final result =
          await ref.read(adminMaintenanceRepositoryProvider).applyCredit(
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

  Future<void> _submitCreditAdjustment(bool isAdd) async {
    final amount = double.tryParse(_creditAmountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (!isAdd && amount > _advanceCredit) {
      setState(
          () => _error = 'Amount exceeds available credit of ₹${_advanceCredit.toStringAsFixed(0)}.');
      return;
    }
    final remarks = _creditRemarksCtl.text.trim();
    if (remarks.isEmpty) {
      setState(() => _error = 'Please provide a reason.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(adminMaintenanceFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      await ref
          .read(adminMaintenanceRepositoryProvider)
          .manualCreditAdjustment(
            villaId: villaId,
            maintenanceCollectionCycleId: cycleId,
            amount: amount,
            type: isAdd ? 'ADD' : 'DEDUCT',
            remarks: remarks,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            '${isAdd ? "Added" : "Deducted"} ₹${amount.toStringAsFixed(0)} credit for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t adjust credit: $e';
      });
    }
  }
}

/// Bottom sheet for editing villa grid row amounts.
class _EditVillaRowSheet extends ConsumerStatefulWidget {
  const _EditVillaRowSheet({required this.resident});

  final Map<String, dynamic> resident;

  @override
  ConsumerState<_EditVillaRowSheet> createState() =>
      _EditVillaRowSheetState();
}

class _EditVillaRowSheetState extends ConsumerState<_EditVillaRowSheet> {
  final _expectedCtl = TextEditingController();
  final _paidCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expected = (widget.resident['amount'] as num?)?.toDouble() ?? 0;
    final paid =
        (widget.resident['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    _expectedCtl.text = expected.toStringAsFixed(0);
    _paidCtl.text = paid.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _expectedCtl.dispose();
    _paidCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final villa = widget.resident['villaNumber']?.toString() ?? '—';
    final owner = widget.resident['ownerName']?.toString() ?? 'Unknown';

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
                'Edit amounts',
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Villa $villa · $owner',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                ),
                child: Text(
                  'This updates the billing snapshot. Any amount above expected becomes advance credit.',
                  style: DesignTypography.caption.copyWith(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _expectedCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Expected amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _paidCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paid / collected (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
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
                              'Save changes',
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
    final expected = double.tryParse(_expectedCtl.text.trim());
    final paid = double.tryParse(_paidCtl.text.trim());
    if (expected == null && paid == null) {
      setState(() => _error = 'Enter at least one amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(adminMaintenanceFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      await ref.read(adminMaintenanceRepositoryProvider).editVillaGridRow(
            cycleId: cycleId,
            villaId: villaId,
            expectedAmount: expected,
            paidAmount: paid,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            'Updated amounts for villa ${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Couldn\'t update: $e';
      });
    }
  }
}
