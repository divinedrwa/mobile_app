import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/resident_dashboard_model.dart';
import 'home_shared.dart';

class HomeSocietyFinances extends StatelessWidget {
  const HomeSocietyFinances({
    super.key,
    required this.dashboardAsync,
  });

  final AsyncValue<ResidentDashboardModel> dashboardAsync;

  @override
  Widget build(BuildContext context) {
    final data = dashboardAsync.valueOrNull;
    final isInitialLoad = dashboardAsync.isLoading && data == null;
    final hasError = dashboardAsync.hasError && data == null;

    if (isInitialLoad) return _loadingSkeleton(context);
    if (hasError) return const EmptyStateWidget(
      icon: Icons.account_balance_outlined,
      title: 'Finance data unavailable',
      subtitle: 'Could not load society finance information.',
    );
    if (data != null) return _buildContent(context, data);
    return _loadingSkeleton(context);
  }

  Widget _loadingSkeleton(BuildContext context) {
    Widget line(double h, {double? w, double r = 6}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
        borderColor: DesignColors.borderLight,
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(12),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF1F5F9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [line(16, w: 140), line(28, w: 88, r: 14)],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: line(56, r: 10)),
                const SizedBox(width: 10),
                Expanded(child: line(56, r: 10)),
              ],
            ),
            const SizedBox(height: 12),
            line(42, r: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ResidentDashboardModel d) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 0,
    );

    final fund = d.fund;
    final isPositive = fund.societyFund >= 0;
    final shownRate = fund.collectionRate.clamp(0.0, 100.0);
    final progress = (shownRate / 100).clamp(0.0, 1.0);
    final progressColor = progress >= 0.9
        ? DesignColors.success
        : progress >= 0.7
            ? DesignColors.warning
            : DesignColors.error;
    final hasPending = fund.pendingDues > 0;
    final hasAdvance = fund.totalAdvanceCredit > 0;
    final bankColor =
        fund.currentBalance >= 0 ? DesignColors.success : DesignColors.error;
    final projected = fund.projectedBalance;
    final projColor =
        projected >= 0 ? DesignColors.success : DesignColors.error;
    final healthLabel = _healthLabel(shownRate, fund.societyFund);
    final healthColor = _healthColor(shownRate, fund.societyFund);
    final healthEmoji = _healthEmoji(shownRate, fund.societyFund);

    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: homeCardShadow(0.04),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Society Finances',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time overview of your society',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HealthBadge(
                healthEmoji: healthEmoji,
                healthLabel: healthLabel,
                healthColor: healthColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Society Fund Balance',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.text.secondary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            inr.format(fund.societyFund),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: DesignColors.textPrimary,
                              letterSpacing: -0.45,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message:
                              'Spendable society fund after advance credit.',
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: context.text.tertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? DesignColors.successLight
                            : DesignColors.errorLight,
                        borderRadius:
                            BorderRadius.circular(DesignRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.check_circle_outline_rounded
                                : Icons.warning_amber_rounded,
                            size: 11,
                            color: isPositive
                                ? DesignColors.success
                                : DesignColors.error,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPositive
                                ? 'Sufficient for this month'
                                : 'Insufficient',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isPositive
                                  ? DesignColors.success
                                  : DesignColors.error,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${shownRate.toStringAsFixed(1)}% collected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: progressColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inr.format(fund.allTimeCollected)} of ${inr.format(fund.expectedAllTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: context.text.tertiary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor:
                            progressColor.withValues(alpha: 0.12),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "This month's collection",
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: context.text.tertiary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _metric(
                    icon: Icons.receipt_long_outlined,
                    label: 'Collection',
                    value: inr.format(fund.allTimeCollected),
                    sub: 'of ${inr.format(fund.expectedAllTime)}',
                    color: DesignColors.success,
                  ),
                ),
                ),
                _verticalDivider(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _metric(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Expenses',
                    value: inr.format(fund.allTimeSpent),
                    sub: 'total spent',
                    color: DesignColors.error,
                  ),
                ),
                ),
                _verticalDivider(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _metric(
                    icon: Icons.campaign_outlined,
                    label: 'Pending Dues',
                    value:
                        hasPending ? inr.format(fund.pendingDues) : 'None',
                    sub: 'across Villas',
                    color: hasPending
                        ? DesignColors.warning
                        : DesignColors.success,
                  ),
                ),
                ),
                _verticalDivider(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _metric(
                    icon: Icons.military_tech_outlined,
                    label: 'Advance Credit',
                    value: hasAdvance
                        ? inr.format(fund.totalAdvanceCredit)
                        : 'None',
                    sub: 'extra paid',
                    color: DesignColors.info,
                  ),
                ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FooterSummary(
            bankColor: bankColor,
            projColor: projColor,
            currentBalance: inr.format(fund.currentBalance),
            projected: inr.format(projected),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(vertical: 4),
      color: DesignColors.borderLight,
    );
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.9)),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: DesignColors.textSecondary.withValues(alpha: 0.85),
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  String _healthLabel(double r, double f) {
    if (r >= 90 && f >= 0) return 'Good';
    if (r >= 70 || f >= 0) return 'Fair';
    return 'Poor';
  }

  Color _healthColor(double r, double f) {
    if (r >= 90 && f >= 0) return DesignColors.success;
    if (r >= 70 || f >= 0) return DesignColors.warning;
    return DesignColors.error;
  }

  String _healthEmoji(double r, double f) {
    if (r >= 90 && f >= 0) return '\u{1F60A}';
    if (r >= 70 || f >= 0) return '\u{1F610}';
    return '\u{2639}\u{FE0F}';
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({
    required this.healthEmoji,
    required this.healthLabel,
    required this.healthColor,
  });

  final String healthEmoji;
  final String healthLabel;
  final Color healthColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: healthColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignRadius.full),
        border: Border.all(color: healthColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(healthEmoji, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Society Health',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: context.text.secondary,
                  height: 1,
                ),
              ),
              Text(
                healthLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: healthColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterSummary extends StatelessWidget {
  const _FooterSummary({
    required this.bankColor,
    required this.projColor,
    required this.currentBalance,
    required this.projected,
  });

  final Color bankColor;
  final Color projColor;
  final String currentBalance;
  final String projected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _footerCell(
                context: context,
                icon: Icons.account_balance_outlined,
                iconColor: bankColor,
                label: 'Balance in bank',
                value: currentBalance,
                valueColor: bankColor,
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFFE2E8F0),
            ),
            Expanded(
              child: _footerCell(
                context: context,
                icon: Icons.trending_up_rounded,
                iconColor: projColor,
                label: 'If all dues are cleared',
                value: projected,
                valueColor: projColor,
                footnote: 'Includes pending dues; excludes advance credit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerCell({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    String? footnote,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 13,
            color: iconColor.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: context.text.secondary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: -0.2,
                  height: 1.1,
                ),
              ),
              if (footnote != null) ...[
                const SizedBox(height: 2),
                Text(
                  footnote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w500,
                    color: context.text.tertiary,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
