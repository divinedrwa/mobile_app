import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Distinct hues for charts and expense categories — not society brand colors.
///
/// Data viz needs stable, distinguishable slices. These read from the active
/// theme where possible (info/warning/error) and use a fixed rotation for
/// categories without a named mapping.
abstract final class ChartPalette {
  static const Map<String, Color> expenseCategory = {
    'Electricity': Color(0xFFF59E0B),
    'Water': Color(0xFF3B82F6),
    'Garbage Collection': Color(0xFF10B981),
    'Security Salary': Color(0xFF8B5CF6),
    'Housekeeping Salary': Color(0xFFEC4899),
    'Maintenance Staff': Color(0xFF6366F1),
    'Gardening': Color(0xFF22C55E),
    'Pest Control': Color(0xFFEF4444),
    'Lift Maintenance': Color(0xFF14B8A6),
    'Generator Maintenance': Color(0xFFF97316),
    'Pump Maintenance': Color(0xFF06B6D4),
    'Common Area Repair': Color(0xFF78716C),
    'Legal Fees': Color(0xFF64748B),
    'Insurance': Color(0xFF0EA5E9),
    'Taxes': Color(0xFFA855F7),
    'Bank Charges': Color(0xFF84CC16),
    'Software Subscription': Color(0xFF2563EB),
  };

  static const List<Color> fallbackSeries = [
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFFEC4899),
  ];

  /// Stable color for a chart slice / expense row.
  static Color expense(String category, int index, {Color? neutral}) {
    if (category == 'Other') {
      return neutral ?? DesignColors.textTertiary;
    }
    return expenseCategory[category] ??
        fallbackSeries[index % fallbackSeries.length];
  }

  static Color series(int index) =>
      fallbackSeries[index % fallbackSeries.length];
}
