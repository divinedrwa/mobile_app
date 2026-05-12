import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// =========================================================================
///  Brand colors
/// =========================================================================
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.primary,
    required this.accent,
    required this.danger,
  });

  /// Slate (`#0F172A` light / `#F1F5F9` dark).
  final Color primary;

  /// Emerald (`#10B981` light / `#34D399` dark). Matches the green `+`
  /// badge in the app icon. Used for primary actions ("Allow entry").
  final Color accent;

  /// Red (`#EF4444` light / `#F87171` dark). Matches the barrier stripes
  /// in the app icon. Used for destructive actions ("Block visitor").
  final Color danger;

  @override
  BrandColors copyWith({Color? primary, Color? accent, Color? danger}) =>
      BrandColors(
        primary: primary ?? this.primary,
        accent: accent ?? this.accent,
        danger: danger ?? this.danger,
      );

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }

  factory BrandColors.fromPalette(AppColorPalette p) => BrandColors(
        primary: p.brandPrimary,
        accent: p.brandAccent,
        danger: p.brandDanger,
      );
}

/// =========================================================================
///  Surface colors
/// =========================================================================
@immutable
class SurfaceColors extends ThemeExtension<SurfaceColors> {
  const SurfaceColors({
    required this.background,
    required this.defaultSurface,
    required this.elevated,
    required this.border,
  });

  /// Outer-most page background (`#FFFFFF` light / `#020617` dark).
  final Color background;

  /// Default card / panel surface (`#F8FAFC` / `#0F172A`).
  /// Field is `defaultSurface` because `default` is a reserved Dart keyword.
  final Color defaultSurface;

  /// Raised surface (modal, popover) (`#F1F5F9` / `#1E293B`).
  final Color elevated;

  /// 1-pixel border between surfaces (`#E2E8F0` / `#334155`).
  final Color border;

  @override
  SurfaceColors copyWith({
    Color? background,
    Color? defaultSurface,
    Color? elevated,
    Color? border,
  }) =>
      SurfaceColors(
        background: background ?? this.background,
        defaultSurface: defaultSurface ?? this.defaultSurface,
        elevated: elevated ?? this.elevated,
        border: border ?? this.border,
      );

  @override
  SurfaceColors lerp(ThemeExtension<SurfaceColors>? other, double t) {
    if (other is! SurfaceColors) return this;
    return SurfaceColors(
      background: Color.lerp(background, other.background, t)!,
      defaultSurface: Color.lerp(defaultSurface, other.defaultSurface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }

  factory SurfaceColors.fromPalette(AppColorPalette p) => SurfaceColors(
        background: p.surfaceBackground,
        defaultSurface: p.surfaceDefault,
        elevated: p.surfaceElevated,
        border: p.surfaceBorder,
      );
}

/// =========================================================================
///  Text colors
/// =========================================================================
@immutable
class TextColors extends ThemeExtension<TextColors> {
  const TextColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.inverse,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  /// Used when text sits on a coloured solid (e.g., white on `brand.accent`).
  final Color inverse;

  @override
  TextColors copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? inverse,
  }) =>
      TextColors(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        tertiary: tertiary ?? this.tertiary,
        inverse: inverse ?? this.inverse,
      );

  @override
  TextColors lerp(ThemeExtension<TextColors>? other, double t) {
    if (other is! TextColors) return this;
    return TextColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      inverse: Color.lerp(inverse, other.inverse, t)!,
    );
  }

  factory TextColors.fromPalette(AppColorPalette p) => TextColors(
        primary: p.textPrimary,
        secondary: p.textSecondary,
        tertiary: p.textTertiary,
        inverse: p.textInverse,
      );
}

/// =========================================================================
///  State (semantic) colors — approved / pending / denied / info
///  Each state has a `.bg`, `.fg`, `.solid` triplet.
/// =========================================================================
@immutable
class StateColorTriplet {
  const StateColorTriplet({
    required this.bg,
    required this.fg,
    required this.solid,
  });

  final Color bg;
  final Color fg;
  final Color solid;

  StateColorTriplet copyWith({Color? bg, Color? fg, Color? solid}) =>
      StateColorTriplet(
        bg: bg ?? this.bg,
        fg: fg ?? this.fg,
        solid: solid ?? this.solid,
      );

