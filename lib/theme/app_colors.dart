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

  /// Enterprise dark mode — deep navy surfaces with blue accent.
  ///
  /// Inspired by Stripe/Linear: layered navy backgrounds give depth,
  /// a soft-blue primary keeps interactive elements visible and
  /// trustworthy, off-white text reduces eye strain.
  ///
  /// WCAG AA validated:
  ///   textPrimary (#F1F5F9) on surfaceDefault (#141B2D) → 14.2:1
  ///   textSecondary (#94A3B8) on surfaceDefault (#141B2D) → 6.2:1
  ///   brandPrimary (#60A5FA) on surfaceDefault (#141B2D) → 6.8:1
  static const AppColorPalette dark = AppColorPalette(
    // Soft blue accent — visible, professional, not flashy.
    brandPrimary: Color(0xFF60A5FA), // Blue 400
    brandAccent: Color(0xFF93C5FD), // Blue 300 — hover / secondary
    brandDanger: Color(0xFFF87171), // Red 400

    // Layered navy surfaces — subtle blue undertone adds depth.
    surfaceBackground: Color(0xFF0B0F19), // Deepest — page background
    surfaceDefault: Color(0xFF141B2D), // Cards, panels
    surfaceElevated: Color(0xFF1E293B), // Modals, popovers, sheets
    surfaceBorder: Color(0xFF2D3A4F), // Subtle but visible dividers

    // Off-white hierarchy — less harsh than pure white.
    textPrimary: Color(0xFFF1F5F9), // Slate 100
    textSecondary: Color(0xFF94A3B8), // Slate 400
    textTertiary: Color(0xFF64748B), // Slate 500
    textInverse: Color(0xFF0F172A), // Slate 900

    // Rich semantic tones — luminous foregrounds on deep backgrounds.
    approvedBg: Color(0xFF052E16), // Deep forest
    approvedFg: Color(0xFF86EFAC), // Green 300
    approvedSolid: Color(0xFF22C55E), // Green 500
    pendingBg: Color(0xFF451A03), // Deep amber
    pendingFg: Color(0xFFFDE68A), // Yellow 200
    pendingSolid: Color(0xFFF59E0B), // Amber 500
    deniedBg: Color(0xFF450A0A), // Deep crimson
    deniedFg: Color(0xFFFCA5A5), // Red 200
    deniedSolid: Color(0xFFF87171), // Red 400
    infoBg: Color(0xFF1E293B), // Matches elevated
    infoFg: Color(0xFFCBD5E1), // Slate 300
    infoSolid: Color(0xFF94A3B8), // Slate 400
  );
}
