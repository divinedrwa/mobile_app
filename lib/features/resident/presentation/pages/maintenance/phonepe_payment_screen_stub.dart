import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_tokens.dart';

/// Web placeholder — PhonePe requires a native WebView which is unavailable
/// on web. The payment method selection screen already hides the PhonePe
/// option on web, but this stub exists as a safety net.
class PhonePePaymentScreen extends ConsumerWidget {
  const PhonePePaymentScreen({
    super.key,
    required this.cycleId,
    required this.amount,
    required this.month,
    required this.year,
    this.payAllPending = false,
  });

  final String cycleId;
  final double amount;
  final int month;
  final int year;
  final bool payAllPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhonePe Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smartphone, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'PhonePe payments are not available on web.',
                textAlign: TextAlign.center,
                style: DesignTypography.label.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please use the mobile app or choose another payment method.',
                textAlign: TextAlign.center,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
