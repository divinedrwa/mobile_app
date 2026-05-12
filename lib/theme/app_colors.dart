import 'package:flutter/material.dart';

/// **Private** hex constants for the GatePass+ theme system.
///
/// **Do NOT import this file from widgets, screens or any feature code.**
/// Widgets must use `context.brand`, `context.surface`, `context.text`,
/// `context.state` (see `context_extensions.dart`) so a future palette swap
/// (including API-driven theming) reaches every screen atomically.
///
/// These values match the brand spec:
/// * Slate `#0F172A` — primary
/// * Emerald `#10B981` — accent (also the green `+` in the app icon)
/// * Red `#EF4444` — danger (matches the barrier stripes in the app icon)
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

  /// The light-mode default palette. Keep aligned with the
  /// [GatePass+ Theme System Implementation Prompt] spec.
  static const AppColorPalette light = AppColorPalette(
    brandPrimary: Color(0xFF0F172A),
    brandAccent: Color(0xFF10B981),
    brandDanger: Color(0xFFEF4444),
    surfaceBackground: Color(0xFFFFFFFF),
    surfaceDefault: Color(0xFFF8FAFC),
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceBorder: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF94A3B8),
    textInverse: Color(0xFFFFFFFF),
    approvedBg: Color(0xFFD1FAE5),
    approvedFg: Color(0xFF047857),
    approvedSolid: Color(0xFF10B981),
    pendingBg: Color(0xFFFEF3C7),
    pendingFg: Color(0xFF92400E),
    pendingSolid: Color(0xFFF59E0B),
    deniedBg: Color(0xFFFEE2E2),
    deniedFg: Color(0xFF991B1B),
    deniedSolid: Color(0xFFEF4444),
    infoBg: Color(0xFFDBEAFE),
    infoFg: Color(0xFF1E40AF),
    infoSolid: Color(0xFF3B82F6),
  );

  /// The dark-mode default palette.
  static const AppColorPalette dark = AppColorPalette(
    brandPrimary: Color(0xFFF1F5F9),
    brandAccent: Color(0xFF34D399),
    brandDanger: Color(0xFFF87171),
    surfaceBackground: Color(0xFF020617),
    surfaceDefault: Color(0xFF0F172A),
    surfaceElevated: Color(0xFF1E293B),
    surfaceBorder: Color(0xFF334155),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textInverse: Color(0xFF0F172A),
    approvedBg: Color(0xFF064E3B),
    approvedFg: Color(0xFF6EE7B7),
    approvedSolid: Color(0xFF34D399),
    pendingBg: Color(0xFF78350F),
    pendingFg: Color(0xFFFCD34D),
    pendingSolid: Color(0xFFFBBF24),
    deniedBg: Color(0xFF7F1D1D),
    deniedFg: Color(0xFFFCA5A5),
    deniedSolid: Color(0xFFF87171),
    infoBg: Color(0xFF1E3A8A),
    infoFg: Color(0xFF93C5FD),
    infoSolid: Color(0xFF60A5FA),
  );
}
