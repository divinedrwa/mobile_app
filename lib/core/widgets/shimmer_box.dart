import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/design_tokens.dart';

/// A single shimmer placeholder box used in skeleton loaders.
///
/// Use [ShimmerWrap] to wrap multiple [ShimmerBox] instances
/// so they share a single shimmer animation (avoids visual jitter).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = DesignRadius.lg,
  });

  /// Fixed width. Defaults to fill parent.
  final double? width;

  /// Fixed height. Required in most layouts.
  final double? height;

  /// Corner rounding. Defaults to 12dp (card radius).
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Wraps children in a single [Shimmer] animation so multiple
/// [ShimmerBox] placeholders pulse in sync.
///
/// ```dart
/// ShimmerWrap(
///   child: Column(children: [
///     ShimmerBox(height: 120),
///     SizedBox(height: 16),
///     Row(children: [
///       Expanded(child: ShimmerBox(height: 80)),
///       SizedBox(width: 16),
///       Expanded(child: ShimmerBox(height: 80)),
///     ]),
///   ]),
/// )
/// ```
class ShimmerWrap extends StatelessWidget {
  const ShimmerWrap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? const Color(0xFF2A2F3D) // dark mode shimmer base
          : DesignColors.surfaceSoft,
      highlightColor: isDark
          ? const Color(0xFF353B4A) // dark mode shimmer highlight
          : DesignColors.surface,
      child: child,
    );
  }
}
