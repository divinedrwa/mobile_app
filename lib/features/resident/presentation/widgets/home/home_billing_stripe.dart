import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/billing_cycle_current_model.dart';
import 'home_shared.dart';

class HomeBillingStripe extends StatelessWidget {
  const HomeBillingStripe({
    super.key,
    required this.cycle,
  });

  final BillingCycleCurrent cycle;

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final total = cycle.totalDue ?? cycle.amount ?? 0;
    final availableCredit = cycle.availableCredit ?? 0;
    final remainingDue = cycle.remainingDue ?? total;
    final isPayableNow = cycle.status?.isOpen == true;
    final isClosed = cycle.status?.isClosed == true;
    final statusLabel = cycle.status?.isOpen == true
        ? 'OPEN'
        : cycle.status?.isUpcoming == true
            ? 'UPCOMING'
            : cycle.status?.isClosed == true
                ? 'CLOSED'
                : 'BILLING';

    if (!isPayableNow &&
        cycle.status?.isUpcoming != true &&
        !isClosed) {
      return const SizedBox.shrink();
    }

    final Color accentColor;
    final IconData accentIcon;
    final String amountLine;

    if (isPayableNow) {
      accentColor = kHomeOrange;
      accentIcon = Icons.event_available_rounded;
      final windowEnd = cycle.dueDateUtc ?? cycle.paymentEndUtc;
      final subtitle = windowEnd != null
          ? 'Pay before ${DateFormat('dd MMM, HH:mm').format(windowEnd.toLocal())}'
          : 'Payment window open';
      amountLine = availableCredit > 0
          ? '$subtitle · ${inr.format(remainingDue)} due after ${inr.format(availableCredit)} credit'
          : '$subtitle · ${inr.format(total)} due';
    } else if (cycle.status?.isUpcoming == true) {
      accentColor = DesignColors.primary;
      accentIcon = Icons.schedule_rounded;
      final start = cycle.paymentStartUtc;
      final dueText = availableCredit > 0
          ? '${inr.format(remainingDue)} due after ${inr.format(availableCredit)} credit'
          : '${inr.format(total)} due';
      amountLine = start != null
          ? 'Opens ${DateFormat('dd MMM, HH:mm').format(start.toLocal())} · $dueText'
          : 'Opening soon · $dueText';
    } else {
      accentColor = DesignColors.error;
      accentIcon = Icons.lock_clock_outlined;
      amountLine = remainingDue > 0
          ? 'Window closed · ${inr.format(remainingDue)} remains due'
          : 'Window closed';
    }

    return Material(
      color: context.surface.defaultSurface,
      borderRadius: DesignRadius.borderLG,
      child: InkWell(
        borderRadius: DesignRadius.borderLG,
        onTap: () {
          DesignHaptics.selection();
          context.push('/resident/maintenance');
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: DesignRadius.borderLG,
            border: Border.all(
                color: accentColor.withValues(alpha: 0.35)),
            boxShadow: DesignElevation.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  accentIcon,
                  size: 22,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor
                                .withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(999),
                            border: Border.all(
                                color: accentColor
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if ((cycle.cycleKey ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            cycle.cycleKey!,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: context.text.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cycle.title ?? 'Maintenance billing',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountLine,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.text.secondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPayableNow)
                FilledButton(
                  onPressed: () =>
                      context.push('/resident/maintenance'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pay now',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: () =>
                      context.push('/resident/maintenance'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    side: BorderSide(
                        color: DesignColors.primary
                            .withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
