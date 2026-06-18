import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/maintenance_due_model.dart';
import '../../../data/models/resident_dashboard_model.dart';

class HomeSocietyFinances extends StatelessWidget {
  const HomeSocietyFinances({
    super.key,
    required this.dashboardAsync,
    required this.pendingState,
  });

  final AsyncValue<ResidentDashboardModel> dashboardAsync;
  final AsyncValue<List<MaintenanceDueModel>> pendingState;

  @override
  Widget build(BuildContext context) {
    return dashboardAsync.when(
      loading: () => _loadingSkeleton(context),
      error: (_, _) => const EmptyStateWidget(
        icon: Icons.account_balance_outlined,
        title: 'Finance data unavailable',
        subtitle: 'Could not load society Finance Information.',
      ),
      data: (d) => _buildContent(context, d),
    );
  }

  /// Card-shaped skeleton sized close to the real card so the section holds
  /// its space (no blank white gap / layout jump) while the dashboard loads.
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
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF1F5F9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [line(16, w: 140), line(30, w: 96, r: 14)],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: line(60, r: 10)),
                const SizedBox(width: 12),
                Expanded(child: line(60, r: 10)),
              ],
            ),
            const SizedBox(height: 16),
            line(46, r: 10),
            const SizedBox(height: 12),
            line(40, r: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ResidentDashboardModel d) {
    final inr = NumberFormat.currency(
        locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    final fund = d.fund;
    final isPositive = fund.societyFund >= 0;
    // Derive the collection % from the same figures shown beside it ("₹X of ₹Y")
    // so the percentage and the amounts on the card always agree.
    final shownRate = fund.expectedAllTime > 0
        ? (fund.allTimeCollected / fund.expectedAllTime * 100)
            .clamp(0.0, 100.0)
            .toDouble()
        : 0.0;
    final progress = (shownRate / 100).clamp(0.0, 1.0);
    final progressColor = progress >= 0.9
        ? const Color(0xFF16A34A)
        : progress >= 0.7
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    final heroColor =
        isPositive ? const Color(0xFF16A34A) : DesignColors.error;
    final hasPending = fund.pendingDues > 0;
    final hasAdvance = fund.totalAdvanceCredit > 0;
    final bankColor =
        fund.currentBalance >= 0 ? const Color(0xFF16A34A) : DesignColors.error;
    final projected = fund.societyFund + fund.pendingDues;
    final projColor =
        projected >= 0 ? const Color(0xFF166534) : DesignColors.error;
    final pendingCount = (pendingState.valueOrNull ?? []).length;
    // Use the displayed (derived) rate, not the backend collectionRate field,
    // which can be unreliable (observed 0% while actual collection was 50%).
    final healthLabel = _healthLabel(shownRate, fund.societyFund);
    final healthColor = _healthColor(shownRate, fund.societyFund);
    final healthEmoji = _healthEmoji(shownRate, fund.societyFund);

    return Container(
        decoration: DesignComponents.cardDecoration(
          color: context.surface.defaultSurface,
          borderColor: DesignColors.borderLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Society Finances',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: DesignColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time summary of your society',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.text.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Health badge with smiley circle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: healthColor.withValues(alpha: 0.06),
                      borderRadius:
                          BorderRadius.circular(DesignRadius.full),
                      border: Border.all(
                        color: healthColor.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Smiley circle
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: healthColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(healthEmoji,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Society health',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w500,
                                color: context.text.secondary,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(healthLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: healthColor,
                                    height: 1)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 14,
                            color: healthColor.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Two-column fund section ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: label + hero amount + badge
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Society Fund Balance',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: heroColor.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                inr.format(fund.societyFund),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: heroColor,
                                  letterSpacing: -0.5,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _showFundInfoSheet(context),
                              child: Icon(Icons.info_outline_rounded,
                                  size: 14,
                                  color:
                                      heroColor.withValues(alpha: 0.3)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Sufficient badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
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
                                    ? const Color(0xFF16A34A)
                                    : DesignColors.error,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  isPositive
                                      ? 'Sufficient for this month'
                                      : 'Insufficient',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isPositive
                                        ? const Color(0xFF16A34A)
                                        : DesignColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right column: collection %, ₹X of ₹Y, progress bar
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Stacked so neither the % nor the larger "₹X of ₹Y"
                        // gets clipped in the narrow column.
                        Text(
                          '${shownRate.toStringAsFixed(1)}% collected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${inr.format(fund.allTimeCollected)} of ${inr.format(fund.expectedAllTime)}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: context.text.tertiary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor:
                                progressColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                progressColor),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "This month's collection",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: context.text.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── 4 metrics row with vertical dividers ──
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _metric(
                        label: 'Collection',
                        value: inr.format(fund.allTimeCollected),
                        sub: 'of ${inr.format(fund.expectedAllTime)}',
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    _verticalDivider(context),
                    Expanded(
                      child: _metric(
                        label: 'Expenses',
                        value: inr.format(fund.allTimeSpent),
                        sub: 'total spent',
                        color: DesignColors.error,
                      ),
                    ),
                    _verticalDivider(context),
                    Expanded(
                      child: _metric(
                        label: 'Pending dues',
                        value: hasPending
                            ? inr.format(fund.pendingDues)
                            : 'None',
                        sub: 'across villas',
                        color: hasPending
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                        badge: hasPending ? pendingCount : null,
                      ),
                    ),
                    _verticalDivider(context),
                    Expanded(
                      child: _metric(
                        label: 'Advance credit',
                        value: hasAdvance
                            ? inr.format(fund.totalAdvanceCredit)
                            : '---',
                        sub: 'extra paid',
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Bottom summary (two items side by side) ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Left: Balance in bank
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_outlined,
                              size: 13,
                              color: bankColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Balance in bank',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: context.text.secondary,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inr.format(fund.currentBalance),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: bankColor,
                                    letterSpacing: -0.2,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPending) ...[
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // Right: If all dues cleared
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              projected >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: projColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'If all dues are cleared',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: context.text.secondary,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        inr.format(projected),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: projColor,
                                          letterSpacing: -0.2,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Includes pending dues & advance credit',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w500,
                                            color: context.text.tertiary,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: context.text.tertiary),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _verticalDivider(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: DesignColors.borderLight,
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required String sub,
    required Color color,
    int? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.65))),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(DesignRadius.full)),
                  child: Text('$badge',
                      style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.45))),
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
    if (r >= 90 && f >= 0) return const Color(0xFF16A34A);
    if (r >= 70 || f >= 0) return const Color(0xFFF59E0B);
    return DesignColors.error;
  }

  String _healthEmoji(double r, double f) {
    if (r >= 90 && f >= 0) return '\u{1F60A}';
    if (r >= 70 || f >= 0) return '\u{1F610}';
    return '\u{2639}\u{FE0F}';
  }

  void _showFundInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Understanding your fund balance',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary)),
            const SizedBox(height: 14),
            _infoRow(context, const Color(0xFF166534), 'Spendable',
                'Money the society can use for expenses.'),
            const SizedBox(height: 10),
            _infoRow(context, const Color(0xFF1E40AF), 'Advance credit',
                'Prepayments by residents for future billing cycles.'),
            const SizedBox(height: 10),
            _infoRow(context, DesignColors.textSecondary, 'In bank',
                'Total cash in the society account (spendable + advance credit).'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.text.secondary,
                      height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
