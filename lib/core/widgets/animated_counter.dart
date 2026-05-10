import 'package:flutter/material.dart';

import '../theme/design_animations.dart';

/// Smoothly animates an integer value change (count-up effect).
///
/// Used on dashboard stats, badge counts, and anywhere a number
/// should "roll" to its new value instead of snapping.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle style;
  final Duration? duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration ?? DesignAnimations.durationCounter,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(
          '$prefix${v.round()}$suffix',
          style: style,
        );
      },
    );
  }
}
