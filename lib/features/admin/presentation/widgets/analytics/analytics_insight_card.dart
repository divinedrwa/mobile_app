import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/enterprise_ui.dart';

/// Single auto-generated, plain-language insight ("Active users grew 12% vs
/// last period"). Severity drives the icon/accent color so admins can scan
/// a list and immediately spot what needs attention.
class AnalyticsInsightCard extends StatelessWidget {
  const AnalyticsInsightCard({super.key, required this.text, required this.severity});

  final String text;

  /// 'positive' | 'warning' | 'critical' | 'info'
  final String severity;

  ({Color color, IconData icon}) _style() {
    switch (severity) {
      case 'positive':
        return (color: DesignColors.success, icon: Icons.trending_up_rounded);
      case 'warning':
        return (color: DesignColors.warning, icon: Icons.warning_amber_rounded);
      case 'critical':
        return (color: DesignColors.error, icon: Icons.error_outline_rounded);
      default:
        return (color: DesignColors.primary, icon: Icons.lightbulb_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: s.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 18, color: s.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section wrapper rendering a list of insight maps from the backend
/// (`{id, severity, text}`) with a shared header + empty state.
class SmartInsightsSection extends StatelessWidget {
  const SmartInsightsSection({super.key, required this.insights});

  final List<Map<String, dynamic>> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: DesignColors.primary),
            const SizedBox(width: 6),
            const Expanded(child: EnterpriseSectionHeader(title: 'Smart insights')),
          ],
        ),
        const SizedBox(height: 8),
        ...insights.map(
          (i) => AnalyticsInsightCard(
            text: i['text']?.toString() ?? '',
            severity: i['severity']?.toString() ?? 'info',
          ),
        ),
      ],
    );
  }
}
