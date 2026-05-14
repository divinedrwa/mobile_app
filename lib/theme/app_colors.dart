import 'package:flutter/material.dart';

/// **Private** hex constants for the GatePass+ theme system.
///
/// **Do NOT import this file from widgets, screens or any feature code.**
/// Widgets must use `context.brand`, `context.surface`, `context.text`,
/// `context.state` (see `context_extensions.dart`) so a future palette swap
/// (including API-driven theming) reaches every screen atomically.
///
/// Neutral enterprise palette:
/// * Charcoal `#111827` — primary
/// * Slate `#4B5563` — accent / interactive neutral
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

  /// Clean light mode — white surfaces with charcoal / grey accents.
  static const AppColorPalette light = AppColorPalette(
    brandPrimary: Color(0xFF374151),
    brandAccent: Color(0xFF6B7280),
    brandDanger: Color(0xFFEF4444),
    surfaceBackground: Color(0xFFFFFFFF),
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF8FAFC),
    surfaceBorder: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF9CA3AF),
    textInverse: Color(0xFFFFFFFF),
    approvedBg: Color(0xFFEFF6F1),
    approvedFg: Color(0xFF166534),
    approvedSolid: Color(0xFF16A34A),
    pendingBg: Color(0xFFFEF3C7),
    pendingFg: Color(0xFF92400E),
    pendingSolid: Color(0xFFF59E0B),
    deniedBg: Color(0xFFFEE2E2),
    deniedFg: Color(0xFF991B1B),
    deniedSolid: Color(0xFFEF4444),
    infoBg: Color(0xFFF3F4F6),
    infoFg: Color(0xFF374151),
    infoSolid: Color(0xFF9CA3AF),
  );

  /// Quiet dark mode — deep neutrals with restrained contrast.
  static const AppColorPalette dark = AppColorPalette(
    brandPrimary: Color(0xFFE5E7EB),
    brandAccent: Color(0xFFD1D5DB),
    brandDanger: Color(0xFFF87171),
    surfaceBackground: Color(0xFF111827),
    surfaceDefault: Color(0xFF1F2937),
    surfaceElevated: Color(0xFF273244),
    surfaceBorder: Color(0xFF374151),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD1D5DB),
    textTertiary: Color(0xFF9CA3AF),
    textInverse: Color(0xFF111827),
    approvedBg: Color(0xFF16341F),
    approvedFg: Color(0xFFBBF7D0),
    approvedSolid: Color(0xFF22C55E),
    pendingBg: Color(0xFF78350F),
    pendingFg: Color(0xFFFDE68A),
    pendingSolid: Color(0xFFF59E0B),
    deniedBg: Color(0xFF7F1D1D),
    deniedFg: Color(0xFFFCA5A5),
    deniedSolid: Color(0xFFF87171),
    infoBg: Color(0xFF1F2937),
    infoFg: Color(0xFFE5E7EB),
    infoSolid: Color(0xFF9CA3AF),
  );
}
