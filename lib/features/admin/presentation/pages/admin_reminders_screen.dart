import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for sending maintenance-dues reminders to residents.
///
/// Uses the same FY → cycle selection flow as AdminMaintenanceHubScreen
/// so admins pick a financial year first, then a billing cycle (month),
/// and finally select which residents to nudge.
class AdminRemindersScreen extends ConsumerStatefulWidget {
  const AdminRemindersScreen({super.key});

  @override
  ConsumerState<AdminRemindersScreen> createState() =>
      _AdminRemindersScreenState();
}

class _AdminRemindersScreenState extends ConsumerState<AdminRemindersScreen>
    with WidgetsBindingObserver {
  final Set<String> _selectedVillaIds = {};
  bool _busy = false;
  bool _initialised = false;

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

  // ── FY / cycle auto-select helpers (same as maintenance hub) ────

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

  // ── resident helpers ────────────────────────────────────────────

  List<Map<String, dynamic>> _actionableResidents(
      Map<String, dynamic> data) {
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
    if (_initialised) return;
    _initialised = true;
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

  void _toggle(String villaId) {
    setState(() {
      if (_selectedVillaIds.contains(villaId)) {
        _selectedVillaIds.remove(villaId);
      } else {
        _selectedVillaIds.add(villaId);
      }
    });
  }

  // ── refresh ─────────────────────────────────────────────────────

  Future<void> _refresh() async {
    final fyId =
        ref.read(adminMaintenanceFilterProvider).financialYearId;
    ref.invalidate(adminCollectionFinancialYearsProvider);
    if (fyId != null && fyId.isNotEmpty) {
      ref.invalidate(adminCollectionCyclesForFYProvider(fyId));
    }
    ref.invalidate(adminMaintenanceDashboardProvider);
    _initialised = false;
    try {
      await ref.read(adminMaintenanceDashboardProvider.future);
    } catch (e) {
      debugPrint('AdminRemindersScreen._refresh failed: $e');
    }
  }

  // ── send ────────────────────────────────────────────────────────

  Future<void> _send() async {
    if (_selectedVillaIds.isEmpty) return;
    setState(() => _busy = true);

    final filter = ref.read(adminMaintenanceFilterProvider);
    final repo = ref.read(adminMaintenanceRepositoryProvider);

    try {
      int totalNotified = 0;
      int failed = 0;

      final data = ref.read(adminMaintenanceDashboardProvider).valueOrNull;
      final residents =
          data != null ? _actionableResidents(data) : <Map<String, dynamic>>[];

      if (_allSelected(residents)) {
        final result = await repo.sendDuesReminders(
          month: filter.month,
          year: filter.year,
        );
        totalNotified = (result['sent'] as num?)?.toInt() ??
            (result['notified'] as num?)?.toInt() ??
            0;
      } else {
        for (final villaId in _selectedVillaIds) {
          try {
            final result = await repo.sendVillaReminder(villaId: villaId);
            totalNotified += (result['sent'] as num?)?.toInt() ?? 0;
          } catch (e) {
            failed++;
            debugPrint('Failed to send reminder for villa $villaId: $e');
          }
        }
      }

      if (!mounted) return;
      setState(() => _busy = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              failed > 0 ? DesignColors.warning : DesignColors.primary,
          content: Text(
            failed > 0
                ? 'Reminded $totalNotified · $failed failed — please retry'
                : totalNotified > 0
                    ? 'Reminded $totalNotified resident${totalNotified == 1 ? "" : "s"}'
                    : 'No residents to remind for this period',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      ref.invalidate(adminMaintenanceDashboardProvider);
      _initialised = false;
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.error,
          content: Text('Couldn\'t send reminders. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminMaintenanceFilterProvider);
    final dashAsync = ref.watch(adminMaintenanceDashboardProvider);
    final periodLabel =
        DateFormat('MMMM y').format(DateTime(filter.year, filter.month));

    // ── Auto-select FY (same logic as AdminMaintenanceHubScreen) ──
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
            _initialised = false;
          });
        });
      });
    }

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Reminders',
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
        backgroundColor: DesignColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh,
                color: DesignColors.textSecondary),
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
            100,
          ),
          children: [
            _fyAndCycleSelector(filter),
            const SizedBox(height: AppSpacing.lg),
            dashAsync.when(
              loading: () => ShimmerWrap(
                child: Column(
                  children: [
                    ShimmerBox(height: 120, borderRadius: DesignRadius.lg),
                    const SizedBox(height: 16),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ShimmerBox(height: 56, borderRadius: DesignRadius.md),
                      ),
                    ),
                  ],
                ),
              ),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load data',
                subtitle: 'Something went wrong. Please try again.',
                iconColor: DesignColors.error,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
              data: (data) {
                final residents = _actionableResidents(data);
                _initSelection(residents);
                return _dataContent(data, residents);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── FY + cycle selector (same pattern as maintenance hub) ───────

  Widget _fyAndCycleSelector(AdminMaintenanceFilter filter) {
    final fysAsync = ref.watch(adminCollectionFinancialYearsProvider);

    return fysAsync.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 48, borderRadius: DesignRadius.lg),
      ),
      error: (_, _) => EnterpriseInfoBanner(
        icon: Icons.error_outline,
        title: 'Error',
        message: 'Couldn\'t load financial years',
        tone: EnterpriseTone.danger,
      ),
      data: (fys) {
        if (fys.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'Not configured',
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
          _initialised = false;
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
        title: 'Error',
        message: 'Couldn\'t load billing periods',
        tone: EnterpriseTone.danger,
      ),
      data: (cycles) {
        if (cycles.isEmpty) {
          return EnterpriseInfoBanner(
            icon: Icons.info_outline,
            title: 'No periods',
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
                  final cur =
                      ref.read(adminMaintenanceFilterProvider);
                  ref
                      .read(adminMaintenanceFilterProvider.notifier)
                      .state = cur.copyWith(
                    maintenanceCollectionCycleId: cycleId,
                    month: pm ?? cur.month,
                    year: py ?? cur.year,
                    clearBillingCycleId: true,
                  );
                  _initialised = false;
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── data content (hero + resident list) ─────────────────────────

  Widget _dataContent(
      Map<String, dynamic> data, List<Map<String, dynamic>> residents) {
    final filter = ref.watch(adminMaintenanceFilterProvider);
    final monthName =
        DateFormat.MMMM().format(DateTime(filter.year, filter.month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryHero(residents, monthName, filter.year),
        const SizedBox(height: AppSpacing.lg),
        _selectionHeader(residents),
        const SizedBox(height: AppSpacing.sm),
        if (residents.isEmpty)
          _emptyState(monthName, filter.year)
        else
          _residentList(residents),
        const SizedBox(height: AppSpacing.lg),
        _sendButton(residents),
      ],
    );
  }

  // ── error tile ──────────────────────────────────────────────────

  // ── summary hero ─────────────────────────────────────────────────

  Widget _summaryHero(
      List<Map<String, dynamic>> residents, String month, int year) {
    int pending = 0, overdue = 0, partial = 0;
    for (final r in residents) {
      final s = (r['status']?.toString() ?? '').toUpperCase();
      if (s == 'OVERDUE') {
        overdue++;
      } else if (s == 'PARTIAL') {
        partial++;
      } else {
        pending++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$month $year',
                      style: DesignTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      '${residents.length} resident${residents.length == 1 ? "" : "s"} with dues',
                      style: DesignTypography.headingM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _heroBadge('Pending', pending, Colors.white),
              const SizedBox(width: AppSpacing.sm),
              _heroBadge('Overdue', overdue, const Color(0xFFFF6B6B)),
              const SizedBox(width: AppSpacing.sm),
              _heroBadge('Partial', partial, const Color(0xFFFFD93D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: DesignTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── selection header ─────────────────────────────────────────────

  Widget _selectionHeader(List<Map<String, dynamic>> residents) {
    return Row(
      children: [
        Text(
          'Select residents',
          style: DesignTypography.bodyMedium.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (residents.isNotEmpty)
          TextButton.icon(
            onPressed: _busy ? null : () => _toggleAll(residents),
            icon: Icon(
              _allSelected(residents) ? Icons.deselect : Icons.select_all,
              size: 18,
            ),
            label: Text(
                _allSelected(residents) ? 'Deselect all' : 'Select all'),
            style: TextButton.styleFrom(
              foregroundColor: DesignColors.primary,
              textStyle: DesignTypography.bodySmall
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  // ── empty state ──────────────────────────────────────────────────

  Widget _emptyState(String month, int year) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: 'All clear!',
        subtitle: 'No residents with pending dues for $month $year.',
        iconColor: DesignColors.success,
      ),
    );
  }

  // ── resident list ────────────────────────────────────────────────

  Widget _residentList(List<Map<String, dynamic>> residents) {
    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return EnterprisePanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Selected count bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: DesignColors.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DesignRadius.lg)),
            ),
            child: Text(
              '${_selectedVillaIds.length} of ${residents.length} selected',
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Resident rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: residents.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 56),
            itemBuilder: (context, index) {
              final r = residents[index];
              final villaId = r['villaId']?.toString() ?? '';
              final villa = r['villaNumber']?.toString() ?? '—';
              final owner = r['ownerName']?.toString() ?? 'Unknown';
              final amount = (r['amount'] as num?)?.toDouble() ?? 0;
              final paidToward =
                  (r['paidTowardCycle'] as num?)?.toDouble() ?? 0;
              final remaining =
                  (amount - paidToward).clamp(0, double.infinity);
              final status =
                  (r['status']?.toString() ?? '').toUpperCase();
              final isChecked = _selectedVillaIds.contains(villaId);

              return InkWell(
                onTap: _busy ? null : () => _toggle(villaId),
                borderRadius: BorderRadius.circular(DesignRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: DesignColors.primary,
                          onChanged: _busy ? null : (_) => _toggle(villaId),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Villa $villa', style: DesignTypography.bodyMedium.copyWith(color: DesignColors.textPrimary, fontWeight: FontWeight.w600)),
                            Text('$owner · ${inr.format(remaining)} due', style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary)),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── send button ──────────────────────────────────────────────────

  Widget _sendButton(List<Map<String, dynamic>> residents) {
    final enabled = !_busy && _selectedVillaIds.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? _send : null,
        icon: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(
          _selectedVillaIds.isEmpty
              ? 'Select residents to remind'
              : 'Send reminder to ${_selectedVillaIds.length} resident${_selectedVillaIds.length == 1 ? "" : "s"}',
          style: DesignTypography.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          disabledBackgroundColor:
              const Color(0xFFF59E0B).withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
        ),
      ),
    );
  }

  // ── status badge ─────────────────────────────────────────────────

  Widget _statusBadge(String status) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'OVERDUE':
        bg = DesignColors.error.withValues(alpha: 0.1);
        fg = DesignColors.error;
        label = 'Overdue';
      case 'PARTIAL':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFC2410C);
        label = 'Partial';
      default:
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFF854D0E);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: DesignTypography.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
