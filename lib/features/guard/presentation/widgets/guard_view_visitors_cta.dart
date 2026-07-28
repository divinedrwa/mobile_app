import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// Primary navigation to the active visitors list — sits above Quick actions.
class GuardViewVisitorsCta extends ConsumerWidget {
  const GuardViewVisitorsCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(guardLiveQueueCountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final needsAction = counts?.needsGuardAction ?? 0;
    final accentBorder = needsAction > 0
        ? GuardTokens.warning.withValues(alpha: isDark ? 0.55 : 0.45)
        : (isDark
            ? GuardTokens.darkBorder
            : GuardTokens.guardAccent.withValues(alpha: 0.22));

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
                      needsAction > 0
                          ? GuardTokens.warning.withValues(alpha: 0.08)
                          : GuardTokens.guardAccent.withValues(alpha: 0.08),
                      scheme.surface,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: accentBorder),
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
                Stack(
                  clipBehavior: Clip.none,
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
                        color:
                            isDark ? Colors.white : GuardTokens.guardAccentDeep,
                        size: 24,
                      ),
                    ),
                    if (needsAction > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: _CountBadge(
                          count: needsAction,
                          tone: GuardTokens.warning,
                        ),
                      ),
                  ],
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
                        counts?.dashboardSubtitle() ??
                            'On-site guests, approvals, pre-approved & exits',
                        style: GuardTokens.captionStyle(context).copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: needsAction > 0
                              ? GuardTokens.warning
                              : GuardTokens.textSecondary,
                        ),
                      ),
                      if (counts != null && counts.onPremises > 0) ...[
                        const SizedBox(height: 8),
                        _LiveCountChips(counts: counts),
                      ],
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

class _LiveCountChips extends StatelessWidget {
  const _LiveCountChips({required this.counts});

  final GuardLiveQueueCounts counts;

  @override
  Widget build(BuildContext context) {
    final chips = <({String label, Color color})>[];
    if (counts.onPremises > 0) {
      chips.add((
        label: '${counts.onPremises} inside',
        color: GuardTokens.success,
      ));
    }
    if (counts.readyToAdmit > 0) {
      chips.add((
        label: '${counts.readyToAdmit} admit',
        color: GuardTokens.guardAccentDeep,
      ));
    }
    if (counts.preApproved > 0) {
      chips.add((
        label: '${counts.preApproved} pre-approved',
        color: const Color(0xFF6D28D9),
      ));
    }
    if (counts.awaitingResident > 0) {
      chips.add((
        label: '${counts.awaitingResident} pending',
        color: GuardTokens.warning,
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                c.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: c.color,
                  height: 1.1,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.tone});

  final int count;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
