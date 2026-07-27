import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/analytics/analytics_bar_chart.dart';
import '../widgets/analytics/analytics_tab_switcher.dart';

/// Admin screen for gate analytics and visitor statistics.
class AdminGateAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminGateAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminGateAnalyticsScreen> createState() =>
      _AdminGateAnalyticsScreenState();
}

class _AdminGateAnalyticsScreenState
    extends ConsumerState<AdminGateAnalyticsScreen> {
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
          'Gate Analytics',
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
              currentRoute: '/resident/admin-gate-analytics',
            ),
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
                  ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                          height: 64, borderRadius: DesignRadius.lg),
                    ),
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
                  title: 'Failed to load analytics',
                  subtitle: 'Something went wrong. Please try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (overview) => _buildBody(overview),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> overview) {
    final visitorStatsAsync = ref.watch(adminGateAnalyticsVisitorStatsProvider);
    final peakHoursAsync = ref.watch(adminGateAnalyticsPeakHoursProvider);
    final dailyTrendAsync = ref.watch(adminGateAnalyticsDailyTrendProvider);

    final totalGates = _toInt(overview['totalGates']);
    final activeGates = _toInt(overview['activeGates']);
    final todayVisitors = _toInt(overview['todayVisitors']);
    final guardsOnDuty = _toInt(overview['guardsOnDuty']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Overview hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Gate Overview',
                    style: DesignTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _overviewStat('Gates', '$activeGates/$totalGates'),
                  const SizedBox(width: 16),
                  _overviewStat('Today', '$todayVisitors visitors'),
                  const SizedBox(width: 16),
                  _overviewStat('Guards', '$guardsOnDuty on duty'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Visitor statistics
        EnterpriseSectionHeader(title: 'Visitor Statistics (30 days)'),
        const SizedBox(height: 8),
        visitorStatsAsync.when(
          loading: () =>
              ShimmerWrap(child: ShimmerBox(height: 80, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => _visitorStatsCard(stats),
        ),
        const SizedBox(height: 16),

        // Peak hours
        EnterpriseSectionHeader(title: 'Peak Hours'),
        const SizedBox(height: 8),
        peakHoursAsync.when(
          loading: () =>
              ShimmerWrap(child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (peak) => _peakHoursCard(peak),
        ),
        const SizedBox(height: 16),

        // Daily trend
        EnterpriseSectionHeader(title: '7-Day Trend'),
        const SizedBox(height: 8),
        dailyTrendAsync.when(
          loading: () =>
              ShimmerWrap(child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (trend) => _dailyTrendCard(trend),
        ),
      ],
    );
  }

  Widget _overviewStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: DesignTypography.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorStatsCard(Map<String, dynamic> stats) {
    final total = _toInt(stats['totalVisitors']);
    final breakdown = stats['typeBreakdown'];
    final entries = <MapEntry<String, int>>[];
    if (breakdown is Map) {
      breakdown.forEach((key, value) {
        entries.add(MapEntry(key.toString(), _toInt(value)));
      });
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    final topTypes = entries.take(3).toList();

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statChip('Total', total, const Color(0xFF0891B2)),
              if (topTypes.isNotEmpty) ...[
                const SizedBox(width: 12),
                _statChip(
                  _formatVisitorType(topTypes.first.key),
                  topTypes.first.value,
                  DesignColors.success,
                ),
              ],
              if (topTypes.length > 1) ...[
                const SizedBox(width: 12),
                _statChip(
                  _formatVisitorType(topTypes[1].key),
                  topTypes[1].value,
                  DesignColors.warning,
                ),
              ],
              if (topTypes.length > 2) ...[
                const SizedBox(width: 12),
                _statChip(
                  _formatVisitorType(topTypes[2].key),
                  topTypes[2].value,
                  const Color(0xFF8B5CF6),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _formatVisitorType(String type) {
    switch (type.toUpperCase()) {
      case 'GUEST':
        return 'Guest';
      case 'DELIVERY':
        return 'Delivery';
      case 'SERVICE_PROVIDER':
        return 'Service';
      case 'VENDOR':
        return 'Vendor';
      case 'CONTRACTOR':
        return 'Contractor';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Widget _statChip(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _peakHoursCard(Map<String, dynamic> peak) {
    final hours = (peak['peakHours'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return AnalyticsBarChart(
      color: const Color(0xFF0891B2),
      emptyIcon: Icons.schedule_outlined,
      emptyTitle: 'No peak hour data',
      emptySubtitle: 'Visitor peak hours will appear here once data is available.',
      points: hours
          .map(
            (h) => AnalyticsBarPoint(
              label: h['label']?.toString() ??
                  '${_toInt(h['hour']).toString().padLeft(2, '0')}:00',
              value: _toInt(h['count'] ?? h['totalEvents']).toDouble(),
            ),
          )
          .toList(),
    );
  }

  Widget _dailyTrendCard(Map<String, dynamic> trend) {
    final days = (trend['trendData'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        (trend['dailyTrend'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];

    return AnalyticsBarChart(
      color: DesignColors.success,
      emptyTitle: 'No trend data',
      emptySubtitle: '7-day visitor trends will appear here once data is available.',
      points: days.map((d) {
        final date = d['date']?.toString() ?? '';
        final shortDate = d['displayDate']?.toString().isNotEmpty == true
            ? d['displayDate'].toString()
            : (date.length >= 10 ? date.substring(5, 10) : date);
        return AnalyticsBarPoint(
          label: shortDate,
          value: _toInt(d['total'] ?? d['count']).toDouble(),
        );
      }).toList(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
