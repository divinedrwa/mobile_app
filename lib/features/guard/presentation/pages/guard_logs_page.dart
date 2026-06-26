import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../../../resident/data/models/parcel_model.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_empty_placeholder.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_keep_alive_tab.dart';
import '../widgets/guard_skeletons.dart';

/// Gate logs: today/date range filter + searchable lists per tab.
class GuardLogsPage extends ConsumerStatefulWidget {
  const GuardLogsPage({super.key});

  @override
  ConsumerState<GuardLogsPage> createState() => _GuardLogsPageState();
}

class _GuardLogsPageState extends ConsumerState<GuardLogsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int _segment = 0;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabCtl);
  }

  void _onTabCtl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabCtl);
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _logKey {
    if (_segment == 0 || _rangeStart == null || _rangeEnd == null) {
      return 'today';
    }
    return '${_ymd(_rangeStart!)}_${_ymd(_rangeEnd!)}';
  }

  String get _rangeLabel {
    if (_rangeStart == null || _rangeEnd == null) return '';
    return '${_ymd(_rangeStart!)} → ${_ymd(_rangeEnd!)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _rangeStart != null && _rangeEnd != null
        ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
        : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
    );
    if (!mounted) return;
    if (picked == null) {
      if (_segment == 1) {
        setState(() {
          _segment = 0;
          _rangeStart = null;
          _rangeEnd = null;
        });
      }
      return;
    }
    setState(() {
      _segment = 1;
      _rangeStart = picked.start;
      _rangeEnd = picked.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim();
    final key = _logKey;

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text('Gate logs', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
          bottom: TabBar(
            controller: _tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            tabs: const [
              Tab(text: 'Visitors'),
              Tab(text: 'Deliveries'),
              Tab(text: 'Vehicles'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GuardTokens.padScreen,
                GuardTokens.g2,
                GuardTokens.padScreen,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Today')),
                      ButtonSegment(value: 1, label: Text('Date range')),
                    ],
                    selected: {_segment},
                    onSelectionChanged: (s) async {
                      final next = s.first;
                      if (next == 1) {
                        await _pickRange();
                      } else {
                        setState(() {
                          _segment = 0;
                          _rangeStart = null;
                          _rangeEnd = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search name, flat, courier, reg…',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: GuardTokens.guardAccent,
                      ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          GuardTokens.radiusButton,
                        ),
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ],
              ),
            ),
            if (_segment == 1 && _rangeStart != null && _rangeEnd != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GuardTokens.padScreen,
                  GuardTokens.g2,
                  GuardTokens.padScreen,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _rangeLabel,
                        style: GuardTokens.captionStyle(context),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickRange,
                      style: GuardTokens.textLink(context),
                      child: const Text('Change range'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: [
                  GuardKeepAliveTab(
                    child: _VisitorLogs(logKey: key, query: q),
                  ),
                  GuardKeepAliveTab(
                    child: _DeliveryLogs(logKey: key, query: q),
                  ),
                  GuardKeepAliveTab(
                    child: _VehicleLogs(logKey: key, query: q),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _visitorMatch(GuardVisitorRow v, String q) {
  if (q.isEmpty) return true;
  final qq = q.toLowerCase();
  final phone = v.phone.replaceAll(RegExp(r'\s'), '');
  final qc = qq.replaceAll(RegExp(r'\s'), '');
  return v.name.toLowerCase().contains(qq) ||
      phone.contains(qc) ||
      (v.villaLabel?.toLowerCase().contains(qq) ?? false) ||
      v.status.toLowerCase().contains(qq);
}

bool _parcelMatch(ParcelModel p, String q) {
  if (q.isEmpty) return true;
  final qq = q.toLowerCase();
  return p.courier.toLowerCase().contains(qq) ||
      p.trackingNumber.toLowerCase().contains(qq) ||
      p.status.label.toLowerCase().contains(qq);
}

bool _vehicleMatch(GuardVehicleEntry v, String q) {
  if (q.isEmpty) return true;
  final qq = q.toLowerCase();
  return v.registrationNumber.toLowerCase().contains(qq) ||
      v.kind.toLowerCase().contains(qq) ||
      v.flatLabel.toLowerCase().contains(qq);
}

class _VisitorLogs extends ConsumerWidget {
  const _VisitorLogs({required this.logKey, required this.query});

  final String logKey;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardVisitorLogsProvider(logKey));
    final emptyHint = logKey == 'today'
        ? 'No visits logged today.'
        : 'No visitors in this range.';
    return async.when(
      loading: () => const GuardListSkeleton(),
      error: (e, _) => GuardCenteredError(
        message: userFacingMessage(e),
        onRetry: () => ref.invalidate(guardVisitorLogsProvider(logKey)),
      ),
      data: (rows) {
        final filtered = rows.where((v) => _visitorMatch(v, query)).toList();
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardVisitorLogsProvider(logKey));
          },
          child: filtered.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    GuardEmptyPlaceholder(
                      icon: Icons.groups_outlined,
                      title: query.isNotEmpty ? 'No matches' : 'No visitors',
                      message: emptyHint,
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: GuardTokens.padScreen,
                    vertical: GuardTokens.g2,
                  ),
                  itemCount: filtered.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final inside = filtered
                          .where((v) => v.checkOutTime == null)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                        child: _LogSummaryChip(
                          label:
                              '${filtered.length} total · $inside inside · ${filtered.length - inside} exited',
                        ),
                      );
                    }
                    final v = filtered[i - 1];
                    final rowIdx = i - 1;
                    final inGate = v.checkOutTime == null;
                    final tone = inGate
                        ? GuardTokens.success
                        : GuardTokens.textSecondary;
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                          side: BorderSide(
                            color: isDark
                                ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                                : GuardTokens.borderSubtle.withValues(alpha: 0.9),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: GuardTokens.guardAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: GuardTokens.guardAccent.withValues(alpha: 0.22),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  v.name.trim().isNotEmpty ? v.name.trim()[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: GuardTokens.guardAccentDeep,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.name,
                                      style: GuardTokens.headingStyle(context).copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (v.villaLabel != null) 'Flat ${v.villaLabel}',
                                        v.status,
                                      ].join(' · '),
                                      style: GuardTokens.captionStyle(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: tone.withValues(alpha: 0.30)),
                                ),
                                child: Text(
                                  inGate ? 'IN' : 'OUT',
                                  style: TextStyle(
                                    color: tone,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: DesignAnimations.staggerFor(rowIdx)).fadeIn(duration: 200.ms).slideY(begin: 0.04);
                  },
                ),
        );
      },
    );
  }
}

class _DeliveryLogs extends ConsumerWidget {
  const _DeliveryLogs({required this.logKey, required this.query});

  final String logKey;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardParcelLogsProvider(logKey));
    final emptyHint = logKey == 'today'
        ? 'No deliveries today.'
        : 'No deliveries in this range.';
    return async.when(
      loading: () => const GuardListSkeleton(),
      error: (e, _) => GuardCenteredError(
        message: userFacingMessage(e),
        onRetry: () => ref.invalidate(guardParcelLogsProvider(logKey)),
      ),
      data: (rows) {
        final filtered = rows.where((p) => _parcelMatch(p, query)).toList();
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardParcelLogsProvider(logKey));
          },
          child: filtered.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    GuardEmptyPlaceholder(
                      icon: Icons.inventory_2_outlined,
                      title: query.isNotEmpty ? 'No matches' : 'No deliveries',
                      message: emptyHint,
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: GuardTokens.padScreen,
                    vertical: GuardTokens.g2,
                  ),
                  itemCount: filtered.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final pending = filtered
                          .where((p) => p.status == ParcelStatus.pending)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                        child: _LogSummaryChip(
                          label:
                              '${filtered.length} total · $pending pending · ${filtered.length - pending} collected',
                        ),
                      );
                    }
                    final p = filtered[i - 1];
                    final rowIdx = i - 1;
                    final title = p.trackingNumber.isNotEmpty ? p.trackingNumber : p.courier;
                    final statusTone = p.status == ParcelStatus.collected
                        ? GuardTokens.success
                        : p.status == ParcelStatus.returned
                            ? GuardTokens.textSecondary
                            : GuardTokens.warning;
                    final isDarkD = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                          side: BorderSide(
                            color: isDarkD
                                ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                                : GuardTokens.borderSubtle.withValues(alpha: 0.9),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: GuardTokens.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: GuardTokens.warning.withValues(alpha: 0.22),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 19,
                                  color: GuardTokens.warning,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GuardTokens.headingStyle(context).copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      p.courier.isNotEmpty ? p.courier : '—',
                                      style: GuardTokens.captionStyle(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusTone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusTone.withValues(alpha: 0.30)),
                                ),
                                child: Text(
                                  p.status.label,
                                  style: TextStyle(
                                    color: statusTone,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: DesignAnimations.staggerFor(rowIdx)).fadeIn(duration: 200.ms).slideY(begin: 0.04);
                  },
                ),
        );
      },
    );
  }
}

