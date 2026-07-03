import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/notice_model.dart';
import '../../data/providers/content_provider.dart';
import '../../data/providers/maintenance_provider.dart';
import '../../data/resident_data_refresh.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/providers/dashboard_provider.dart';
import '../../data/providers/security_contact_provider.dart';
import '../../data/providers/banner_provider.dart';
import '../../data/providers/utilities_provider.dart';
import '../providers/resident_tab_provider.dart';
import '../providers/visitor_provider.dart';
import '../widgets/home/home_banner_carousel.dart';
import '../widgets/home/home_gate_visitor_requests.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_quick_actions.dart';
import '../widgets/home/home_important_notices.dart';
import '../widgets/home/home_maintenance_card.dart';
import '../widgets/home/home_recent_activity.dart';
import '../widgets/home/home_shared.dart';
import '../widgets/home/home_society_finances.dart';
import '../widgets/home/home_special_projects_card.dart';
import '../widgets/home/home_support_strip.dart';
import '../widgets/home/home_utility_status_strip.dart';

// Re-export so existing `import 'home_screen.dart'` still provides currentTabProvider.
export '../providers/resident_tab_provider.dart' show currentTabProvider;

/// Resident home — mock-aligned layout with conditional sections preserved.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
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
    final isBillingExcluded =
        (user?.isBillingExcluded ?? false) || billingExcludedFromCycle;
    final isTenant = user?.isTenant ?? false;
    final showSocietyFinances = !isBillingExcluded && !isTenant;
    final unreadNotifications = notificationsState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );
    final notices = noticesState.valueOrNull ?? const <NoticeModel>[];
    final hasImportantNotices =
        noticesState.isLoading || notices.isNotEmpty;

    return Scaffold(
      backgroundColor: DesignColors.surfaceSoft,
      body: RefreshIndicator(
        color: kHomePurple,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHeader(
                name: user?.name ?? 'User',
                role: user?.role ?? UserRole.resident,
                user: user,
                unreadNotifications: unreadNotifications,
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(kHomePadH, 0, kHomePadH, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Live ops — water / garbage (hidden when inactive)
                    const HomeUtilityStatusStrip().animateSection(0),
                    // Urgent gate approvals (hidden when no pending)
                    const HomeGateVisitorRequests().animateSection(1),
                    // Quick Actions — GatePass+ hero + 5-slot icon rows
                    const HomeQuickActions().animateSection(2),
                    const SizedBox(height: kHomeSectionGap),
                    // Society banners (hidden when empty)
                    const HomeBannerCarousel().animateSection(3),
                    // Notices (hidden when empty after load)
                    if (hasImportantNotices) ...[
                      HomeImportantNotices(
                        noticesState: noticesState,
                        onViewAll: () => openCommunityTab(ref, subTab: 0),
                        onRetry: () => ref.invalidate(noticesProvider),
                      ),
                      const SizedBox(height: kHomeSectionGap),
                    ],
                    // Society finances — owners only, not billing-excluded
                    if (showSocietyFinances) ...[
                      HomeSocietyFinances(
                        dashboardAsync: dashboardAsync,
                        seed: ref.watch(residentDashboardSeedProvider),
                      ),
                      const SizedBox(height: kHomeSectionGap),
                    ],
                    // Personal maintenance card
                    if (!isBillingExcluded) ...[
                      const HomeMaintenanceCard(),
                      const SizedBox(height: kHomeSectionGap),
                    ],
                    // Special projects (hidden when no active projects)
                    // The card itself returns SizedBox.shrink when empty,
                    // so we let it manage its own bottom padding internally.
                    const HomeSpecialProjectsCard(),
                    // Support strip — always visible (falls back to 100 emergency)
                    HomeSupportStrip(
                      securityContactsAsync: securityContactsAsync,
                    ),
                    // Recent activity — hidden when empty
                    HomeRecentActivity(
                      notificationsState: notificationsState,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _SectionAnimate on Widget {
  Widget animateSection(int index) {
    if (index > 2) return this;
    return animate(
      delay: DesignAnimations.sectionStaggerFor(index),
    )
        .fadeIn(
          duration: DesignAnimations.durationEntrance,
          curve: DesignAnimations.curveEntrance,
        )
        .slideY(
          begin: DesignAnimations.slideSubtle,
          curve: DesignAnimations.curveEntrance,
        );
  }
}
