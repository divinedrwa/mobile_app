import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../polished_card.dart';

/// GatePass+ surface card — white fill, 16px radius, optional tap.
class GpCard extends StatelessWidget {
  const GpCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.showShadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return PolishedCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      showShadow: showShadow,
      color: DesignColors.surface,
      borderRadius: 16,
      child: child,
    );
  }
}
