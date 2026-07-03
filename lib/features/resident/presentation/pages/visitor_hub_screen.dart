import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/models/pre_approved_visitor_model.dart';
import '../../data/providers/visitor_history_provider.dart';
import '../providers/visitor_provider.dart';

// ─── design accents ──────────────────────────────────────────────────────────
// Dynamic: resolves to the society's primary brand colour at runtime.
Color get _kPurple => DesignColors.primary;
Color get _kGreen => DesignColors.success;
Color get _kGreenLight => DesignColors.successLight;
Color get _kBlue => DesignColors.info;

// ─── hub screen ──────────────────────────────────────────────────────────────

class VisitorHubScreen extends ConsumerStatefulWidget {
  const VisitorHubScreen({super.key});

  @override
  ConsumerState<VisitorHubScreen> createState() => _VisitorHubScreenState();
}

class _VisitorHubScreenState extends ConsumerState<VisitorHubScreen> {
  Future<void> _refresh() async {
    ref.invalidate(preApprovedVisitorsProvider);
    ref.invalidate(visitorApprovalRequestsProvider('pending'));
    ref.invalidate(visitorHistoryProvider);
    ref.invalidate(visitorTodaySummaryProvider);
    await Future.wait<void>([
      ref.read(preApprovedVisitorsProvider.future).then((_) {}).catchError((_) {}),
      ref.read(visitorApprovalRequestsProvider('pending').future).then((_) {}).catchError((_) {}),
      ref.read(visitorHistoryProvider.future).then((_) {}).catchError((_) {}),
      ref.read(visitorTodaySummaryProvider.future).then((_) {}).catchError((_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final preApprovedAsync = ref.watch(preApprovedVisitorsProvider);
    final preApprovedSeed = ref.watch(preApprovedVisitorsSeedProvider);
    final pendingAsync = ref.watch(visitorApprovalRequestsProvider('pending'));
    final todaySummaryAsync = ref.watch(visitorTodaySummaryProvider);
    final todaySummarySeed = ref.watch(visitorTodaySummarySeedProvider);
    // Use visitor history for live visitors and history sections.
    final historyAsync = ref.watch(visitorHistoryProvider);

    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: DesignColors.background,
      body: RefreshIndicator(
        color: _kPurple,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HubAppBar(pendingCount: pendingCount),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _TodaySummaryCard(
                    summaryAsync: todaySummaryAsync,
                    seed: todaySummarySeed,
                    onRetry: () => ref.invalidate(visitorTodaySummaryProvider),
                  ),
                  const SizedBox(height: 16),
                  _QuickActionsRow(
                    preApprovedAsync: preApprovedAsync,
                    pendingCount: pendingCount,
                  ),
                  const SizedBox(height: 20),
                  _LiveVisitorsSection(historyAsync: historyAsync),
                  _UpcomingVisitorsSection(
                    preApprovedAsync: preApprovedAsync,
                    seed: preApprovedSeed,
                  ),
                  _PendingApprovalsSection(
                    pendingAsync: pendingAsync,
                  ),
                  _HistoryFooterCard(historyAsync: historyAsync),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _HubAppBar extends StatelessWidget {
  const _HubAppBar({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: DesignColors.background,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: DesignColors.textPrimary,
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visitors',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: DesignColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          Text(
            'Manage your guests and gate passes',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: DesignColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
      actions: [
        // Bell — pending gate approvals badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Gate approval requests',
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DesignColors.borderLight),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: DesignColors.textPrimary,
                ),
              ),
              onPressed: () => context.push('/resident/visitor-requests'),
            ),
            if (pendingCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: DesignColors.error,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        // "+ Invite Guest" primary CTA
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: () {
              DesignHaptics.selection();
              context.push('/resident/pre-approve-visitor');
            },
            icon: Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Invite Guest',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Today's Summary ──────────────────────────────────────────────────────────
// Uses GET /residents/visitors-today for accurate same-day counts.

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.summaryAsync,
    required this.onRetry,
    this.seed,
  });

  final AsyncValue<VisitorTodaySummary> summaryAsync;
  final VoidCallback onRetry;

  /// Persisted counts from the last session — painted on a cold start while the
  /// live [summaryAsync] is still loading, instead of a skeleton.
  final VisitorTodaySummary? seed;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayFmt = DateFormat('d MMM, yyyy');
    final weekdayFmt = DateFormat('EEEE');

    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: _kPurple, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Summary",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.25,
                      ),
                    ),
                    Text(
                      '${dayFmt.format(today)}  •  ${weekdayFmt.format(today)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              // "View Requests" → live gate approval requests screen
              GestureDetector(
                onTap: () => context.push('/resident/visitor-requests'),
                child: Row(
                  children: [
                    Text(
                      'View Requests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kPurple.withValues(alpha: 0.9),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _kPurple, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final summary = summaryAsync.valueOrNull ?? seed;
            if (summaryAsync.isLoading && summary == null) {
              return Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    const Expanded(
                      child: ShimmerWrap(
                        child: ShimmerBox(height: 90, borderRadius: 12),
                      ),
                    ),
                  ],
                ],
              );
            }
            if (summary == null) {
              return _SummaryErrorRow(onRetry: onRetry);
            }
            return Row(
                children: [
                  _StatBox(
                    count: summary.total,
                    label: 'Visitors',
                    sublabel: 'Arrived today',
                    footer: 'Today',
                    footerIcon: Icons.schedule_rounded,
                    accentColor: _kPurple,
                    onTap: () => context.push('/resident/visitor-history'),
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    count: summary.checkedIn,
                    label: 'Inside',
                    sublabel: 'Currently inside',
                    footer: 'Live now',
                    footerIcon: Icons.circle,
                    footerIconColor: _kGreen,
                    accentColor: _kGreen,
                    onTap: () => context.push(
                      '/resident/visitor-history?status=CHECKED_IN',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    count: summary.checkedOut,
                    label: 'Completed',
                    sublabel: 'Checked out today',
                    footer: 'Today',
                    footerIcon: Icons.check_circle_outline_rounded,
                    accentColor: _kBlue,
                    onTap: () => context.push(
                      '/resident/visitor-history?status=CHECKED_OUT',
                    ),
                  ),
                ],
              );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }
}

class _SummaryErrorRow extends StatelessWidget {
  const _SummaryErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: DesignColors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: DesignColors.borderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 16, color: DesignColors.textSecondary),
            SizedBox(width: 6),
            Text(
              'Couldn\'t load today\'s stats',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DesignColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tap to retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.count,
    required this.label,
    required this.sublabel,
    required this.footer,
    required this.footerIcon,
    required this.accentColor,
    required this.onTap,
    this.footerIconColor,
  });

  final int count;
  final String label;
  final String sublabel;
  final String footer;
  final IconData footerIcon;
  final Color accentColor;
  final VoidCallback onTap;
  final Color? footerIconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 22, color: accentColor.withValues(alpha: 0.75)),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: DesignColors.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    footerIcon,
                    size: 10,
                    color: (footerIconColor ?? accentColor).withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    footer,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: (footerIconColor ?? accentColor).withValues(alpha: 0.8),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.preApprovedAsync,
    required this.pendingCount,
  });

