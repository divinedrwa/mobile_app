import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';

/// Shared enterprise-style KPI card: value, label, status color, and an
/// optional trend arrow comparing against the previous period. Used across
/// the Analytics hub so every KPI looks and behaves consistently.
class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    super.key,
    required this.label,
    required this.displayValue,
    this.status = 'watch',
    this.trend,
    this.growthPct,
    this.hint,
    this.dark = false,
    this.onTap,
  });

  final String label;
  final String displayValue;

  /// 'good' | 'watch' | 'critical'
  final String status;

  /// 'up' | 'down' | 'flat' — omit to hide the trend badge entirely.
  final String? trend;
  final int? growthPct;
  final String? hint;

  /// Use the light-on-dark palette when placed on a gradient hero card.
  final bool dark;
  final VoidCallback? onTap;

  Color _statusColor() {
    switch (status) {
      case 'good':
        return DesignColors.success;
      case 'critical':
        return DesignColors.error;
      default:
        return DesignColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final textColor = dark ? Colors.white : DesignColors.textPrimary;
    final subTextColor = dark ? Colors.white70 : DesignColors.textSecondary;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.12) : DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(
          color: dark
              ? statusColor.withValues(alpha: 0.45)
              : DesignColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.captionSmall.copyWith(
              color: subTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          if (trend != null && growthPct != null) ...[
            const SizedBox(height: 6),
            _trendBadge(dark),
          ],
        ],
      ),
    );

    if (hint == null && onTap == null) return card;

    return Tooltip(
      message: hint ?? '',
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(DesignRadius.md),
              onTap: onTap,
              child: card,
            )
          : card,
    );
  }

  Widget _trendBadge(bool dark) {
    final isUp = trend == 'up';
    final isFlat = trend == 'flat';
    final color = isFlat
        ? (dark ? Colors.white60 : DesignColors.textSecondary)
        : (isUp ? DesignColors.success : DesignColors.error);
    final icon = isFlat
        ? Icons.remove_rounded
        : (isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          '${growthPct!.abs()}% vs prev.',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

/// Responsive grid of [AnalyticsKpiCard]s — 2 columns on phones.
class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({super.key, required this.cards});

  final List<AnalyticsKpiCard> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: cards,
    );
  }
}
