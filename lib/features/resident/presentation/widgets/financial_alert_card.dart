import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';

/// Ultra-polished Financial Alert Card with native feel
class FinancialAlertCard extends StatelessWidget {
  final double amount;
  final DateTime dueDate;
  final bool isOverdue;
  final VoidCallback onPayNow;

  const FinancialAlertCard({
    super.key,
    required this.amount,
    required this.dueDate,
    required this.isOverdue,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? Colors.red : Colors.orange;
    final formattedAmount = '₹${amount.toStringAsFixed(0)}';
    final formattedDate = DateFormat('MMM dd, yyyy').format(dueDate);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.shade50, color.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPayNow,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade600, color.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isOverdue ? Icons.warning_rounded : Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge + Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.shade700,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.shade700.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                isOverdue ? 'OVERDUE' : 'PENDING',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Maintenance Due',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: color.shade900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Amount
                        Text(
                          formattedAmount,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: color.shade900,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                        ),
                        const SizedBox(height: 4),
                        // Due Date
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: color.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Due: $formattedDate',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: color.shade800,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Arrow Button
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: color.shade900,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic)
        .shimmer(duration: 1800.ms, delay: 600.ms);
  }
}
