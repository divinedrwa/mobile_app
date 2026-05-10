import 'package:flutter/material.dart';

import '../../../../../core/theme/design_tokens.dart';

/// Single key-value row used inside the cycle detail breakdown card.
/// Visually a label on the left, an amount on the right, optionally with
/// a coloured emphasis (e.g. red for "Overdue amount", green for "Credit
/// applied"). Multiple rows stack with `const Divider()` between them.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.icon,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: DesignColors.textTertiary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: (bold
                    ? DesignTypography.bodyMedium
                    : DesignTypography.bodySmall)
                .copyWith(
              color: valueColor ?? DesignColors.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
