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

/// Water analytics: hours of supply per day, longest outage, what is running now.
class AdminWaterAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminWaterAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminWaterAnalyticsScreen> createState() => _AdminWaterAnalyticsScreenState();
}

class _AdminWaterAnalyticsScreenState extends ConsumerState<AdminWaterAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminWaterAnalyticsOverviewProvider);
    ref.invalidate(adminWaterAnalyticsDailyProvider);
    ref.invalidate(adminWaterAnalyticsGateProvider);
    ref.invalidate(adminWaterRecentEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminWaterAnalyticsOverviewProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Water supply',
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
            child: AnalyticsTabSwitcher(currentRoute: '/resident/admin-water-analytics'),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: overviewAsync.when(
          loading: () => Padding(
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
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load water analytics',
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
    final days = ref.watch(adminWaterAnalyticsDaysProvider);
    final daily = ref.watch(adminWaterAnalyticsDailyProvider).valueOrNull ?? const [];
    final gates = ref.watch(adminWaterAnalyticsGateProvider).valueOrNull ?? const [];
    final recent = ref.watch(adminWaterRecentEventsProvider).valueOrNull ?? const [];

    final s = (overview['summary'] as Map?) ?? const {};
    final status = (overview['currentStatus'] as List? ?? const []).whereType<Map>().toList();
    final supplyMin = analyticsInt(s['supplyMinutes']);
    final noData = analyticsInt(s['totalEvents']) == 0 && supplyMin == 0;
    final gap = s['longestGapMinutes'];

    final attention = <AnalyticsAttentionItem>[
      for (final g in status)
        if (g['currentStatus'] == 'ON' && g['lastUpdated'] != null)
          if (_minutesSince(g['lastUpdated'].toString()) >= 60)
            AnalyticsAttentionItem(
              tone: _minutesSince(g['lastUpdated'].toString()) >= 180 ? 'critical' : 'watch',
              title: '${g['gateName']}: water ON for ${analyticsMinutes(_minutesSince(g['lastUpdated'].toString()))}',
              detail: 'Check the tank — the motor may have been left running.',
            ),
      if (gap != null && analyticsInt(gap) >= 24 * 60)
        AnalyticsAttentionItem(
          title: 'Longest stretch without water: ${analyticsMinutes(analyticsInt(gap))}',
          detail: 'Residents may have gone a full day without supply.',
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AnalyticsSectionTitle(
          'Last $days days',
          trailing: _PeriodChips(
            value: days,
            onChanged: (d) => ref.read(adminWaterAnalyticsDaysProvider.notifier).state = d,
          ),
        ),
        if (noData)
          AnalyticsCard(
            child: Text(
              'No water updates yet. Guards log water ON/OFF from Gate utilities; supply hours and outages appear here once they start.',
              style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary, height: 1.4),
            ),
          )
        else
          AnalyticsKpiGrid(
            cards: [
              AnalyticsKpiCard(
                label: 'Supply per day',
                displayValue: analyticsMinutes(analyticsInt(s['avgSupplyMinutesPerDay'])),
                status: 'good',
                hint: 'Total ${analyticsMinutes(supplyMin)} in $days days.',
              ),
              AnalyticsKpiCard(
                label: 'Running now',
                displayValue: '${analyticsInt(s['runningNow'])}/${status.length}',
                status: analyticsInt(s['runningNow']) > 0 ? 'good' : 'neutral',
                hint: 'Gates where water is ON.',
              ),
              AnalyticsKpiCard(
                label: 'Longest without water',
                displayValue: gap == null ? '—' : analyticsMinutes(analyticsInt(gap)),
                status: gap != null && analyticsInt(gap) >= 24 * 60 ? 'watch' : 'neutral',
              ),
              AnalyticsKpiCard(
                label: 'Typical supply',
                displayValue: analyticsInt(s['completedCycles']) > 0
                    ? analyticsMinutes(analyticsInt(s['avgDurationMinutes']))
                    : '—',
                status: 'neutral',
                hint: '${analyticsInt(s['completedCycles'])} supplies · longest ${analyticsMinutes(analyticsInt(s['longestSupplyMinutes']))}',
              ),
            ],
          ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Needs attention'),
        AnalyticsAttentionList(items: attention, emptyText: 'Nothing unusual with water supply.'),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Hours of supply per day'),
        AnalyticsBarChart(
          points: [
            for (final d in daily)
              AnalyticsBarPoint(
                label: (d['displayDate']?.toString() ?? '').split(' ').last,
                value: analyticsDouble(d['supplyHours']),
              ),
          ],
          color: DesignColors.info,
          emptyTitle: 'No supply logged',
          emptySubtitle: 'Daily hours appear once guards log water ON/OFF.',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    gates[i]['gateName']?.toString() ?? 'Gate',
                                    style: DesignTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${analyticsMinutes(analyticsInt(gates[i]['supplyMinutes']))} supply in 30 days · '
                                    'updated ${_ago(gates[i]['lastEventTime']?.toString())}',
                                    style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            AnalyticsPill(
                              switch (gates[i]['currentStatus']) {
                                'ON' => 'Water ON',
                                'OFF' => 'Water OFF',
                                _ => 'No updates',
                              },
                              tone: gates[i]['currentStatus'] == 'ON'
                                  ? 'good'
                                  : (gates[i]['currentStatus'] == 'OFF' ? 'neutral' : 'watch'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Recent updates'),
        AnalyticsCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No updates yet.', style: DesignTypography.bodySmall),
                )
              : Column(
                  children: [
                    for (var i = 0; i < recent.length && i < 10; i++) ...[
                      if (i > 0) Divider(height: 1, color: DesignColors.borderLight),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            AnalyticsPill(
                              recent[i]['action']?.toString() ?? '',
                              tone: recent[i]['action'] == 'ON' ? 'good' : 'neutral',
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                [
                                  (recent[i]['gate'] as Map?)?['name']?.toString() ?? 'Gate',
                                  if ((recent[i]['reason']?.toString() ?? '').isNotEmpty) recent[i]['reason'].toString(),
                                ].join(' · '),
                                style: DesignTypography.bodySmall.copyWith(color: DesignColors.textPrimary),
                              ),
                            ),
                            Text(
                              _ago(recent[i]['timestamp']?.toString()),
                              style: DesignTypography.captionSmall.copyWith(color: DesignColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static int _minutesSince(String iso) {
    final t = DateTime.tryParse(iso);
    return t == null ? 0 : DateTime.now().difference(t).inMinutes;
  }

  static String _ago(String? iso) {
    if (iso == null) return 'never';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '—';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'just now';
    if (m < 60) return '$m min ago';
    if (m < 24 * 60) return '${m ~/ 60} h ago';
    return '${t.day}/${t.month}';
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final d in const [7, 30, 90])
          ChoiceChip(
            label: Text('${d}d'),
            selected: value == d,
            onSelected: (_) => onChanged(d),
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: value == d ? Colors.white : DesignColors.textSecondary,
            ),
            selectedColor: DesignColors.primary,
            showCheckmark: false,
          ),
      ],
    );
  }
}
