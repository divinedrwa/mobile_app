import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_counter.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';

/// Compact “today” metrics — dense 2×2 grid inside one card (less vertical space than tall tiles).
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
    final scheme = Theme.of(context).colorScheme;
    final outerRadius = BorderRadius.circular(GuardTokens.radiusCard + 2);
    final cardBg = isDark ? GuardTokens.darkCard : Colors.white;
    final innerTint = isDark
        ? GuardTokens.darkSurface.withValues(alpha: 0.55)
        : GuardTokens.guardAccent.withValues(alpha: 0.04);
    final borderColor =
        isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Today's summary",
                            style: GuardTokens.headingStyle(context).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (onOpenDetail != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: GuardTokens.captionStyle(context).copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.primary,
                                size: 22,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: innerTint,
                        borderRadius:
                            BorderRadius.circular(GuardTokens.radiusCard),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Column(
                        children: [
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
                              ],
                            ),
                          ),
                          Divider(height: 1, thickness: 1, color: borderColor),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                ],
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCounter(
                  value: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.05,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GuardTokens.captionStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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
