import 'package:flutter/material.dart';

import '../../../../../core/telemetry/telemetry_safe.dart';
import '../../../../../core/theme/design_tokens.dart';
import 'analytics_insight_card.dart';
import 'analytics_kpi_card.dart';

/// Business-growth executive block: health score, KPIs with trends,
/// smart insights, activation funnel with drop-offs, and next actions.
///
/// Designed to sit **below** [AnalyticsRoleAdoptionPanel] so admins first
/// see who uses the app, then how the business is performing.
class AnalyticsGrowthPanel extends StatelessWidget {
  const AnalyticsGrowthPanel({super.key, required this.growth});

  final Map<String, dynamic> growth;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final score = _toInt(growth['healthScore']);
    final periodDays = _toInt(growth['period']?['days']);
    final days = periodDays > 0 ? periodDays : 30;
    final kpis = telemetrySafeMapList(growth['kpis']);
    final insights = telemetrySafeMapList(growth['smartInsights']);
    final funnel = telemetrySafeMapList(growth['funnel']);
    final levers = telemetrySafeMapList(growth['growthLevers']);
    final pillars = telemetrySafeMap(growth['pillars']);

    final status = _scoreStatus(score);

    // Prefer actionable insights first.
    final orderedInsights = [...insights]..sort((a, b) {
      int rank(String? s) {
        switch (s) {
          case 'critical':
            return 0;
          case 'warning':
            return 1;
          case 'positive':
            return 2;
          default:
            return 3;
        }
      }

      return rank(a['severity']?.toString()).compareTo(rank(b['severity']?.toString()));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business growth',
          style: DesignTypography.headingM.copyWith(
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last $days days · Is the society activating, retaining, and completing key work?',
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        _HealthBanner(score: score, status: status),
        const SizedBox(height: 12),
        if (pillars.isNotEmpty) ...[
          _PillarStrip(pillars: pillars, days: days),
          const SizedBox(height: 14),
        ],
        Text(
          'Key performance',
          style: DesignTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Green = healthy · Amber = watch · Red = needs action. Trends vs previous $days days.',
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        AnalyticsKpiGrid(
          cards: kpis
              .where((k) => k['id']?.toString() != 'health_score')
              .map(
                (k) => AnalyticsKpiCard(
                  label: _kpiLabel(k),
                  displayValue: k['displayValue']?.toString() ?? '',
                  status: k['status']?.toString() ?? 'watch',
                  trend: k['trend']?.toString(),
                  growthPct:
                      k['growthPct'] == null ? null : _toInt(k['growthPct']),
                  hint: k['hint']?.toString(),
                ),
              )
              .toList(),
        ),
        if (orderedInsights.isNotEmpty) ...[
          const SizedBox(height: 18),
          SmartInsightsSection(insights: orderedInsights.take(5).toList()),
        ],
        if (funnel.length >= 2) ...[
          const SizedBox(height: 18),
          _ActivationFunnel(funnel: funnel),
        ],
        if (levers.isNotEmpty) ...[
          const SizedBox(height: 18),
          _NextActions(levers: levers.take(4).toList()),
        ],
      ],
    );
  }

  static ({String label, String meaning, Color color}) _scoreStatus(int score) {
    if (score >= 70) {
      return (
        label: 'Healthy',
        meaning: 'Activation, stickiness, retention, and reliability look solid.',
        color: DesignColors.success,
      );
    }
    if (score >= 45) {
      return (
        label: 'Needs attention',
        meaning: 'Some pillars are weak — check insights and next actions below.',
        color: DesignColors.warning,
      );
    }
    return (
      label: 'At risk',
      meaning: 'Low engagement or reliability — prioritise outreach and fixes.',
      color: DesignColors.error,
    );
  }

  /// Shorter, admin-friendly KPI names.
  static String _kpiLabel(Map<String, dynamic> k) {
    switch (k['id']?.toString()) {
      case 'activation_rate':
        return 'Ever used app';
      case 'active_rate':
        return 'Active this period';
      case 'stickiness':
        return 'Daily stickiness';
      case 'retention_d7':
        return '7-day return';
      case 'guard_success':
        return 'Gate flow success';
      case 'maintenance_payments':
        return 'Online payments';
      case 'pre_approvals':
        return 'Visitor pre-approvals';
      default:
        return k['label']?.toString() ?? '';
    }
  }
}

class _HealthBanner extends StatelessWidget {
  const _HealthBanner({required this.score, required this.status});

