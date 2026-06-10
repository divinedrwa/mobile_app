import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/maintenance_due_model.dart';
import 'home_shared.dart';

class HomeOutstandingDues extends StatelessWidget {
  const HomeOutstandingDues({
    super.key,
    required this.pendingState,
    required this.onRetry,
  });

  final AsyncValue<List<MaintenanceDueModel>> pendingState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return pendingState.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 72, borderRadius: DesignRadius.xl),
      ),
      error: (_, _) => Material(
        color: context.surface.defaultSurface,
        borderRadius: DesignRadius.borderXL,
        child: InkWell(
          onTap: onRetry,
          borderRadius: DesignRadius.borderXL,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: DesignRadius.borderXL,
              border: Border.all(color: const Color(0xFFFFCDD2)),
              boxShadow: DesignElevation.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load dues. Tap to retry.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(Icons.refresh_rounded,
                    color: Colors.red.shade700, size: 22),
              ],
            ),
          ),
        ),
      ),
      data: (pending) {
        final inr = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );
        final totalDue = pending.fold<double>(
            0, (sum, item) => sum + item.remainingDue);
        final hasDue = totalDue > 0;
        if (!hasDue) {
          return const SizedBox.shrink();
        }

        final count = pending.length;
        DateTime? earliestDue;
        for (final item in pending) {
          earliestDue =
              earliestDue == null || item.dueDate.isBefore(earliestDue)
                  ? item.dueDate
                  : earliestDue;
        }

        final now = DateTime.now();

        final String statusLabel;
        final Color accent;
        final Color badgeBg;
        final Color badgeFg;

        if (earliestDue == null) {
          statusLabel = 'Due';
          accent = DesignColors.primary;
          badgeBg = DesignColors.primary.withValues(alpha: 0.12);
          badgeFg = DesignColors.primary;
        } else if (earliestDue.isBefore(now)) {
          statusLabel = 'Overdue';
          accent = DesignColors.error;
          badgeBg = const Color(0xFFFEE2E2);
          badgeFg = const Color(0xFFB91C1C);
        } else {
          statusLabel = 'Due soon';
          accent = const Color(0xFFD97706);
          badgeBg = const Color(0xFFFEF3C7);
          badgeFg = const Color(0xFFB45309);
        }

        final String scheduleLine;
        if (earliestDue == null) {
          scheduleLine = 'Tap to review and pay';
        } else if (earliestDue.isBefore(now)) {
          final overdueDays =
              now.difference(earliestDue).inDays.abs();
          scheduleLine =
              '$overdueDays day${overdueDays == 1 ? '' : 's'} overdue · ${DateFormat('dd MMM yyyy').format(earliestDue)}';
        } else {
          final daysLeft =
              earliestDue.difference(now).inDays + 1;
          scheduleLine =
              '${DateFormat('dd MMM yyyy').format(earliestDue)} · $daysLeft day${daysLeft == 1 ? '' : 's'} left';
        }

        final countHint = count > 1 ? ' · $count charges' : '';

        void openPayments() =>
            context.push('/resident/maintenance/dues');

        return Padding(
          padding: const EdgeInsets.only(bottom: kHomeSectionGap),
          child: Material(
          color: context.surface.defaultSurface,
          borderRadius: DesignRadius.borderLG,
          elevation: 0,
          child: InkWell(
            borderRadius: DesignRadius.borderLG,
            onTap: () {
              DesignHaptics.selection();
              openPayments();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: DesignRadius.borderLG,
                border: Border.all(
                    color: accent.withValues(alpha: 0.28)),
                boxShadow: DesignElevation.sm,
              ),
              padding:
                  const EdgeInsets.fromLTRB(0, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.95),
                      borderRadius:
                          const BorderRadius.horizontal(
                              right: Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 22,
                      color:
                          accent.withValues(alpha: 0.95)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Outstanding dues',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DesignColors
                                    .textSecondary,
                                letterSpacing: 0.05,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius:
                                    BorderRadius.circular(
                                        20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: badgeFg,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$scheduleLine$countHint',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color:
                                context.text.secondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inr.format(totalDue),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color:
                              DesignColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.primary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: DesignColors.textTertiary
                          .withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }
}
