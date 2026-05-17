import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/visitor_provider.dart';
import '../../data/models/maintenance_due_model.dart';
import '../../data/models/notice_model.dart';
import '../../data/models/quick_action_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/providers/content_provider.dart';
import '../../data/providers/maintenance_provider.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/providers/dashboard_provider.dart';
import '../../data/providers/security_contact_provider.dart';
import '../../data/models/billing_cycle_current_model.dart';
import '../../data/models/resident_dashboard_model.dart';
import '../../data/models/security_contact_model.dart';
import 'amenities_screen.dart';
import 'amenity_booking_history_screen.dart';
import 'complaint_screen.dart';
import 'vendors_staff_screen.dart';
import 'notifications_center_screen.dart';
import 'parcel_management_screen.dart';
import 'sos_screen.dart';
import 'visitor_history_screen.dart';

/// Landing / home dashboard — UI aligned to product reference (light cards, blue accents).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// —— Reference design spec (resident landing) — GatePass+ brand ——
const Color _kOrange = Color(0xFFF39C12); // Brand warning amber
const Color _kGreen = DesignColors.primary; // Brand forest green
const Color _kPageBg = DesignColors.background;
const Color _kTextSecondary = Color(0xFF64748B);

const double _kPadH = 20;
const double _kSectionGap = 20;
const double _kRadiusLg = 16;
const double _kRadiusMd = 14;
const double _kRadiusSm = 12;