  final AsyncValue<List<PreApprovedVisitorModel>> preApprovedAsync;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Active pre-approvals = non-expired ones
    final activePreApproved = preApprovedAsync.valueOrNull
            ?.where((v) =>
                v.passcodeExpiry == null || v.passcodeExpiry!.toLocal().isAfter(now))
            .length ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Invite Guest — primary (50% width, featured star)
            _QuickActionCard(
              flex: 2,
              bgColor: _kPurple.withValues(alpha: 0.09),
              borderColor: _kPurple.withValues(alpha: 0.22),
              iconBg: _kPurple.withValues(alpha: 0.15),
              icon: Icons.person_add_alt_1_rounded,
              iconColor: _kPurple,
              title: 'Invite Guest',
              subtitle: 'Send invitation quickly',
              showStar: true,
              onTap: () => context.push('/resident/pre-approve-visitor'),
            ),
            const SizedBox(width: 10),
            // Pre-Approve — badge = active pre-approvals count
            _QuickActionCard(
              flex: 1,
              bgColor: _kGreenLight,
              borderColor: _kGreen.withValues(alpha: 0.2),
              iconBg: _kGreen.withValues(alpha: 0.15),
              icon: Icons.verified_user_outlined,
              iconColor: _kGreen,
              title: 'Pre-Approve',
              subtitle: 'Manage passes',
              badge: activePreApproved > 0 ? activePreApproved : null,
              onTap: () => context.push('/resident/my-pre-approved-visitors'),
            ),
            const SizedBox(width: 10),
            // Gate Requests — badge = pending gate approvals count
            _QuickActionCard(
              flex: 1,
              bgColor: _kBlue.withValues(alpha: 0.07),
              borderColor: _kBlue.withValues(alpha: 0.2),
              iconBg: _kBlue.withValues(alpha: 0.13),
              icon: Icons.door_front_door_outlined,
              iconColor: _kBlue,
              title: 'Gate Requests',
              subtitle: 'Approve visitors',
              badge: pendingCount > 0 ? pendingCount : null,
              badgeColor: DesignColors.error,
              onTap: () => context.push('/resident/visitor-requests'),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 60.ms).slideY(begin: 0.04, end: 0);
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.flex,
    required this.bgColor,
    required this.borderColor,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showStar = false,
    this.badge,
    this.badgeColor,
  });

  final int flex;
  final Color bgColor;
  final Color borderColor;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showStar;
  final int? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = badgeColor ?? iconColor;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          DesignHaptics.selection();
          onTap();
        },
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  const Spacer(),
                  if (showStar)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                    )
                  else if (badge != null && badge! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: effectiveBadgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: flex == 1 ? 11.5 : 12.5,
                            fontWeight: FontWeight.w800,
                            color: DesignColors.textPrimary,
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: DesignColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded, size: 14, color: iconColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live Visitors ────────────────────────────────────────────────────────────
// Uses visitor history (CHECKED_IN status) rather than approval-requests.

class _LiveVisitorsSection extends StatelessWidget {
  const _LiveVisitorsSection({required this.historyAsync});

  final AsyncValue<List<dynamic>> historyAsync;

  @override
  Widget build(BuildContext context) {
    final visitors = historyAsync.valueOrNull;
    if (historyAsync.isLoading && visitors == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Live Visitors', null, null),
            const SizedBox(height: 10),
            const ShimmerWrap(child: ShimmerBox(height: 72, borderRadius: 12)),
          ],
        ),
      );
    }
    if (visitors == null) return const SizedBox.shrink();
    return Builder(builder: (context) {
        final live = visitors
            .where((v) => (v.status as String).toUpperCase() == 'CHECKED_IN')
            .toList();
        if (live.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                'Live Visitors',
                'View all',
                () => context.push('/resident/visitor-requests'),
                badge: '${live.length} Inside',
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DesignColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < live.length && i < 3; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: DesignColors.borderLight),
                      _LiveVisitorRow(visitor: live[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 80.ms);
    });
  }
}

