import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens for the GatePass+ theme system.
///
/// Font family is **Inter** (per brand kit), loaded via Google Fonts.
/// Sizes match the spec: 12, 14, 16, 18, 22, 28, 36, 48.
/// Weights: 400 (regular), 500 (medium), 600 (semibold), 700 (bold).
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  // Sizes
  static const double fs12 = 12;
  static const double fs14 = 14;
  static const double fs16 = 16;
  static const double fs18 = 18;
  static const double fs22 = 22;
  static const double fs28 = 28;
  static const double fs36 = 36;
  static const double fs48 = 48;

  // Weights
  static const FontWeight wRegular = FontWeight.w400;
  static const FontWeight wMedium = FontWeight.w500;
  static const FontWeight wSemibold = FontWeight.w600;
  static const FontWeight wBold = FontWeight.w700;

  /// Material 3 [TextTheme] populated with our scale.
  /// Used by [AppTheme] to wire `Theme.of(context).textTheme.*`.
  static TextTheme textTheme(Color onSurface) {
    final base = GoogleFonts.interTextTheme();
    TextStyle style(double size, FontWeight w, {double? height}) =>
        base.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: w,
          color: onSurface,
          height: height,
          fontFamilyFallback: const ['Inter'],
        );

    return TextTheme(
      displayLarge: style(fs48, wBold, height: 1.1),
      displayMedium: style(fs36, wBold, height: 1.15),
      displaySmall: style(fs28, wBold, height: 1.2),
      headlineLarge: style(fs28, wSemibold, height: 1.2),
      headlineMedium: style(fs22, wSemibold, height: 1.25),
      headlineSmall: style(fs18, wSemibold, height: 1.3),
      titleLarge: style(fs22, wSemibold, height: 1.3),
      titleMedium: style(fs16, wSemibold, height: 1.4),
      titleSmall: style(fs14, wSemibold, height: 1.4),
      bodyLarge: style(fs16, wRegular, height: 1.5),
      bodyMedium: style(fs14, wRegular, height: 1.5),
      bodySmall: style(fs12, wRegular, height: 1.45),
      labelLarge: style(fs14, wMedium, height: 1.4),
      labelMedium: style(fs12, wMedium, height: 1.4),
      labelSmall: style(fs12, wMedium, height: 1.3),
    );
  }
}
