import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Application typography — Plus Jakarta Sans via [GoogleFonts] so Android and iOS
/// render identical glyphs (no Roboto vs SF Pro fallback mismatch).
class AppTypography {
  AppTypography._();

  /// Resolved font family name after Google Fonts registration.
  static String get fontFamily =>
      GoogleFonts.plusJakartaSans().fontFamily ?? 'Plus Jakarta Sans';

  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.3,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0.2,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.5,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.normal,
        height: 1.4,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      );

  static TextStyle get overline => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
      );
}
