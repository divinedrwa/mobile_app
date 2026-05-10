import 'package:flutter/animation.dart';

/// Standardized animation tokens for the Divine App.
///
/// Ensures consistent motion throughout the app.
/// All durations, curves, and distances are defined here —
/// screens should never use raw `Duration` or `Offset` values for entrance animations.
abstract final class DesignAnimations {
  // ── DURATIONS ──

  /// Ultra-fast interactions (button press scale, toggle flip) — 100ms
  static const Duration durationFast = Duration(milliseconds: 100);

  /// Standard interactions (card press, state change) — 150ms
  static const Duration durationInteraction = Duration(milliseconds: 150);

  /// Content entrance (fade-in, slide-in) — 280ms
  static const Duration durationEntrance = Duration(milliseconds: 280);

  /// Emphasized entrance (hero cards, success reveals) — 400ms
  static const Duration durationEmphasis = Duration(milliseconds: 400);

  /// Slow / celebratory (confetti, elastic bounces) — 600ms
  static const Duration durationSlow = Duration(milliseconds: 600);

  /// Counter / number animation — 800ms
  static const Duration durationCounter = Duration(milliseconds: 800);

  // ── CURVES ──

  /// Standard entrance for content appearing on screen
  static const Curve curveEntrance = Curves.easeOutCubic;

  /// Exit / dismissal curve
  static const Curve curveExit = Curves.easeInCubic;

  /// Emphasized / bouncy entrance (success states, celebrations)
  static const Curve curveEmphasis = Curves.elasticOut;

  /// Smooth deceleration for slides
  static const Curve curveDecelerate = Curves.decelerate;

  /// Standard interaction curve (press/release)
  static const Curve curveInteraction = Curves.easeOut;

  // ── SLIDE DISTANCES ──
  // These are the `begin` values for `.slideY()` / `.slideX()` in flutter_animate.
  // Positive = starts below/right and slides to position.

  /// Subtle slide for card/list item entrances — 0.04
  static const double slideSubtle = 0.04;

  /// Normal slide for section entrances — 0.06
  static const double slideNormal = 0.06;

  /// Emphasis slide for modals/hero content — 0.10
  static const double slideEmphasis = 0.10;

  // ── SCALE VALUES ──

  /// Button press scale (pressed state)
  static const double scalePressed = 0.95;

  /// Card press scale (pressed state)
  static const double scaleCardPressed = 0.97;

  /// Quick action card press scale
  static const double scaleQuickAction = 0.92;

  // ── STAGGER DELAYS ──

  /// Delay between consecutive list item animations — 50ms
  static const Duration staggerDelay = Duration(milliseconds: 50);

  /// Calculates staggered delay for a list item at [index].
  static Duration staggerFor(int index) =>
      Duration(milliseconds: 50 * index);

  /// Calculates staggered delay for a section (slower stagger) at [index].
  static Duration sectionStaggerFor(int index) =>
      Duration(milliseconds: 80 * index);

  // ── FADE ──

  /// Default fade-in begin opacity
  static const double fadeBegin = 0.0;

  /// Default fade-in end opacity
  static const double fadeEnd = 1.0;
}
