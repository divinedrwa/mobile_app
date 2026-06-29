import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../polished_button.dart';

/// GatePass+ approve / success action — emerald fill, white label.
class GpApproveButton extends StatelessWidget {
  const GpApproveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return PolishedButton(
      text: text,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      color: DesignColors.accent,
      textColor: Colors.white,
    );
  }
}
