import 'package:flutter/material.dart';

import '../../theme/app_colors.dart' as gp;

/// Mutable snapshot backing legacy [AppColors] getters.
///
/// Defaults match `frontend/src/theme/defaultThemeColors.ts` — keep in sync.
class AppColorState {
  const AppColorState({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryContainer,
    required this.accent,
    required this.accentLight,
    required this.accentContainer,
    required this.success,
    required this.successLight,
    required this.warning,
    required this.warningLight,
    required this.error,
    required this.errorLight,
    required this.info,
    required this.infoLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.background,
    required this.backgroundSoft,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.cardHover,
    required this.border,
    required this.borderDark,
    required this.divider,
    required this.buttonBg,
    required this.buttonText,
    required this.secondaryButtonBg,
    required this.secondaryButtonText,
    required this.iconColor,
    required this.iconBg,
    required this.fieldText,
    required this.gradientStart,
    required this.gradientMiddle,
    required this.gradientEnd,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryLight;
  final Color secondaryContainer;
  final Color accent;
  final Color accentLight;
  final Color accentContainer;
  final Color success;
  final Color successLight;
  final Color warning;
  final Color warningLight;
  final Color error;
  final Color errorLight;
  final Color info;
  final Color infoLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textInverse;
  final Color background;
  final Color backgroundSoft;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color cardHover;
  final Color border;
  final Color borderDark;
  final Color divider;
  final Color buttonBg;
  final Color buttonText;
  final Color secondaryButtonBg;
  final Color secondaryButtonText;
  final Color iconColor;
  final Color iconBg;
  final Color fieldText;
  final Color gradientStart;
  final Color gradientMiddle;
  final Color gradientEnd;

  /// GatePass+ brand defaults — mirror `frontend/src/theme/defaultThemeColors.ts`.
  static const AppColorState defaults = AppColorState(
    primary: Color(0xFF0D1B3D),
    primaryDark: Color(0xFF091428),
    primaryLight: Color(0xFFE8ECF4),
    primaryContainer: Color(0xFFEEF2F8),
    secondary: Color(0xFF2563EB),
    secondaryLight: Color(0xFFDBEAFE),
    secondaryContainer: Color(0xFFBFDBFE),
    accent: Color(0xFF16A34A),
    accentLight: Color(0xFFDCFCE7),
    accentContainer: Color(0xFFBBF7D0),
    success: Color(0xFF16A34A),
    successLight: Color(0xFFDCFCE7),
    warning: Color(0xFFD97706),
    warningLight: Color(0xFFFEF3C7),
    error: Color(0xFFDC2626),
    errorLight: Color(0xFFFEE2E2),
    info: Color(0xFF2563EB),
    infoLight: Color(0xFFDBEAFE),
    textPrimary: Color(0xFF0D1B3D),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    textDisabled: Color(0xFF94A3B8),
    textInverse: Color(0xFFFFFFFF),
    background: Color(0xFFF8FAFC),
    backgroundSoft: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F5F9),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderDark: Color(0xFFCBD5E1),
    divider: Color(0xFFF1F5F9),
    buttonBg: Color(0xFF0D1B3D),
    buttonText: Color(0xFFFFFFFF),
    secondaryButtonBg: Color(0xFF2563EB),
    secondaryButtonText: Color(0xFFFFFFFF),
    iconColor: Color(0xFF64748B),
    iconBg: Color(0xFFFFFFFF),
    fieldText: Color(0xFF0D1B3D),
    gradientStart: Color(0xFF070F22),
    gradientMiddle: Color(0xFF0D1B3D),
    gradientEnd: Color(0xFF2563EB),
  );

  factory AppColorState.fromPalette(gp.AppColorPalette palette) {
    final d = defaults;
    return AppColorState(
      primary: palette.brandPrimary,
      primaryDark: palette.brandPrimaryHover,
      primaryLight: palette.brandPrimaryLight,
      primaryContainer: palette.brandPrimaryContainer,
      secondary: palette.brandSecondary,
      secondaryLight: palette.brandSecondaryLight,
      secondaryContainer: palette.brandSecondaryContainer,
      accent: palette.brandAccent,
      accentLight: palette.accentLight,
      accentContainer: palette.accentContainer,
      success: palette.approvedSolid,
      successLight: palette.approvedBg,
      warning: palette.pendingSolid,
      warningLight: palette.pendingBg,
      error: palette.brandDanger,
      errorLight: palette.deniedBg,
      info: palette.infoSolid,
      infoLight: palette.infoBg,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      textTertiary: palette.textTertiary,
      textDisabled: d.textDisabled,
      textInverse: palette.textInverse,
      background: palette.surfaceBackground,
      backgroundSoft: palette.surfaceElevated,
      surface: palette.surfaceDefault,
      surfaceVariant: palette.surfaceElevated,
      card: palette.surfaceDefault,
      cardHover: d.cardHover,
      border: palette.surfaceBorder,
      borderDark: d.borderDark,
      divider: d.divider,
      buttonBg: palette.buttonBackground,
      buttonText: palette.buttonForeground,
      secondaryButtonBg: palette.secondaryButtonBackground,
      secondaryButtonText: palette.secondaryButtonForeground,
      iconColor: palette.iconForeground,
      iconBg: palette.iconBackground,
      fieldText: palette.fieldForeground,
      gradientStart: palette.brandGradientStart,
      gradientMiddle: palette.brandGradientMiddle,
      gradientEnd: palette.brandGradientEnd,
    );
  }

  LinearGradient get primaryGradient => LinearGradient(
        colors: [gradientStart, gradientMiddle, gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get primaryGradientShort => LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get accentGradient => LinearGradient(
        colors: [secondary, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

/// Global holder — updated by [gp.themeTokensProvider] after API fetch.
class AppColorBridge {
  AppColorBridge._();

  static AppColorState current = AppColorState.defaults;

  static void applyPalette(gp.AppColorPalette palette) {
    current = AppColorState.fromPalette(palette);
  }

  static void reset() {
    current = AppColorState.defaults;
  }
}
