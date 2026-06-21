import 'package:flutter/material.dart';

import '../theme/design_animations.dart';
import '../theme/design_haptics.dart';

/// Wraps any [child] with a quick press-down scale + light haptic, giving
/// tactile "this is tappable" feedback without imposing visual styling.
///
/// Use this for bespoke tappable surfaces (tiles, chips, custom rows) that
/// aren't a [PolishedCard]/[PolishedButton]. For standard Material rows where
/// an ink ripple is enough, prefer `InkWell`.
///
/// Cheap by design: a single implicit [AnimatedScale]; no [AnimationController],
/// no rebuild of [child]. Honors the OS "reduce motion" setting.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = DesignAnimations.scaleCardPressed,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Pressed-state scale (defaults to the card-press token, 0.97).
  final double scale;

  /// Fire a light selection haptic on press.
  final bool haptic;

  final HitTestBehavior behavior;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = (_pressed && !reduceMotion) ? widget.scale : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _interactive
          ? (_) {
              _setPressed(true);
              if (widget.haptic) DesignHaptics.selection();
            }
          : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: target,
        duration: DesignAnimations.durationInteraction,
        curve: DesignAnimations.curveInteraction,
        child: widget.child,
      ),
    );
  }
}
