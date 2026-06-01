import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized haptic feedback patterns for the Divine App.
///
/// Maps interaction types to appropriate haptic intensities.
/// Use these instead of calling [HapticFeedback] directly.
/// All methods are no-ops on web (no haptic hardware).
abstract final class DesignHaptics {
  /// Light tap — tab switches, toggle changes, chip selection.
  static void selection() {
    if (!kIsWeb) HapticFeedback.selectionClick();
  }

  /// Medium tap — button presses, card taps, navigation actions.
  static void impact() {
    if (!kIsWeb) HapticFeedback.mediumImpact();
  }

  /// Heavy tap — important confirmations: SOS sent, payment confirmed,
  /// QR code scanned, destructive action confirmed.
  static void success() {
    if (!kIsWeb) HapticFeedback.heavyImpact();
  }

  /// Double-tap pattern — error states, form validation failures.
  /// Uses lightImpact since errors shouldn't feel heavy.
  static void error() {
    if (!kIsWeb) HapticFeedback.lightImpact();
  }

  /// Warning tap — approaching limits, overdue reminders.
  static void warning() {
    if (!kIsWeb) HapticFeedback.mediumImpact();
  }

  /// Notification arrival — new push notification while app is open.
  static void notification() {
    if (!kIsWeb) HapticFeedback.selectionClick();
  }
}
