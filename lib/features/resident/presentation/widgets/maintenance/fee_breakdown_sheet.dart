import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../theme/context_extensions.dart';

/// Reusable bottom sheet showing a categorised expense breakdown.
///
/// Call [show] to present it. Designed to replace inline
/// `showModalBottomSheet` calls in `maintenance_payment_screen.dart`.
class FeeBreakdownSheet {
  FeeBreakdownSheet._();

  static void show(
    BuildContext context, {
    required int month,
    required int year,
    required double totalExpense,
    required Map<String, double> breakdown,
  }) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(year, month));

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ctx.brand.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: ctx.brand.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense breakdown',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          monthLabel,
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                color: ctx.text.secondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ctx.brand.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inr.format(totalExpense),
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ctx.brand.primary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...sorted.map((e) => _CategoryRow(
                    label: e.key,
                    amount: e.value,
                    fraction: totalExpense > 0 ? e.value / totalExpense : 0,
                    inr: inr,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.inr,
  });

  final String label;
  final double amount;
  final double fraction;
  final NumberFormat inr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                inr.format(amount),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: context.surface.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(context.brand.primary),
            ),
          ),
        ],
      ),
    );
  }
}
