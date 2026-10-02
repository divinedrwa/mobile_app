import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_bar_chart.dart';
import '../widgets/analytics/analytics_blocks.dart';
import '../widgets/analytics/analytics_kpi_card.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';

/// Gate & visitor analytics: who is inside now, what happened to requests,
/// how fast residents answer, and what needs attention.
class AdminGateAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminGateAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminGateAnalyticsScreen> createState() => _AdminGateAnalyticsScreenState();
}

class _AdminGateAnalyticsScreenState extends ConsumerState<AdminGateAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminGateAnalyticsOverviewProvider);
    ref.invalidate(adminGateAnalyticsVisitorStatsProvider);
    ref.invalidate(adminGateAnalyticsPeakHoursProvider);
    ref.invalidate(adminGateAnalyticsDailyTrendProvider);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminGateAnalyticsOverviewProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Gate & visitors',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: AnalyticsTabSwitcher(currentRoute: '/resident/admin-gate-analytics'),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: overviewAsync.when(
          loading: () => const _Loading(),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load gate analytics',
                  subtitle: 'Check the connection and try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: _body,
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> overview) {
    final stats = ref.watch(adminGateAnalyticsVisitorStatsProvider).valueOrNull ?? const {};
    final peak = ref.watch(adminGateAnalyticsPeakHoursProvider).valueOrNull ?? const {};
    final trend = ref.watch(adminGateAnalyticsDailyTrendProvider).valueOrNull ?? const {};

    final gates = (overview['gates'] as List? ?? const []).whereType<Map>().toList();
    final activeGates = analyticsInt(overview['activeGates']);
    final onShift = analyticsInt(overview['guardsOnDuty']);
    final waitingNow = analyticsInt(overview['waitingNow']);

    final o = (stats['outcomes'] as Map?) ?? const {};
    final a = (stats['approvals'] as Map?) ?? const {};
    final st = (stats['stay'] as Map?) ?? const {};
    final asked = analyticsInt(a['asked']);
    final answered = analyticsInt(a['answered']);

    final attention = <AnalyticsAttentionItem>[
      for (final g in gates.where((g) => g['isActive'] == true))
        if ((g['assignedGuard'] as Map?)?['onShift'] != true)
          AnalyticsAttentionItem(
            tone: 'critical',
            title: '${g['name']}: no guard on shift',
            detail: g['assignedGuard'] is Map
                ? '${(g['assignedGuard'] as Map)['name']} is assigned but not on an active shift.'
                : 'No guard assigned.',
          ),
      if (waitingNow > 0)
        AnalyticsAttentionItem(
          title: '$waitingNow ${waitingNow == 1 ? 'visitor is' : 'visitors are'} waiting for a reply',
          detail: 'Guards get a call button after 3 minutes without a reply.',
        ),
      if (asked >= 5 && analyticsInt(a['noReplyPct']) >= 30)
        AnalyticsAttentionItem(
          title: '${a['noReplyPct']}% of gate requests got no reply in the app',
          detail: 'Remind residents to keep GatePass+ notifications on.',
        ),
      if (analyticsInt(st['exitNotMarkedPct']) >= 20)
        AnalyticsAttentionItem(
          title: '${st['exitNotMarkedPct']}% of visits had no exit marked',
          detail: "Guards should tap Mark exit — it keeps 'inside now' accurate.",
        ),
    ];

    final trendPoints = [
      for (final d in (trend['trendData'] as List? ?? const []).whereType<Map>())
        AnalyticsBarPoint(
          label: (d['displayDate']?.toString() ?? '').split(' ').last,
          value: analyticsDouble(d['total']),
        ),
    ];
    final hourPoints = [
      for (final h in (peak['hourlyData'] as List? ?? const []).whereType<Map>().toList()
        ..sort((x, y) => analyticsInt(x['hour']).compareTo(analyticsInt(y['hour']))))
        AnalyticsBarPoint(
          label: _shortHour(analyticsInt(h['hour'])),
          value: analyticsDouble(h['count']),
        ),
    ];
    final peaks = (peak['peakHours'] as List? ?? const []).whereType<Map>().map((p) => p['label']).join(', ');

    final types = ((stats['typeBreakdown'] as Map?) ?? const {}).entries.toList()
      ..sort((x, y) => analyticsInt(y.value).compareTo(analyticsInt(x.value)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const AnalyticsSectionTitle('Right now'),
        AnalyticsKpiGrid(
          cards: [
            AnalyticsKpiCard(
              label: 'Inside now',
              displayValue: '${analyticsInt(overview['insideNow'])}',
              status: 'good',
              hint: 'Let in and not yet exited.',
            ),
            AnalyticsKpiCard(
              label: 'Waiting for residents',
              displayValue: '$waitingNow',
              status: waitingNow > 0 ? 'watch' : 'good',
              hint: 'Requests with no reply yet.',
            ),
            AnalyticsKpiCard(
              label: 'Let in today',
              displayValue: '${analyticsInt(overview['todayVisitors'])}',
              status: 'neutral',
              hint: '${analyticsInt(overview['todayRequests'])} requests logged today.',
            ),
            AnalyticsKpiCard(
              label: 'Guards on shift',
              displayValue: '$onShift/$activeGates',
              status: onShift >= activeGates ? 'good' : 'critical',
              hint: 'Active gates with a guard on duty.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Needs attention'),
        AnalyticsAttentionList(items: attention, emptyText: 'Gates are running smoothly.'),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Last 30 days'),
        AnalyticsKpiGrid(
          cards: [
            AnalyticsKpiCard(
              label: 'People let in',
              displayValue: '${analyticsInt(o['entries'] ?? stats['totalVisitors'])}',
              status: 'neutral',
              hint: '${analyticsInt(o['requests'])} requests · ${analyticsInt(o['preApprovedEntries'])} pre-approved',
            ),
            AnalyticsKpiCard(
              label: 'Residents approved',
              displayValue: answered > 0 ? '${a['approvalRatePct']}%' : '—',
              status: answered > 0 ? analyticsTone(analyticsInt(a['approvalRatePct']), 80, 60) : 'neutral',
              hint: '$answered of $asked requests answered.',
            ),
            AnalyticsKpiCard(
              label: 'Answered in the app',
              displayValue: asked > 0 ? '${a['answeredInAppPct']}%' : '—',
              status: asked > 0 ? analyticsTone(analyticsInt(a['answeredInAppPct']), 75, 50) : 'neutral',
              hint: 'Rest needed a call, an override or expired.',
            ),
            AnalyticsKpiCard(
              label: 'Typical reply time',
              displayValue: answered > 0 ? analyticsMinutes(analyticsInt(a['medianResponseMinutes'])) : '—',
              status: answered > 0
                  ? analyticsTone(analyticsInt(a['medianResponseMinutes']), 3, 10, lowerIsBetter: true)
                  : 'neutral',
              hint: 'Median time to approve or reject.',
            ),
            AnalyticsKpiCard(
              label: 'Typical visit length',
              displayValue: analyticsInt(st['medianMinutes']) > 0
                  ? analyticsMinutes(analyticsInt(st['medianMinutes']))
                  : '—',
              status: 'neutral',
              hint: 'Only visits with a real exit.',
            ),
            AnalyticsKpiCard(
              label: 'Exit not marked',
              displayValue: '${analyticsInt(st['exitNotMarkedPct'])}%',
              status: analyticsTone(analyticsInt(st['exitNotMarkedPct']), 5, 20, lowerIsBetter: true),
              hint: '${analyticsInt(st['exitNotMarked'])} visits closed automatically.',
            ),
            AnalyticsKpiCard(
              label: 'Rejected by residents',
              displayValue: '${analyticsInt(o['rejected'])}',
              status: 'neutral',
              hint: '${analyticsInt(o['expired'])} expired without an answer.',
            ),
            AnalyticsKpiCard(
              label: 'Guard overrides',
              displayValue: '${analyticsInt(a['guardOverrides'])}',
              status: 'neutral',
              hint: 'Let in without an app reply.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Daily entries', subtitle: 'People let in · last 7 days'),
        AnalyticsBarChart(
          points: trendPoints,
          emptyTitle: 'No entries yet',
          emptySubtitle: 'Daily entries appear once visitors are let in.',
        ),
        const SizedBox(height: 18),
        AnalyticsSectionTitle(
          'Busiest hours',
          subtitle: peaks.isEmpty ? 'When people are let in' : 'Peak: $peaks',
        ),
        AnalyticsBarChart(
          points: hourPoints,
          color: DesignColors.info,
          height: 150,
          emptyTitle: 'No entries yet',
          emptySubtitle: 'Busy hours appear once visitors are let in.',
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Request outcomes', subtitle: 'What happened to every request'),
        AnalyticsShareBars(
          emptyText: 'No gate requests in this period.',
          items: [
            AnalyticsShare('Let in', analyticsInt(o['entries']), DesignColors.success),
            AnalyticsShare('Rejected by residents', analyticsInt(o['rejected']), DesignColors.error),
            AnalyticsShare('Expired (no answer in 12 h)', analyticsInt(o['expired']), DesignColors.warning),
            AnalyticsShare('Exit marked, entry not recorded', analyticsInt(o['leftWithoutEntering']), DesignColors.textTertiary),
            AnalyticsShare('Still waiting', analyticsInt(o['waiting']), DesignColors.info),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Who came in'),
        AnalyticsShareBars(
          emptyText: 'Nobody let in during this period.',
          items: [
            for (final t in types)
              AnalyticsShare(_typeLabel(t.key.toString()), analyticsInt(t.value), _typeColor(t.key.toString())),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Gates'),
        AnalyticsCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: gates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No gates yet.', style: DesignTypography.bodySmall),
                )
              : Column(
                  children: [
                    for (var i = 0; i < gates.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: DesignColors.borderLight),
                      _GateRow(gate: gates[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static String _shortHour(int h) => h == 0 ? '12a' : h < 12 ? '${h}a' : h == 12 ? '12p' : '${h - 12}p';

  static String _typeLabel(String t) => const {
        'GUEST': 'Guests',
        'DELIVERY': 'Deliveries',
        'CAB': 'Cabs',
        'SERVICE_PROVIDER': 'Service',
        'SERVICE': 'Service',
        'VENDOR': 'Vendors',
      }[t] ??
      t;

  static Color _typeColor(String t) => switch (t) {
        'DELIVERY' => DesignColors.success,
        'CAB' => DesignColors.warning,
        'SERVICE_PROVIDER' || 'SERVICE' => DesignColors.info,
        'VENDOR' => DesignColors.accent,
        _ => DesignColors.primary,
      };
}

class _GateRow extends StatelessWidget {
  const _GateRow({required this.gate});

  final Map gate;

  @override
  Widget build(BuildContext context) {
    final guard = gate['assignedGuard'] as Map?;
    final onShift = guard?['onShift'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${gate['name']}${gate['isActive'] == true ? '' : ' (inactive)'}',
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                onShift ? Icons.verified_user_rounded : Icons.shield_outlined,
                size: 16,
                color: onShift ? DesignColors.success : DesignColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                guard == null ? 'No guard' : (onShift ? '${guard['name']} · on shift' : '${guard['name']} · off shift'),
                style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AnalyticsPill('${analyticsInt(gate['insideNow'] ?? gate['activeVisitors'])} inside', tone: 'good'),
              if (analyticsInt(gate['waitingNow']) > 0)
                AnalyticsPill('${analyticsInt(gate['waitingNow'])} waiting', tone: 'watch'),
              AnalyticsPill('${analyticsInt(gate['todayEntries'] ?? gate['todayVisitors'])} today'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ShimmerWrap(
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShimmerBox(height: 84, borderRadius: DesignRadius.lg),
              ),
          ],
        ),
      ),
    );
  }
}
