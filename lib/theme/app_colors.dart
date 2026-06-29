import 'package:flutter/material.dart';

/// **Private** hex constants for the GatePass+ theme system.
///
/// Defaults match `frontend/src/theme/defaultThemeColors.ts` — keep in sync.
@immutable
class AppColorPalette {
  /// Compile-time GP brand anchors — used by splash/const widgets; keep in sync with `.light`.
  static const Color brandNavy = Color(0xFF0D1B3D);
  static const Color brandAccentGreen = Color(0xFF16A34A);

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
      if (v == null) return null;
      final trimmed = v.toString().trim();
      if (trimmed.isEmpty) return null;
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

  /// GatePass+ brand identity — navy / blue / green (see defaultThemeColors.ts).
  static const AppColorPalette light = AppColorPalette(
    brandPrimary: brandNavy,
    brandPrimaryHover: Color(0xFF091428),
    brandPrimaryLight: Color(0xFFE8ECF4),
    brandPrimaryContainer: Color(0xFFEEF2F8),
    brandSecondary: Color(0xFF2563EB),
    brandSecondaryLight: Color(0xFFDBEAFE),
    brandSecondaryContainer: Color(0xFFBFDBFE),
    brandAccent: brandAccentGreen,
    brandGradientStart: Color(0xFF070F22),
    brandGradientMiddle: Color(0xFF0D1B3D),
    brandGradientEnd: Color(0xFF2563EB),
    accentLight: Color(0xFFDCFCE7),
    accentContainer: Color(0xFFBBF7D0),
    brandDanger: Color(0xFFDC2626),
    buttonBackground: Color(0xFF0D1B3D),
    buttonForeground: Color(0xFFFFFFFF),
    secondaryButtonBackground: Color(0xFF2563EB),
    secondaryButtonForeground: Color(0xFFFFFFFF),
    iconForeground: Color(0xFF64748B),
    iconBackground: Color(0xFFFFFFFF),
    fieldForeground: Color(0xFF0D1B3D),
    surfaceBackground: Color(0xFFF8FAFC),
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceBorder: Color(0xFFE2E8F0),
    skeletonBase: Color(0xFFE2E8F0),
    skeletonHighlight: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF0D1B3D),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    textInverse: Color(0xFFFFFFFF),
    approvedBg: Color(0xFFDCFCE7),
    approvedFg: Color(0xFF166534),
    approvedSolid: Color(0xFF16A34A),
    pendingBg: Color(0xFFFEF3C7),
    pendingFg: Color(0xFFB45309),
    pendingSolid: Color(0xFFD97706),
    deniedBg: Color(0xFFFEE2E2),
    deniedFg: Color(0xFFB91C1C),
    deniedSolid: Color(0xFFDC2626),
    infoBg: Color(0xFFDBEAFE),
    infoFg: Color(0xFF1D4ED8),
    infoSolid: Color(0xFF2563EB),
  );

  /// GP brand dark theme — navy surfaces, lifted blue primary (see DESIGN_SYSTEM.md).
  static const AppColorPalette dark = AppColorPalette(
    brandPrimary: Color(0xFF3B82F6),
    brandPrimaryHover: Color(0xFF2563EB),
    brandPrimaryLight: Color(0xFF1E3A5F),
    brandPrimaryContainer: Color(0xFF172554),
    brandSecondary: Color(0xFF60A5FA),
    brandSecondaryLight: Color(0xFF1E3A8A),
    brandSecondaryContainer: Color(0xFF1E3A8A),
    brandAccent: Color(0xFF22C55E),
    brandGradientStart: Color(0xFF060E1C),
    brandGradientMiddle: Color(0xFF0D1B3D),
    brandGradientEnd: Color(0xFF2563EB),
    accentLight: Color(0xFF14532D),
    accentContainer: Color(0xFF166534),
    brandDanger: Color(0xFFEF4444),
    buttonBackground: Color(0xFF3B82F6),
    buttonForeground: Color(0xFFFFFFFF),
    secondaryButtonBackground: Color(0xFF2563EB),
    secondaryButtonForeground: Color(0xFFFFFFFF),
    iconForeground: Color(0xFF94A3B8),
    iconBackground: Color(0xFF1F2937),
    fieldForeground: Color(0xFFF8FAFC),
    surfaceBackground: Color(0xFF0B1220),
    surfaceDefault: Color(0xFF111827),
    surfaceElevated: Color(0xFF1F2937),
    surfaceBorder: Color(0xFF374151),
    skeletonBase: Color(0xFF1F2937),
    skeletonHighlight: Color(0xFF374151),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textInverse: Color(0xFF0D1B3D),
    approvedBg: Color(0xFF14532D),
    approvedFg: Color(0xFF86EFAC),
    approvedSolid: Color(0xFF16A34A),
    pendingBg: Color(0xFF451A03),
    pendingFg: Color(0xFFFCD34D),
    pendingSolid: Color(0xFFF59E0B),
    deniedBg: Color(0xFF450A0A),
    deniedFg: Color(0xFFFCA5A5),
    deniedSolid: Color(0xFFEF4444),
    infoBg: Color(0xFF172554),
    infoFg: Color(0xFF93C5FD),
    infoSolid: Color(0xFF3B82F6),
  );
}
