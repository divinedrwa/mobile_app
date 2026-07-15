part of '../maintenance_payment_screen.dart';
extension _MaintenanceDashboardOverviewDuesPart on _MaintenancePaymentScreenState {
  Widget _buildOverviewDuesStrip(
    double remaining,
    NumberFormat inr,
  ) {
    if (remaining <= 0.005) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Material(
          color: DesignColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _goToDues,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: DesignColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your dues',
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          inr.format(remaining),
                          style: DesignTypography.headingM.copyWith(
                            fontWeight: FontWeight.w800,
                            color: DesignColors.warning,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _goToDues,
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Pay',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
