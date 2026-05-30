import 'dart:async';
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
import '../../../../core/widgets/enterprise_ui.dart';
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
import '../../data/resident_data_refresh.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/providers/dashboard_provider.dart';
import '../../data/providers/security_contact_provider.dart';
import '../../data/providers/special_project_provider.dart';
import '../../data/providers/banner_provider.dart';
import '../../data/providers/utilities_provider.dart';
import '../../data/models/water_supply_model.dart';
import '../../data/models/banner_model.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      requestResidentDataRefresh();
    }
  }

  Future<void> _handleRefresh() async {
    invalidateMaintenancePaymentProviders(ref);
    ref.invalidate(noticesProvider);
    ref.invalidate(eventsProvider);
    ref.invalidate(pollsProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(visitorApprovalRequestsProvider('pending'));
    ref.invalidate(visitorApprovalRequestsProvider('all'));
    ref.invalidate(activeBannersProvider);
    ref.invalidate(waterSupplyStatusProvider);
    ref.invalidate(garbageCollectionActiveProvider);
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
      case UserRole.residentCumAdmin:
        return 'Admin · Resident';
    }
  }

  /// Home header pill: show Owner / Tenant / Family member when `/residents/me` provides it.
  String _headerOccupantOrRoleBadge(UserRole role, UserModel? user) {
    if (role.isResidentLike) {
      final occ = user?.effectiveOccupantDisplay;
      if (occ != null && occ.isNotEmpty) return occ;
    }
    if (role.isAdminLike && user?.villaId != null && user!.villaId!.isNotEmpty) {
      return 'Admin · Resident';
    }
    return _roleLabel(role);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      final pu = prev?.user;
      final nu = next.user;
      if (pu?.id != nu?.id ||
          pu?.villaId != nu?.villaId ||
          pu?.maintenanceBillingRole != nu?.maintenanceBillingRole) {
        invalidateMaintenancePaymentProviders(ref);
      }
    });

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
        if (!c.hasCycle || c.isPaid) {
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
      backgroundColor: context.surface.background,
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
                    // === UTILITY status strip ===
                    _buildUtilityStatusStrip(context),

                    // === BANNER zone — promotional/event banners ===
                    _buildBannerCarousel(context),

                    // === URGENCY zone — time-sensitive, only renders when relevant ===

                    // Gate visitor requests: "someone is at the gate right
                    // now". Self-hides when there are zero pending requests
                    // so a quiet day doesn't waste prime real estate.
                    _buildGateVisitorRequestsBanner(context),

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

                    // Special Projects — quick view of active projects
                    _buildSpecialProjectsCard(context),
                    const SizedBox(height: 8),

                    // Community-level ledger — informational, not actionable.
                    // Hidden from tenants: fund balance is internal governance data.
                    if (!isBillingExcluded && !(user?.isTenant ?? false)) ...[
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
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 105,
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
        final hasPending = fund.pendingDues > 0;
        // Hero shows societyFund (collection − expenses, no advance credit)
        final isPositive = fund.societyFund >= 0;
        // Projected = societyFund + pending (advance credit separate)
        final projectedSociety = fund.societyFund + fund.pendingDues;
        final projectedPositive = projectedSociety >= 0;
        final projectedColor =
            projectedPositive ? const Color(0xFF166534) : const Color(0xFFDC2626);
        // Bank balance colors (for summary section)
        final bankPositive = fund.currentBalance >= 0;
        final bankColor = bankPositive
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);
        final progress = (fund.collectionRate / 100).clamp(0.0, 1.0);
        final progressColor = progress >= 0.9
            ? const Color(0xFF16A34A)
            : progress >= 0.7
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        // Hero colors — green-ish when positive, red-ish when negative
        final heroBg = isPositive
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2);
        final heroBorder = isPositive
            ? const Color(0xFFBBF7D0)
            : const Color(0xFFFECACA);
        final heroAmountColor = isPositive
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626);
        final heroMuted = isPositive
            ? const Color(0xFF15803D)
            : const Color(0xFF991B1B);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              // ══════════ Hero: Fund Balance (compact) ══════════
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                decoration: BoxDecoration(
                  color: heroBg,
                  border: Border(bottom: BorderSide(color: heroBorder)),
                ),
                child: Column(
                  children: [
                    // Header + amount on one row
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
                          onTap: () => _showFundInfoSheet(context),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: heroMuted.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                    // Progress bar
                    if (fund.expectedAllTime > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: heroMuted.withValues(alpha: 0.08),
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
                    // Row 1: Collection + Expenses
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            label: 'Collection',
                            value: inr.format(fund.allTimeCollected),
                            subtitle: 'of ${inr.format(fund.expectedAllTime)}',
                            accentColor: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFF0FDF4),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _metricTile(
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
                    // Row 2: Pending + Advance Credit
                    Row(
                      children: [
                        Expanded(
                          child: _metricTile(
                            label: 'Pending Dues',
                            value: hasPending
                                ? inr.format(fund.pendingDues)
                                : 'None',
                            subtitle: hasPending ? 'outstanding' : 'all clear',
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
                          child: _metricTile(
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
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // ── Balance in Bank (society fund + advance credit) ──
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
                              : 'Collection ${inr.format(fund.allTimeCollected)} − Expenses ${inr.format(fund.allTimeSpent)}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),

                      // ── After all dues cleared ──
                      if (hasPending) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
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
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                child: _buildPersonalCreditInline(billingAsync, inr),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Enterprise-style metric tile with colored left accent border.
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
            // Colored accent bar
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
              context.text.secondary,
              'In bank',
              'Total cash in the society account (spendable + advance credit).',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(Color color, String title, String description) {
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
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: context.text.secondary,
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
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.text.secondary,
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

  void _confirmPayThenMaintenance(BuildContext context) {
    // Navigate directly to maintenance hub where resident can access
    // UPI payment, view dues, and pay individual or all bills.
    context.push('/resident/maintenance');
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
      case 'utilities':
        return 'Water supply & garbage collection';
      case 'directory':
        return 'Searchable resident directory';
      case 'incidents':
        return 'Society incident reports';
      case 'vehicle_log':
        return 'Vehicle gate entry/exit log';
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
                          color: hasPending ? DesignColors.primary : context.text.secondary,
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
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: context.text.secondary,
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

  // ── Banner Carousel ──────────────────────────────────────────────────
  Widget _buildBannerCarousel(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersProvider);
    return bannersAsync.maybeWhen(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        return _BannerCarouselWidget(banners: banners);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  // ── Utility Status Strip ───────────────────────────────────────────
  Widget _buildUtilityStatusStrip(BuildContext context) {
    final waterAsync = ref.watch(waterSupplyStatusProvider);
    final garbageAsync = ref.watch(garbageCollectionActiveProvider);
    final garbageHistoryAsync = ref.watch(garbageCollectionHistoryProvider);

    final waterGates = waterAsync.valueOrNull ?? [];
    final garbageStatus = garbageAsync.valueOrNull;
    final collectorInside = garbageStatus?.isInside ?? false;
    final garbageHistory = garbageHistoryAsync.valueOrNull ?? [];

    if (waterGates.isEmpty) return const SizedBox.shrink();

    // Determine garbage status: inside / left today / absent
    String garbageLabel;
    Color garbageColor;
    bool garbagePulse = false;
    if (collectorInside) {
      garbageLabel = 'Garbage Collection Inside';
      garbageColor = DesignColors.warning;
      garbagePulse = true;
    } else {
      // Check if collector visited today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayVisit = garbageHistory.where((e) {
        return e.entryTime.isAfter(todayStart) && e.exitTime != null;
      }).toList();
      if (todayVisit.isNotEmpty) {
        final lastExit = todayVisit.first.exitTime!;
        final exitTime = DateFormat.jm().format(lastExit.toLocal());
        garbageLabel = 'Garbage Left $exitTime';
        garbageColor = DesignColors.success;
      } else {
        garbageLabel = 'Garbage Absent Today';
        garbageColor = context.text.tertiary;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push('/resident/utilities'),
        child: EnterprisePanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Water status + Request button
              Row(
                children: [
                  Icon(Icons.water_drop_rounded,
                      size: 14, color: DesignColors.primary),
                  const SizedBox(width: 6),
                  // Water gate chips
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: waterGates.map((g) {
                        final isOn = g.isOn;
                        return _statusChip(
                          label: '${g.gateName.isNotEmpty ? g.gateName : "Water"} ${isOn ? "ON" : "OFF"}',
                          color: isOn ? DesignColors.success : DesignColors.error,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showWaterRequestSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: DesignColors.primary.withValues(alpha: 0.4),
                        ),
                        borderRadius:
                            BorderRadius.circular(DesignRadius.full),
                      ),
                      child: Text(
                        'Request',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Row 2: Garbage status + view details hint
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 14, color: garbageColor),
                  const SizedBox(width: 6),
                  _statusChip(
                    label: garbageLabel,
                    color: garbageColor,
                    pulse: garbagePulse,
                  ),
                  const Spacer(),
                  Text(
                    'View details',
                    style: DesignTypography.captionSmall.copyWith(
                      color: context.text.tertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 14, color: context.text.tertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

  Widget _statusChip({
    required String label,
    required Color color,
    bool pulse = false,
  }) {
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulse
              ? dot
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 800.ms)
                  .then()
                  .fadeOut(duration: 800.ms)
              : dot,
          const SizedBox(width: 5),
          Text(
            label,
            style: DesignTypography.captionSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showWaterRequestSheet(BuildContext context) {
    final waterGates = ref.read(waterSupplyStatusProvider).valueOrNull ?? [];
    if (waterGates.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WaterRequestSheet(gates: waterGates),
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
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
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
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
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
        final totalDue = pending.fold<double>(0, (sum, item) => sum + item.remainingDue);
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

        void openPayments() => context.push('/resident/maintenance/dues');

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
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: context.text.secondary,
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
                      statusColor: latest[i].isRead ? context.text.secondary : _kGreen,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
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
          Icon(Icons.info_outline, color: context.text.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.text.secondary,
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
                                  color: context.text.secondary.withValues(alpha: 0.88),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.text.secondary.withValues(alpha: 0.92),
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
                      color: context.text.secondary.withValues(alpha: 0.95),
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

  // ── Special Projects card ───────────────────────────────────────
  Widget _buildSpecialProjectsCard(BuildContext context) {
    final projectsAsync = ref.watch(residentSpecialProjectsProvider);

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final active =
            projects.where((p) => p.status == 'ACTIVE').toList();
        if (active.isEmpty) return const SizedBox.shrink();

        final inr = NumberFormat.currency(
            locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
        final myOutstanding = active.fold(0.0, (sum, p) =>
            sum + (p.myContribution?.outstanding ?? 0));
        final totalCollected =
            active.fold(0.0, (sum, p) => sum + p.totalCollected);
        final totalTarget =
            active.fold(0.0, (sum, p) => sum + p.targetAmount);
        final progress = totalTarget > 0
            ? (totalCollected / totalTarget).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: context.surface.defaultSurface,
            borderRadius: BorderRadius.circular(_kRadiusLg),
            border: Border.all(color: context.surface.border),
            boxShadow: _cardShadow(),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(_kRadiusLg),
              onTap: () => context.push('/resident/special-projects'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.construction_rounded,
                              color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${active.length} Active Project${active.length != 1 ? 's' : ''}',
                                style: DesignTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.text.primary,
                                ),
                              ),
                              if (myOutstanding > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'My Outstanding: ${inr.format(myOutstanding)}',
                                  style: DesignTypography.caption.copyWith(
                                    color: DesignColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: context.text.tertiary),
                      ],
                    ),
                    // Aggregate progress bar
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DesignRadius.full),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: context.surface.border,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${inr.format(totalCollected)} / ${inr.format(totalTarget)} collected',
                        style: DesignTypography.captionSmall.copyWith(
                          color: context.text.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: DesignAnimations.durationEntrance)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }
}

/// Tab index for [ResidentShell] (home / community / profile).
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Bottom sheet for submitting a water supply request.
class _WaterRequestSheet extends ConsumerStatefulWidget {
  const _WaterRequestSheet({required this.gates});
  final List<WaterSupplyStatus> gates;

  @override
  ConsumerState<_WaterRequestSheet> createState() => _WaterRequestSheetState();
}

class _WaterRequestSheetState extends ConsumerState<_WaterRequestSheet> {
  late String _selectedGateId;
  String _requestType = 'TURN_ON';
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedGateId = widget.gates.first.gateId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason (min 3 chars)')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(utilitiesRepositoryProvider);
      await repo.submitWaterRequest(
        gateId: _selectedGateId,
        requestType: _requestType,
        reason: reason,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water request submitted')),
        );
        ref.invalidate(waterSupplyMyRequestsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Request Water Supply',
            style: DesignTypography.headingM.copyWith(
              color: context.text.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Gate selector
          DropdownButtonFormField<String>(
            value: _selectedGateId,
            decoration: const InputDecoration(
              labelText: 'Gate',
              border: OutlineInputBorder(),
            ),
            items: widget.gates
                .map((g) => DropdownMenuItem(
                      value: g.gateId,
                      child: Text(g.gateName.isNotEmpty ? g.gateName : 'Gate'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedGateId = v);
            },
          ),
          const SizedBox(height: 12),
          // Request type toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Turn ON'),
                  selected: _requestType == 'TURN_ON',
                  selectedColor: DesignColors.success.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setState(() => _requestType = 'TURN_ON'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Turn OFF'),
                  selected: _requestType == 'TURN_OFF',
                  selectedColor: DesignColors.error.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setState(() => _requestType = 'TURN_OFF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Reason
          TextField(
            controller: _reasonController,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why do you need this change?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.water_drop_rounded),
              label: const Text('Submit Request'),
            ),
          ),
        ],
      ),
    );
  }
}

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

// ══════════════════════════════════════════════════════════════════════
//  Banner Carousel Widget
// ══════════════════════════════════════════════════════════════════════
class _BannerCarouselWidget extends StatefulWidget {
  const _BannerCarouselWidget({required this.banners});
  final List<BannerModel> banners;

  @override
  State<_BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<_BannerCarouselWidget> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.banners.length > 1) {
      _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final next = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Color _bannerTypeColor(String type) {
    return switch (type.toUpperCase()) {
      'EMERGENCY' => DesignColors.error,
      'MAINTENANCE' => DesignColors.warning,
      'EVENT' || 'FESTIVAL' => const Color(0xFF7C3AED),
      'OFFER' => const Color(0xFF2563EB),
      'COMMUNITY' => DesignColors.primary,
      _ => DesignColors.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kSectionGap),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                final typeColor = _bannerTypeColor(banner.type);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      if (banner.actionUrl != null &&
                          banner.actionUrl!.isNotEmpty) {
                        launchUrl(Uri.parse(banner.actionUrl!),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(_kRadiusLg),
                        border: Border.all(
                          color: typeColor.withValues(alpha: 0.2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.imageUrl != null &&
                              banner.imageUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: resolveServerFileUrl(banner.imageUrl!) ?? banner.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: typeColor.withValues(alpha: 0.06),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: typeColor.withValues(alpha: 0.06),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.65),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(
                                    DesignRadius.full),
                              ),
                              child: Text(
                                banner.type,
                                style:
                                    DesignTypography.captionSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 14,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: DesignTypography.headingM.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (banner.description != null &&
                                    banner.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    banner.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DesignTypography.bodySmall
                                        .copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.banners.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? DesignColors.primary
                        : DesignColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance)
        .slideY(begin: DesignAnimations.slideSubtle, end: 0);
  }
}
