import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Primary navigation to the active visitors list — sits above Quick actions.
class GuardViewVisitorsCta extends StatelessWidget {
  const GuardViewVisitorsCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      GuardTokens.guardAccentDeep.withValues(alpha: 0.35),
                      GuardTokens.darkCard,
                    ]
                  : [
                      GuardTokens.guardAccent.withValues(alpha: 0.08),
                      scheme.surface,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isDark
                  ? GuardTokens.darkBorder
                  : GuardTokens.guardAccent.withValues(alpha: 0.22),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? GuardTokens.guardAccent.withValues(alpha: 0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: GuardTokens.guardAccent.withValues(alpha: 0.35),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.groups_rounded,
                    color: isDark ? Colors.white : GuardTokens.guardAccentDeep,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View visitors',
                        style: GuardTokens.headingStyle(context).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'On-site guests, approvals, pre-approved & exits',
                        style: GuardTokens.captionStyle(context).copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: GuardTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: GuardTokens.textSecondary.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
