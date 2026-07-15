part of '../admin_maintenance_hub_screen.dart';

extension _AdminMaintenanceHubHeroPart on _AdminMaintenanceHubScreenState {
  // ---- hero ----

  Widget _snapshotHero(Map<String, dynamic> data) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final summary = (data['summary'] as Map?) ?? const {};
    final fund = (data['fund'] as Map?) ?? const {};

    final expected = (summary['totalExpected'] as num?)?.toDouble() ?? 0;
    final collected = (summary['collected'] as num?)?.toDouble() ?? 0;
    final cycleCash = (summary['cycleCashCollected'] as num?)?.toDouble() ?? collected;
    final balance = (fund['currentFundBalance'] as num?)?.toDouble() ?? 0;
    final rate = expected > 0 ? (collected / expected).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DesignColors.primaryLight, DesignColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: [
          BoxShadow(
            color: DesignColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLLECTED THIS CYCLE',
            style: DesignTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                inr.format(cycleCash),
                style: DesignTypography.headingXL.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${inr.format(expected)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(rate * 100).round()}% of expected',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Fund balance ${inr.format(balance)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  Widget _heroSkeleton() => ShimmerWrap(
      child: ShimmerBox(height: 160, borderRadius: DesignRadius.xl),
    );

  // ---- stat row ----

  Widget _statRow(Map<String, dynamic> data) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final summary = (data['summary'] as Map?) ?? const {};
    final fund = (data['fund'] as Map?) ?? const {};
    final paid = (summary['paidCount'] as num?)?.toInt() ?? 0;
    final pending = (summary['unpaidCount'] as num?)?.toInt() ?? 0;
    final credit = (fund['totalAdvanceCredit'] as num?)?.toDouble() ?? 0;

    return Row(
      children: [
        Expanded(
          child: MaintenanceStatChip(
            label: 'Paid',
            value: '$paid',
            tone: MaintenanceStatTone.success,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MaintenanceStatChip(
            label: 'Pending',
            value: '$pending',
            tone: pending > 0 ? MaintenanceStatTone.warning : MaintenanceStatTone.neutral,
            icon: Icons.pending_actions_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MaintenanceStatChip(
            label: 'Credit pool',
            value: inr.format(credit),
            tone: credit > 0 ? MaintenanceStatTone.info : MaintenanceStatTone.neutral,
            icon: Icons.savings_outlined,
          ),
        ),
      ],
    );
  }
}
