import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/maintenance_provider.dart';
import '../widgets/list_skeleton.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(maintenanceHistoryProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(title: const Text('Payment History')),
      body: historyState.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.receipt_long_outlined,
            title: 'Could not load payment history',
            message: error.toString(),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(maintenanceHistoryProvider),
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
          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.spacing.s16,
              context.spacing.s16,
              context.spacing.s16,
              context.spacing.s32,
            ),
            children: [
              const EnterpriseInfoBanner(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Maintenance payment ledger',
                message:
                    'Review recent payments, credit adjustments, dues, and overdue amounts in one place.',
                tone: EnterpriseTone.info,
              ),
              SizedBox(height: context.spacing.s24),
              EnterpriseSectionHeader(
                title: 'Transactions',
                subtitle:
                    '${records.length} ${records.length == 1 ? 'record' : 'records'} available',
              ),
              SizedBox(height: context.spacing.s12),
              for (int index = 0; index < records.length; index++)
                _PaymentHistoryCard(record: records[index])
                    .animate()
                    .fadeIn(
                      duration: 300.ms,
                      delay: DesignAnimations.staggerFor(index),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.record});

  final dynamic record;

  @override
  Widget build(BuildContext context) {
    final paidDate = record.paidAt ?? record.dueDate;
    final monthLabel =
        DateFormat('MMM yyyy').format(DateTime(record.year, record.month));
    final status = record.status.toUpperCase();
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
    final trailingAmount = record.cashPaidAmount > 0
        ? record.cashPaidAmount
        : (record.creditApplied > 0
            ? record.creditApplied
            : (record.paidAmount > 0 ? record.paidAmount : record.amount));

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.receipt_long_rounded, color: statusColor),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maintenance - $monthLabel',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    record.paidAt != null
                        ? DateFormat('dd MMM yyyy').format(paidDate)
                        : status == 'AUTO_SETTLED'
                            ? 'Adjusted from previous credit'
                            : 'Remaining due INR ${record.remainingDue.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'INR ${trailingAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.text.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: context.spacing.s4),
                _BillingStatusChip(
                  label: statusLabel,
                  color: statusColor,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  borderColor: statusColor.withValues(alpha: 0.24),
                ),
              ],
            ),
          ],
        ),
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
