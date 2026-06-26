import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Step indicator + title stack for multi-step resident flows.
class DivineFlowStepHeader extends StatelessWidget {
  const DivineFlowStepHeader({
    super.key,
    required this.currentStep,
    required this.stepCount,
    required this.title,
    this.subtitle,
  });

  final int currentStep;
  final int stepCount;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final progress = stepCount <= 0 ? 0.0 : (currentStep + 1) / stepCount;
    final stepLabel = 'Step ${currentStep + 1} of $stepCount';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignSpacing.screenPaddingH,
        DesignSpacing.sm,
        DesignSpacing.screenPaddingH,
        DesignSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stepLabel,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.textTertiary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: DesignSpacing.sm),
          ClipRRect(
            borderRadius: DesignRadius.borderFull,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: DesignColors.surfaceSoft,
              color: DesignColors.primary,
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          Text(
            title,
            style: DesignTypography.headingM,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: DesignSpacing.xs),
            Text(
              subtitle!,
              style: DesignTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Sticky bottom actions for step flows — secondary left, primary right (expanded).
class DivineFlowBottomBar extends StatelessWidget {
  const DivineFlowBottomBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.showLeadingAction = true,
    this.leadingLabel,
    this.onLeading,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool showLeadingAction;
  final String? leadingLabel;
  final VoidCallback? onLeading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: DesignColors.surface,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          border: Border(
            top: BorderSide(color: DesignColors.borderLight.withValues(alpha: 0.9)),
          ),
          boxShadow: DesignElevation.sm,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(
            left: DesignSpacing.screenPaddingH,
            right: DesignSpacing.screenPaddingH,
            bottom: DesignSpacing.sm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: DesignSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showLeadingAction && leadingLabel != null) ...[
                  OutlinedButton(
                    onPressed: primaryLoading ? null : onLeading,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignColors.textPrimary,
                      side: BorderSide(color: DesignColors.border, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSpacing.lg,
                        vertical: DesignSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignRadius.borderMD,
                      ),
                    ),
                    child: Text(
                      leadingLabel!,
                      style: DesignTypography.label.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignSpacing.md),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: primaryLoading ? null : onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: DesignColors.tertiary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignSpacing.md + 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignRadius.borderMD,
                      ),
                    ),
                    child: primaryLoading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(
                            primaryLabel,
                            style: DesignTypography.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable option card (visitor type, categories, etc.).
class DivineChoiceCard extends StatelessWidget {
  const DivineChoiceCard({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? DesignColors.primary : DesignColors.borderLight;
    final bg = selected
        ? DesignColors.primary.withValues(alpha: 0.06)
        : DesignColors.surface;
    final iconBg = selected
        ? DesignColors.primary.withValues(alpha: 0.12)
        : DesignColors.surfaceSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignRadius.borderLG,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(DesignSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DesignRadius.borderLG,
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? DesignElevation.sm : DesignElevation.none,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: DesignRadius.borderMD,
                ),
                child: Icon(
                  icon,
                  color: selected ? DesignColors.primary : DesignColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: DesignSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DesignTypography.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: DesignTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: DesignColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings-style row for date/time and similar pickers.
class DivinePickerRow extends StatelessWidget {
  const DivinePickerRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignColors.surface,
      borderRadius: DesignRadius.borderLG,
      child: InkWell(
        onTap: onTap,
        borderRadius: DesignRadius.borderLG,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.md,
            vertical: DesignSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: DesignRadius.borderLG,
            border: Border.all(color: DesignColors.borderLight),
            boxShadow: DesignElevation.none,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignColors.surfaceSoft,
                  borderRadius: DesignRadius.borderMD,
                ),
                child: Icon(icon, color: DesignColors.primary, size: 20),
              ),
              const SizedBox(width: DesignSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DesignTypography.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: DesignTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (helper != null && helper!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(helper!, style: DesignTypography.caption),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: DesignColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Review / summary key-value row.
class DivineSummaryRow extends StatelessWidget {
  const DivineSummaryRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title above grouped content in flows.
class DivineFlowSectionLabel extends StatelessWidget {
  const DivineFlowSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignSpacing.sm),
      child: Text(
        text,
        style: DesignTypography.label.copyWith(
          color: DesignColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
