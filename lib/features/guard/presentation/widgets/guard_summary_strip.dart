import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_counter.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';

/// Compact "today" metrics — dense 2×2 grid inside one card (less vertical space than tall tiles).
class GuardSummaryStrip extends StatelessWidget {
  const GuardSummaryStrip({
    super.key,
    required this.stats,
    this.onOpenDetail,
  });

  final GuardTodayStats stats;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerRadius = BorderRadius.circular(GuardTokens.radiusCard + 2);
    final cardBg = isDark ? GuardTokens.darkCard : Colors.white;
    final borderColor =
        isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle;

    return Material(
      color: Colors.transparent,
      borderRadius: outerRadius,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: outerRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: outerRadius,
            color: cardBg,
            border: Border.all(color: borderColor),
            boxShadow: isDark ? null : GuardTokens.softCardShadow(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Today's overview",
                        style: GuardTokens.headingStyle(context).copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (onOpenDetail != null)
                      Text(
                        'Details →',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? GuardTokens.guardAccent
                              : GuardTokens.guardAccentDeep,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: borderColor),
              // Stat cells
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SummaryCell(
                        label: 'Visitors',
                        value: stats.visitors,
                        icon: Icons.groups_rounded,
                        accent: GuardTokens.guardAccent,
                        isDark: isDark,
                      ),
                    ),
                    _VLine(color: borderColor),
                    Expanded(
                      child: _SummaryCell(
                        label: 'Deliveries',
                        value: stats.parcels,
                        icon: Icons.local_shipping_outlined,
                        accent: GuardTokens.success,
                        isDark: isDark,
                      ),
                    ),
                    _VLine(color: borderColor),
                    Expanded(
                      child: _SummaryCell(
                        label: 'Patrols',
                        value: stats.patrols,
                        icon: Icons.directions_walk_rounded,
                        accent: const Color(0xFF6366F1),
                        isDark: isDark,
                      ),
                    ),
                    _VLine(color: borderColor),
                    Expanded(
                      child: _SummaryCell(
                        label: 'Incidents',
                        value: stats.incidents,
                        icon: Icons.shield_rounded,
                        accent: GuardTokens.warning,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color.withValues(alpha: 0.65));
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 5),
          AnimatedCounter(
            value: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GuardTokens.captionStyle(context).copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
