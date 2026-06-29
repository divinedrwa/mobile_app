import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Visual state for maintenance due / billing urgency (not payment gateway status).
enum DueVisualState { caughtUp, dueSoon, overdue }

/// Palette for a maintenance due state — used by home card shells and headers.
class DueStatePalette {
  const DueStatePalette({
    required this.accent,
    required this.gradientTop,
    required this.gradientBottom,
    required this.iconBg,
    required this.shellTop,
    required this.shellBorder,
    required this.navIcon,
    required this.alertSurface,
  });

  final Color accent;
  final Color gradientTop;
  final Color gradientBottom;
  final Color iconBg;
  final Color shellTop;
  final Color shellBorder;
  final Color navIcon;
  final Color alertSurface;

  static DueStatePalette of(DueVisualState state) {
    switch (state) {
      case DueVisualState.overdue:
        return DueStatePalette(
          accent: DesignColors.error,
          gradientTop: DesignColors.errorLight,
          gradientBottom: DesignColors.errorLight.withValues(alpha: 0.5),
          iconBg: DesignColors.error.withValues(alpha: 0.22),
          shellTop: DesignColors.errorLight,
          shellBorder: DesignColors.error.withValues(alpha: 0.25),
          navIcon: DesignColors.error,
          alertSurface: DesignColors.errorLight.withValues(alpha: 0.65),
        );
      case DueVisualState.dueSoon:
        return DueStatePalette(
          accent: DesignColors.warning,
          gradientTop: DesignColors.warningLight,
          gradientBottom: DesignColors.warningLight.withValues(alpha: 0.55),
          iconBg: DesignColors.warning.withValues(alpha: 0.22),
          shellTop: DesignColors.warningLight,
          shellBorder: DesignColors.warning.withValues(alpha: 0.28),
          navIcon: DesignColors.warning,
          alertSurface: DesignColors.warningLight.withValues(alpha: 0.7),
        );
      case DueVisualState.caughtUp:
        return DueStatePalette(
          accent: DesignColors.success,
          gradientTop: DesignColors.successLight,
          gradientBottom: DesignColors.surface,
          iconBg: DesignColors.accent.withValues(alpha: 0.18),
          shellTop: DesignColors.successLight,
          shellBorder: DesignColors.accent.withValues(alpha: 0.28),
          navIcon: DesignColors.accent,
          alertSurface: DesignColors.successLight.withValues(alpha: 0.65),
        );
    }
  }
}

/// Resident billing / collection status filters and badges.
abstract final class PaymentStatusColors {
  static Color forCollectionRate(double ratePercent) {
    if (ratePercent >= 80) return DesignColors.success;
    if (ratePercent >= 50) return DesignColors.warning;
    return DesignColors.error;
  }

  static Color forNetBalance(double net) {
    if (net >= 0) return DesignColors.success;
    return DesignColors.error;
  }

  static Color forResidentFilter(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return DesignColors.success;
      case 'PARTIAL':
        return DesignColors.warning;
      case 'OVERDUE':
        return DesignColors.error;
      case 'UNPAID':
        return DesignColors.warning;
      default:
        return DesignColors.textSecondary;
    }
  }

  static Color forAdvanceBalance({required bool ahead}) {
    return ahead ? DesignColors.success : DesignColors.warning;
  }

  static Color forDeficitHero({required bool hasDeficit}) {
    return hasDeficit ? DesignColors.warning : DesignColors.success;
  }

  static Color forOverdueAccent({required bool isOverdue}) {
    return isOverdue ? DesignColors.error : DesignColors.warning;
  }
}

/// Muted label / meta text on financial dashboards.
abstract final class SemanticColors {
  static Color get metaLabel => DesignColors.textSecondary;

  static Color metaLabelBg([double alpha = 0.1]) =>
      DesignColors.textSecondary.withValues(alpha: alpha);

  static Color infoAccent([double alpha = 1]) =>
      DesignColors.info.withValues(alpha: alpha);

  static Color warningSurface([double alpha = 0.1]) =>
      DesignColors.warning.withValues(alpha: alpha);

  static Color warningText([double alpha = 1]) =>
      Color.alphaBlend(
        DesignColors.warning.withValues(alpha: alpha),
        DesignColors.textPrimary,
      );

  static Color get errorEmphasis => DesignColors.error;
}
