import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/enterprise_ui.dart';

/// One bar in an [AnalyticsBarChart] — a short bottom-axis label plus its value.
class AnalyticsBarPoint {
  const AnalyticsBarPoint({required this.label, required this.value});

  final String label;
  final double value;
}

/// Shared enterprise bar chart used across the Analytics hub (replaces the
/// old ad-hoc "label + LinearProgressIndicator row" lists that several
/// analytics screens used instead of a real chart).
class AnalyticsBarChart extends StatelessWidget {
  const AnalyticsBarChart({
    super.key,
    required this.points,
    this.color,
    this.height = 170,
    this.emptyTitle = 'No data yet',
    this.emptySubtitle = 'Data will appear here once activity is recorded.',
    this.emptyIcon = Icons.show_chart_rounded,
  });

  final List<AnalyticsBarPoint> points;
  final Color? color;
  final double height;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return EnterprisePanel(
        padding: const EdgeInsets.all(16),
        child: EmptyStateWidget(
          icon: emptyIcon,
          title: emptyTitle,
          subtitle: emptySubtitle,
          iconColor: color ?? DesignColors.primary,
        ),
      );
    }

    final barColor = color ?? DesignColors.primary;
    var maxY = 1.0;
    for (final p in points) {
      if (p.value > maxY) maxY = p.value;
    }
    // Whole-number step, and a top that lands on a step, so axis labels never repeat.
    final step = maxY > 4 ? (maxY / 4).ceilToDouble() : 1.0;
    final topY = step * ((maxY * 1.15) / step).ceilToDouble();

    final groups = <BarChartGroupData>[
      for (var i = 0; i < points.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: points[i].value,
              width: points.length > 14 ? 8 : 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              gradient: LinearGradient(
                colors: [barColor, barColor.withValues(alpha: 0.6)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
        ),
    ];

    return EnterprisePanel(
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: topY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step,
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
                  interval: step,
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
                    if (i < 0 || i >= points.length) return const SizedBox.shrink();
                    // Thin labels out when there are many bars so they don't collide.
                    final step = (points.length / 8).ceil().clamp(1, points.length);
                    if (step > 1 && i % step != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        points[i].label,
                        style: DesignTypography.captionSmall.copyWith(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => DesignColors.textPrimary,
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  '${points[group.x].label}\n${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                ),
              ),
            ),
            barGroups: groups,
          ),
        ),
      ),
    );
  }
}
