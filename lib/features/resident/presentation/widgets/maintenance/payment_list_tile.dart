import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';

/// Single row in any maintenance / payment list. Used both for "pending
/// dues" lists (where it carries an action button) and for "history"
/// lists (where the trailing slot is a status chip).
class PaymentListTile extends StatelessWidget {
  const PaymentListTile({
    super.key,
    required this.title,
    required this.amount,
    required this.status,
    this.subtitle,
    this.dueDate,
    this.paidDate,
    this.onTap,
    this.onAction,
    this.actionLabel,
  });

  final String title;
  final String? subtitle;
  final double amount;
  final PaymentTileStatus status;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('d MMM y');
    final palette = _palette(status);

    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.iconBg,
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                    child: Icon(palette.icon, size: 18, color: palette.iconFg),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: DesignTypography.bodyMedium.copyWith(
                            color: DesignColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: DesignTypography.caption.copyWith(
                              color: DesignColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr.format(amount),
                        style: DesignTypography.bodyMedium.copyWith(
                          color: DesignColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _StatusBadge(status: status),
                    ],
                  ),
                ],
              ),
              if (dueDate != null || paidDate != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      paidDate != null
                          ? Icons.check_circle_outline
                          : Icons.event_outlined,
                      size: 14,
                      color: DesignColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      paidDate != null
                          ? 'Paid ${dateFmt.format(paidDate!)}'
                          : 'Due ${dateFmt.format(dueDate!)}',
                      style: DesignTypography.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.iconFg,
                      side: BorderSide(color: palette.iconFg.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignRadius.md),
                      ),
                      textStyle: DesignTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PaymentTileStatus status;

  @override
  Widget build(BuildContext context) {
    final p = _palette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.iconBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        p.label,
        style: DesignTypography.caption.copyWith(
          color: p.iconFg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontSize: 10,
        ),
      ),
    );
  }
}

enum PaymentTileStatus { paid, partial, pending, overdue, upcoming }

class _Palette {
  const _Palette({
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
}

_Palette _palette(PaymentTileStatus status) {
  switch (status) {
    case PaymentTileStatus.paid:
      return _Palette(
        label: 'PAID',
        icon: Icons.check_circle,
        iconBg: DesignColors.success.withValues(alpha: 0.12),
        iconFg: DesignColors.success,
      );
    case PaymentTileStatus.partial:
      return _Palette(
        label: 'PARTIAL',
        icon: Icons.adjust,
        iconBg: DesignColors.primary.withValues(alpha: 0.10),
        iconFg: DesignColors.primary,
      );
    case PaymentTileStatus.pending:
      return _Palette(
        label: 'DUE',
        icon: Icons.schedule,
        iconBg: DesignColors.warning.withValues(alpha: 0.14),
        iconFg: DesignColors.warning,
      );
    case PaymentTileStatus.overdue:
      return _Palette(
        label: 'OVERDUE',
        icon: Icons.error_outline,
        iconBg: DesignColors.error.withValues(alpha: 0.12),
        iconFg: DesignColors.error,
      );
    case PaymentTileStatus.upcoming:
      return const _Palette(
        label: 'UPCOMING',
        icon: Icons.event_available_outlined,
        iconBg: DesignColors.surfaceSoft,
        iconFg: DesignColors.textSecondary,
      );
  }
}
