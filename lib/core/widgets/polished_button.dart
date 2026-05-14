import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_elevations.dart';
import '../theme/app_spacing.dart';
import '../theme/design_animations.dart';
import '../theme/design_haptics.dart';
import '../theme/design_tokens.dart';

/// Ultra-polished button with native feel
class PolishedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double borderRadius;

  const PolishedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.borderRadius = 14,
  });

  @override
  State<PolishedButton> createState() => _PolishedButtonState();
}

class _PolishedButtonState extends State<PolishedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.primaryColor;
    final textColor = widget.textColor ?? DesignColors.surface;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) {
        setState(() => _isPressed = false);
        DesignHaptics.impact();
        widget.onPressed!();
      } : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: Container(
          width: widget.isFullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: isEnabled ? buttonColor : DesignColors.textTertiary,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isEnabled
                ? AppElevations.buttonShadow(buttonColor)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: widget.isLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: widget.isFullWidth
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: textColor, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.text,
                            style: DesignTypography.button.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
    )
        .animate(target: _isPressed ? 1 : 0)
        .scaleXY(
          begin: 1,
          end: DesignAnimations.scalePressed,
          duration: DesignAnimations.durationInteraction,
        );
  }
}

/// Outlined polished button
class PolishedOutlinedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const PolishedOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<PolishedOutlinedButton> createState() => _PolishedOutlinedButtonState();
}

class _PolishedOutlinedButtonState extends State<PolishedOutlinedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.primaryColor;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) {
        setState(() => _isPressed = false);
        DesignHaptics.impact();
        widget.onPressed!();
      } : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: DesignAnimations.durationInteraction,
        curve: DesignAnimations.curveInteraction,
        transform: Matrix4.identity()
          ..scaleByDouble(_isPressed ? DesignAnimations.scalePressed : 1.0, _isPressed ? DesignAnimations.scalePressed : 1.0, 1.0, 1.0),
        child: Container(
          width: widget.isFullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: _isPressed ? buttonColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEnabled ? buttonColor : DesignColors.textTertiary,
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: widget.isLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: widget.isFullWidth
                            ? MainAxisSize.max
                            : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: buttonColor, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.text,
                            style: DesignTypography.button.copyWith(
                              color: buttonColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
