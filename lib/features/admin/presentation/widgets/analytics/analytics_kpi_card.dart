import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';

/// Shared KPI card: value, label, status colour, an optional change vs the
/// previous period and a short visible hint. Used across the Analytics hub so
/// every KPI looks and behaves the same.
class AnalyticsKpiCard extends StatelessWidget {
  const AnalyticsKpiCard({
    super.key,
    required this.label,
    required this.displayValue,
    this.status = 'watch',
    this.trend,
    this.growthPct,
    this.deltaLabel,
    this.lowerIsBetter = false,
    this.hint,
    this.dark = false,
    this.onTap,
  });

  final String label;
  final String displayValue;

  /// 'good' | 'watch' | 'critical' | 'neutral'
  final String status;

  /// 'up' | 'down' | 'flat' — omit to hide the change line.
  final String? trend;
  final int? growthPct;

  /// Server-formatted change, e.g. "+12 pts" or "−40%" (preferred over [growthPct]).
  final String? deltaLabel;

  /// Up is bad (e.g. errors): flips the change colour.
  final bool lowerIsBetter;
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
      case 'neutral':
        return DesignColors.textSecondary;
      default:
        return DesignColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final valueColor = dark
        ? Colors.white
        : (status == 'neutral' ? DesignColors.textPrimary : statusColor);
    final subTextColor = dark ? Colors.white70 : DesignColors.textSecondary;
    final showDelta = trend != null && (deltaLabel != null || growthPct != null);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.12) : DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.md),
        border: Border.all(
          color: dark ? statusColor.withValues(alpha: 0.45) : DesignColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTypography.captionSmall.copyWith(
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              displayValue,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (showDelta) ...[
            const SizedBox(height: 4),
            _changeLine(dark),
          ],
          if (hint != null && hint!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: DesignTypography.captionSmall.copyWith(
                color: dark ? Colors.white60 : DesignColors.textTertiary,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(DesignRadius.md),
      onTap: onTap,
      child: card,
    );
  }

  Widget _changeLine(bool dark) {
    final isUp = trend == 'up';
    final isFlat = trend == 'flat';
    final good = lowerIsBetter ? !isUp : isUp;
    final color = isFlat
        ? (dark ? Colors.white60 : DesignColors.textSecondary)
        : (good ? DesignColors.success : DesignColors.error);
    final icon = isFlat
        ? Icons.remove_rounded
        : (isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);
    final text = deltaLabel ?? '${growthPct!.abs()}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            isFlat ? 'No change' : '$text vs before',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

/// Two-column KPI grid whose rows size to their tallest card (no empty space).
class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 8),
              Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 8));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
