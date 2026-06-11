import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/maintenance_due_model.dart';

/// Compact recent-payment row with an inline receipt-download icon.
class RecentPaymentRow extends StatelessWidget {
  const RecentPaymentRow({
    super.key,
    required this.item,
    required this.inr,
    required this.downloading,
    required this.onTap,
    this.onDownload,
  });

  final MaintenanceDueModel item;
  final NumberFormat inr;
  final bool downloading;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final title = item.title.isNotEmpty
        ? item.title
        : DateFormat('MMMM y').format(DateTime(item.year, item.month));
    final paidAmount =
        item.cashPaidAmount > 0 ? item.cashPaidAmount : item.paidAmount;
    final paidOn = item.paidAt != null
        ? 'Paid on ${DateFormat('d MMM y').format(item.paidAt!)}'
        : 'Paid';
    final ref = item.cycleKey.isNotEmpty ? ' · ${item.cycleKey}' : '';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            const Icon(Icons.check_circle,
                size: 22, color: DesignColors.success),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$paidOn$ref',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  inr.format(paidAmount),
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: DesignColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PAID',
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            if (onDownload != null)
              IconButton(
                tooltip: 'Download receipt',
                onPressed: downloading ? null : onDownload,
                icon: downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded,
                        size: 20, color: DesignColors.textSecondary),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
