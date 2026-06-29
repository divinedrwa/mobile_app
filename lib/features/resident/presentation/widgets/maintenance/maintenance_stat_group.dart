import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/billing_cycle_current_model.dart';

/// The four at-a-glance maintenance stats (this cycle / credit / pending bills
/// / due date) shown under the hero.
class MaintenanceStatGroup extends StatelessWidget {
  const MaintenanceStatGroup({
    super.key,
    required this.cycle,
    required this.pendingCount,
  });

  final BillingCycleCurrent? cycle;
  final int pendingCount;

  static final _inr =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _inr2 =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _dateFmt = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    // Amount billed for the current cycle (shown even after it's paid),
    // not the remaining balance.
    final thisCycle =
        (cycle?.expectedAmount ?? cycle?.amount ?? cycle?.totalDue ?? 0)
            .toDouble();
    final credit = (cycle?.availableCredit ?? 0).toDouble();
    final dueDate = cycle?.dueDateUtc;
    // Only "overdue" when there's actually something outstanding — a fully
    // paid cycle whose window has passed isn't overdue.
    final overdue =
        pendingCount > 0 && dueDate != null && dueDate.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.borderLight),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatCell(
              icon: Icons.receipt_long_outlined,
              tone: DesignColors.warning,
              label: 'This cycle',
              value: _inr.format(thisCycle),
            ),
            const _StatDivider(),
            _StatCell(
              icon: Icons.savings_outlined,
              tone: DesignColors.primary,
              label: 'Your credit',
              value: _inr2.format(credit),
              pill: credit > 0 ? 'Available' : 'Good',
              pillTone: DesignColors.success,
            ),
            const _StatDivider(),
            _StatCell(
              icon: Icons.pending_actions_outlined,
              tone: pendingCount > 0
                  ? DesignColors.warning
                  : DesignColors.success,
              label: 'Pending bills',
              value: '$pendingCount',
              pill: pendingCount > 0 ? 'Action' : 'All clear',
              pillTone:
                  pendingCount > 0 ? DesignColors.warning : DesignColors.success,
            ),
            const _StatDivider(),
            _StatCell(
              icon: Icons.event_outlined,
              tone: overdue ? DesignColors.error : DesignColors.primary,
              label: 'Due date',
              value: dueDate != null ? _dateFmt.format(dueDate) : '—',
              pill: dueDate == null ? null : (overdue ? 'Overdue' : 'On time'),
              pillTone: overdue ? DesignColors.error : DesignColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: EdgeInsets.symmetric(vertical: 4),
        color: DesignColors.borderLight,
      );
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.pill,
    this.pillTone,
  });

  final IconData icon;
  final Color tone;
  final String label;
  final String value;
  final String? pill;
  final Color? pillTone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Icon(icon, size: 15, color: tone),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DesignTypography.captionSmall.copyWith(
                color: DesignColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (pill != null) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      (pillTone ?? DesignColors.success).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pill!,
                  style: DesignTypography.captionSmall.copyWith(
                    color: pillTone ?? DesignColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
