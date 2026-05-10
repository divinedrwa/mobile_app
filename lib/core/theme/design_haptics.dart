import 'package:flutter/services.dart';

/// Centralized haptic feedback patterns for the Divine App.
///
/// Maps interaction types to appropriate haptic intensities.
/// Use these instead of calling [HapticFeedback] directly.
abstract final class DesignHaptics {
  /// Light tap — tab switches, toggle changes, chip selection.
  static void selection() => HapticFeedback.selectionClick();

  /// Medium tap — button presses, card taps, navigation actions.
  static void impact() => HapticFeedback.mediumImpact();

  /// Heavy tap — important confirmations: SOS sent, payment confirmed,
  /// QR code scanned, destructive action confirmed.
  static void success() => HapticFeedback.heavyImpact();

  /// Double-tap pattern — error states, form validation failures.
  /// Uses lightImpact since errors shouldn't feel heavy.
  static void error() => HapticFeedback.lightImpact();

  /// Warning tap — approaching limits, overdue reminders.
  static void warning() => HapticFeedback.mediumImpact();

  /// Notification arrival — new push notification while app is open.
  static void notification() => HapticFeedback.selectionClick();
}
