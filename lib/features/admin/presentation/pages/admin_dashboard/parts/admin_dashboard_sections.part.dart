part of '../admin_dashboard_screen.dart';

extension _AdminDashboardSectionsPart on _AdminDashboardScreenState {
  Widget _body(BuildContext ctx, AdminDashboardModel d) {
    final notificationsAsync = ref.watch(notificationProvider);
    final fundAsync = ref.watch(residentDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryStrip(d),
        _buildUpiPendingAlert(ctx),
        SizedBox(height: kAdminDashSectionGap),
        _buildAppUsageCard(ctx),
        SizedBox(height: kAdminDashSectionGap),
        // Same "Society Finances" card the resident home page shows.
        HomeSocietyFinances(
          dashboardAsync: fundAsync,
        ),
        SizedBox(height: kAdminDashSectionGap),
        _buildAdminMaintenanceCard(ctx),
        SizedBox(height: kAdminDashSectionGap + 4),
        const AdminDashboardQuickActions(),
        SizedBox(height: kAdminDashSectionGap + 4),
        _buildRecentActivity(ctx, notificationsAsync),
        const SizedBox(height: 20),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP USAGE (admin home — not bottom nav)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAppUsageCard(BuildContext ctx) {
    final summaryAsync = ref.watch(adminAppAnalyticsSummaryProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.zero,
        child: BannerSkeleton(height: 88),
      ),
      error: (_, __) => _appUsageCardShell(
        ctx,
        dailyActive: null,
        weeklyActive: null,
      ),
      data: (summary) {
        final totals =
            (summary['totals'] as Map?)?.cast<String, dynamic>() ?? {};
        return _appUsageCardShell(
          ctx,
          dailyActive: totals['dailyActiveUsers'] as int?,
          weeklyActive: totals['weeklyActiveUsers'] as int?,
        );
      },
    );
  }

  Widget _appUsageCardShell(
    BuildContext ctx, {
    required int? dailyActive,
    required int? weeklyActive,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kAdminDashRadiusLg),
        onTap: () {
          HapticFeedback.lightImpact();
          ctx.push('/resident/admin-app-analytics');
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kAdminDashRadiusLg),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: adminDashCardShadow(0.05),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DesignColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.smartphone_outlined,
                      color: DesignColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Usage',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: DesignColors.textPrimary,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Residents, guards & admins — mobile & web activity',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: DesignColors.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: DesignColors.textSecondary.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ],
              ),
              if (dailyActive != null || weeklyActive != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _appUsageStatChip(
                        label: 'Daily active',
                        value: dailyActive ?? 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _appUsageStatChip(
                        label: 'Weekly active',
                        value: weeklyActive ?? 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _appUsageStatChip({required String label, required int value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: DesignColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DesignColors.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // UPI PENDING ALERT
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildUpiPendingAlert(BuildContext ctx) {
    final statsAsync = ref.watch(adminUpiStatsProvider);
    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: BannerSkeleton(height: 56),
      ),
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
                borderRadius: BorderRadius.circular(kAdminDashRadiusMd),
                border: Border.all(color: DesignColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DesignColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.currency_rupee_rounded,
                        color: DesignColors.warning, size: 18),
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
  // 2b. ADMIN MAINTENANCE CARD (3 sub-CTAs)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAdminMaintenanceCard(BuildContext ctx) {
    final outstandingAsync = ref.watch(adminOutstandingDuesProvider);
    final villasCount = outstandingAsync.whenOrNull(
      data: (d) => (d['villasWithDuesCount'] as num?)?.toInt() ?? 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kAdminDashRadiusLg),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: adminDashCardShadow(0.05),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
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
            onTap: () => ctx.push('/resident/admin-mark-payment'),
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
            iconColor: DesignColors.error,
            title: 'Outstanding dues',
            subtitle: 'All pending payments across villas',
            onTap: () => ctx.push('/resident/admin-outstanding-dues'),
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
                      style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textSecondary,
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.error,
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
        borderRadius: BorderRadius.circular(kAdminDashRadiusLg),
        color: Colors.white,
        border: Border.all(color: borderColor),
        boxShadow: adminDashCardShadow(0.04),
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
                borderRadius: BorderRadius.circular(kAdminDashRadiusMd),
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
                        AdminDashboardVLine(color: borderColor),
                        Expanded(
                          child: _summaryCell(
                            label: 'Parcels',
                            value: d.pendingParcels,
                            icon: Icons.inventory_2_outlined,
                            accent: DesignColors.warning,
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
                            accent: DesignColors.error,
                          ),
                        ),
                        AdminDashboardVLine(color: borderColor),
                        Expanded(
                          child: _summaryCell(
                            label: 'Unread',
                            value: unreadCount,
                            icon: Icons.notifications_active_outlined,
                            accent: DesignColors.secondary,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: DesignColors.textSecondary,
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
}
