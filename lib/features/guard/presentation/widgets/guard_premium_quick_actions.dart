import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Compact quick actions — neutral tiles with accent icon chips (less visual weight).
class GuardPremiumQuickActions extends StatelessWidget {
  const GuardPremiumQuickActions({
    super.key,
    required this.onAddVisitor,
    required this.onScanQr,
    required this.onDelivery,
    required this.onEmergency,
    required this.onPreApprovedVisitors,
    required this.onPatrol,
  });

  final VoidCallback onAddVisitor;
  final VoidCallback onScanQr;
  final VoidCallback onDelivery;
  final VoidCallback onEmergency;
  final VoidCallback onPreApprovedVisitors;
  final VoidCallback onPatrol;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick actions',
          style: GuardTokens.headingStyle(context).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add visitor',
                subtitle: 'Guest or staff',
                accent: GuardTokens.guardAccentDeep,
                isDark: isDark,
                onTap: onAddVisitor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan QR',
                subtitle: 'Fast check-in',
                accent: const Color(0xFF6D28D9),
                isDark: isDark,
                onTap: onScanQr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.inventory_2_rounded,
                label: 'Delivery',
                subtitle: 'Parcel / courier',
                accent: GuardTokens.success,
                isDark: isDark,
                onTap: onDelivery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                icon: Icons.emergency_rounded,
                label: 'Emergency',
                subtitle: 'SOS broadcast',
                accent: GuardTokens.dangerBrand,
                isDark: isDark,
                onTap: onEmergency,
                emphasize: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.event_available_rounded,
                label: 'Pre-approved',
                subtitle: 'Expected guests',
                accent: const Color(0xFFEA580C),
                isDark: isDark,
                onTap: onPreApprovedVisitors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickTile(
                icon: Icons.shield_rounded,
                label: 'Patrol',
                subtitle: 'Start a round',
                accent: const Color(0xFF0891B2),
                isDark: isDark,
                onTap: onPatrol,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.isDark,
    required this.onTap,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final bool emphasize;

  static List<BoxShadow>? _tileShadow(BuildContext context, bool isDark) {
    if (isDark) return null;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 1),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = isDark ? GuardTokens.darkCard : Colors.white;
    final borderColor = emphasize
        ? GuardTokens.dangerBrand.withValues(alpha: 0.35)
        : (isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle);

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
            color: surface,
            border: Border.all(
              color: borderColor,
              width: emphasize ? 1.25 : 1,
            ),
            boxShadow: _tileShadow(context, isDark),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.11),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 21, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GuardTokens.captionStyle(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: GuardTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return tile;
  }
}
