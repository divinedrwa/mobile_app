import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_bar_chart.dart';
import '../widgets/analytics/analytics_blocks.dart';
import '../widgets/analytics/analytics_kpi_card.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';

/// Complaint analytics: what is open, how fast it is resolved, and which
/// categories lag. Resolved includes complaints that were later auto-closed.
class AdminComplaintAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminComplaintAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminComplaintAnalyticsScreen> createState() => _AdminComplaintAnalyticsScreenState();
}

class _AdminComplaintAnalyticsScreenState extends ConsumerState<AdminComplaintAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminComplaintAnalyticsSummaryProvider);
    ref.invalidate(adminComplaintAnalyticsByCategoryProvider);
    ref.invalidate(adminComplaintAnalyticsPendingProvider);
    ref.invalidate(adminComplaintAnalyticsTrendProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminComplaintAnalyticsSummaryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Complaints',
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
            child: AnalyticsTabSwitcher(currentRoute: '/resident/admin-complaint-analytics'),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: summaryAsync.when(
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
                  title: 'Could not load complaint analytics',
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

  Widget _body(Map<String, dynamic> data) {
    final s = (data['summary'] as Map?) ?? const {};
    final categories = ref.watch(adminComplaintAnalyticsByCategoryProvider).valueOrNull ?? const [];
    final pending = ref.watch(adminComplaintAnalyticsPendingProvider).valueOrNull ?? const [];
    final trend = ref.watch(adminComplaintAnalyticsTrendProvider).valueOrNull ?? const [];

    final total = analyticsInt(s['totalComplaints']);
    final resolved = analyticsInt(s['resolvedCount']);
    final openNow = analyticsInt(s['openNow'] ?? (analyticsInt(s['pendingCount']) + analyticsInt(s['inProgressCount'])));
    final over7 = analyticsInt(s['openOver7Days']);
    final sla = s['slaComplianceRate'];
    final median = s['medianResolutionDays'] ?? s['avgResolutionTime'];
    final byPriority = (s['byPriority'] as Map?) ?? const {};

    final attention = [
      for (final c in pending.take(8))
        AnalyticsAttentionItem(
          tone: c['urgencyLevel'] == 'critical'
              ? 'critical'
              : (c['urgencyLevel'] == 'high' ? 'watch' : 'neutral'),
          title: c['title']?.toString() ?? 'Complaint',
          detail: [
            if (c['villa'] is Map) 'Flat ${_flat(c['villa'] as Map)}',
            c['category']?.toString(),
            analyticsInt(c['daysPending']) == 0
                ? 'today'
                : '${analyticsInt(c['daysPending'])} ${analyticsInt(c['daysPending']) == 1 ? 'day' : 'days'} open',
            if (c['slaBreached'] == true) 'SLA missed',
          ].whereType<String>().join(' · '),
          action: IconButton(
            tooltip: 'Open complaints',
            visualDensity: VisualDensity.compact,
            onPressed: () => context.push('/resident/admin-complaints'),
            icon: Icon(Icons.chevron_right_rounded, color: DesignColors.textSecondary),
          ),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const AnalyticsSectionTitle('Right now'),
        AnalyticsKpiGrid(
          cards: [
            AnalyticsKpiCard(
              label: 'Open right now',
              displayValue: '$openNow',
              status: openNow > 0 ? 'watch' : 'good',
              hint: 'Open or in progress, from any date.',
            ),
            AnalyticsKpiCard(
              label: 'Open over 7 days',
              displayValue: '$over7',
              status: over7 > 0 ? 'critical' : 'good',
              hint: 'Oldest items residents are waiting on.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Needs attention', subtitle: 'Most urgent open complaints first'),
        AnalyticsAttentionList(items: attention, emptyText: 'No open complaints.'),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Last 30 days'),
        AnalyticsKpiGrid(
          cards: [
            AnalyticsKpiCard(
              label: 'Resolved',
              displayValue: total > 0 ? '$resolved/$total' : '0',
              status: total > 0 ? analyticsTone(analyticsInt(s['resolutionRate']), 80, 50) : 'neutral',
              hint: total > 0 ? '${s['resolutionRate']}% of complaints filed.' : 'No complaints filed.',
            ),
            AnalyticsKpiCard(
              label: 'Typical time to resolve',
              displayValue: resolved > 0 ? '$median days' : '—',
              status: resolved > 0 ? analyticsTone(analyticsDouble(median), 2, 5, lowerIsBetter: true) : 'neutral',
              hint: resolved > 0 ? 'Median · average ${s['avgResolutionTime']} days.' : null,
            ),
            AnalyticsKpiCard(
              label: 'Resolved within SLA',
              displayValue: sla == null ? '—' : '$sla%',
              status: sla == null ? 'neutral' : analyticsTone(analyticsInt(sla), 90, 70),
              hint: sla == null ? 'Nothing with an SLA resolved yet.' : 'Of resolved complaints with an SLA.',
            ),
            AnalyticsKpiCard(
              label: 'SLA missed (still open)',
              displayValue: '${analyticsInt(s['slaBreached'])}',
              status: analyticsInt(s['slaBreached']) > 0 ? 'critical' : 'good',
            ),
            AnalyticsKpiCard(
              label: 'Urgent / high priority',
              displayValue: '${analyticsInt(byPriority['URGENT']) + analyticsInt(byPriority['HIGH'])}',
              status: 'neutral',
              hint: '${analyticsInt(byPriority['URGENT'])} urgent · ${analyticsInt(byPriority['HIGH'])} high',
            ),
            AnalyticsKpiCard(
              label: 'Filed',
              displayValue: '$total',
              status: 'neutral',
              hint: 'In the last 30 days.',
            ),
          ],
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('Filed per month', subtitle: 'Last 6 months'),
        AnalyticsBarChart(
          points: [
            for (final m in trend)
              AnalyticsBarPoint(label: _month(m['month']?.toString() ?? ''), value: analyticsDouble(m['totalComplaints'])),
          ],
          color: DesignColors.warning,
          emptyTitle: 'No complaints yet',
          emptySubtitle: 'Monthly counts appear once complaints are filed.',
        ),
        const SizedBox(height: 18),
        const AnalyticsSectionTitle('By category', subtitle: 'Last 30 days'),
        AnalyticsCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: categories.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No complaints filed in this period.', style: DesignTypography.bodySmall),
                )
              : Column(
                  children: [
                    for (var i = 0; i < categories.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: DesignColors.borderLight),
                      _CategoryRow(c: categories[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  static String _flat(Map v) {
    final b = v['block']?.toString() ?? '';
    return b.isEmpty ? '${v['villaNumber']}' : '$b-${v['villaNumber']}';
  }

  static String _month(String key) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(key.split('-').last) ?? 0;
    return m >= 1 && m <= 12 ? names[m - 1] : key;
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final resolved = analyticsInt(c['resolvedCount']);
    final open = analyticsInt(c['pendingCount']) + analyticsInt(c['inProgressCount']);
    final perf = c['performance']?.toString() ?? 'none';
    final tone = switch (perf) { 'good' => 'good', 'fair' => 'watch', 'slow' => 'critical', _ => 'neutral' };
    final label = (c['performanceStatus']?.toString() ?? '').replaceAll(RegExp(r'^[^A-Za-z]+'), '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['category']?.toString() ?? 'Other',
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${analyticsInt(c['totalCount'])} filed · $open open · $resolved resolved'
                  '${resolved > 0 ? ' · ${c['avgResolutionTime']} days avg' : ''}',
                  style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
                ),
              ],
            ),
          ),
          AnalyticsPill(label.isEmpty ? '—' : label, tone: tone),
        ],
      ),
    );
  }
}
