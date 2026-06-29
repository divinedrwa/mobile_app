import 'package:flutter/material.dart';

import 'app_colors_bridge.dart';

/// GatePass+ unified color palette — resolves from [AppColorBridge].
///
/// Legacy screens import `AppColors.*`; values update automatically when
/// society theme colors load from the admin dashboard API.
///
/// Prefer `context.brand` / `context.surface` in new code.
class AppColors {
  AppColors._();

  static AppColorState get _c => AppColorBridge.current;

  // ── PRIMARY BRAND ────────────────────────────────────────────────────────────
  static Color get primary => _c.primary;
  static Color get primaryDark => _c.primaryDark;
  static Color get primaryLight => _c.primaryLight;
  static Color get primaryContainer => _c.primaryContainer;

  // ── SECONDARY ────────────────────────────────────────────────────────────────
  static Color get secondary => _c.secondary;
  static Color get secondaryLight => _c.secondaryLight;
  static Color get secondaryContainer => _c.secondaryContainer;

  // ── ACCENT ─────────────────────────────────────────────────────────────────────
  static Color get accent => _c.accent;
  static Color get accentLight => _c.accentLight;
  static Color get accentContainer => _c.accentContainer;

  // ── BRAND GRADIENT ─────────────────────────────────────────────────────────────
  static Color get gradientStart => _c.gradientStart;
  static Color get gradientMiddle => _c.gradientMiddle;
  static Color get gradientEnd => _c.gradientEnd;

  static LinearGradient get primaryGradient => _c.primaryGradient;
  static LinearGradient get primaryGradientShort => _c.primaryGradientShort;
  static LinearGradient get accentGradient => _c.accentGradient;

  // ── SEMANTIC ───────────────────────────────────────────────────────────────────
  static Color get success => _c.success;
  static Color get successLight => _c.successLight;
  static Color get warning => _c.warning;
  static Color get warningLight => _c.warningLight;
  static Color get error => _c.error;
  static Color get errorLight => _c.errorLight;
  static Color get info => _c.info;
  static Color get infoLight => _c.infoLight;

  // ── TEXT ───────────────────────────────────────────────────────────────────────
  static Color get textPrimary => _c.textPrimary;
  static Color get textSecondary => _c.textSecondary;
  static Color get textTertiary => _c.textTertiary;
  static Color get textDisabled => _c.textDisabled;
  static Color get textInverse => _c.textInverse;

  // ── SURFACES ─────────────────────────────────────────────────────────────────
  static Color get background => _c.background;
  static Color get backgroundSoft => _c.backgroundSoft;
  static Color get surface => _c.surface;
  static Color get surfaceVariant => _c.surfaceVariant;
  static Color get card => _c.card;
  static Color get cardHover => _c.cardHover;

  // ── BORDERS ────────────────────────────────────────────────────────────────────
  static Color get border => _c.border;
  static Color get borderDark => _c.borderDark;
  static Color get divider => _c.divider;

  // ── BUTTONS (admin-configurable) ─────────────────────────────────────────────
  static Color get buttonBg => _c.buttonBg;
  static Color get buttonText => _c.buttonText;
  static Color get secondaryButtonBg => _c.secondaryButtonBg;
  static Color get secondaryButtonText => _c.secondaryButtonText;

  // ── ICONS ──────────────────────────────────────────────────────────────────────
  static Color get iconColor => _c.iconColor;
  static Color get iconBg => _c.iconBg;
  static Color get fieldText => _c.fieldText;

