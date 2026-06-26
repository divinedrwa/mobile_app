import 'package:flutter/material.dart';

/// **Private** hex constants for the GatePass+ theme system.
///
/// Defaults match `frontend/src/theme/defaultThemeColors.ts` — keep in sync.
@immutable
class AppColorPalette {
  const AppColorPalette({
    required this.brandPrimary,
    required this.brandPrimaryHover,
    required this.brandPrimaryLight,
    required this.brandPrimaryContainer,
    required this.brandSecondary,
    required this.brandSecondaryLight,
    required this.brandSecondaryContainer,
    required this.brandAccent,
    required this.brandGradientStart,
    required this.brandGradientMiddle,
    required this.brandGradientEnd,
    required this.accentLight,
    required this.accentContainer,
    required this.brandDanger,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.secondaryButtonBackground,
    required this.secondaryButtonForeground,
    required this.iconForeground,
    required this.iconBackground,
    required this.fieldForeground,
    required this.surfaceBackground,
    required this.surfaceDefault,
    required this.surfaceElevated,
    required this.surfaceBorder,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textInverse,
    required this.approvedBg,
    required this.approvedFg,
    required this.approvedSolid,
    required this.pendingBg,
    required this.pendingFg,
    required this.pendingSolid,
    required this.deniedBg,
    required this.deniedFg,
    required this.deniedSolid,
    required this.infoBg,
    required this.infoFg,
    required this.infoSolid,
  });

  final Color brandPrimary;
  final Color brandPrimaryHover;
  final Color brandPrimaryLight;
  final Color brandPrimaryContainer;
  final Color brandSecondary;
  final Color brandSecondaryLight;
  final Color brandSecondaryContainer;
  final Color brandAccent;
  final Color brandGradientStart;
  final Color brandGradientMiddle;
  final Color brandGradientEnd;
  final Color accentLight;
  final Color accentContainer;
  final Color brandDanger;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color secondaryButtonBackground;
  final Color secondaryButtonForeground;
  final Color iconForeground;
  final Color iconBackground;
  final Color fieldForeground;
  final Color surfaceBackground;
  final Color surfaceDefault;
  final Color surfaceElevated;
  final Color surfaceBorder;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color approvedBg;
  final Color approvedFg;
  final Color approvedSolid;
  final Color pendingBg;
  final Color pendingFg;
  final Color pendingSolid;
  final Color deniedBg;
  final Color deniedFg;
  final Color deniedSolid;
  final Color infoBg;
  final Color infoFg;
  final Color infoSolid;

  AppColorPalette copyWith({
    Color? brandPrimary,
    Color? brandPrimaryHover,
    Color? brandPrimaryLight,
    Color? brandPrimaryContainer,
    Color? brandSecondary,
    Color? brandSecondaryLight,
    Color? brandSecondaryContainer,
    Color? brandAccent,
    Color? brandGradientStart,
    Color? brandGradientMiddle,
    Color? brandGradientEnd,
    Color? accentLight,
    Color? accentContainer,
    Color? brandDanger,
    Color? buttonBackground,
    Color? buttonForeground,
    Color? secondaryButtonBackground,
    Color? secondaryButtonForeground,
    Color? iconForeground,
    Color? iconBackground,
    Color? fieldForeground,
    Color? surfaceBackground,
    Color? surfaceDefault,
    Color? surfaceElevated,
    Color? surfaceBorder,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textInverse,
    Color? approvedBg,
    Color? approvedFg,
    Color? approvedSolid,
    Color? pendingBg,
    Color? pendingFg,
    Color? pendingSolid,
    Color? deniedBg,
    Color? deniedFg,
    Color? deniedSolid,
    Color? infoBg,
    Color? infoFg,
    Color? infoSolid,
  }) {
    return AppColorPalette(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryHover: brandPrimaryHover ?? this.brandPrimaryHover,
      brandPrimaryLight: brandPrimaryLight ?? this.brandPrimaryLight,
      brandPrimaryContainer: brandPrimaryContainer ?? this.brandPrimaryContainer,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      brandSecondaryLight: brandSecondaryLight ?? this.brandSecondaryLight,
      brandSecondaryContainer: brandSecondaryContainer ?? this.brandSecondaryContainer,
      brandAccent: brandAccent ?? this.brandAccent,
      brandGradientStart: brandGradientStart ?? this.brandGradientStart,
      brandGradientMiddle: brandGradientMiddle ?? this.brandGradientMiddle,
      brandGradientEnd: brandGradientEnd ?? this.brandGradientEnd,
      accentLight: accentLight ?? this.accentLight,
      accentContainer: accentContainer ?? this.accentContainer,
      brandDanger: brandDanger ?? this.brandDanger,
      buttonBackground: buttonBackground ?? this.buttonBackground,
      buttonForeground: buttonForeground ?? this.buttonForeground,
      secondaryButtonBackground:
          secondaryButtonBackground ?? this.secondaryButtonBackground,
      secondaryButtonForeground:
          secondaryButtonForeground ?? this.secondaryButtonForeground,
      iconForeground: iconForeground ?? this.iconForeground,
      iconBackground: iconBackground ?? this.iconBackground,
      fieldForeground: fieldForeground ?? this.fieldForeground,
      surfaceBackground: surfaceBackground ?? this.surfaceBackground,
      surfaceDefault: surfaceDefault ?? this.surfaceDefault,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textInverse: textInverse ?? this.textInverse,
      approvedBg: approvedBg ?? this.approvedBg,
      approvedFg: approvedFg ?? this.approvedFg,
      approvedSolid: approvedSolid ?? this.approvedSolid,
      pendingBg: pendingBg ?? this.pendingBg,
      pendingFg: pendingFg ?? this.pendingFg,
      pendingSolid: pendingSolid ?? this.pendingSolid,
      deniedBg: deniedBg ?? this.deniedBg,
      deniedFg: deniedFg ?? this.deniedFg,
      deniedSolid: deniedSolid ?? this.deniedSolid,
      infoBg: infoBg ?? this.infoBg,
      infoFg: infoFg ?? this.infoFg,
      infoSolid: infoSolid ?? this.infoSolid,
    );
  }

