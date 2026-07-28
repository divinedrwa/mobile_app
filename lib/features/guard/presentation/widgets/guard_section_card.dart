import 'package:flutter/material.dart';

import '../../ui/guard_tokens.dart';

/// Premium form/list section shell — [Material] + border (+ subtle light shadow).
///
/// Replaces raw [Card] widgets so guard flows match active-entries / dashboard polish.
class GuardSectionCard extends StatelessWidget {
  const GuardSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GuardTokens.padScreen),
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = GuardTokens.radiusCard,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = color ?? Theme.of(context).colorScheme.surface;
    final side = borderColor ??
        (isDark
            ? GuardTokens.darkBorder.withValues(alpha: 0.85)
            : GuardTokens.borderSubtle.withValues(alpha: 0.9));

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: showShadow && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(color: side),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
