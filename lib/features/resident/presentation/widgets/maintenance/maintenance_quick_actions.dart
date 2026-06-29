import 'package:flutter/material.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
// Colors is part of flutter/material.dart — no extra import needed.

/// Horizontal row of icon shortcuts under the hero. Each tile has an icon,
/// a label, and an optional status sub-label (e.g. "No pending",
/// "5 payments"). Mirrors the quick-actions strip in the design reference.
class MaintenanceQuickActions extends StatelessWidget {
  const MaintenanceQuickActions({
    super.key,
    required this.actions,
  });

  final List<MaintenanceQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(child: _Tile(action: actions[i])),
            if (i < actions.length - 1)
              Container(
                width: 1,
                height: 56,
                margin: EdgeInsets.symmetric(vertical: 8),
                color: DesignColors.borderLight,
              ),
          ],
        ],
      ),
    );
  }
}

class MaintenanceQuickAction {
  const MaintenanceQuickAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
    this.subLabel,
    this.subTone,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;
  final String? subLabel;
  final Color? subTone;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});
  final MaintenanceQuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DesignRadius.md),
      onTap: action.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: action.tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: action.tone, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DesignTypography.caption.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            if (action.subLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                action.subLabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTypography.captionSmall.copyWith(
                  color: action.subTone ?? DesignColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
