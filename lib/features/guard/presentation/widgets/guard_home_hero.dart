import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Compact gate header — greeting, gate line, on-duty chip, notifications (less height than legacy hero).
class GuardHomeHero extends StatelessWidget {
  const GuardHomeHero({
    super.key,
    required this.guardName,
    this.gateName,
    this.gateLocation,
    this.onNotificationsTap,
  });

  final String guardName;
  final String? gateName;
  final String? gateLocation;
  final VoidCallback? onNotificationsTap;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gateLine = [
      if (gateName != null && gateName!.trim().isNotEmpty) gateName!.trim(),
      if (gateLocation != null && gateLocation!.trim().isNotEmpty)
        gateLocation!.trim(),
    ].join(' · ');

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
      shadowColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    GuardTokens.darkCard,
                    GuardTokens.darkSurface,
                  ]
                : [
                    GuardTokens.guardAccentDeep,
                    const Color(0xFF2563EB),
                    GuardTokens.guardAccent,
                  ],
          ),
          boxShadow: GuardTokens.softCardShadow(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor:
                    Colors.white.withValues(alpha: isDark ? 0.12 : 0.2),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${_greeting()}, $guardName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.35,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _OnDutyPill(isDark: isDark),
                      ],
                    ),
                    if (gateLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        gateLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Gate duty',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onNotificationsTap != null)
                IconButton(
                  tooltip: 'Notifications',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onPressed: onNotificationsTap,
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnDutyPill extends StatelessWidget {
  const _OnDutyPill({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 13,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 4),
          Text(
            'On duty',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
