import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

/// D2 — 3-step checkout progress: confirm amount → pick method → pay.
class CheckoutStepIndicator extends StatelessWidget {
  const CheckoutStepIndicator({super.key, required this.currentStep});

  /// 1 = amount, 2 = method, 3 = pay/receipt
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _step(1, 'Amount'),
        _line(1),
        _step(2, 'Method'),
        _line(2),
        _step(3, 'Pay'),
      ],
    );
  }

  Widget _step(int n, String label) {
    final active = currentStep >= n;
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: active ? DesignColors.primary : DesignColors.borderLight,
            child: Text(
              '$n',
              style: TextStyle(
                color: active ? Colors.white : DesignColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? DesignColors.textPrimary : DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(int afterStep) {
    final done = currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: done ? DesignColors.primary : DesignColors.borderLight,
      ),
    );
  }
}
