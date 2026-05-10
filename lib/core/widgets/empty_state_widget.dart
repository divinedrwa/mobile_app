import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/design_animations.dart';
import '../theme/design_tokens.dart';

/// Warm, consistent empty state used across all screens.
///
/// Shows a tinted icon circle, title, subtitle, and optional action button.
/// Entrance animation: fadeIn + scale from 0.92 for a gentle reveal.
///
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.inbox_rounded,
///   title: "You're all caught up!",
///   subtitle: 'No new notifications right now.',
///   actionLabel: 'Refresh',
///   onAction: () => ref.invalidate(provider),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.actionLabel,
    this.onAction,
  });

  /// The icon displayed in the tinted circle.
  final IconData icon;

  /// Primary message (bold).
  final String title;

  /// Secondary helper text.
  final String subtitle;

  /// Override icon circle tint. Defaults to [DesignColors.primary].
  final Color? iconColor;

  /// If non-null, a CTA button is shown below the text.
  final String? actionLabel;

  /// Callback for the CTA button.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? DesignColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DesignSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // -- Icon circle --
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: tint.withValues(alpha: 0.7)),
            ),

            const SizedBox(height: DesignSpacing.xl),

            // -- Title --
            Text(
              title,
              textAlign: TextAlign.center,
              style: DesignTypography.headingM.copyWith(
                color: DesignColors.textPrimary,
              ),
            ),

            const SizedBox(height: DesignSpacing.sm),

            // -- Subtitle --
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textTertiary,
                height: 1.5,
              ),
            ),

            // -- Action button --
            if (actionLabel != null) ...[
              const SizedBox(height: DesignSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  foregroundColor: DesignColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSpacing.xl,
                    vertical: DesignSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance)
        .scaleXY(
          begin: 0.92,
          end: 1.0,
          duration: DesignAnimations.durationEmphasis,
          curve: DesignAnimations.curveEntrance,
        );
  }
}