  final int score;
  final ({String label, String meaning, Color color}) status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: status.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: (score.clamp(0, 100)) / 100,
                    strokeWidth: 5,
                    backgroundColor: status.color.withValues(alpha: 0.15),
                    color: status.color,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Growth health · ${status.label}',
                  style: DesignTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.meaning,
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarStrip extends StatelessWidget {
  const _PillarStrip({required this.pillars, required this.days});

  final Map<String, dynamic> pillars;
  final int days;

  int _n(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final engagement = telemetrySafeMap(pillars['engagement']);
    final operations = telemetrySafeMap(pillars['operations']);
    final monetization = telemetrySafeMap(pillars['monetization']);
    final communication = telemetrySafeMap(pillars['communication']);

    final items = [
      _PillarItem(
        label: 'DAU',
        value: '${_n(engagement['dailyActiveUsers'])}',
        hint: 'Today',
      ),
      _PillarItem(
        label: 'MAU',
        value: '${_n(engagement['monthlyActiveUsers'])}',
        hint: '$days days',
      ),
      _PillarItem(
        label: 'Sessions',
        value: '${_n(operations['sessions'])}',
        hint: '$days days',
      ),
      _PillarItem(
        label: 'Payments',
        value: '${_n(monetization['maintenancePayments'])}',
        hint: 'Completed',
      ),
      _PillarItem(
        label: 'Pre-approvals',
        value: '${_n(communication['preApprovals'])}',
        hint: 'Visitors',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(width: 1, height: 36, color: DesignColors.borderLight),
              SizedBox(width: 72, child: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillarItem extends StatelessWidget {
  const _PillarItem({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: DesignTypography.body.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: DesignColors.textPrimary,
            ),
          ),
          Text(
            hint,
            style: DesignTypography.captionSmall.copyWith(
              fontSize: 9,
              color: DesignColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationFunnel extends StatelessWidget {
  const _ActivationFunnel({required this.funnel});

  final List<Map<String, dynamic>> funnel;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activation funnel',
          style: DesignTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Where people drop off before completing a key action in the app.',
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            border: Border.all(color: DesignColors.borderLight),
          ),
          child: Column(
            children: [
              for (var i = 0; i < funnel.length; i++) ...[
                _FunnelStage(
                  index: i + 1,
                  stage: funnel[i],
                ),
                if (i < funnel.length - 1) ...[
                  _FunnelDrop(
                    from: _toInt(funnel[i]['count']),
                    to: _toInt(funnel[i + 1]['count']),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FunnelStage extends StatelessWidget {
  const _FunnelStage({
    required this.index,
    required this.stage,
  });

  final int index;
  final Map<String, dynamic> stage;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final label = stage['stage']?.toString() ?? '';
    final count = _toInt(stage['count']);
    final pct = _toInt(stage['ratePct']);
    final widthFactor = (pct.clamp(0, 100)) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: DesignColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$pct%',
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: widthFactor,
            minHeight: 8,
            backgroundColor: DesignColors.borderLight,
            color: DesignColors.primary,
          ),
        ),
      ],
    );
  }
}

class _FunnelDrop extends StatelessWidget {
  const _FunnelDrop({required this.from, required this.to});

  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    if (from <= 0) return const SizedBox(height: 12);
    final lost = from - to;
    if (lost <= 0) return const SizedBox(height: 12);
    final lostPct = ((lost / from) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 30),
          Icon(Icons.arrow_downward_rounded, size: 14, color: DesignColors.error),
          const SizedBox(width: 4),
          Text(
            'Lost $lost ($lostPct%)',
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActions extends StatelessWidget {
  const _NextActions({required this.levers});

  final List<Map<String, dynamic>> levers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Do this next',
          style: DesignTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Low-adoption features — promote these to grow usage.',
          style: DesignTypography.captionSmall.copyWith(
            color: DesignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...levers.asMap().entries.map((e) {
          final i = e.key;
          final lever = e.value;
          final adoption = lever['adoptionPct'] ?? 0;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: BorderRadius.circular(DesignRadius.lg),
              border: Border.all(color: DesignColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DesignColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: DesignColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lever['label']?.toString() ?? '',
                        style: DesignTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lever['recommendation']?.toString() ?? '',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$adoption% of accounts used this · ${lever['count'] ?? 0} times',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
