part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOverviewHeadersPart on _MaintenancePaymentScreenState {
  Widget _collapsibleSectionHeader(
    String title,
    String subtitle, {
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: DesignTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.text.primary,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: DesignTypography.caption.copyWith(
                  color: context.text.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
              color: context.text.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: DesignTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: context.text.primary,
                fontSize: 15,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: DesignTypography.caption.copyWith(
                color: context.text.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

}
