import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
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
import '../widgets/home/home_dashboard_stats_row.dart';
import '../widgets/home/home_gate_visitor_requests.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_important_notices.dart';
import '../widgets/home/home_maintenance_card.dart';
import '../widgets/home/home_quick_actions.dart';
import '../widgets/home/home_recent_activity.dart';
import '../widgets/home/home_shared.dart';
import '../widgets/home/home_society_finances.dart';
import '../widgets/home/home_special_projects_card.dart';
import '../widgets/home/home_support_strip.dart';
import '../widgets/home/home_utility_status_strip.dart';
import '../widgets/home/home_visitors_gate_section.dart';

// Re-export so existing `import 'home_screen.dart'` still provides currentTabProvider.
export '../providers/resident_tab_provider.dart' show currentTabProvider;

/// Landing / home dashboard — UI aligned to product reference (light cards, blue accents).
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
    final isBillingExcluded =
        (user?.isBillingExcluded ?? false) || billingExcludedFromCycle;
    final unreadNotifications = notificationsState.maybeWhen(
      data: (list) => list.where((n) => !n.isRead).length,
      orElse: () => 0,
    );
    final hasImportantNotices =
        (noticesState.valueOrNull ?? const <NoticeModel>[]).isNotEmpty;

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
              HomeHeader(
                name: user?.name ?? 'User',
                role: user?.role ?? UserRole.resident,
                user: user,
                unreadNotifications: unreadNotifications,
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(kHomePadH, 12, kHomePadH, 112),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 0: Utility status (water + garbage cards)
                    const HomeUtilityStatusStrip()
                        .animateSection(0),
                    // 1: Banner carousel
                    const HomeBannerCarousel()
                        .animateSection(1),
                    // 2: Gate visitor requests
                    const HomeGateVisitorRequests()
                        .animateSection(2),

                    // 3: Important notices (conditional)
                    if (hasImportantNotices) ...[
                      HomeImportantNotices(
                        noticesState: noticesState,
                        onViewAll: () => ref
                            .read(currentTabProvider.notifier)
                            .state = 1,
                        onNoticesTap: () => ref
                            .read(currentTabProvider.notifier)
                            .state = 1,
                        onRetry: () =>
                            ref.invalidate(noticesProvider),
                      ).animateSection(3),
                      const SizedBox(height: kHomeSectionGap),
                    ],

                    // 4: Quick actions (5-column grid)
                    const HomeQuickActions()
                        .animateSection(4),
                    const SizedBox(height: kHomeSectionGap),

                    // 5: Society Finances mega-card (replaces outstanding dues + billing stripe + fund card)
                    if (!isBillingExcluded &&
                        !(user?.isTenant ?? false)) ...[
                      HomeSocietyFinances(
                        dashboardAsync: dashboardAsync,
                        pendingState: pendingState,
                      ).animateSection(5),
                      const SizedBox(height: kHomeSectionGap),
                    ],

                    // 6: Dashboard stats row (with month picker)
                    HomeDashboardStatsRow(
                      dashboardAsync: dashboardAsync,
                      isBillingExcluded: isBillingExcluded,
                    ).animateSection(6),
                    const SizedBox(height: kHomeSectionGap),

                    // 7: Maintenance card
                    if (!isBillingExcluded) ...[
                      const HomeMaintenanceCard()
                          .animateSection(7),
                      const SizedBox(height: kHomeSectionGap),
                    ],

                    // 8: Special projects (gap is internal — hidden when no active projects)
                    const HomeSpecialProjectsCard()
                        .animateSection(8),

                    // 9: Visitors & gate (side-by-side cards)
                    const HomeVisitorsGateSection()
                        .animateSection(9),
                    const SizedBox(height: kHomeSectionGap),

                    // 10: Support strip
                    HomeSupportStrip(
                        securityContactsAsync:
                            securityContactsAsync)
                        .animateSection(10),
                    const SizedBox(height: kHomeSectionGap),

                    // 11: Recent activity
                    HomeRecentActivity(
                      notificationsState: notificationsState,
                      onRetry: () =>
                          ref.invalidate(notificationProvider),
                    ).animateSection(11),
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
  Widget animateSection(int index) => animate(
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
