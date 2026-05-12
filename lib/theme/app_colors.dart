import 'package:flutter/material.dart';

/// **Private** hex constants for the GatePass+ theme system.
///
/// **Do NOT import this file from widgets, screens or any feature code.**
/// Widgets must use `context.brand`, `context.surface`, `context.text`,
/// `context.state` (see `context_extensions.dart`) so a future palette swap
/// (including API-driven theming) reaches every screen atomically.
///
/// Premium teal-and-gold palette:
/// * Deep Teal `#0F766E` — primary (rich, trustworthy, premium)
/// * Warm Amber `#F59E0B` — accent (golden highlights, CTA warmth)
/// * Red `#EF4444` — danger
///
/// Light/dark pairs were chosen to hit WCAG AA contrast. Do not change a
/// single hex without re-validating contrast for every pairing.
@immutable
class AppColorPalette {
  const AppColorPalette({
    required this.brandPrimary,
    required this.brandAccent,
    required this.brandDanger,
    required this.surfaceBackground,
    required this.surfaceDefault,
    required this.surfaceElevated,
    required this.surfaceBorder,
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
  final Color brandAccent;
  final Color brandDanger;

  final Color surfaceBackground;
  final Color surfaceDefault;
  final Color surfaceElevated;
  final Color surfaceBorder;

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

  /// Premium light mode — Deep Teal + Warm Amber.
  ///
  /// Teal `#0F766E` primary, amber `#F59E0B` accent, warm off-white
  /// surfaces with subtle teal tinting. WCAG AA verified.
  static const AppColorPalette light = AppColorPalette(
    brandPrimary: Color(0xFF0F766E),
    brandAccent: Color(0xFFF59E0B),
    brandDanger: Color(0xFFEF4444),
    surfaceBackground: Color(0xFFF0FDFA),
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFCCFBF1),
    surfaceBorder: Color(0xFF99F6E4),
    textPrimary: Color(0xFF134E4A),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    textInverse: Color(0xFFFFFFFF),
    approvedBg: Color(0xFFD1FAE5),
    approvedFg: Color(0xFF065F46),
    approvedSolid: Color(0xFF10B981),
    pendingBg: Color(0xFFFEF3C7),
    pendingFg: Color(0xFF92400E),
    pendingSolid: Color(0xFFF59E0B),
    deniedBg: Color(0xFFFEE2E2),
    deniedFg: Color(0xFF991B1B),
    deniedSolid: Color(0xFFEF4444),
    infoBg: Color(0xFFF0FDFA),
    infoFg: Color(0xFF115E59),
    infoSolid: Color(0xFF14B8A6),
  );

  /// Premium dark mode — Deep Teal + Warm Amber.
  ///
  /// Dark teal-tinted surfaces with lighter teal accents.
  static const AppColorPalette dark = AppColorPalette(
    brandPrimary: Color(0xFFF0FDFA),
    brandAccent: Color(0xFFFBBF24),
    brandDanger: Color(0xFFF87171),
    surfaceBackground: Color(0xFF0A1A18),
    surfaceDefault: Color(0xFF112220),
    surfaceElevated: Color(0xFF1A302D),
    surfaceBorder: Color(0xFF2D4A46),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD1D5DB),
    textTertiary: Color(0xFF9CA3AF),
    textInverse: Color(0xFF134E4A),
    approvedBg: Color(0xFF064E3B),
    approvedFg: Color(0xFF6EE7B7),
    approvedSolid: Color(0xFF34D399),
    pendingBg: Color(0xFF78350F),
    pendingFg: Color(0xFFFCD34D),
    pendingSolid: Color(0xFFFBBF24),
    deniedBg: Color(0xFF7F1D1D),
    deniedFg: Color(0xFFFCA5A5),
    deniedSolid: Color(0xFFF87171),
    infoBg: Color(0xFF042F2E),
    infoFg: Color(0xFF5EEAD4),
    infoSolid: Color(0xFF2DD4BF),
  );
}
