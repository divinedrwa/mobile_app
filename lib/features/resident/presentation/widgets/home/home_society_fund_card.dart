import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/billing_cycle_current_model.dart';
import '../../../data/models/resident_dashboard_model.dart';

class HomeSocietyFundCard extends StatelessWidget {
  const HomeSocietyFundCard({
    super.key,
    required this.dashboardAsync,
    required this.billingAsync,
  });

  final AsyncValue<ResidentDashboardModel> dashboardAsync;
  final AsyncValue<BillingCycleCurrent> billingAsync;

  @override
  Widget build(BuildContext context) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return dashboardAsync.when(
      loading: () => ShimmerWrap(
        child: Column(
          children: [
            ShimmerBox(height: 72, borderRadius: DesignRadius.xl),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg)),
                const SizedBox(width: 7),
                Expanded(child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg)),
              ],
            ),
          ],
        ),
      ),
      error: (_, _) => const EmptyStateWidget(
        icon: Icons.account_balance_outlined,
        title: 'Fund data unavailable',
        subtitle: 'Could not load society fund information.',
      ),
      data: (d) {
        final fund = d.fund;
        final hasAdvanceCredit = fund.totalAdvanceCredit > 0;
        final hasPending = fund.pendingDues > 0;
        final isPositive = fund.societyFund >= 0;
        final projectedSociety =
            fund.societyFund + fund.pendingDues;
        final projectedPositive = projectedSociety >= 0;
        final projectedColor = projectedPositive
            ? DesignColors.success
            : DesignColors.error;
        final bankPositive = fund.currentBalance >= 0;
        final bankColor = bankPositive
            ? DesignColors.success
            : DesignColors.error;
        final progress =
            (fund.collectionRate / 100).clamp(0.0, 1.0);
        final progressColor = progress >= 0.9
            ? DesignColors.success
            : progress >= 0.7
                ? DesignColors.warning
                : DesignColors.error;

        final heroBg = isPositive
            ? DesignColors.successLight
            : DesignColors.errorLight;
        final heroBorder = isPositive
            ? DesignColors.success.withValues(alpha: 0.35)
            : DesignColors.error.withValues(alpha: 0.35);
        final heroAmountColor = isPositive
            ? DesignColors.success
            : DesignColors.error;
        final heroMuted = isPositive
            ? DesignColors.primary
            : DesignColors.error;

        return Container(
          decoration: DesignComponents.cardDecoration(
            color: context.surface.defaultSurface,
            borderColor: DesignColors.borderLight,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero: Fund Balance
              Container(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 9),
                decoration: BoxDecoration(
                  color: heroBg,
                  border: Border(
                      bottom: BorderSide(color: heroBorder)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 17,
                          color: heroMuted
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Society Fund',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: heroMuted
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Fund Balance',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: heroMuted
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          inr.format(fund.societyFund),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: heroAmountColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () =>
                              _showFundInfoSheet(context),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: heroMuted
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    if (fund.expectedAllTime > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: heroMuted
                              .withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  progressColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${fund.collectionRate.toStringAsFixed(1)}% collected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: progressColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${inr.format(fund.allTimeCollected)} of ${inr.format(fund.expectedAllTime)}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: heroMuted
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // 2×2 Metric Grid
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            label: 'Collection',
                            value: inr
                                .format(fund.allTimeCollected),
                            subtitle:
                                'of ${inr.format(fund.expectedAllTime)}',
                            accentColor: DesignColors.success,
                            bgColor: DesignColors.successLight,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _metricTile(
                            label: 'Expenses',
                            value:
                                inr.format(fund.allTimeSpent),
                            subtitle: 'total spent',
                            accentColor:
                                DesignColors.error,
                            bgColor:
                                const Color(0xFFFEF2F2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            label: 'Pending Dues',
                            value: hasPending
                                ? inr
                                    .format(fund.pendingDues)
                                : 'None',
                            subtitle: hasPending
                                ? 'outstanding'
                                : 'all clear',
                            accentColor: hasPending
                                ? DesignColors.warning
                                : DesignColors.success,
                            bgColor: hasPending
                                ? DesignColors.warning.withValues(alpha: 0.08)
                                : DesignColors.successLight,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _metricTile(
                            label: 'Advance Credit',
                            value: hasAdvanceCredit
                                ? inr.format(
                                    fund.totalAdvanceCredit)
                                : '---',
                            subtitle: hasAdvanceCredit
                                ? 'resident credit'
                                : 'no credit',
                            accentColor: DesignColors.info,
                            bgColor: DesignColors.info.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary: Bank Balance + Projected
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons
                                .account_balance_wallet_outlined,
                            size: 15,
                            color: bankColor
                                .withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Balance in Bank',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            inr.format(fund.currentBalance),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: bankColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          hasAdvanceCredit
                              ? 'Society Fund ${inr.format(fund.societyFund)} + Advance Credit ${inr.format(fund.totalAdvanceCredit)}'
                              : 'Collection ${inr.format(fund.allTimeCollected)} − Expenses ${inr.format(fund.allTimeSpent)}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      if (hasPending) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 8),
                          child: Divider(
                              height: 1,
                              color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          children: [
                            Icon(
                              projectedPositive
                                  ? Icons
                                      .trending_up_rounded
                                  : Icons
                                      .trending_down_rounded,
                              size: 15,
                              color: projectedColor,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'After all dues cleared',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              inr.format(projectedSociety),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: projectedColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Society Fund ${inr.format(fund.societyFund)} + Pending ${inr.format(fund.pendingDues)}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        if (hasAdvanceCredit) ...[
                          const SizedBox(height: 2),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '+ ${inr.format(fund.totalAdvanceCredit)} advance credit in bank (belongs to residents)',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // Additional funds note
              if (fund.additionalMergedInflowAllTime > 0)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    'Collection includes additional funds of ${inr.format(fund.additionalMergedInflowAllTime)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: context.text.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Personal advance credit
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(2, 0, 2, 2),
                child: _buildPersonalCreditInline(
                    billingAsync, inr),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required String subtitle,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 3.5, color: accentColor),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textTertiary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFundInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding:
            const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Understanding your fund balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(
              context,
              DesignColors.success,
              'Spendable',
              'Money the society can use for expenses. This is the total bank balance minus advance credit.',
            ),
            const SizedBox(height: 10),
            _infoRow(
              context,
              DesignColors.info,
              'Advance credit',
              'Prepayments by residents for future billing cycles. Reserved for those residents and not available for general spending.',
            ),
            const SizedBox(height: 10),
            _infoRow(
              context,
              context.text.secondary,
              'In bank',
              'Total cash in the society account (spendable + advance credit).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, Color color,
      String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.text.secondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalCreditInline(
    AsyncValue<BillingCycleCurrent> billingAsync,
    NumberFormat inr,
  ) {
    return billingAsync.maybeWhen(
      data: (cycle) {
        final credit =
            (cycle.availableCredit ?? 0).toDouble();
        if (credit <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                size: 13,
                color: Color(0xFF1E40AF),
              ),
              const SizedBox(width: 5),
              Text(
                'Your advance credit: ${inr.format(credit)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const Padding(
        padding: EdgeInsets.only(top: 6),
        child: ShimmerWrap(
          child: ShimmerBox(height: 14, borderRadius: 6, width: 180),
        ),
      ),
    );
  }
}
