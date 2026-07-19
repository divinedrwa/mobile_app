import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin view of first-party mobile/web app usage with premium charts.
class AdminAppAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAppAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAppAnalyticsScreen> createState() =>
      _AdminAppAnalyticsScreenState();
}

class _AdminAppAnalyticsScreenState extends ConsumerState<AdminAppAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminAppAnalyticsSummaryProvider);
    ref.invalidate(adminAppAnalyticsDailyTrendProvider);
    ref.invalidate(adminAppAnalyticsScreensProvider);
    ref.invalidate(adminAppAnalyticsFlowsProvider);
    ref.invalidate(adminAppAnalyticsActionsProvider);
    ref.invalidate(adminAppAnalyticsErrorsProvider);
    ref.invalidate(adminAppAnalyticsInsightsProvider);
    ref.invalidate(adminAppAnalyticsActiveUsersProvider);
    ref.invalidate(adminAppAnalyticsUserEngagementProvider);
  }

  String _fmtDuration(int ms) {
    if (ms <= 0) return '—';
    final m = (ms / 60000).floor();
    final s = ((ms % 60000) / 1000).floor();
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(adminAppAnalyticsSummaryProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'App Usage',
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
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: summaryAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
              SizedBox(height: 12),
              ShimmerBox(height: 160, borderRadius: DesignRadius.lg),
            ],
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load app analytics',
                  subtitle: e.toString(),
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (summary) => _buildBody(summary),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> summary) {
    final totals = (summary['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final engagementSummary =
        (summary['engagement'] as Map?)?.cast<String, dynamic>() ?? {};

    final trendAsync = ref.watch(adminAppAnalyticsDailyTrendProvider);
    final insightsAsync = ref.watch(adminAppAnalyticsInsightsProvider);
    final actionsAsync = ref.watch(adminAppAnalyticsActionsProvider);
    final flowsAsync = ref.watch(adminAppAnalyticsFlowsProvider);
    final screensAsync = ref.watch(adminAppAnalyticsScreensProvider);
    final engagementAsync = ref.watch(adminAppAnalyticsUserEngagementProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _heroCard(totals),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Engagement breakdown'),
        const SizedBox(height: 8),
        _engagementDonut(engagementSummary),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Daily active users (14 days)'),
        const SizedBox(height: 8),
        trendAsync.when(
          loading: () =>
              const ShimmerBox(height: 140, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (trend) => _trendBarChart(trend),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Growth insights'),
        const SizedBox(height: 8),
        insightsAsync.when(
          loading: () =>
              const ShimmerBox(height: 90, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (insights) => _insightsCard(insights),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Feature adoption'),
        const SizedBox(height: 8),
        actionsAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (actions) => _horizontalBars(
            items: actions
                .take(8)
                .map(
                  (a) => (
                    label: a['label']?.toString() ?? '',
                    value: _toInt(a['count']),
                    trailing: '${a['adoptionPct'] ?? 0}%',
                  ),
                )
                .toList(),
            emptyLabel: 'No business actions recorded yet',
            barColor: DesignColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Guard flows'),
        const SizedBox(height: 8),
        flowsAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (flows) => _horizontalBars(
            items: flows
                .take(8)
                .map(
                  (f) => (
                    label: (f['flowId']?.toString() ?? '').replaceAll('_', ' '),
                    value: _toInt(f['count']),
                    trailing: '${f['successRate'] ?? 0}% ok',
                  ),
                )
                .toList(),
            emptyLabel: 'No guard flow data yet',
            barColor: const Color(0xFF0E7490),
          ),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Top screens'),
        const SizedBox(height: 8),
        screensAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (screens) => _horizontalBars(
            items: screens
                .take(8)
                .map(
                  (s) => (
                    label: _shortScreen(s['screen']?.toString() ?? ''),
                    value: _toInt(s['views']),
                    trailing: 'views',
                  ),
                )
                .toList(),
            emptyLabel: 'No screen views yet',
            barColor: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Outreach lists'),
        const SizedBox(height: 8),
        engagementAsync.when(
          loading: () =>
              const ShimmerBox(height: 120, borderRadius: DesignRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (engagement) => _outreachSection(engagement),
        ),
      ],
    );
  }

  Widget _heroCard(Map<String, dynamic> totals) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignColors.primary,
            DesignColors.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'App health snapshot',
                style: DesignTypography.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Analytics + login + push signals — all roles',
            style: DesignTypography.captionSmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat('DAU', '${totals['dailyActiveUsers'] ?? 0}'),
              _heroStat('WAU', '${totals['weeklyActiveUsers'] ?? 0}'),
              _heroStat('MAU', '${totals['monthlyActiveUsers'] ?? totals['uniqueActiveUsers'] ?? 0}'),
              _heroStat('Stickiness', '${totals['stickinessPct'] ?? 0}%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroStat('Sessions', '${totals['sessions'] ?? 0}'),
              _heroStat('Actions', '${totals['actions'] ?? 0}'),
              _heroStat('Avg session', _fmtDuration(_toInt(totals['avgSessionDurationMs']))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _engagementDonut(Map<String, dynamic> engagement) {
    final active = _toInt(engagement['activeInPeriod']);
    final dormant = _toInt(engagement['inactiveInPeriod']);
    final never = _toInt(engagement['neverUsedApp']);
    final deactivated = _toInt(engagement['deactivatedAccounts']);
    final total = active + dormant + never + deactivated;

    if (total == 0) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No registered users yet',
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final sections = [
      _PieSlice('Active', active, DesignColors.success),
      _PieSlice('Dormant', dormant, DesignColors.warning),
      _PieSlice('No signals', never, DesignColors.error),
      _PieSlice('Deactivated', deactivated, DesignColors.textSecondary),
    ].where((s) => s.value > 0).toList();

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: sections
                    .map(
                      (s) => PieChartSectionData(
                        value: s.value.toDouble(),
                        color: s.color,
                        radius: 22,
                        title: '',
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: DesignTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${s.value}',
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendBarChart(List<Map<String, dynamic>> trend) {
    if (trend.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Trend appears after users open the app',
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final spots = <BarChartGroupData>[];
    var maxY = 1.0;
    for (var i = 0; i < trend.length; i++) {
      final y = _toInt(trend[i]['activeUsers']).toDouble();
      if (y > maxY) maxY = y;
      spots.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              width: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              gradient: LinearGradient(
                colors: [DesignColors.primary, DesignColors.primary.withValues(alpha: 0.65)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
        ),
      );
    }

    return EnterprisePanel(
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.15,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 4 ? (maxY / 4).ceilToDouble() : 1,
              getDrawingHorizontalLine: (_) => FlLine(
                color: DesignColors.border.withValues(alpha: 0.35),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                    final date = trend[i]['displayDate']?.toString() ?? '';
                    final short = date.length >= 5 ? date.substring(5) : date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        short,
                        style: DesignTypography.captionSmall.copyWith(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: spots,
          ),
        ),
      ),
    );
  }

  Widget _insightsCard(Map<String, dynamic> insights) {
    final stickiness =
        (insights['stickiness'] as Map?)?.cast<String, dynamic>() ?? {};
    final retention =
        (insights['retention'] as Map?)?.cast<String, dynamic>() ?? {};
    final peakHours = insights['peakHours'] as List? ?? [];

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _insightChip('7d retention', '${retention['d7Pct'] ?? 0}%', DesignColors.success),
          _insightChip('30d retention', '${retention['d30Pct'] ?? 0}%', const Color(0xFF0E7490)),
          _insightChip('WAU/MAU', '${stickiness['wauMauPct'] ?? 0}%', DesignColors.primary),
          if (peakHours.isNotEmpty)
            _insightChip(
              'Peak hour',
              '${peakHours.first['label']} (${peakHours.first['count']})',
              DesignColors.warning,
            ),
        ],
      ),
    );
  }

  Widget _insightChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalBars({
    required List<({String label, int value, String trailing})> items,
    required String emptyLabel,
    required Color barColor,
  }) {
    if (items.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          emptyLabel,
          style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final maxVal = items.fold<int>(0, (m, i) => i.value > m ? i.value : m);

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items.map((item) {
          final fraction = maxVal > 0 ? item.value / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesignTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${item.value} ${item.trailing}',
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: DesignColors.border.withValues(alpha: 0.35),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _outreachSection(Map<String, dynamic> engagement) {
    final dormant = engagement['inactiveUsers'] as List? ?? [];
    final never = engagement['neverUsedUsers'] as List? ?? [];

    if (dormant.isEmpty && never.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: Text(
          'All registered users show app activity signals in this period.',
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dormant.isNotEmpty) ...[
          Text(
            'Dormant — used before, not in last 30 days (${dormant.length})',
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          EnterprisePanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: dormant.take(8).map((u) => _userRow(u, showLastSeen: true)).toList(),
            ),
          ),
        ],
        if (never.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'No app signals — never logged in on mobile (${never.length})',
            style: DesignTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: DesignColors.warning,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Only accounts with no analytics, push device, or login token appear here.',
            style: DesignTypography.captionSmall.copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: 8),
          EnterprisePanel(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: never.take(8).map((u) => _userRow(u, showLastSeen: false)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _userRow(Map<dynamic, dynamic> u, {required bool showLastSeen}) {
    final lastSeen = u['lastSeenAt']?.toString().split('T').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: DesignColors.primary.withValues(alpha: 0.12),
            child: Text(
              (u['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: DesignColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['name']?.toString() ?? '',
                  style: DesignTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${u['role']} · ${u['villaNumber'] ?? u['username'] ?? ''}',
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showLastSeen && lastSeen != null)
            Text(
              lastSeen,
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  String _shortScreen(String path) {
    if (path.startsWith('/resident/tab/')) return path.replaceFirst('/resident/tab/', '');
    if (path.startsWith('/guard/tab/')) return path.replaceFirst('/guard/tab/', '');
    return path.length > 28 ? '…${path.substring(path.length - 26)}' : path;
  }
}

class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}