class _VehicleLogs extends ConsumerWidget {
  const _VehicleLogs({required this.logKey, required this.query});

  final String logKey;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardVehicleLogsProvider(logKey));
    final emptyHint = logKey == 'today'
        ? 'No vehicles logged today.'
        : 'No vehicles in this range.';
    return async.when(
      loading: () => const GuardListSkeleton(),
      error: (e, _) => GuardCenteredError(
        message: userFacingMessage(e),
        onRetry: () => ref.invalidate(guardVehicleLogsProvider(logKey)),
      ),
      data: (rows) {
        final list = rows.where((v) => _vehicleMatch(v, query)).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardVehicleLogsProvider(logKey));
          },
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    GuardEmptyPlaceholder(
                      icon: Icons.directions_car_outlined,
                      title: query.isNotEmpty ? 'No matches' : 'No vehicles',
                      message: emptyHint,
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: GuardTokens.padScreen,
                    vertical: GuardTokens.g2,
                  ),
                  itemCount: list.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final inside = list.where((v) => v.isInside).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                        child: _LogSummaryChip(
                          label:
                              '${list.length} total · $inside inside · ${list.length - inside} exited',
                        ),
                      );
                    }
                    final v = list[i - 1];
                    final rowIdx = i - 1;
                    final vTone = v.isInside ? GuardTokens.success : GuardTokens.textSecondary;
                    final isDarkV = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                          side: BorderSide(
                            color: isDarkV
                                ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                                : GuardTokens.borderSubtle.withValues(alpha: 0.9),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: vTone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: vTone.withValues(alpha: 0.22)),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.directions_car_outlined,
                                  size: 19,
                                  color: vTone,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.registrationNumber.isEmpty ? '(No plate)' : v.registrationNumber,
                                      style: GuardTokens.headingStyle(context).copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      v.kind.replaceAll('_', ' '),
                                      style: GuardTokens.captionStyle(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: vTone.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: vTone.withValues(alpha: 0.30)),
                                ),
                                child: Text(
                                  v.isInside ? 'IN' : 'OUT',
                                  style: TextStyle(
                                    color: vTone,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: DesignAnimations.staggerFor(rowIdx)).fadeIn(duration: 200.ms).slideY(begin: 0.04);
                  },
                ),
        );
      },
    );
  }
}

class _LogSummaryChip extends StatelessWidget {
  const _LogSummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuardTokens.g2,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
      ),
      child: Text(
        label,
        style: GuardTokens.captionStyle(
          context,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

