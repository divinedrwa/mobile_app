import 'package:flutter/material.dart';
import '../theme/app_elevations.dart';
import '../theme/design_animations.dart';
import '../theme/design_haptics.dart';
import '../theme/design_tokens.dart';

/// Ultra-polished card widget with native feel
class PolishedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showShadow;
  final double borderRadius;

  const PolishedCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.padding,
    this.margin,
    this.showShadow = true,
    this.borderRadius = 16,
  });

  @override
  State<PolishedCard> createState() => _PolishedCardState();
}

class _PolishedCardState extends State<PolishedCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseBg = widget.color ?? theme.cardColor;
    final bgColor = _isHovered
        ? Color.alphaBlend(
            theme.primaryColor.withValues(alpha: 0.04), baseBg)
        : baseBg;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _isPressed = false);
        DesignHaptics.selection();
        widget.onTap!();
      } : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: DesignAnimations.durationInteraction,
        curve: DesignAnimations.curveInteraction,
        margin: widget.margin,
        transform: Matrix4.identity()
          ..scaleByDouble(_isPressed ? DesignAnimations.scaleCardPressed : 1.0, _isPressed ? DesignAnimations.scaleCardPressed : 1.0, 1.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.showShadow
                ? AppElevations.cardShadow(theme.shadowColor)
                : null,
          ),
          child: Material(
            color: DesignColors.surface.withValues(alpha: 0),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(DesignSpacing.cardPadding),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