List<BoxShadow> _cardShadow([double opacity = 0.06]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _handleRefresh() async {
    ref.invalidate(pendingMaintenanceProvider);
    ref.invalidate(maintenanceHistoryProvider);
    ref.invalidate(residentBillingCycleProvider);
    ref.invalidate(residentDashboardProvider);
    ref.invalidate(noticesProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(pollsProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(visitorApprovalRequestsProvider('pending'));
    ref.invalidate(visitorApprovalRequestsProvider('all'));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late Night';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Platform';
      case UserRole.admin:
        return 'Admin';
      case UserRole.guard:
        return 'Guard';
      case UserRole.resident:
        return 'Resident';
    }
  }

  /// Home header pill: show Owner / Tenant / Family member when `/residents/me` provides it.
  String _headerOccupantOrRoleBadge(UserRole role, UserModel? user) {
    if (role == UserRole.resident) {
      final occ = user?.effectiveOccupantDisplay;
      if (occ != null && occ.isNotEmpty) return occ;
    }
    return _roleLabel(role);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final pendingState = ref.watch(pendingMaintenanceProvider);
    final noticesState = ref.watch(noticesProvider);
    final notificationsState = ref.watch(notificationProvider);
    final dashboardAsync = ref.watch(residentDashboardProvider);
    final billingAsync = ref.watch(residentBillingCycleProvider);
    final securityContactsAsync = ref.watch(securityContactsProvider);
    final user = authState.user;
    final billingExcludedFromCycle = billingAsync.maybeWhen(
      data: (c) => c.maintenanceBillingExcluded,
      orElse: () => false,
    );
    final isBillingExcluded = (user?.isBillingExcluded ?? false) || billingExcludedFromCycle;
    final unreadNotifications = notificationsState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );
    final hasImportantNotices =
        (noticesState.valueOrNull ?? const <NoticeModel>[]).isNotEmpty;

    final activeBillingCycle = billingAsync.maybeWhen(
      data: (c) {
        if (user?.role == UserRole.admin || !c.hasCycle || c.isPaid) {
          return null;
        }
        final s = c.status;
        if (s?.isOpen == true || s?.isUpcoming == true || s?.isClosed == true) {
          return c;
        }
        return null;
      },
      orElse: () => null,
    );
    return Scaffold(
      backgroundColor: _kPageBg,
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                context,
                user?.name ?? 'User',
                user?.role ?? UserRole.resident,
                user,
                unreadNotifications,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_kPadH, 12, _kPadH, 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === URGENCY zone — time-sensitive, only renders when relevant ===

                    // Gate visitor requests: "someone is at the gate right
                    // now". Self-hides when there are zero pending requests
                    // so a quiet day doesn't waste prime real estate.
                    _buildGateVisitorRequestsBanner(context),
                    const SizedBox(height: _kSectionGap),

                    // Society notices flagged as important / urgent.
                    if (hasImportantNotices) ...[
                      _buildImportantNotices(context, noticesState),
                      const SizedBox(height: _kSectionGap),
                    ],

                    // === HABIT zone — actions the resident takes regularly ===

                    // Pre-approve visitors, complaints, amenities, etc. The
                    // single most-used section on the home screen.
                    _buildQuickActions(context),
                    const SizedBox(height: _kSectionGap),

                    // Personal money owed — `_buildOutstandingDues` returns
                    // `SizedBox.shrink()` internally when there are no unpaid
                    // bills, so it disappears on a clean ledger.
                    if (!isBillingExcluded) ...[
                      _buildOutstandingDues(context, pendingState),
                      const SizedBox(height: _kSectionGap),
                    ],

                    // Active billing cycle status (current month progress).
                    if (!isBillingExcluded && activeBillingCycle != null) ...[
                      _buildOpenBillingStripe(context, activeBillingCycle),
                      const SizedBox(height: _kSectionGap),
                    ],

                    // === AWARENESS zone — passive at-a-glance numbers ===

                    // 4-tile stats row — at-a-glance personal counts.
                    _buildDashboardStatsRow(context, dashboardAsync, isBillingExcluded: isBillingExcluded),
                    const SizedBox(height: _kSectionGap),

                    // Maintenance: single card with two sub-CTAs (dues +
                    // trends). Replaces the previous pair of separate
                    // cards to save ~150px of vertical real estate while
                    // keeping both destinations a single tap away.
                    if (!isBillingExcluded) ...[
                      _buildMaintenanceCard(context),
                      const SizedBox(height: _kSectionGap),
                    ],

                    // Community-level ledger — informational, not actionable.
                    if (!isBillingExcluded) ...[
                      _buildSocietyFundBalanceCard(context, dashboardAsync, billingAsync),
                      const SizedBox(height: _kSectionGap),
                    ],

                    // === BROWSE zone — history and reference ===

                    // Recent visitor history, my pre-approved list, gate logs.
                    _buildVisitorsAndGateSection(context),
                    const SizedBox(height: _kSectionGap),

                    // Always-accessible support and security contacts.
                    _buildSupportStripWithFab(context, securityContactsAsync),
                    const SizedBox(height: _kSectionGap),

                    // Low-priority notification feed (scrollable bottom).
                    _buildRecentActivity(context, notificationsState),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    UserRole role,
    UserModel? user,
    int unreadNotifications,
  ) {
    final society = user?.societyName?.trim();

    final unitBlockLabel = <String>[];
    final propLine = user?.effectivePropertyDisplay;
    final unitLine = user?.effectiveUnitDisplay;
    if (propLine != null && propLine.isNotEmpty) unitBlockLabel.add(propLine);
    if (unitLine != null && unitLine.isNotEmpty) unitBlockLabel.add(unitLine);
    if (unitBlockLabel.isEmpty) {
      final unitNo = user?.villaNumber?.trim();
      if (unitNo != null && unitNo.isNotEmpty) {
        unitBlockLabel.add('Unit $unitNo');
      }
      final block = user?.villaBlock?.trim();
      if (block != null && block.isNotEmpty) unitBlockLabel.add('Block $block');
    }
    final unitBlockText = unitBlockLabel.join(' · ');

    final badgeText = unreadNotifications > 99
        ? '99+'
        : '$unreadNotifications';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(
          bottom: BorderSide(color: context.surface.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _buildHeaderIllustration(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_kPadH, 4, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeaderAvatar(name: name, photoUrl: user?.photoUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.text.secondary,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: 0.02,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LayoutBuilder(
                          builder: (context, c) {
                            const gap = 6.0;
                            const pillReserve = 76.0;
                            final nameW =
                                (c.maxWidth - pillReserve - gap).clamp(48.0, double.infinity);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: nameW,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: context.text.primary,
                                      height: 1.18,
                                      letterSpacing: -0.4,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: gap),
                                _buildHeaderActivePill(),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.brand.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined, size: 12, color: context.brand.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    _headerOccupantOrRoleBadge(role, user),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.brand.primary,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (unitBlockText.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxWidth: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.surface.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: context.surface.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.apartment_rounded,
                                      size: 12,
                                      color: DesignColors.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        unitBlockText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.text.primary,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (society != null && society.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          KeyedSubtree(
                            key: ValueKey<String>(society),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.surface.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.surface.border,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: context.brand.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.domain_rounded,
                                      size: 14,
                                      color: context.brand.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Society',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                            color: context.text.secondary,
                                            height: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          society,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: context.text.primary,
                                            height: 1.28,
                                            letterSpacing: -0.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                                .slideY(
                                  begin: DesignAnimations.slideNormal,
                                  end: 0,
                                  duration: 380.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: context.surface.defaultSurface,
                    elevation: 0,
                    shape: const CircleBorder(),
                    shadowColor: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => residentNotificationsEntry,
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surface.border),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              color: context.text.primary,
                              size: 20,
                            ),
                            if (unreadNotifications > 0)
                              Positioned(
                                right: 5,
                                top: 5,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: unreadNotifications > 9 ? 3 : 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white, width: 1.25),
                                  ),
                                  constraints: const BoxConstraints(minHeight: 15),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Active',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _kGreen,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Subtle house + trees art (top-right), scaled down to reduce header height.
  Widget _buildHeaderIllustration() {
    return Positioned(
      right: 8,
      top: 34,
      child: IgnorePointer(
        child: SizedBox(
          width: 88,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 2,
                top: 14,
                child: Icon(
                  Icons.grass_rounded,
                  size: 22,
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                right: 24,
                top: 6,
                child: Icon(
                  Icons.park_rounded,
                  size: 26,
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.16),
                ),
              ),
              Positioned(
                right: 28,
                top: 22,
                child: Icon(
                  Icons.holiday_village_rounded,
                  size: 34,
                  color: DesignColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Overview — 2×2 grid of independent tile-cards that visually match
  /// the Quick Actions section (white card, border, shadow, tinted icon).
  Widget _buildDashboardStatsRow(
    BuildContext context,
    AsyncValue<ResidentDashboardModel> dash, {
    bool isBillingExcluded = false,
  }) {
    const fallbackStats = ResidentDashboardStats(
      pendingMaintenance: 0,
      activeComplaints: 0,
      pendingParcels: 0,
      upcomingBookings: 0,
    );
    final s = dash.maybeWhen(
      data: (d) => d.stats,
      orElse: () => fallbackStats,
    );

    final tiles = <_OverviewTileSpec>[
      if (!isBillingExcluded)
        _OverviewTileSpec(
          label: 'Maintenance',
          value: s.pendingMaintenance,
          color: _kOrange,
          icon: Icons.payments_outlined,
          onTap: () => context.push('/resident/maintenance'),
        ),
      _OverviewTileSpec(
        label: 'Complaints',
        value: s.activeComplaints,
        color: const Color(0xFFE65100),
        icon: Icons.report_problem_outlined,
        onTap: () => context.push('/resident/my-complaints'),
      ),
      _OverviewTileSpec(
        label: 'Parcels',
        value: s.pendingParcels,
        color: DesignColors.primary,
        icon: Icons.inventory_2_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ParcelManagementScreen(),
            ),
          );
        },
      ),
      _OverviewTileSpec(
        label: 'Bookings',
        value: s.upcomingBookings,
        color: const Color(0xFF00897B),
        icon: Icons.event_available_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AmenityBookingHistoryScreen(),
            ),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.38,
                height: 1.15,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => context.push('/resident/overview'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    color: DesignColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: 92,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => _overviewTile(context, tiles[index]),
        ),
      ],
    );
  }

  Widget _overviewTile(BuildContext context, _OverviewTileSpec spec) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        border: Border.all(color: context.surface.border),
        boxShadow: _cardShadow(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadiusMd),
          onTap: spec.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: spec.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(spec.icon, color: spec.color, size: 17),
                ),
                const SizedBox(height: 6),
                AnimatedCounter(
                  value: spec.value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.text.primary,
                      height: 1.1,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocietyFundBalanceCard(
    BuildContext context,
    AsyncValue<ResidentDashboardModel> dash,
    AsyncValue<BillingCycleCurrent> billingAsync,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return dash.when(
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
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        final fund = d.fund;
        final hasAdvanceCredit = fund.totalAdvanceCredit > 0;
        final spendable = fund.societyFund;
        final isPositive = spendable >= 0;
        final balanceColor =
            isPositive ? const Color(0xFF166534) : const Color(0xFFB91C1C);
        final balanceBg =
            isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
        final snapshotLabel =
            '${DateFormat('MMM yyyy').format(DateTime(fund.year > 0 ? fund.year : DateTime.now().year, fund.month >= 1 && fund.month <= 12 ? fund.month : DateTime.now().month))} snapshot';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _cardShadow(0.05),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: DesignColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Society fund balance',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (hasAdvanceCredit)
                    GestureDetector(
                      onTap: () => _showFundInfoSheet(context),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: _kTextSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (hasAdvanceCredit) ...[
                // Three-column breakdown
                Row(
                  children: [
                    // Society Fund (spendable)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: balanceBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inr.format(spendable),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: balanceColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Spendable',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Advance Credit
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inr.format(fund.totalAdvanceCredit),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E40AF),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Advance credit',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // In Bank (total)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inr.format(fund.currentBalance),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _kTextSecondary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'In bank',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _kTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Single balance display (no advance credit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: balanceBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        inr.format(fund.currentBalance),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: balanceColor,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        snapshotLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Collected ${inr.format(fund.allTimeCollected)} · Spent ${inr.format(fund.allTimeSpent)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                ),
              ),
              if (fund.additionalMergedInflowAllTime > 0 ||
                  fund.additionalMergedInflowMonth > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Additional funds (merged): ${inr.format(fund.additionalMergedInflowMonth)} this month · ${inr.format(fund.additionalMergedInflowAllTime)} all-time',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: DesignColors.primary,
                  ),
                ),
              ],
              // Personal advance credit — compact inline mention
              _buildPersonalCreditInline(billingAsync, inr),
            ],
          ),
        );
      },
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

  /// Compact inline widget showing the resident's personal advance credit
  /// inside the society fund card. Returns SizedBox.shrink when credit is 0.
  Widget _buildPersonalCreditInline(
    AsyncValue<BillingCycleCurrent> billingAsync,
    NumberFormat inr,
  ) {
    return billingAsync.maybeWhen(
      data: (cycle) {
        final credit = (cycle.availableCredit ?? 0).toDouble();
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
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildOpenBillingStripe(
    BuildContext context,
    BillingCycleCurrent cycle,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final total = cycle.totalDue ?? cycle.amount ?? 0;
    final availableCredit = cycle.availableCredit ?? 0;
    final remainingDue = cycle.remainingDue ?? total;
    final isPayableNow = cycle.status?.isOpen == true;
    final isClosed = cycle.status?.isClosed == true;
    final statusLabel = cycle.status?.isOpen == true
        ? 'OPEN'
        : cycle.status?.isUpcoming == true
        ? 'UPCOMING'
        : cycle.status?.isClosed == true
        ? 'CLOSED'
        : 'BILLING';

    if (!isPayableNow && cycle.status?.isUpcoming != true && !isClosed) {
      return const SizedBox.shrink();
    }

    final Color accentColor;
    final IconData accentIcon;
    final String amountLine;

    if (isPayableNow) {
      accentColor = _kOrange;
      accentIcon = Icons.event_available_rounded;
      final windowEnd = cycle.dueDateUtc ?? cycle.paymentEndUtc;
      final subtitle = windowEnd != null
          ? 'Pay before ${DateFormat('dd MMM, HH:mm').format(windowEnd.toLocal())}'
          : 'Payment window open';
      amountLine = availableCredit > 0
          ? '$subtitle · ${inr.format(remainingDue)} due after ${inr.format(availableCredit)} credit'
          : '$subtitle · ${inr.format(total)} due';
    } else if (cycle.status?.isUpcoming == true) {
      accentColor = DesignColors.primary;
      accentIcon = Icons.schedule_rounded;
      final start = cycle.paymentStartUtc;
      final dueText = availableCredit > 0
          ? '${inr.format(remainingDue)} due after ${inr.format(availableCredit)} credit'
          : '${inr.format(total)} due';
      amountLine = start != null
          ? 'Opens ${DateFormat('dd MMM, HH:mm').format(start.toLocal())} · $dueText'
          : 'Opening soon · $dueText';
    } else {
      accentColor = DesignColors.error;
      accentIcon = Icons.lock_clock_outlined;
      amountLine = remainingDue > 0
          ? 'Window closed · ${inr.format(remainingDue)} remains due'
          : 'Window closed';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_kRadiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadiusMd),
        onTap: () => isPayableNow
            ? _confirmPayThenMaintenance(context)
            : _pushMaintenanceFinance(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kRadiusMd),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            boxShadow: _cardShadow(0.05),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  accentIcon,
                  size: 22,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if ((cycle.cycleKey ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            cycle.cycleKey!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cycle.title ?? 'Maintenance billing',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amountLine,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _kTextSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPayableNow)
                FilledButton(
                  onPressed: () => _confirmPayThenMaintenance(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Pay now',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: () => _pushMaintenanceFinance(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    side: BorderSide(color: DesignColors.primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  void _pushMaintenanceFinance(BuildContext context) {
    context.push('/resident/maintenance');
  }

  Future<void> _confirmPayThenMaintenance(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete payment'),
        content: const Text(
          'In-app checkout is not available yet. Please pay this cycle at your '
          'society office or through the method your administrator shares. You can '
          'open Maintenance & finances to review dues and receipts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/resident/maintenance');
            },
            child: const Text('Open maintenance'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onViewAll, {bool dense = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.35,
            height: dense ? 1.1 : 1.2,
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: DesignColors.primary,
            padding: EdgeInsets.fromLTRB(4, dense ? 0 : 4, 4, dense ? 0 : 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
          ),
          child: Text(
            'View All >',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: dense ? 1.1 : 1.2,
              color: DesignColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  void _openQuickAction(BuildContext context, QuickAction action) {
    switch (action.id) {
      case 'parcels':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ParcelManagementScreen()),
        );
        return;
      case 'visitor_history':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const VisitorHistoryScreen()),
        );
        return;
      case 'amenity_bookings':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AmenityBookingHistoryScreen()),
        );
        return;
      case 'maintenance_expenses':
        context.push('/resident/maintenance-payment');
        return;
      case 'community':
        ref.read(currentTabProvider.notifier).state = 1;
        return;
      case 'sos':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SOSScreen()),
        );
        return;
      case 'amenities':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AmenitiesScreen()),
        );
        return;
      case 'complaint':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ComplaintScreen()),
        );
        return;
      case 'daily_help':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const VendorsStaffScreen()),
        );
        return;
      case 'more':
        _showMoreServicesSheet(context);
        return;
      default:
        if (action.route.isNotEmpty) {
          context.push(action.route);
        }
        return;
    }
  }

  String _quickActionOverflowSubtitle(String id) {
    switch (id) {
      case 'parcels':
        return 'Deliveries and pickups';
      case 'maintenance_expenses':
        return 'Paid/unpaid months and expense split';
      case 'community':
        return 'Notices, polls, events';
      case 'sos':
        return 'Emergency assistance';
      case 'amenities':
        return 'Book society amenities';
      case 'complaint':
        return 'Raise a complaint';
      case 'daily_help':
        return 'Service vendors';
      default:
        return '';
    }
  }

  void _showMoreServicesSheet(BuildContext context) {
    final userExcluded = ref.read(authProvider).user?.isBillingExcluded ?? false;
    final cycleExcluded = ref.read(residentBillingCycleProvider).maybeWhen(
      data: (c) => c.maintenanceBillingExcluded,
      orElse: () => false,
    );
    final excluded = userExcluded || cycleExcluded;
    final overflowActions = excluded
        ? residentQuickActionsOverflow.where((a) => a.id != 'maintenance_expenses').toList()
        : residentQuickActionsOverflow;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: DesignColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'More actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  excluded
                      ? 'Parcels and community notices'
                      : 'Parcels, maintenance & expenses, and community notices',
                  style: const TextStyle(fontSize: 13, color: DesignColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...overflowActions.map(
                  (action) => _moreSheetTile(
                    icon: action.icon,
                    title: action.label,
                    subtitle: _quickActionOverflowSubtitle(action.id),
                    color: action.color,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openQuickAction(context, action);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _moreSheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: DesignColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: DesignColors.textTertiary),
      onTap: onTap,
    );
  }

  Widget _buildGateVisitorRequestsBanner(BuildContext context) {
    final gateAsync = ref.watch(visitorApprovalRequestsProvider('pending'));

    // Self-hide on a normal (no-pending) day. We only short-circuit on a
    // definite empty list — loading/error keep the title visible so the
    // resident gets feedback that we're checking.
    final pendingList = gateAsync.valueOrNull;
    if (pendingList != null && pendingList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gate visitor requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.35,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        gateAsync.when(
          loading: () => Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _cardShadow(0.04),
            ),
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
          error: (_, _) => Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadiusMd),
            child: InkWell(
              onTap: () =>
                  ref.invalidate(visitorApprovalRequestsProvider('pending')),
              borderRadius: BorderRadius.circular(_kRadiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                  boxShadow: _cardShadow(0.04),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Could not load gate requests. Tap to retry.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade900,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Icon(Icons.refresh_rounded, color: Colors.red.shade700, size: 22),
                  ],
                ),
              ),
            ),
          ),
          data: (list) {
            final n = list.length;
            final hasPending = n > 0;
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(_kRadiusMd),
                onTap: () => context.push('/resident/visitor-requests'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_kRadiusMd),
                    border: Border.all(
                      color: hasPending
                          ? DesignColors.primary.withValues(alpha: 0.35)
                          : const Color(0xFFE8ECF0),
                    ),
                    boxShadow: _cardShadow(0.04),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasPending
                              ? DesignColors.primary.withValues(alpha: 0.12)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.how_to_reg_rounded,
                          size: 20,
                          color: hasPending ? DesignColors.primary : _kTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPending
                                  ? '$n pending ${n == 1 ? 'request' : 'requests'}'
                                  : 'No pending approvals',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                                letterSpacing: -0.25,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPending
                                  ? 'Approve or decline — security is waiting'
                                  : 'Visitors registered for your flat appear here',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _kTextSecondary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (hasPending)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: DesignColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: DesignColors.textSecondary.withValues(alpha: 0.85),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVisitorsAndGateSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Visitors & gate',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.35,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pre-approve guests and passes for your flat',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: DesignColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _cardShadow(0.05),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.push('/resident/pre-approve-visitor'),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: const Text(
                  'Add pre-approved visitor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/resident/my-pre-approved-visitors'),
                icon: Icon(Icons.groups_2_outlined, color: DesignColors.primary.withValues(alpha: 0.95), size: 20),
                label: Text(
                  'My pre-approved visitors',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.primary.withValues(alpha: 0.95),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignColors.primary,
                  side: const BorderSide(color: Color(0xFFCBD8F5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tight header: avoids [TextButton] minimum vertical insets that widen the gap to the grid.
  Widget _buildQuickActionsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.text.primary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Most-used resident tasks',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.text.secondary,
                  ),
            ),
          ],
        ),
        InkWell(
          onTap: () => _showAllQuickActionsSheet(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 2, 2),
            child: Text(
              'View all',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.brand.primary,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuickActionsHeader(context),
        const SizedBox(height: 10),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 80,
          ),
          itemCount: residentHomeQuickActionsGrid.length,
          itemBuilder: (context, index) {
            return _quickActionTile(context, residentHomeQuickActionsGrid[index]);
          },
        ),
      ],
    );
  }

  Widget _quickActionTile(BuildContext context, QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        border: Border.all(color: context.surface.border),
        boxShadow: _cardShadow(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadiusMd),
          onTap: () => _openQuickAction(context, action),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(action.icon, color: action.color, size: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.text.primary,
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


  /// Single Maintenance card with two sub-CTAs (dues + insights).
  ///
  /// Replaces the previous pair of separate cards
  /// (`_buildMaintenanceOverviewEntry` + `_buildMaintenanceInsightsEntry`)
  /// which both lived in the awareness zone and roughly doubled the
  /// vertical real estate of the same domain. Each row keeps its own
  /// destination route so no functionality is lost.
  Widget _buildMaintenanceCard(BuildContext context) {
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
          _maintenanceCardRow(
            context,
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF43A047),
            title: 'Dues, payments & credit',
            subtitle: 'Pay open bills, view history and credit balance',
            onTap: () => context.push('/resident/maintenance'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _maintenanceCardRow(
            context,
            icon: Icons.insights_rounded,
            iconColor: DesignColors.primary,
            title: 'Trends & expenses',
            subtitle: 'Month-wise paid/unpaid, society spend, pending dues',
            onTap: () => context.push('/resident/maintenance-payment'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 46),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ),
          _maintenanceCardRow(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFDC2626),
            title: 'Outstanding dues',
            subtitle: 'All pending payments across villas',
            onTap: () => context.push('/resident/maintenance-payment'),
            trailingBadge: villasCount != null && villasCount > 0
                ? villasCount
                : null,
          ),
        ],
      ),
    );
  }

  Widget _maintenanceCardRow(
    BuildContext context, {
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
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

  Widget _buildOutstandingDues(
    BuildContext context,
    AsyncValue<List<MaintenanceDueModel>> pendingState,
  ) {
    return pendingState.when(
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
      error: (_, _) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        child: InkWell(
          onTap: () => ref.invalidate(pendingMaintenanceProvider),
          borderRadius: BorderRadius.circular(_kRadiusLg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kRadiusLg),
              border: Border.all(color: const Color(0xFFFFCDD2)),
              boxShadow: _cardShadow(0.04),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load dues. Tap to retry.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(Icons.refresh_rounded, color: Colors.red.shade700, size: 22),
              ],
            ),
          ),
        ),
      ),
      data: (pending) {
        final inr = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        );
        final totalDue = pending.fold<double>(0, (sum, item) => sum + item.amount);
        final hasDue = totalDue > 0;
        if (!hasDue) {
          return const SizedBox.shrink();
        }

        final count = pending.length;
        DateTime? earliestDue;
        for (final item in pending) {
          earliestDue = earliestDue == null || item.dueDate.isBefore(earliestDue)
              ? item.dueDate
              : earliestDue;
        }

        final now = DateTime.now();

        final String statusLabel;
        final Color accent;
        final Color badgeBg;
        final Color badgeFg;

        if (earliestDue == null) {
          statusLabel = 'Due';
          accent = DesignColors.primary;
          badgeBg = DesignColors.primary.withValues(alpha: 0.12);
          badgeFg = DesignColors.primary;
        } else if (earliestDue.isBefore(now)) {
          statusLabel = 'Overdue';
          accent = const Color(0xFFDC2626);
          badgeBg = const Color(0xFFFEE2E2);
          badgeFg = const Color(0xFFB91C1C);
        } else {
          statusLabel = 'Due soon';
          accent = const Color(0xFFD97706);
          badgeBg = const Color(0xFFFEF3C7);
          badgeFg = const Color(0xFFB45309);
        }

        final String scheduleLine;
        if (earliestDue == null) {
          scheduleLine = 'Tap to review and pay';
        } else if (earliestDue.isBefore(now)) {
          final overdueDays = now.difference(earliestDue).inDays.abs();
          scheduleLine =
              '$overdueDays day${overdueDays == 1 ? '' : 's'} overdue · ${DateFormat('dd MMM yyyy').format(earliestDue)}';
        } else {
          final daysLeft = earliestDue.difference(now).inDays + 1;
          scheduleLine =
              '${DateFormat('dd MMM yyyy').format(earliestDue)} · $daysLeft day${daysLeft == 1 ? '' : 's'} left';
        }

        final countHint = count > 1 ? ' · $count charges' : '';

        void openPayments() => context.push('/resident/maintenance');

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kRadiusMd),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(_kRadiusMd),
            onTap: openPayments,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kRadiusMd),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
                boxShadow: _cardShadow(0.04),
              ),
              padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Icon(Icons.account_balance_wallet_outlined, size: 22, color: accent.withValues(alpha: 0.95)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Outstanding dues',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: DesignColors.textSecondary,
                                letterSpacing: 0.05,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: badgeFg,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$scheduleLine$countHint',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: _kTextSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        inr.format(totalDue),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.primary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: DesignColors.textTertiary.withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    AsyncValue<List<NotificationModel>> notificationsState,
  ) {
    final notifications = notificationsState.valueOrNull ?? const <NotificationModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Recent Activity', () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => residentNotificationsEntry),
          );
        }),
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
            error: (_, _) => _emptyBlock(
              context,
              message: 'Could not load recent activity',
              onRetry: () => ref.invalidate(notificationProvider),
            ),
            data: (_) {
              if (notifications.isEmpty) {
                return _emptyBlock(
                  context,
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
                          '${latest[i].message} • ${_timeAgo(latest[i].createdAt)}',
                      status: latest[i].isRead ? 'Seen' : 'New',
                      statusColor: latest[i].isRead ? _kTextSecondary : _kGreen,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => residentNotificationsEntry,
                          ),
                        );
                      },
                    ),
                    if (i != latest.length - 1)
                      const Divider(height: 1, color: DesignColors.borderLight),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(_kRadiusSm),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: chipColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: DesignColors.textTertiary, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAllQuickActionsSheet(BuildContext context) {
    final userExcluded = ref.read(authProvider).user?.isBillingExcluded ?? false;
    final cycleExcluded = ref.read(residentBillingCycleProvider).maybeWhen(
      data: (c) => c.maintenanceBillingExcluded,
      orElse: () => false,
    );
    final excluded = userExcluded || cycleExcluded;
    final viewAllActions = excluded
        ? residentQuickActionsViewAll.where((a) => a.id != 'maintenance_expenses').toList()
        : residentQuickActionsViewAll;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: DesignColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Additional shortcuts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'These are not on your home quick row',
                  style: TextStyle(fontSize: 13, color: DesignColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (viewAllActions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No extra shortcuts right now.',
                      style: TextStyle(fontSize: 14, color: DesignColors.textSecondary),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: viewAllActions.map((action) {
                      return SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 60) / 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openQuickAction(context, action);
                          },
                          icon: Icon(action.icon, color: action.color, size: 18),
                          label: Text(
                            action.label,
                            style: const TextStyle(
                              color: DesignColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            side: const BorderSide(color: DesignColors.borderLight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportantNotices(
    BuildContext context,
    AsyncValue<List<NoticeModel>> noticesState,
  ) {
    final notices = noticesState.valueOrNull ?? const <NoticeModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Important Notices', () {
          ref.read(currentTabProvider.notifier).state = 1;
        }),
        const SizedBox(height: 6),
        noticesState.when(
          loading: () => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadiusLg),
              boxShadow: _cardShadow(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _emptyBlock(
            context,
            message: 'Could not load notices',
            onRetry: () => ref.invalidate(noticesProvider),
          ),
          data: (_) {
            if (notices.isEmpty) {
              return _emptyBlock(
                context,
                message: 'No notices published yet',
                onRetry: () => ref.invalidate(noticesProvider),
              );
            }
            final top = notices.take(2).toList();
            const borderLight = DesignColors.borderLight;
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              elevation: 0,
              shadowColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kRadiusMd),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _cardShadow(0.055),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < top.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, thickness: 1, color: borderLight),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              ref.read(currentTabProvider.notifier).state = 1,
                          child: _buildNoticeCard(
                            title: top[i].title,
                            content: top[i].content,
                            date: _timeAgo(top[i].publishedAt),
                            accentColor: top[i].isUrgent
                                ? const Color(0xFFE53935)
                                : DesignColors.primary,
                            showUrgentBadge: top[i].isUrgent,
                            embeddedInPanel: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _emptyBlock(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        boxShadow: _cardShadow(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _kTextSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kTextSecondary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildNoticeCard({
    required String title,
    required String content,
    required String date,
    required Color accentColor,
    required bool showUrgentBadge,
    bool embeddedInPanel = false,
  }) {
    const accentW = 4.0;
    const titleSize = 14.0;
    const bodySize = 12.5;
    const bodyLines = 3;

    final inner = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: accentW,
            decoration: BoxDecoration(color: accentColor),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.campaign_outlined,
                          size: 20,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showUrgentBadge) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'URGENT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                                letterSpacing: -0.28,
                                height: 1.22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: _kTextSecondary.withValues(alpha: 0.88),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextSecondary.withValues(alpha: 0.92),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: DesignColors.textTertiary.withValues(alpha: 0.75),
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    content,
                    maxLines: bodyLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: bodySize,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary.withValues(alpha: 0.95),
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (embeddedInPanel) {
      return inner;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kRadiusLg),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _buildSupportStripWithFab(
    BuildContext context,
    AsyncValue<List<SecurityContactModel>> securityContactsAsync,
  ) {
    return _buildSupportBanner(context, securityContactsAsync);
  }

  Widget _buildSupportBanner(
    BuildContext context,
    AsyncValue<List<SecurityContactModel>> securityContactsAsync, {
    double trailingReserve = 0,
  }) {
    final contacts = securityContactsAsync.maybeWhen(
      data: (list) => list.where((c) => c.phone.trim().isNotEmpty).toList(),
      orElse: () => const <SecurityContactModel>[],
    );
    final primaryPhone = contacts.isNotEmpty ? contacts.first.phone.trim() : '100';
    final hasGuardContact = contacts.isNotEmpty;
    final securityLine = hasGuardContact
        ? 'Security desk: $primaryPhone'
        : 'Emergency fallback: 100';

    Future<void> callSecurity() async {
      final uri = Uri.parse('tel:$primaryPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return Material(
      color: context.state.info.bg.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(_kRadiusLg),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadiusLg),
        onTap: callSecurity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: context.brand.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: trailingReserve),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Need Help? Contact Security',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.brand.primary,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            securityLine,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: context.text.secondary,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    color: context.surface.defaultSurface,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: callSecurity,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(Icons.phone, color: context.brand.primary, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                hasGuardContact
                    ? 'Tap Call to reach your society security desk.'
                    : 'No active guard contact found. Calling emergency line 100.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: DesignColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab index for [ResidentShell] (home / community / profile).
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Static data describing one Overview metric tile.
class _OverviewTileSpec {
  const _OverviewTileSpec({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
}

/// Circular avatar shown in the home header.
///
/// Renders the resident's uploaded `photoUrl` when available (cached) and
/// falls back to the first letter of the name on load error or missing URL.
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveServerFileUrl(photoUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.brand.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: context.brand.primary.withValues(alpha: 0.16),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? _initialFallback(context, initial)
          : CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              cacheKey: url,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => _initialFallback(context, initial),
              errorWidget: (_, _, _) => _initialFallback(context, initial),
            ),
    );
  }

  Widget _initialFallback(BuildContext context, String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: context.brand.primary,
          letterSpacing: -0.35,
          height: 1,
        ),
      ),
    );
  }
}