  StateColorTriplet lerp(StateColorTriplet other, double t) =>
      StateColorTriplet(
        bg: Color.lerp(bg, other.bg, t)!,
        fg: Color.lerp(fg, other.fg, t)!,
        solid: Color.lerp(solid, other.solid, t)!,
      );
}

@immutable
class StateColors extends ThemeExtension<StateColors> {
  const StateColors({
    required this.approved,
    required this.pending,
    required this.denied,
    required this.info,
  });

  /// Visitor approved · transaction successful.
  final StateColorTriplet approved;

  /// Visitor waiting for resident decision · payment in flight.
  final StateColorTriplet pending;

  /// Visitor denied · payment failed · permission revoked.
  final StateColorTriplet denied;

  /// Notices, announcements, neutral hints.
  final StateColorTriplet info;

  @override
  StateColors copyWith({
    StateColorTriplet? approved,
    StateColorTriplet? pending,
    StateColorTriplet? denied,
    StateColorTriplet? info,
  }) =>
      StateColors(
        approved: approved ?? this.approved,
        pending: pending ?? this.pending,
        denied: denied ?? this.denied,
        info: info ?? this.info,
      );

  @override
  StateColors lerp(ThemeExtension<StateColors>? other, double t) {
    if (other is! StateColors) return this;
    return StateColors(
      approved: approved.lerp(other.approved, t),
      pending: pending.lerp(other.pending, t),
      denied: denied.lerp(other.denied, t),
      info: info.lerp(other.info, t),
    );
  }

  factory StateColors.fromPalette(AppColorPalette p) => StateColors(
        approved: StateColorTriplet(
          bg: p.approvedBg,
          fg: p.approvedFg,
          solid: p.approvedSolid,
        ),
        pending: StateColorTriplet(
          bg: p.pendingBg,
          fg: p.pendingFg,
          solid: p.pendingSolid,
        ),
        denied: StateColorTriplet(
          bg: p.deniedBg,
          fg: p.deniedFg,
          solid: p.deniedSolid,
        ),
        info: StateColorTriplet(
          bg: p.infoBg,
          fg: p.infoFg,
          solid: p.infoSolid,
        ),
      );
}

/// =========================================================================
///  Spacing
/// =========================================================================
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.s4 = AppSpacingTokens.s4,
    this.s8 = AppSpacingTokens.s8,
    this.s12 = AppSpacingTokens.s12,
    this.s16 = AppSpacingTokens.s16,
    this.s24 = AppSpacingTokens.s24,
    this.s32 = AppSpacingTokens.s32,
    this.s48 = AppSpacingTokens.s48,
    this.s64 = AppSpacingTokens.s64,
  });

  final double s4;
  final double s8;
  final double s12;
  final double s16;
  final double s24;
  final double s32;
  final double s48;
  final double s64;

  @override
  AppSpacing copyWith({
    double? s4,
    double? s8,
    double? s12,
    double? s16,
    double? s24,
    double? s32,
    double? s48,
    double? s64,
  }) =>
      AppSpacing(
        s4: s4 ?? this.s4,
        s8: s8 ?? this.s8,
        s12: s12 ?? this.s12,
        s16: s16 ?? this.s16,
        s24: s24 ?? this.s24,
        s32: s32 ?? this.s32,
        s48: s48 ?? this.s48,
        s64: s64 ?? this.s64,
      );

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppSpacing(
      s4: l(s4, other.s4),
      s8: l(s8, other.s8),
      s12: l(s12, other.s12),
      s16: l(s16, other.s16),
      s24: l(s24, other.s24),
      s32: l(s32, other.s32),
      s48: l(s48, other.s48),
      s64: l(s64, other.s64),
    );
  }
}

/// =========================================================================
///  Border radius
/// =========================================================================
@immutable
class AppRadius extends ThemeExtension<AppRadius> {
  const AppRadius({
    this.sm = AppRadiusTokens.sm,
    this.md = AppRadiusTokens.md,
    this.lg = AppRadiusTokens.lg,
    this.full = AppRadiusTokens.full,
  });

  final double sm;
  final double md;
  final double lg;
  final double full;

  @override
  AppRadius copyWith({double? sm, double? md, double? lg, double? full}) =>
      AppRadius(
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        full: full ?? this.full,
      );

  @override
  AppRadius lerp(ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppRadius(
      sm: l(sm, other.sm),
      md: l(md, other.md),
      lg: l(lg, other.lg),
      full: l(full, other.full),
    );
  }
}