class _LiveVisitorRow extends StatelessWidget {
  const _LiveVisitorRow({required this.visitor});

  final dynamic visitor;

  @override
  Widget build(BuildContext context) {
    final name = (visitor.name as String? ?? '').trim();
    final displayName = name.isEmpty ? 'Visitor' : name;
    final phone = (visitor.phone as String? ?? '').trim();
    final checkInTime = visitor.checkInTime as DateTime?;
    final timeFmt = checkInTime != null
        ? 'Since ${DateFormat('h:mm a').format(checkInTime.toLocal())}'
        : null;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    Future<void> callVisitor() async {
      if (phone.isEmpty) return;
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }

    // Residents cannot check out visitors (guard action).
    // Row taps → gate requests screen (live status view).
    return InkWell(
      onTap: () => context.push('/resident/visitor-requests'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kPurple,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                            height: 1.1,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Inside',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _kPurple,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (timeFmt != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _kGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeFmt,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _kGreen,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Call button (if phone available)
            if (phone.isNotEmpty)
              _ActionIconBtn(
                icon: Icons.phone_outlined,
                label: 'Call',
                color: _kGreen,
                onTap: callVisitor,
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: DesignColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  const _ActionIconBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        DesignHaptics.selection();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming Visitors (pre-approved, not yet arrived) ────────────────────────

class _UpcomingVisitorsSection extends StatelessWidget {
  const _UpcomingVisitorsSection({required this.preApprovedAsync, this.seed});

  final AsyncValue<List<PreApprovedVisitorModel>> preApprovedAsync;

  /// Persisted list from the last session — used on a cold start while the live
  /// [preApprovedAsync] is loading, instead of a skeleton.
  final List<PreApprovedVisitorModel>? seed;

  @override
  Widget build(BuildContext context) {
    final list = preApprovedAsync.valueOrNull ?? seed;
    if (preApprovedAsync.isLoading && list == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Upcoming Visitors', null, null),
            const SizedBox(height: 10),
            ...List.generate(
              2,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: ShimmerWrap(child: ShimmerBox(height: 60, borderRadius: 12)),
              ),
            ),
          ],
        ),
      );
    }
    if (list == null) return const SizedBox.shrink();
    return Builder(builder: (context) {
        final now = DateTime.now();
        // Non-expired active pre-approvals (all of them, not just today)
        final upcoming = list
            .where((v) =>
                v.passcodeExpiry == null || v.passcodeExpiry!.toLocal().isAfter(now))
            .take(4)
            .toList();

        if (upcoming.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                context,
                'Upcoming Visitors',
                'View all',
                () => context.push('/resident/my-pre-approved-visitors'),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DesignColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < upcoming.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: DesignColors.borderLight),
                      _UpcomingRow(visitor: upcoming[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 120.ms);
    });
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.visitor});

  final PreApprovedVisitorModel visitor;

  static IconData _typeIcon(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return Icons.person_rounded;
      case VisitorType.delivery:
        return Icons.local_shipping_outlined;
      case VisitorType.service:
        return Icons.home_repair_service_outlined;
      case VisitorType.vendor:
        return Icons.storefront_outlined;
    }
  }