  /// Society admin `themeColors` JSON → runtime palette (partial overrides OK).
  factory AppColorPalette.fromApiJson(
    Map<String, dynamic> json,
    AppColorPalette defaults,
  ) {
    Color? parse(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) return null;
      final trimmed = v.trim();
      if (trimmed.startsWith('#')) {
        final s = trimmed.substring(1);
        if (s.length != 6) return null;
        final parsed = int.tryParse('FF$s', radix: 16);
        return parsed == null ? null : Color(parsed);
      }
      final rgb = RegExp(
        r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (rgb != null) {
        String hex(int n) => n.clamp(0, 255).toRadixString(16).padLeft(2, '0');
        final parsed = int.tryParse(
          'FF${hex(int.parse(rgb.group(1)!))}${hex(int.parse(rgb.group(2)!))}${hex(int.parse(rgb.group(3)!))}',
          radix: 16,
        );
        return parsed == null ? null : Color(parsed);
      }
      return null;
    }

    final primary = parse('primaryColor');
    final primaryHover = parse('primaryHover');
    final primaryLight = parse('primaryLight') ?? parse('primaryContainer');
    final primaryContainer = parse('primaryContainer') ?? primaryLight;
    final secondary = parse('secondaryColor');
    final accent = parse('accentColor');
    final gradientStart = parse('gradientStart');
    final gradientMiddle = parse('gradientMiddle');
    final gradientEnd = parse('gradientEnd');
    final buttonBg = parse('buttonBg');
    final buttonText = parse('buttonText');
    final secondaryBtnBg = parse('secondaryButtonBg');
    final secondaryBtnText = parse('secondaryButtonText');
    final warning = parse('warningColor');
    final error = parse('errorColor');

    return defaults.copyWith(
      brandPrimary: primary,
      brandPrimaryHover: primaryHover,
      brandPrimaryLight: primaryLight,
      brandPrimaryContainer: primaryContainer,
      brandSecondary: secondary,
      brandSecondaryLight: secondary != null
          ? Color.alphaBlend(const Color(0xE6FFFFFF), secondary)
          : null,
      brandAccent: accent,
      brandGradientStart: gradientStart,
      brandGradientMiddle: gradientMiddle,
      brandGradientEnd: gradientEnd,
      accentLight: accent != null
          ? Color.alphaBlend(const Color(0xE6FFFFFF), accent)
          : null,
      brandDanger: error,
      buttonBackground: buttonBg ?? primary,
      buttonForeground: buttonText,
      secondaryButtonBackground: secondaryBtnBg ?? secondary,
      secondaryButtonForeground: secondaryBtnText,
      iconForeground: parse('iconColor'),
      iconBackground: parse('iconBg'),
      fieldForeground: parse('fieldText'),
      surfaceBackground: parse('backgroundColor'),
      surfaceDefault: parse('cardColor'),
      surfaceElevated: parse('fieldBg'),
      surfaceBorder: parse('borderColor'),
      textPrimary: parse('headingColor'),
      textSecondary: parse('bodyTextColor'),
      textTertiary: parse('mutedTextColor'),
      approvedSolid: accent,
      approvedBg: accent != null
          ? Color.alphaBlend(const Color(0xD9FFFFFF), accent)
          : null,
      pendingSolid: warning,
      pendingBg: warning != null
          ? Color.alphaBlend(const Color(0xD9FFFFFF), warning)
          : null,
      deniedSolid: error,
      deniedBg: error != null
          ? Color.alphaBlend(const Color(0xD9FFFFFF), error)
          : null,
      infoSolid: primary,
      infoBg: primaryLight,
    );
  }

