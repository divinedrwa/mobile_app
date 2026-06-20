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

  void _setPeriod(int days) {
    ref.read(adminWaterAnalyticsDaysProvider.notifier).state = days;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(adminWaterAnalyticsDaysProvider);
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
          data: (overview) => _buildBody(overview, period),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> overview, int period) {
    final dailyAsync = ref.watch(adminWaterAnalyticsDailyProvider);
    final hourlyAsync = ref.watch(adminWaterAnalyticsHourlyProvider);
    final gateAsync = ref.watch(adminWaterAnalyticsGateProvider);

    final totalEvents = _toInt(overview['totalEvents']);
    final onEvents = _toInt(overview['onEvents']);
    final offEvents = _toInt(overview['offEvents']);
    final cycles = _toInt(overview['completedCycles']);
    final avgDuration = _toDouble(overview['averageDurationMinutes']);
    final totalGates = _toInt(overview['totalGates']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Row(
          children: [
            _periodChip('7 days', 7, period),
            const SizedBox(width: 8),
            _periodChip('30 days', 30, period),
          ],
        ),
        const SizedBox(height: 12),
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
                    'Water Supply ($period days)',
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
                  _overviewStat('Total', '$totalEvents'),
                  _overviewStat('ON', '$onEvents'),
                  _overviewStat('OFF', '$offEvents'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _overviewStat('Cycles', '$cycles'),
                  _overviewStat('Avg', '${avgDuration.round()} min'),
                  _overviewStat('Gates', '$totalGates'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Daily usage (ON + OFF per day)'),
        const SizedBox(height: 8),
        dailyAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (daily) {
            final activeDays = daily
                .where((d) => _toInt(d['totalEvents']) > 0)
                .toList();
            return activeDays.isEmpty
                ? _emptyPanel('No water toggles in this period')
                : _dailyList(activeDays);
          },
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Peak hours (last 30 days)'),
        const SizedBox(height: 8),
        hourlyAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (hourly) => _hourlyList(hourly),
        ),
        const SizedBox(height: 16),
        EnterpriseSectionHeader(title: 'Gate performance (last 30 days)'),
        const SizedBox(height: 8),
        gateAsync.when(
          loading: () => ShimmerWrap(
              child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg)),
          error: (_, __) => const SizedBox.shrink(),
          data: (gates) => _gateList(gates),
        ),
      ],
    );
  }

  Widget _periodChip(String label, int days, int selected) {
    final isSelected = selected == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setPeriod(days),
      selectedColor: const Color(0xFF0EA5E9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      showCheckmark: false,
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

  Widget _dailyList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _emptyPanel('No daily water events in this period');
    }

    final sorted = [...items]
      ..sort((a, b) => (a['date'] ?? '').toString().compareTo(
            (b['date'] ?? '').toString(),
          ));

    final maxVal = sorted.fold<int>(
      0,
      (m, i) => _toInt(i['totalEvents']) > m ? _toInt(i['totalEvents']) : m,
    );

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: sorted.map((item) {
          final label =
              item['displayDate']?.toString() ?? item['date']?.toString() ?? '';
          final total = _toInt(item['totalEvents']);
          final on = _toInt(item['onCount']);
          final off = _toInt(item['offCount']);
          final fraction = maxVal > 0 ? total / maxVal : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        label,
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
                          backgroundColor:
                              const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$total',
                        style: DesignTypography.captionSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 56, top: 2),
                  child: Text(
                    'ON $on · OFF $off',
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _hourlyList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return _emptyPanel('No hourly pattern data');
    }

    final maxVal = items.fold<int>(
      0,
      (m, i) => _toInt(i['totalEvents']) > m ? _toInt(i['totalEvents']) : m,
    );

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: items.map((item) {
          final label = item['label']?.toString() ??
              '${item['hour']?.toString().padLeft(2, '0')}:00';
          final total = _toInt(item['totalEvents']);
          final on = _toInt(item['onCount']);
          final off = _toInt(item['offCount']);
          final fraction = maxVal > 0 ? total / maxVal : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
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
                      backgroundColor:
                          const Color(0xFF6366F1).withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$total',
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

  Widget _gateList(List<Map<String, dynamic>> gates) {
    if (gates.isEmpty) {
      return _emptyPanel('No gate water events in this period');
    }

    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: gates.map((g) {
          final gateName =
              g['gateName']?.toString() ?? g['name']?.toString() ?? '';
          final total = _toInt(g['totalEvents'] ?? g['count'] ?? g['events']);
          final on = _toInt(g['onEvents'] ?? g['onCount']);
          final off = _toInt(g['offEvents'] ?? g['offCount']);
          final avgMin = _toDouble(
            g['avgDurationMinutes'] ?? g['averageDurationMinutes'],
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.door_sliding_outlined,
                    size: 16, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gateName,
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total events · ON $on · OFF $off · ${avgMin.round()} min avg',
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyPanel(String message) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: DesignTypography.bodySmall
            .copyWith(color: DesignColors.textSecondary),
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
