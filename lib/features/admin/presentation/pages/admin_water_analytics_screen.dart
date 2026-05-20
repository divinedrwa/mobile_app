import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for water supply analytics.
class AdminWaterAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminWaterAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminWaterAnalyticsScreen> createState() =>
      _AdminWaterAnalyticsScreenState();
}

class _AdminWaterAnalyticsScreenState
    extends ConsumerState<AdminWaterAnalyticsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminWaterAnalyticsOverviewProvider);
    ref.invalidate(adminWaterAnalyticsDailyProvider);
    ref.invalidate(adminWaterAnalyticsHourlyProvider);
    ref.invalidate(adminWaterAnalyticsGateProvider);
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
          'Water Analytics',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
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
        child: overviewAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 12),
                  ...List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                          height: 80, borderRadius: DesignRadius.lg),
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
    final dailyAsync = ref.watch(adminWaterAnalyticsDailyProvider);
    final hourlyAsync = ref.watch(adminWaterAnalyticsHourlyProvider);
    final gateAsync = ref.watch(adminWaterAnalyticsGateProvider);

    final totalEvents = _toInt(overview['totalEvents']);
    final avgDuration = _toDouble(overview['averageDurationMinutes']);
    final totalGates = _toInt(overview['totalGates']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Overview hero
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
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
                  const Icon(Icons.water_drop_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Water Supply Overview',
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
                  _overviewStat('Events (7d)', '$totalEvents'),
                  const SizedBox(width: 16),
                  _overviewStat('Avg Duration', '${avgDuration.round()} min'),
                  const SizedBox(width: 16),
                  _overviewStat('Gates', '$totalGates'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Daily usage
        EnterpriseSectionHeader(title: 'Daily Usage'),
        const SizedBox(height: 8),
        dailyAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (daily) => _barList(daily, 'date', 'count',
              const Color(0xFF0EA5E9)),
        ),
        const SizedBox(height: 16),

        // Hourly pattern
        EnterpriseSectionHeader(title: 'Hourly Pattern'),
        const SizedBox(height: 8),
        hourlyAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (hourly) => _barList(hourly, 'hour', 'count',
              const Color(0xFF6366F1),
              formatKey: (k) => '${k.toString().padLeft(2, '0')}:00'),
        ),
        const SizedBox(height: 16),

        // Gate performance
        EnterpriseSectionHeader(title: 'Gate Performance'),
        const SizedBox(height: 8),
        gateAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (gates) {
            if (gates.isEmpty) {
              return EnterprisePanel(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No gate data available',
                  style: DesignTypography.bodySmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
              );
            }
            return EnterprisePanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: gates.map((g) {
                  final gateName =
                      g['gateName']?.toString() ?? g['name']?.toString() ?? '';
                  final count = _toInt(g['count'] ?? g['events']);
                  final avgMin = _toDouble(
                      g['averageDurationMinutes'] ?? g['avgDuration']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.door_sliding_outlined,
                            size: 16, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            gateName,
                            style: DesignTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '$count events \u00b7 ${avgMin.round()} min avg',
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
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

  Widget _barList(
    List<Map<String, dynamic>> items,
    String keyField,
    String valueField,
    Color color, {
    String Function(dynamic)? formatKey,
  }) {
    if (items.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(14),
        child: Text(
          'No data available',
          style: DesignTypography.bodySmall
              .copyWith(color: DesignColors.textSecondary),
        ),
      );
    }

    final maxVal = items.fold<int>(
        0, (m, i) => _toInt(i[valueField]) > m ? _toInt(i[valueField]) : m);

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items.take(10).map((item) {
          final key = item[keyField];
          final val = _toInt(item[valueField]);
          final fraction = maxVal > 0 ? val / maxVal : 0.0;
          final label = formatKey != null
              ? formatKey(key)
              : key?.toString() ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label.length > 5 ? label.substring(label.length - 5) : label,
                    style: DesignTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 14,
                      backgroundColor: color.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$val',
                    style: DesignTypography.captionSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
