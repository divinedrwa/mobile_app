import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/providers/maintenance_provider.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(maintenanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 72,
                      color: DesignColors.textSecondary.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No maintenance payments yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: DesignColors.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Paid invoices will appear here once maintenance is marked paid.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DesignColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final paid = records
              .where((r) => r.status.toUpperCase() == 'PAID')
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: paid.length,
            itemBuilder: (context, index) {
              final payment = paid[index];
              final paidDate = payment.dueDate;
              final monthLabel = DateFormat(
                'MMM yyyy',
              ).format(DateTime(payment.year, payment.month));
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: DesignColors.success.withValues(alpha: 0.1),
                      borderRadius: DesignRadius.borderMD,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: DesignColors.success,
                    ),
                  ),
                  title: Text(
                    'Maintenance - $monthLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(paidDate)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${payment.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: DesignColors.success.withValues(alpha: 0.1),
                          borderRadius: DesignRadius.borderXS,
                        ),
                        child: const Text(
                          'PAID',
                          style: TextStyle(
                            fontSize: 10,
                            color: DesignColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
            },
          );
        },
      ),
    );
  }
}
