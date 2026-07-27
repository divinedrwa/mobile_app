import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/telemetry/telemetry_safe.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_growth_panel.dart';
import '../widgets/analytics/analytics_role_adoption_panel.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';

/// Admin view of first-party mobile/web app usage with premium charts.
class AdminAppAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAppAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAppAnalyticsScreen> createState() =>
      _AdminAppAnalyticsScreenState();
}

class _AdminAppAnalyticsScreenState extends ConsumerState<AdminAppAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminAppAnalyticsDailyTrendProvider);
    ref.invalidate(adminAppAnalyticsScreensProvider);
    ref.invalidate(adminAppAnalyticsFlowsProvider);
    ref.invalidate(adminAppAnalyticsActionsProvider);
    ref.invalidate(adminAppAnalyticsInsightsProvider);
    ref.invalidate(adminAppAnalyticsGrowthDashboardProvider);
    ref.invalidate(adminAppAnalyticsRoleAdoptionProvider);
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Widget _sectionError(String title, Object error) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: DesignColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.toString(),
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Analytics',
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
            child: AnalyticsTabSwitcher(
              currentRoute: '/resident/admin-app-analytics',
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final trendAsync = ref.watch(adminAppAnalyticsDailyTrendProvider);
    final insightsAsync = ref.watch(adminAppAnalyticsInsightsProvider);
    final actionsAsync = ref.watch(adminAppAnalyticsActionsProvider);
    final flowsAsync = ref.watch(adminAppAnalyticsFlowsProvider);
    final screensAsync = ref.watch(adminAppAnalyticsScreensProvider);
    final growthAsync = ref.watch(adminAppAnalyticsGrowthDashboardProvider);
    final roleAdoptionAsync = ref.watch(adminAppAnalyticsRoleAdoptionProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // 1) Who uses the app (role adoption)
        roleAdoptionAsync.when(
          loading: () =>
              const ShimmerBox(height: 200, borderRadius: DesignRadius.xl),
          error: (error, _) =>
              _sectionError('Could not load app usage by role', error),
          data: (adoption) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnalyticsRoleAdoptionPanel(adoption: adoption),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // 2) Business growth — below app-usage analytics
        growthAsync.when(
          loading: () =>
              const ShimmerBox(height: 220, borderRadius: DesignRadius.xl),
          error: (error, _) =>
              _sectionError('Could not load business growth metrics', error),
          data: (growth) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnalyticsGrowthPanel(growth: growth),
              const SizedBox(height: 20),
            ],
          ),
        ),
        const EnterpriseSectionHeader(
          title: 'Daily active users',
          subtitle: 'Last 14 days — how many people opened the app each day',
        ),
        const SizedBox(height: 8),
        trendAsync.when(
          loading: () =>
              const ShimmerBox(height: 140, borderRadius: DesignRadius.lg),
          error: (error, _) =>
              _sectionError('Could not load daily active users', error),
          data: (trend) => _trendBarChart(trend),
        ),
        const SizedBox(height: 16),
        insightsAsync.when(
          loading: () =>
              const ShimmerBox(height: 90, borderRadius: DesignRadius.lg),
          error: (error, _) =>
              _sectionError('Could not load retention insights', error),
          data: (insights) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EnterpriseSectionHeader(
                title: 'Retention & peak hours',
                subtitle: 'How often people return, and when the app is busiest',
              ),
              const SizedBox(height: 8),
              _insightsCard(insights),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const EnterpriseSectionHeader(
          title: 'Feature adoption',
          subtitle: 'Which business actions residents and admins complete',
        ),
        const SizedBox(height: 8),
        actionsAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (error, _) =>
              _sectionError('Could not load feature adoption', error),
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
        const EnterpriseSectionHeader(
          title: 'Guard flows',
          subtitle: 'Gate workflows — volume and success rate',
        ),
        const SizedBox(height: 8),
        flowsAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (error, _) =>
              _sectionError('Could not load guard flow metrics', error),
          data: (flows) => _horizontalBars(
            items: flows
                .take(8)
                .map(
                  (f) => (
                    label: f['label']?.toString() ??
                        (f['flowId']?.toString() ?? '').replaceAll('_', ' '),
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
        const EnterpriseSectionHeader(
          title: 'Top screens',
          subtitle: 'Most visited screens in the app',
        ),
        const SizedBox(height: 8),
        screensAsync.when(
          loading: () =>
              const ShimmerBox(height: 100, borderRadius: DesignRadius.lg),
          error: (error, _) =>
              _sectionError('Could not load top screens', error),
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
      ],
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
    final stickiness = telemetrySafeMap(insights['stickiness']);
    final retention = telemetrySafeMap(insights['retention']);
    final peakHours = telemetrySafeMapList(insights['peakHours']);
    final peak = peakHours.isNotEmpty ? peakHours.first : null;

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _insightChip('1d retention', '${retention['d1Pct'] ?? 0}%', const Color(0xFF7C3AED)),
          _insightChip('7d retention', '${retention['d7Pct'] ?? 0}%', DesignColors.success),
          _insightChip('30d retention', '${retention['d30Pct'] ?? 0}%', const Color(0xFF0E7490)),
          _insightChip('WAU/MAU', '${stickiness['wauMauPct'] ?? 0}%', DesignColors.primary),
          if (peak != null)
            _insightChip(
              'Peak hour',
              '${peak['label'] ?? ''} (${peak['count'] ?? 0})',
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

  String _shortScreen(String path) {
    if (path.startsWith('/resident/tab/')) return path.replaceFirst('/resident/tab/', '');
    if (path.startsWith('/guard/tab/')) return path.replaceFirst('/guard/tab/', '');
    return path.length > 28 ? '…${path.substring(path.length - 26)}' : path;
  }
}