  static Color _typeColor(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return _kPurple;
      case VisitorType.delivery:
        return const Color(0xFF0891B2);
      case VisitorType.service:
        return const Color(0xFF7C3AED);
      case VisitorType.vendor:
        return const Color(0xFFCA8A04);
    }
  }

  static String _typeLabel(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return 'Guest';
      case VisitorType.delivery:
        return 'Delivery';
      case VisitorType.service:
        return 'Service';
      case VisitorType.vendor:
        return 'Vendor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcon(visitor.type);
    final color = _typeColor(visitor.type);
    final label = _typeLabel(visitor.type);
    final timeFmt = DateFormat('d MMM · h:mm a').format(visitor.visitDate);
    final flat = visitor.flatLabel ?? '';
    final hasExpiry = visitor.passcodeExpiry != null;
    final isToday = visitor.visitDate.toLocal().day == DateTime.now().day &&
        visitor.visitDate.toLocal().month == DateTime.now().month &&
        visitor.visitDate.toLocal().year == DateTime.now().year;

    return InkWell(
      onTap: () => context.push('/resident/my-pre-approved-visitors'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          visitor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DesignColors.textPrimary,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${isToday ? 'Today' : timeFmt}${flat.isNotEmpty ? '  ·  Flat $flat' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: DesignColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: hasExpiry
                    ? _kBlue.withValues(alpha: 0.1)
                    : _kGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasExpiry
                      ? _kBlue.withValues(alpha: 0.2)
                      : _kGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                hasExpiry ? 'Timed' : 'Open',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hasExpiry ? _kBlue : _kGreen,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: DesignColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Pending Gate Approvals (inline section) ──────────────────────────────────
// Shows only when there are pending gate requests — contextual CTA.

class _PendingApprovalsSection extends StatelessWidget {
  const _PendingApprovalsSection({required this.pendingAsync});

  final AsyncValue<List<Map<String, dynamic>>> pendingAsync;

  @override
  Widget build(BuildContext context) {
    final pending = pendingAsync.valueOrNull ?? [];
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context,
            'Gate Approval Needed',
            'Review all',
            () => context.push('/resident/visitor-requests'),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDBA74).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: DesignColors.warning.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < pending.length && i < 2; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: Color(0xFFFDBA74)),
                  _PendingApprovalRow(data: pending[i]),
                ],
                if (pending.length > 2)
                  InkWell(
                    onTap: () => context.push('/resident/visitor-requests'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+${pending.length - 2} more pending',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: Color(0xFFC2410C)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }
}

class _PendingApprovalRow extends StatelessWidget {
  const _PendingApprovalRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = (data['name'] as String? ?? '').trim();
    final displayName = name.isEmpty ? 'Visitor' : name;
    final gate = (data['gate'] as Map?)?['name']?.toString().trim() ?? '';
    final arrivedAt = _parseTime(data['checkInTime']) ?? _parseTime(data['checkInAt']);
    final arrivedStr =
        arrivedAt != null ? DateFormat('h:mm a').format(arrivedAt.toLocal()) : null;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return InkWell(
      onTap: id.isNotEmpty
          ? () => context.push('/resident/visitor-requests/$id')
          : () => context.push('/resident/visitor-requests'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC2410C),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (gate.isNotEmpty) 'At $gate',
                      if (arrivedStr != null) 'Arrived $arrivedStr',
                      'Waiting for approval',
                    ].join('  ·  '),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC2410C),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFC2410C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Review',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

// ─── Visitor History Footer ───────────────────────────────────────────────────
// Uses visitor history data for accurate today/total counts.

class _HistoryFooterCard extends StatelessWidget {
  const _HistoryFooterCard({required this.historyAsync});

  final AsyncValue<List<dynamic>> historyAsync;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final all = historyAsync.valueOrNull ?? [];

    final todayCount = all.where((v) {
      final ci = v.checkInTime as DateTime?;
      return ci != null && ci.toLocal().isAfter(todayStart);
    }).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/resident/visitor-history'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DesignColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.calendar_month_outlined,
                      color: _kPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor History',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DesignColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Track all past and today's visitors",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: DesignColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$todayCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${all.length}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kPurple,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: DesignColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 140.ms);
  }
}

// ─── Section header helper ────────────────────────────────────────────────────

Widget _sectionHeader(
  BuildContext context,
  String title,
  String? actionLabel,
  VoidCallback? onAction, {
  String? badge,
  Color? badgeColor,
}) {
  final resolvedBadgeColor = badgeColor ?? _kGreen;
  final isLiveBadge = badge != null && badge.contains('Inside');
  return Row(
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
      if (isLiveBadge) ...[
        const SizedBox(width: 8),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: resolvedBadgeColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          badge,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: resolvedBadgeColor,
            height: 1,
          ),
        ),
      ],
      const Spacer(),
      if (onAction != null && actionLabel != null && !isLiveBadge)
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kPurple,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _kPurple, size: 16),
            ],
          ),
        ),
    ],
  );
}
