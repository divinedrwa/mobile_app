import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';

/// Visual state of the maintenance hero. Drives gradient + badge + icon.
enum MaintenanceHeroKind { paid, due, overdue, upcoming, excluded }

/// Large status banner at the top of the maintenance hub. Shows — at a
/// glance — the cycle name, whether anything is owed, the headline amount,
/// the next/upcoming due date, and the cycle window. A decorative receipt
/// illustration sits on the right (drawn, not an asset).
class MaintenanceHeroCard extends StatelessWidget {
  const MaintenanceHeroCard({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.badgeLabel,
    this.primaryLabel,
    this.primaryValue,
    this.secondaryLabel,
    this.secondaryValue,
    this.windowText,
    this.onViewDetails,
  });

  final MaintenanceHeroKind kind;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final String? primaryLabel;
  final String? primaryValue;
  final String? secondaryLabel;
  final String? secondaryValue;
  final String? windowText;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(kind);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: palette.gradient.last.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative receipt — clipped to the card corners.
          Positioned(
            right: -6,
            top: 10,
            bottom: 10,
            child: _ReceiptArt(accent: palette.gradient.last),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(palette.icon,
                          color: palette.gradient.last, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badgeLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeLabel!.toUpperCase(),
                                style: DesignTypography.captionSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reserve room for the decorative receipt so the title /
                    // subtitle never run underneath and clip.
                    const SizedBox(width: 84),
                  ],
                ),
                if (primaryValue != null || secondaryValue != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      if (primaryValue != null)
                        Expanded(
                          child: _MetricBlock(
                            label: primaryLabel ?? '',
                            value: primaryValue!,
                            emphasize: true,
                          ),
                        ),
                      if (secondaryValue != null)
                        Expanded(
                          child: _MetricBlock(
                            label: secondaryLabel ?? '',
                            value: secondaryValue!,
                            leadingIcon: Icons.event_outlined,
                          ),
                        ),
                    ],
                  ),
                ],
                if (windowText != null || onViewDetails != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22)),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (windowText != null) ...[
                          Icon(Icons.schedule,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.85)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              windowText!,
                              style: DesignTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (onViewDetails != null)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: onViewDetails,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Row(
                                children: [
                                  Text(
                                    'View details',
                                    style:
                                        DesignTypography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      size: 16, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(
          begin: DesignAnimations.slideSubtle,
          end: 0,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.leadingIcon,
  });

  final String label;
  final String value;
  final bool emphasize;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: DesignTypography.captionSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.78),
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon,
                  size: 15, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: emphasize ? 22 : 15,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stylised receipt illustration (drawn, no asset). A tilted white "paper"
/// with faint text lines and a check seal — echoes the design reference.
class _ReceiptArt extends StatelessWidget {
  const _ReceiptArt({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.95,
      child: Transform.rotate(
        angle: 0.06,
        child: SizedBox(
          width: 96,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 78,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in const [0.9, 0.6, 0.8, 0.5]) ...[
                      _line(w),
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 4,
                bottom: 6,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(double widthFactor) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
}

class _HeroPalette {
  const _HeroPalette({required this.gradient, required this.icon});
  final List<Color> gradient;
  final IconData icon;
}

_HeroPalette _palette(MaintenanceHeroKind kind) {
  switch (kind) {
    case MaintenanceHeroKind.paid:
      return const _HeroPalette(
        gradient: [Color(0xFF34A853), Color(0xFF1E7A3D)],
        icon: Icons.check_rounded,
      );
    case MaintenanceHeroKind.due:
      return _HeroPalette(
        gradient: [DesignColors.primaryLight, DesignColors.primaryDark],
        icon: Icons.account_balance_wallet_outlined,
      );
    case MaintenanceHeroKind.overdue:
      return const _HeroPalette(
        gradient: [Color(0xFFF97316), Color(0xFFC2410C)],
        icon: Icons.warning_amber_rounded,
      );
    case MaintenanceHeroKind.upcoming:
      return const _HeroPalette(
        gradient: [Color(0xFF64748B), Color(0xFF475569)],
        icon: Icons.event_available_outlined,
      );
    case MaintenanceHeroKind.excluded:
      return _HeroPalette(
        gradient: [DesignColors.primary, DesignColors.primaryDark],
        icon: Icons.info_outline,
      );
  }
}
