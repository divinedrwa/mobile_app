import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';

/// Hero card at the top of the maintenance hub. Tells the resident — at a
/// glance — what they owe and whether anything needs action right now.
///
/// The gradient and accent colour come from [MaintenanceStatusKind] so the
/// state is communicated visually without reading any text. We deliberately
/// avoid Material Banner / SnackBar patterns here: the card needs to live
/// inline as the first scrollable element, not float over content.
class MaintenanceStatusCard extends StatelessWidget {
  const MaintenanceStatusCard({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.amountLabel,
    this.amountValue,
    this.actionLabel,
    this.onAction,
    this.busy = false,
    this.dueDate,
  });

  final MaintenanceStatusKind kind;
  final String title;
  final String subtitle;
  final String? amountLabel;
  final String? amountValue;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final String? dueDate;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: palette.gradient.last.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(DesignRadius.md),
                ),
                child: Icon(palette.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DesignTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: DesignTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (amountValue != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (amountLabel != null)
              Text(
                amountLabel!.toUpperCase(),
                style: DesignTypography.captionSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              amountValue!,
              style: DesignTypography.headingXL.copyWith(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ],
          if (dueDate != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  dueDate!,
                  style: DesignTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: palette.gradient.last,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                  textStyle: DesignTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  elevation: 0,
                ),
                child: busy
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: palette.gradient.last,
                        ),
                      )
                    : Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: DesignAnimations.durationEntrance).slideY(begin: DesignAnimations.slideSubtle, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

enum MaintenanceStatusKind {
  paid,
  due,
  overdue,
  upcoming,
  excluded,
}

class _Palette {
  const _Palette({required this.gradient, required this.icon});
  final List<Color> gradient;
  final IconData icon;
}

_Palette _palette(MaintenanceStatusKind kind) {
  switch (kind) {
    case MaintenanceStatusKind.paid:
      return const _Palette(
        gradient: [Color(0xFF22C55E), Color(0xFF15803D)],
        icon: Icons.check_circle_outline,
      );
    case MaintenanceStatusKind.due:
      return _Palette(
        gradient: [DesignColors.primaryLight, DesignColors.primaryDark],
        icon: Icons.account_balance_wallet_outlined,
      );
    case MaintenanceStatusKind.overdue:
      return const _Palette(
        gradient: [Color(0xFFF97316), Color(0xFFC2410C)],
        icon: Icons.warning_amber_rounded,
      );
    case MaintenanceStatusKind.upcoming:
      return const _Palette(
        gradient: [Color(0xFF94A3B8), Color(0xFF475569)],
        icon: Icons.event_available_outlined,
      );
    case MaintenanceStatusKind.excluded:
      return _Palette(
        gradient: [DesignColors.primary, DesignColors.primaryDark],
        icon: Icons.info_outline,
      );
  }
}
