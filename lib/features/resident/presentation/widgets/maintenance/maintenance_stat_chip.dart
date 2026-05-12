import 'package:flutter/material.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';

/// Compact stat tile used in a horizontal row under the hero card.
/// Three of these fit edge-to-edge on a phone width without crowding.
class MaintenanceStatChip extends StatelessWidget {
  const MaintenanceStatChip({
    super.key,
    required this.label,
    required this.value,
    this.tone = MaintenanceStatTone.neutral,
    this.icon,
  });

  final String label;
  final String value;
  final MaintenanceStatTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Icon(icon, size: 14, color: c.fg),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            label,
            style: DesignTypography.caption.copyWith(
              color: DesignColors.textTertiary,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: DesignTypography.bodyMedium.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum MaintenanceStatTone { neutral, success, warning, info }

class _ToneColors {
  const _ToneColors(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

_ToneColors _toneColors(MaintenanceStatTone tone) {
  switch (tone) {
    case MaintenanceStatTone.neutral:
      return const _ToneColors(DesignColors.surfaceSoft, DesignColors.textSecondary);
    case MaintenanceStatTone.success:
      return _ToneColors(DesignColors.success.withValues(alpha: 0.12), DesignColors.success);
    case MaintenanceStatTone.warning:
      return _ToneColors(DesignColors.warning.withValues(alpha: 0.12), DesignColors.warning);
    case MaintenanceStatTone.info:
      return _ToneColors(DesignColors.primary.withValues(alpha: 0.10), DesignColors.primary);
  }
}
