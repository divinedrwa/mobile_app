import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../resident/data/models/notification_model.dart';
import '../../../resident/data/models/resident_dashboard_model.dart';
import '../../../resident/data/providers/dashboard_provider.dart';
import '../../../resident/data/providers/maintenance_provider.dart';
import '../../../resident/data/providers/notification_provider.dart';
import '../../../resident/presentation/pages/notifications_center_screen.dart';
import '../../data/models/admin_dashboard_model.dart';
import '../../data/providers/admin_providers.dart';

// ── Design tokens ────────────────────────────────────────────────────
const Color _kAdminGradientStart = Color(0xFF1B3A2D);
const Color _kAdminGradientEnd = Color(0xFF2D5A47);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kGreen = Color(0xFF16A34A);
const double _kPadH = 18;
const double _kSectionGap = 20;
const double _kRadiusLg = 16;
const double _kRadiusMd = 14;

List<BoxShadow> _cardShadow([double opacity = 0.06]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ═════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Future<void> _handleRefresh() async {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(residentDashboardProvider);
    ref.invalidate(outstandingDuesProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(adminUpiStatsProvider);
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: DesignColors.primary,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(context, user?.name, user?.societyName, unread),
              Padding(
                padding: const EdgeInsets.fromLTRB(_kPadH, 14, _kPadH, 100),
                child: dashboardAsync.when(
                  loading: _skeleton,
                  error: (_, __) => _error(),
                  data: (d) => _body(context, d),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. ADMIN HERO CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeroCard(
    BuildContext ctx,
    String? name,
    String? society,
    int unreadNotifications,
  ) {
    final top = MediaQuery.of(ctx).padding.top;
    final firstName = name?.split(' ').first ?? 'Admin';
    final badgeText =
        unreadNotifications > 99 ? '99+' : '$unreadNotifications';

    return Container(
      padding: EdgeInsets.fromLTRB(14, top + 12, 8, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kAdminGradientStart, _kAdminGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Watermark illustration (right side)
          Positioned(
            right: -4,
            top: -6,
            bottom: -6,
            child: IgnorePointer(
              child: SizedBox(
                width: 130,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 10,
                      top: 6,
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    Positioned(
                      right: 52,
                      bottom: 2,
                      child: Icon(
                        Icons.shield_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 26,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_greeting()}, $firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.35,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Admin" role pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (society != null && society.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        society,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Date
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('d MMM').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(DateTime.now()),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              // Notification bell
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                        builder: (_) => residentNotificationsEntry,
                      ),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                          size: 23,
                        ),
                        if (unreadNotifications > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    unreadNotifications > 9 ? 3 : 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _kAdminGradientEnd, width: 1.25),
                              ),
                              constraints:
                                  const BoxConstraints(minHeight: 15),
                              child: Text(
                                badgeText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BODY
  // ═══════════════════════════════════════════════════════════════════

  Widget _body(BuildContext ctx, AdminDashboardModel d) {
    final notificationsAsync = ref.watch(notificationProvider);
    final fundAsync = ref.watch(residentDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryStrip(d),
        _buildUpiPendingAlert(ctx),
        SizedBox(height: _kSectionGap),
        _buildSocietyFundCard(ctx, fundAsync),
        SizedBox(height: _kSectionGap),
        _buildAdminMaintenanceCard(ctx),
        SizedBox(height: _kSectionGap + 4),
        _buildQuickActionsSection(ctx),
        SizedBox(height: _kSectionGap + 4),
        _buildRecentActivity(ctx, notificationsAsync),
        const SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // UPI PENDING ALERT
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildUpiPendingAlert(BuildContext ctx) {
    final statsAsync = ref.watch(adminUpiStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final pending = stats['pending'] as int? ?? 0;
        if (pending == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GestureDetector(
            onTap: () => ctx.push('/resident/admin-upi-verifications'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(_kRadiusMd),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.currency_rupee_rounded,
                        color: Color(0xFFF59E0B), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pending UPI payment${pending > 1 ? 's' : ''} pending verification',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const Text(
                          'Tap to review and verify',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFB45309), size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. SOCIETY FUND CARD (from resident pattern)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSocietyFundCard(
    BuildContext ctx,
    AsyncValue<ResidentDashboardModel> dashAsync,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 0,
    );

    return dashAsync.when(
      loading: () => Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kRadiusLg),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _cardShadow(0.05),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) {
        final fund = d.fund;
        final hasAdvanceCredit = fund.totalAdvanceCredit > 0;
        final hasPending = fund.pendingDues > 0;
        final isPositive = fund.societyFund >= 0;
        final projectedSociety = fund.societyFund + fund.pendingDues;
        final projectedPositive = projectedSociety >= 0;
        final projectedColor = projectedPositive
            ? const Color(0xFF166534)
            : const Color(0xFFDC2626);
        final bankPositive = fund.currentBalance >= 0;
        final bankColor =
            bankPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final progress = (fund.collectionRate / 100).clamp(0.0, 1.0);
        final progressColor = progress >= 0.9
            ? const Color(0xFF16A34A)
            : progress >= 0.7
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        final heroBg =
            isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
        final heroBorder =
            isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);
        final heroAmountColor =
            isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
        final heroMuted =
            isPositive ? const Color(0xFF15803D) : const Color(0xFF991B1B);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ══════════ Hero: Fund Balance ══════════
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                decoration: BoxDecoration(
                  color: heroBg,
                  border: Border(bottom: BorderSide(color: heroBorder)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 17,
                          color: heroMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Society Fund',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: heroMuted.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Fund Balance',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: heroMuted.withValues(alpha: 0.4),
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
                          onTap: () => _showFundInfoSheet(ctx),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: heroMuted.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    if (fund.expectedAllTime > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor:
                              heroMuted.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(progressColor),
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
                              color: heroMuted.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ══════════ 2×2 Metric Grid ══════════
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _fundMetricTile(
                            label: 'Collection',
                            value: inr.format(fund.allTimeCollected),
                            subtitle:
                                'of ${inr.format(fund.expectedAllTime)}',
                            accentColor: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFF0FDF4),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _fundMetricTile(
                            label: 'Expenses',
                            value: inr.format(fund.allTimeSpent),
                            subtitle: 'total spent',
                            accentColor: const Color(0xFFDC2626),
                            bgColor: const Color(0xFFFEF2F2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: _fundMetricTile(
                            label: 'Pending Dues',
                            value: hasPending
                                ? inr.format(fund.pendingDues)
                                : 'None',
                            subtitle:
                                hasPending ? 'outstanding' : 'all clear',
                            accentColor: hasPending
                                ? const Color(0xFFD97706)
                                : const Color(0xFF16A34A),
                            bgColor: hasPending
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF0FDF4),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _fundMetricTile(
                            label: 'Advance Credit',
                            value: hasAdvanceCredit
                                ? inr.format(fund.totalAdvanceCredit)
                                : '---',
                            subtitle: hasAdvanceCredit
                                ? 'resident credit'
                                : 'no credit',
                            accentColor: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ══════════ Summary: Bank Balance + Projected ══════════
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 15,
                            color: bankColor.withValues(alpha: 0.7),
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
                              : 'Collection ${inr.format(fund.allTimeCollected)} \u2212 Expenses ${inr.format(fund.allTimeSpent)}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      if (hasPending) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child:
                              Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          children: [
                            Icon(
                              projectedPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    'Collection includes additional funds of ${inr.format(fund.additionalMergedInflowAllTime)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _fundMetricTile({
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
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Understanding your fund balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _infoRow(
              const Color(0xFF166534),
              'Spendable',
              'Money the society can use for expenses. This is the total bank balance minus advance credit.',
            ),
            const SizedBox(height: 10),
            _infoRow(
              const Color(0xFF1E40AF),
              'Advance credit',
              'Prepayments by residents for future billing cycles. Reserved for those residents and not available for general spending.',
            ),
            const SizedBox(height: 10),
            _infoRow(
              _kTextSecondary,
              'In bank',
              'Total cash in the society account (spendable + advance credit).',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _infoRow(Color color, String title, String description) {
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2b. ADMIN MAINTENANCE CARD (3 sub-CTAs)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAdminMaintenanceCard(BuildContext ctx) {
    final outstandingAsync = ref.watch(outstandingDuesProvider);
    final villasCount = outstandingAsync.whenOrNull(
      data: (d) => (d['villasWithDuesCount'] as num?)?.toInt() ?? 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _cardShadow(0.05),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Maintenance',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.25,
              ),
            ),
          ),
          _maintenanceRow(
            ctx,
            icon: Icons.insights_rounded,
            iconColor: DesignColors.primary,
            title: 'Trends & expenses',
            subtitle: 'Month-wise paid/unpaid, society spend, pending dues',
            onTap: () => ctx.push('/resident/maintenance-payment'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _maintenanceRow(
            ctx,
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFDC2626),
            title: 'Outstanding dues',
            subtitle: 'All pending payments across villas',
            onTap: () => ctx.push('/resident/maintenance-payment'),
            trailingBadge:
                villasCount != null && villasCount > 0 ? villasCount : null,
          ),
        ],
      ),
    );
  }

  Widget _maintenanceRow(
    BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? trailingBadge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _kTextSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$trailingBadge',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: DesignColors.textSecondary.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. SUMMARY STRIP (2×2)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSummaryStrip(AdminDashboardModel d) {
    final borderColor = DesignColors.borderLight;
    final unreadCount = ref.watch(unreadCountProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadiusLg),
        color: Colors.white,
        border: Border.all(color: borderColor),
        boxShadow: _cardShadow(0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              "Today's Summary",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(_kRadiusMd),
                border: Border.all(
                    color: borderColor.withValues(alpha: 0.65)),
              ),
              child: Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _summaryCell(
                            label: 'Visitors',
                            value: d.todayVisitors,
                            icon: Icons.groups_rounded,
                            accent: DesignColors.primary,
                          ),
                        ),
                        _VLine(color: borderColor),
                        Expanded(
                          child: _summaryCell(
                            label: 'Parcels',
                            value: d.pendingParcels,
                            icon: Icons.inventory_2_outlined,
                            accent: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor.withValues(alpha: 0.65)),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _summaryCell(
                            label: 'Complaints',
                            value: d.openComplaints,
                            icon: Icons.report_problem_outlined,
                            accent: const Color(0xFFEF4444),
                          ),
                        ),
                        _VLine(color: borderColor),
                        Expanded(
                          child: _summaryCell(
                            label: 'Unread',
                            value: unreadCount,
                            icon: Icons.notifications_active_outlined,
                            accent: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell({
    required String label,
    required int value,
    required IconData icon,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCounter(
                  value: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.05,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════════
  // 5. QUICK ACTIONS (4 categorized sections, 3-column grids)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildQuickActionsSection(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _qaSection(
          ctx,
          title: 'Operations',
          subtitle: 'Day-to-day management',
          items: const [
            _QA(Icons.report_problem_outlined, 'Complaints', Color(0xFFEF4444),
                '/resident/admin-complaints'),
            _QA(Icons.notifications_active_outlined, 'Reminders',
                Color(0xFFF59E0B), '/resident/admin-reminders'),
            _QA(Icons.account_balance_wallet_outlined, 'Expenses',
                Color(0xFF8B5CF6), '/resident/admin-expenses'),
            _QA(Icons.campaign_outlined, 'Notices', Color(0xFF3B82F6),
                '/resident/admin-notices'),
            _QA(Icons.inventory_2_outlined, 'Parcels', Color(0xFF06B6D4),
                '/resident/admin-parcels'),
            _QA(Icons.currency_rupee_rounded, 'UPI Verifications',
                Color(0xFF16A34A), '/resident/admin-upi-verifications'),
          ],
        ),
        const SizedBox(height: 14),
        _qaSection(
          ctx,
          title: 'People & Property',
          subtitle: 'Users, units, and configuration',
          items: const [
            _QA(Icons.people_outlined, 'Residents', Color(0xFF0D9488),
                '/resident/admin-residents'),
            _QA(Icons.home_work_outlined, 'Properties', Color(0xFF7C3AED),
                '/resident/admin-villas'),
            _QA(Icons.person_add_outlined, 'Invite Users', Color(0xFFEC4899),
                '/resident/admin-invitations'),
            _QA(Icons.badge_outlined, 'Staff', Color(0xFF059669),
                '/resident/admin-staff'),
            _QA(Icons.manage_accounts_outlined, 'Roles', Color(0xFF6366F1),
                '/resident/admin-roles'),
            _QA(Icons.schedule_rounded, 'Guard Shifts', Color(0xFF0EA5E9),
                '/resident/admin-guard-shifts'),
            _QA(Icons.shield_rounded, 'Patrols', Color(0xFF0891B2),
                '/resident/admin-patrols'),
            _QA(Icons.report_outlined, 'Incidents', Color(0xFFDC2626),
                '/resident/admin-incidents'),
          ],
        ),
        const SizedBox(height: 14),
        _qaSection(
          ctx,
          title: 'Insights & Analytics',
          subtitle: 'Reports and data views',
          items: const [
            _QA(Icons.analytics_outlined, 'Gate Analytics', Color(0xFF0891B2),
                '/resident/admin-gate-analytics'),
            _QA(Icons.bar_chart_rounded, 'Complaint Analytics',
                Color(0xFFE11D48), '/resident/admin-complaint-analytics'),
            _QA(Icons.account_balance_outlined, 'Reconciliation',
                Color(0xFF059669), '/resident/admin-reconciliation'),
            _QA(Icons.local_parking, 'Parking', Color(0xFF6366F1),
                '/resident/admin-parking'),
            _QA(Icons.water_outlined, 'Water Analytics', Color(0xFF0284C7),
                '/resident/admin-water-analytics'),
            _QA(Icons.upload_file_outlined, 'Data Tools', Color(0xFF78716C),
                '/resident/admin-data-tools'),
          ],
        ),
        const SizedBox(height: 14),
        _qaSection(
          ctx,
          title: 'More Tools',
          subtitle: 'Additional utilities',
          items: const [
            _QA(Icons.water_drop_outlined, 'Gate Utilities', Color(0xFF10B981),
                '/resident/admin-gate-utilities'),
            _QA(Icons.sos_rounded, 'SOS Alerts', Color(0xFFDC2626),
                '/resident/admin-sos'),
            _QA(Icons.how_to_vote_outlined, 'Polls', Color(0xFF8B5CF6),
                '/resident/admin-polls'),
            _QA(Icons.fitness_center_outlined, 'Amenities', Color(0xFFF59E0B),
                '/resident/admin-amenities'),
            _QA(Icons.account_balance_wallet_outlined, 'Bank Accounts',
                Color(0xFF0EA5E9), '/resident/admin-bank-accounts'),
            _QA(Icons.settings_outlined, 'Settings', Color(0xFF64748B),
                '/resident/admin-settings'),
          ],
        ),
      ],
    );
  }

  Widget _qaSection(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required List<_QA> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _kTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: items.map((a) => _actionTile(ctx, a)).toList(),
        ),
      ],
    );
  }

  Widget _actionTile(BuildContext ctx, _QA a) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: _cardShadow(0.04),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadiusMd),
          onTap: () {
            HapticFeedback.lightImpact();
            ctx.go(a.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: a.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(a.icon, color: a.color, size: 19),
                ),
                const SizedBox(height: 5),
                Text(
                  a.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                    height: 1.15,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 6. RECENT ACTIVITY
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRecentActivity(
    BuildContext ctx,
    AsyncValue<List<NotificationModel>> notificationsState,
  ) {
    final notifications =
        notificationsState.valueOrNull ?? const <NotificationModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.35,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => residentNotificationsEntry,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: DesignColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All >',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            boxShadow: _cardShadow(),
          ),
          clipBehavior: Clip.antiAlias,
          child: notificationsState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _emptyActivityBlock(
              ctx,
              message: 'Could not load recent activity',
              onRetry: () => ref.invalidate(notificationProvider),
            ),
            data: (_) {
              if (notifications.isEmpty) {
                return _emptyActivityBlock(
                  ctx,
                  message: 'No recent activity yet',
                  onRetry: () => ref.invalidate(notificationProvider),
                );
              }
              final latest = notifications.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < latest.length; i++) ...[
                    _activityRow(
                      icon: latest[i].type.icon,
                      iconBg: latest[i].type.color.withValues(alpha: 0.12),
                      iconColor: latest[i].type.color,
                      title: latest[i].title,
                      subtitle:
                          '${latest[i].message} \u00b7 ${_timeAgo(latest[i].createdAt)}',
                      status: latest[i].isRead ? 'Seen' : 'New',
                      statusColor:
                          latest[i].isRead ? _kTextSecondary : _kGreen,
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute<void>(
                            builder: (_) => residentNotificationsEntry,
                          ),
                        );
                      },
                    ),
                    if (i != latest.length - 1)
                      const Divider(
                          height: 1, color: DesignColors.borderLight),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activityRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    final chipColor = statusColor ?? _kGreen;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyActivityBlock(
    BuildContext ctx, {
    required String message,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 36,
            color: _kTextSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOADING / ERROR
  // ═══════════════════════════════════════════════════════════════════

  Widget _skeleton() {
    return ShimmerWrap(
      child: Column(
        children: [
          // Society fund card
          const ShimmerBox(height: 240, borderRadius: 16),
          const SizedBox(height: _kSectionGap),
          // Maintenance card
          const ShimmerBox(height: 160, borderRadius: 16),
          const SizedBox(height: _kSectionGap),
          // Summary strip
          const ShimmerBox(height: 130, borderRadius: 16),
          const SizedBox(height: _kSectionGap),
          // CTA
          const ShimmerBox(height: 72, borderRadius: 16),
          const SizedBox(height: _kSectionGap),
          // 3-column grid
          GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: List.generate(
                6, (_) => const ShimmerBox(height: 70, borderRadius: 14)),
          ),
        ],
      ),
    );
  }

  Widget _error() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: 'Failed to load dashboard',
        subtitle: 'Pull down to refresh or tap retry.',
        actionLabel: 'Retry',
        onAction: _handleRefresh,
      ),
    );
  }
}

// ── Vertical divider widget ──────────────────────────────────────────

class _VLine extends StatelessWidget {
  const _VLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color.withValues(alpha: 0.65));
  }
}

// ── Data class ───────────────────────────────────────────────────────

class _QA {
  const _QA(this.icon, this.label, this.color, this.route);
  final IconData icon;
  final String label;
  final Color color;
  final String route;
}