  // ── MODULE ICON PALETTES (derived from brand where sensible) ─────────────────
  static Color get moduleVisitorBg => primaryContainer;
  static Color get moduleVisitorIcon => primary;
  static Color get moduleSecurityBg => const Color(0xFFEEF0FF);
  static Color get moduleSecurityIcon => const Color(0xFF4F46E5);
  static Color get moduleSocietyBg => accentLight;
  static Color get moduleSocietyIcon => accent;
  static Color get moduleFinanceBg => accentContainer;
  static Color get moduleFinanceIcon => accent;
  static Color get moduleComplaintBg => warningLight;
  static Color get moduleComplaintIcon => warning;
  static Color get moduleSOSBg => errorLight;
  static Color get moduleSOSIcon => error;
  static Color get moduleParcelBg => secondaryLight;
  static Color get moduleParcelIcon => secondary;
  static Color get moduleNoticeBg => const Color(0xFFF3E8FF);
  static Color get moduleNoticeIcon => const Color(0xFF8B5CF6);
  static Color get moduleBookingBg => _c.primaryLight.withValues(alpha: 0.35);
  static Color get moduleBookingIcon => _c.secondary;
  static Color get moduleCommunityBg => const Color(0xFFE0F2FE);
  static Color get moduleCommunityIcon => const Color(0xFF0284C7);
  static Color get moduleVehicleBg => primaryContainer;
  static Color get moduleVehicleIcon => primaryDark;
  static Color get moduleStaffBg => const Color(0xFFF1F5F9);
  static Color get moduleStaffIcon => const Color(0xFF475569);

  // ── STATUS BADGE COLORS ────────────────────────────────────────────────────────
  static Color get statusApprovedBg => successLight;
  static Color get statusApprovedText => const Color(0xFF065F46);
  static Color get statusPendingBg => warningLight;
  static Color get statusPendingText => const Color(0xFF92400E);
  static Color get statusRejectedBg => errorLight;
  static Color get statusRejectedText => const Color(0xFF991B1B);
  static Color get statusCheckedInBg => primaryContainer;
  static Color get statusCheckedInText => const Color(0xFF1E40AF);
  static Color get statusCheckedOutBg => const Color(0xFFF1F5F9);
  static Color get statusCheckedOutText => const Color(0xFF475569);

  // ── SHADOWS ────────────────────────────────────────────────────────────────────
  static Color get shadowLight => const Color(0x0D102A5C);
  static Color get shadowMedium => const Color(0x14102A5C);
  static Color get shadowHeavy => const Color(0x1F102A5C);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: shadowLight, blurRadius: 18, offset: const Offset(0, 4)),
      ];
  static List<BoxShadow> get floatShadow => [
        BoxShadow(color: shadowMedium, blurRadius: 30, offset: const Offset(0, 8)),
      ];
  static List<BoxShadow> get dialogShadow => [
        BoxShadow(color: shadowHeavy, blurRadius: 50, offset: const Offset(0, 16)),
      ];

  // ── OVERLAY / SPECIAL ──────────────────────────────────────────────────────────
  static Color get overlay => const Color(0x80102A5C);
  static Color hoverOverlay(Color base) => base.withValues(alpha: 0.05);
  static Color pressedOverlay(Color base) => base.withValues(alpha: 0.1);
  static Color focusOverlay(Color base) => base.withValues(alpha: 0.12);

  // ── ROLE BADGES ────────────────────────────────────────────────────────────────
  static Color get roleAdmin => error;
  static Color get roleResident => primary;
  static Color get roleGuard => accent;

  // ── SOS VARIANTS ───────────────────────────────────────────────────────────────
  static Color get sosMedical => error;
  static Color get sosFire => const Color(0xFFF97316);
  static Color get sosSecurity => warning;
  static Color get sosOther => textSecondary;

  // ── STATUS DOTS ────────────────────────────────────────────────────────────────
  static Color get statusOnline => accent;
  static Color get statusOffline => textTertiary;
  static Color get statusBusy => error;
  static Color get statusAway => warning;

  // ── CHART COLORS ───────────────────────────────────────────────────────────────
  static List<Color> get chartColors => [
        primary,
        accent,
        secondary,
        warning,
        const Color(0xFF8B5CF6),
        error,
        secondary,
        primaryDark,
      ];
}
