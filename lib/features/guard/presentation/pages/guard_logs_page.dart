import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../../../resident/data/models/parcel_model.dart';
import '../providers/guard_providers.dart';

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
    if (_tab.indexIsChanging) return;
    setState(() {});
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
            // IndexedStack avoids TabBarView + go_router StatefulShellRoute
            // interaction where inactive branches disable tickers, leaving
            // TabBarView pages blank until a manual rebuild.
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                sizing: StackFit.expand,
                children: [
                  _VisitorLogs(logKey: key, query: q),
                  _DeliveryLogs(logKey: key, query: q),
                  _VehicleLogs(logKey: key, query: q),
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

bool _vehicleMatch(Map<String, dynamic> raw, String q) {
  if (q.isEmpty) return true;
  final qq = q.toLowerCase();
  final reg = raw['registrationNumber']?.toString() ?? '';
  final kind = raw['kind']?.toString() ?? '';
  final villa = raw['villa'] as Map?;
  final flat = [
    if (villa?['block'] != null) villa?['block']?.toString() ?? '',
    if (villa?['villaNumber'] != null) villa?['villaNumber']?.toString() ?? '',
  ].join(' ');
  return reg.toLowerCase().contains(qq) ||
      kind.toLowerCase().contains(qq) ||
      flat.toLowerCase().contains(qq);
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LogError(
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
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                    Center(
                      child: Text(
                        emptyHint,
                        style: GuardTokens.bodyStyle(context),
                      ),
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
                    final inGate = v.checkOutTime == null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: GuardTokens.guardAccent.withValues(
                            alpha: 0.14,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: GuardTokens.guardAccentDeep,
                          ),
                        ),
                        title: Text(
                          v.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (v.villaLabel != null) 'Flat ${v.villaLabel}',
                            v.status,
                          ].join(' · '),
                          style: GuardTokens.captionStyle(context),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: inGate
                                ? GuardTokens.successMuted
                                : GuardTokens.dangerMuted,
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusChip,
                            ),
                          ),
                          child: Text(
                            inGate ? 'IN' : 'OUT',
                            style: TextStyle(
                              color: inGate
                                  ? GuardTokens.success
                                  : GuardTokens.dangerBrand,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LogError(
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
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                    Center(
                      child: Text(
                        emptyHint,
                        style: GuardTokens.bodyStyle(context),
                      ),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: GuardTokens.warning.withValues(
                            alpha: 0.14,
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: GuardTokens.warning,
                          ),
                        ),
                        title: Text(
                          p.trackingNumber.isNotEmpty
                              ? p.trackingNumber
                              : p.courier,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${p.courier} · ${p.status.label}',
                          style: GuardTokens.captionStyle(context),
                        ),
                      ),
                    );
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _LogError(
        message: userFacingMessage(e),
        onRetry: () => ref.invalidate(guardVehicleLogsProvider(logKey)),
      ),
      data: (rows) {
        final list = rows
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) => _vehicleMatch(m, query))
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(guardVehicleLogsProvider(logKey));
          },
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                    Center(
                      child: Text(
                        emptyHint,
                        style: GuardTokens.bodyStyle(context),
                      ),
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
                      final inside = list
                          .where((raw) => raw['exitAt'] == null)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                        child: _LogSummaryChip(
                          label:
                              '${list.length} total · $inside inside · ${list.length - inside} exited',
                        ),
                      );
                    }
                    final raw = list[i - 1];
                    final reg = raw['registrationNumber']?.toString() ?? '';
                    final kind = raw['kind']?.toString() ?? '';
                    final exited = raw['exitAt'] != null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: GuardTokens.success.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(Icons.directions_car_rounded),
                        ),
                        title: Text(
                          reg.isEmpty ? '—' : reg,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        subtitle: Text(
                          '${kind.replaceAll('_', ' ')} · ${exited ? 'Out' : 'Inside'}',
                          style: GuardTokens.captionStyle(context),
                        ),
                      ),
                    );
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

class _LogError extends StatelessWidget {
  const _LogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: GuardTokens.warning.withValues(alpha: 0.9),
            ),
            const SizedBox(height: GuardTokens.g2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GuardTokens.bodyStyle(context),
            ),
            const SizedBox(height: GuardTokens.g2),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: GuardTokens.primaryFilled(context),
            ),
          ],
        ),
      ),
    );
  }
}
