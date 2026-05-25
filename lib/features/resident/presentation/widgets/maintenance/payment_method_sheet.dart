import 'package:flutter/material.dart';

import '../../../../../theme/context_extensions.dart';

/// Payment method selection options.
enum PaymentMethodOption {
  razorpay,
  phonePe,
  ;

  String get label {
    switch (this) {
      case PaymentMethodOption.razorpay:
        return 'Pay Online';
      case PaymentMethodOption.phonePe:
        return 'PhonePe';
    }
  }

  String get subtitle {
    switch (this) {
      case PaymentMethodOption.razorpay:
        return 'Credit/Debit Card, UPI, Net Banking';
      case PaymentMethodOption.phonePe:
        return 'UPI via PhonePe';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethodOption.razorpay:
        return Icons.credit_card_rounded;
      case PaymentMethodOption.phonePe:
        return Icons.phone_android_rounded;
    }
  }
}

/// Bottom sheet for selecting a payment gateway.
///
/// Returns the chosen [PaymentMethodOption] or `null` if dismissed.
/// Pass [availableMethods] to control which options are shown (e.g.
/// hide PhonePe when it isn't configured for the society).
class PaymentMethodSheet {
  PaymentMethodSheet._();

  static Future<PaymentMethodOption?> show(
    BuildContext context, {
    List<PaymentMethodOption> availableMethods = PaymentMethodOption.values,
    double? amount,
  }) {
    return showModalBottomSheet<PaymentMethodOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose payment method',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (amount != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Amount: \u20B9${amount.toStringAsFixed(0)}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: ctx.text.secondary,
                      ),
                ),
              ],
              const SizedBox(height: 16),
              ...availableMethods.map((m) => _MethodTile(
                    method: m,
                    onTap: () => Navigator.of(ctx).pop(m),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.onTap});

  final PaymentMethodOption method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.surface.elevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(method.icon, size: 24, color: context.brand.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        method.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.text.secondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.text.tertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