  /// GatePass+ Play Store asset pack — deep teal-green brand (see defaultThemeColors.ts).
  static const AppColorPalette light = AppColorPalette(
    brandPrimary: Color(0xFF004D40),
    brandPrimaryHover: Color(0xFF003D33),
    brandPrimaryLight: Color(0xFFE0F2F1),
    brandPrimaryContainer: Color(0xFFE8F5F0),
    brandSecondary: Color(0xFF00695C),
    brandSecondaryLight: Color(0xFFE0F2F1),
    brandSecondaryContainer: Color(0xFFB2DFDB),
    brandAccent: Color(0xFF00C853),
    brandGradientStart: Color(0xFF003D33),
    brandGradientMiddle: Color(0xFF004D40),
    brandGradientEnd: Color(0xFF00796B),
    accentLight: Color(0xFFE8F5E9),
    accentContainer: Color(0xFFC8E6C9),
    brandDanger: Color(0xFFE53935),
    buttonBackground: Color(0xFF004D40),
    buttonForeground: Color(0xFFFFFFFF),
    secondaryButtonBackground: Color(0xFF00695C),
    secondaryButtonForeground: Color(0xFFFFFFFF),
    iconForeground: Color(0xFF5A6472),
    iconBackground: Color(0xFFFFFFFF),
    fieldForeground: Color(0xFF262626),
    surfaceBackground: Color(0xFFF4F7F6),
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF8FAF9),
    surfaceBorder: Color(0xFFE0E8E4),
    skeletonBase: Color(0xFFE2E8E4),
    skeletonHighlight: Color(0xFFF1F5F3),
    textPrimary: Color(0xFF1A2B3C),
    textSecondary: Color(0xFF5A6472),
    textTertiary: Color(0xFF6B7480),
    textInverse: Color(0xFFFFFFFF),
    approvedBg: Color(0xFFE8F5E9),
    approvedFg: Color(0xFF1B5E20),
    approvedSolid: Color(0xFF00C853),
    pendingBg: Color(0xFFFFF3E0),
    pendingFg: Color(0xFFE65100),
    pendingSolid: Color(0xFFFB8C00),
    deniedBg: Color(0xFFFFEBEE),
    deniedFg: Color(0xFFB71C1C),
    deniedSolid: Color(0xFFE53935),
    infoBg: Color(0xFFE3F2FD),
    infoFg: Color(0xFF1565C0),
    infoSolid: Color(0xFF1976D2),
  );

  static const AppColorPalette dark = AppColorPalette(
    brandPrimary: Color(0xFF26A69A),
    brandPrimaryHover: Color(0xFF00897B),
    brandPrimaryLight: Color(0xFF0A2E28),
    brandPrimaryContainer: Color(0xFF0A2E28),
    brandSecondary: Color(0xFF00695C),
    brandSecondaryLight: Color(0xFF0A2E28),
    brandSecondaryContainer: Color(0xFF0A2E28),
    brandAccent: Color(0xFF00E676),
    brandGradientStart: Color(0xFF00251A),
    brandGradientMiddle: Color(0xFF003D33),
    brandGradientEnd: Color(0xFF00796B),
    accentLight: Color(0xFF0A2E1F),
    accentContainer: Color(0xFF0A2E1F),
    brandDanger: Color(0xFFEF5350),
    buttonBackground: Color(0xFF26A69A),
    buttonForeground: Color(0xFFFFFFFF),
    secondaryButtonBackground: Color(0xFF00695C),
    secondaryButtonForeground: Color(0xFFFFFFFF),
    iconForeground: Color(0xFF94A3B8),
    iconBackground: Color(0xFF1A2824),
    fieldForeground: Color(0xFFF1F5F9),
    surfaceBackground: Color(0xFF0D1A17),
    surfaceDefault: Color(0xFF141F1D),
    surfaceElevated: Color(0xFF1A2824),
    surfaceBorder: Color(0xFF2A3D38),
    skeletonBase: Color(0xFF1E293B),
    skeletonHighlight: Color(0xFF334155),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textInverse: Color(0xFF1A2B3C),
    approvedBg: Color(0xFF0A2E1F),
    approvedFg: Color(0xFF69F0AE),
    approvedSolid: Color(0xFF00E676),
    pendingBg: Color(0xFF3E2723),
    pendingFg: Color(0xFFFFB74D),
    pendingSolid: Color(0xFFFB8C00),
    deniedBg: Color(0xFF3E1010),
    deniedFg: Color(0xFFEF9A9A),
    deniedSolid: Color(0xFFEF5350),
    infoBg: Color(0xFF0D2137),
    infoFg: Color(0xFF90CAF9),
    infoSolid: Color(0xFF42A5F5),
  );
}
