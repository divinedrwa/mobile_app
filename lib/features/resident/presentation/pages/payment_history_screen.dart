import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/maintenance_provider.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../widgets/list_skeleton.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(maintenanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: historyState.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(maintenanceHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'No payment history',
              subtitle: 'Your maintenance payment records will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final payment = records[index];
              final paidDate = payment.paidAt ?? payment.dueDate;
              final monthLabel = DateFormat(
                'MMM yyyy',
              ).format(DateTime(payment.year, payment.month));
              final status = payment.status.toUpperCase();
              final statusColor = switch (status) {
                'AUTO_SETTLED' => DesignColors.primary,
                'PARTIAL' => DesignColors.warning,
                'OVERDUE' => DesignColors.error,
                'PENDING' => DesignColors.warning,
                _ => DesignColors.success,
              };
              final statusLabel = switch (status) {
                'AUTO_SETTLED' => 'CREDIT',
                'PARTIAL' => 'PARTIAL',
                'OVERDUE' => 'OVERDUE',
                'PENDING' => 'DUE',
                _ => 'PAID',
              };
              final statusBg = statusColor.withValues(alpha: 0.12);
              final statusBorder = statusColor.withValues(alpha: 0.26);
              final trailingAmount = payment.cashPaidAmount > 0
                  ? payment.cashPaidAmount
                  : (payment.creditApplied > 0
                      ? payment.creditApplied
                      : (payment.paidAmount > 0
                          ? payment.paidAmount
                          : payment.amount));
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: DesignRadius.borderMD,
                    ),
                    child: Icon(Icons.check_circle, color: statusColor),
                  ),
                  title: Text(
                    'Maintenance - $monthLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    payment.paidAt != null
                        ? DateFormat('dd MMM yyyy').format(paidDate)
                        : status == 'AUTO_SETTLED'
                        ? 'Adjusted from previous credit'
                        : 'Remaining due ₹${payment.remainingDue.toStringAsFixed(0)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${trailingAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      _BillingStatusChip(
                        label: statusLabel,
                        color: statusColor,
                        backgroundColor: statusBg,
                        borderColor: statusBorder,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: DesignAnimations.staggerFor(index));
            },
          );
        },
      ),
    );
  }
}

class _BillingStatusChip extends StatelessWidget {
  const _BillingStatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
