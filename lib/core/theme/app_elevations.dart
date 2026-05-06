import 'package:flutter/material.dart';

/// Ultra-polished elevation and shadow system
class AppElevations {
  AppElevations._();

  /// No elevation
  static const double none = 0;

  /// Very subtle elevation
  static const double subtle = 2;

  /// Small elevation for cards
  static const double small = 4;

  /// Medium elevation for raised elements
  static const double medium = 8;

  /// Large elevation for floating elements
  static const double large = 12;

  /// Extra large elevation for dialogs
  static const double xlarge = 16;

  /// Maximum elevation for modals
  static const double max = 24;

  /// Get shadow for custom colors
  static List<BoxShadow> getShadow(
    Color color, {
    double elevation = small,
    double opacity = 0.15,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: elevation * 1.5,
        offset: Offset(0, elevation / 2),
      ),
    ];
  }

  /// Card shadow
  static List<BoxShadow> cardShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  /// Button shadow
  static List<BoxShadow> buttonShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  /// Floating shadow
  static List<BoxShadow> floatingShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}
