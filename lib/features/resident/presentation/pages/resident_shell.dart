import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/telemetry/app_analytics_service.dart';
import '../../../../core/telemetry/app_analytics_tab_paths.dart';
import '../../../admin/data/providers/admin_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../admin/presentation/pages/admin_dashboard/admin_dashboard_screen.dart';
import '../../data/resident_home_prefetch.dart';
import '../../data/providers/maintenance_provider.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/resident_data_refresh.dart';
import '../../data/services/payment_orchestrator.dart';
import '../providers/resident_tab_provider.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Main shell for resident app with modern bottom navigation
class ResidentShell extends ConsumerStatefulWidget {
  const ResidentShell({super.key});

  @override
  ConsumerState<ResidentShell> createState() => _ResidentShellState();
}

class _ResidentShellState extends ConsumerState<ResidentShell> {
  int? _lastLoggedTab;
  bool _loggedAdminOnly = false;

  void _logTabIfNeeded(int tabIndex, {required bool isAdmin, required bool adminOnly}) {
    if (adminOnly) {
      if (_loggedAdminOnly) return;
      _loggedAdminOnly = true;
      unawaited(AppAnalyticsService.logTabScreen(AppAnalyticsTabPaths.residentAdminOnly));
      return;
    }
    if (_lastLoggedTab == tabIndex) return;
    _lastLoggedTab = tabIndex;
    unawaited(
      AppAnalyticsService.logTabScreen(
        AppAnalyticsTabPaths.residentTab(tabIndex, isAdmin: isAdmin),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      prefetchResidentHomeData(ref);
      PaymentOrchestrator.recoverPendingPayment(context: context, ref: ref);
      final user = ref.read(authProvider).user;
      final isAdmin = user?.role.isAdminLike ?? false;
      final hasVilla = user?.villaId != null && (user?.villaId?.isNotEmpty ?? false);
      final adminOnly = isAdmin && !hasVilla;
      final tab = ref.read(currentTabProvider).clamp(0, adminOnly ? 0 : (isAdmin ? 3 : 2));
      _logTabIfNeeded(tab, isAdmin: isAdmin, adminOnly: adminOnly);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role.isAdminLike ?? false;

    ref.listen<int>(currentTabProvider, (prev, next) {
      final hasVillaNow = user?.villaId != null && (user?.villaId?.isNotEmpty ?? false);
      final adminOnlyNow = isAdmin && !hasVillaNow;
      if (prev != next) {
        _logTabIfNeeded(next, isAdmin: isAdmin, adminOnly: adminOnlyNow);
      }
      if (next == 1) {
        prefetchCommunityTabData(
          ref,
          activeTab: ref.read(communitySubTabIndexProvider),
        );
      }
      if (isAdmin && next == 2 && prev != 2) {
        invalidateAdminHomeFinanceProviders(ref);
        ref.invalidate(adminDashboardProvider);
        ref.invalidate(adminOutstandingDuesProvider);
        ref.invalidate(adminBillingCyclesProvider);
      }
    });

    final currentTab = ref.watch(currentTabProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final hasVilla = user?.villaId != null &&
        (user?.villaId?.isNotEmpty ?? false);

    // Admin without villa → admin-only mode (single tab, no bottom nav)
    final adminOnly = isAdmin && !hasVilla;

    if (adminOnly) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!kIsWeb) SystemNavigator.pop();
        },
        child: const Scaffold(
          body: AdminDashboardScreen(),
        ),
      );
    }

    // Admin with villa → 4 tabs; Resident → 3 tabs
    final profileIndex = isAdmin ? 3 : 2;
    final wide = isWideScreen(context);

    final pages = [
      const HomeScreen(),
      const CommunityScreen(),
      if (isAdmin) const AdminDashboardScreen(),
      const ProfileScreen(),
    ];

    // Clamp to valid range — if an admin's role flips mid-session (auth
    // refresh, logout transition, etc.) the page list shrinks but the
    // global currentTabProvider may still hold a stale high index.
    final safeIndex = currentTab.clamp(0, pages.length - 1);

    final body = IndexedStack(
      index: safeIndex,
      children: pages,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (safeIndex != 0) {
          ref.read(currentTabProvider.notifier).state = 0;
          return;
        }
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.surface.background,
        body: wide
            ? Row(
                children: [
                  _buildNavigationRail(
                    context,
                    ref,
                    currentTab: safeIndex,
                    isAdmin: isAdmin,
                    profileIndex: profileIndex,
                    unreadCount: unreadCount,
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: WebContentConstraint(child: body)),
                ],
              )
            : body,
        bottomNavigationBar: wide
            ? null
            : SafeArea(
                top: false,
                minimum: EdgeInsets.fromLTRB(
                  context.spacing.s16,
                  0,
                  context.spacing.s16,
                  context.spacing.s12,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.surface.defaultSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.surface.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        context,
                        ref,
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Home',
                        index: 0,
                        isSelected: safeIndex == 0,
                        badgeCount: unreadCount,
                      ),
                      _buildNavItem(
                        context,
                        ref,
                        icon: Icons.people_outline_rounded,
                        selectedIcon: Icons.people_rounded,
                        label: 'Community',
                        index: 1,
                        isSelected: safeIndex == 1,
                      ),
                      if (isAdmin)
                        _buildNavItem(
                          context,
                          ref,
                          icon: Icons.admin_panel_settings_outlined,
                          selectedIcon: Icons.admin_panel_settings_rounded,
                          label: 'Admin',
                          index: 2,
                          isSelected: safeIndex == 2,
                        ),
                      _buildNavItem(
                        context,
                        ref,
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        index: profileIndex,
                        isSelected: safeIndex == profileIndex,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavigationRail(
    BuildContext context,
    WidgetRef ref, {
    required int currentTab,
    required bool isAdmin,
    required int profileIndex,
    required int unreadCount,
  }) {
    return NavigationRail(
      selectedIndex: currentTab,
      onDestinationSelected: (index) {
        DesignHaptics.selection();
        ref.read(currentTabProvider.notifier).state = index;
        if (index == 0) {
          requestResidentDataRefresh();
        }
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: context.surface.defaultSurface,
      selectedIconTheme: IconThemeData(color: context.brand.primary),
      unselectedIconTheme: IconThemeData(color: context.text.tertiary),
      selectedLabelTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.brand.primary,
          ),
      unselectedLabelTextStyle:
          Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.text.secondary,
              ),
      destinations: [
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            backgroundColor: DesignColors.error,
            child: const Icon(Icons.home_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            backgroundColor: DesignColors.error,
            child: const Icon(Icons.home_rounded),
          ),
          label: const Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline_rounded),
          selectedIcon: Icon(Icons.people_rounded),
          label: Text('Community'),
        ),
        if (isAdmin)
          const NavigationRailDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded),
            label: Text('Admin'),
          ),
        const NavigationRailDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: Text('Profile'),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isSelected,
    int badgeCount = 0,
  }) {
    return Expanded(
      child: Semantics(
        label: '$label tab',
        selected: isSelected,
        child: InkWell(
          onTap: () {
            DesignHaptics.selection();
            ref.read(currentTabProvider.notifier).state = index;
            if (index == 0) {
              requestResidentDataRefresh();
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: DesignAnimations.durationInteraction,
            curve: DesignAnimations.curveInteraction,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.brand.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: DesignAnimations.durationInteraction,
                  curve: DesignAnimations.curveInteraction,
                  child: Badge(
                    isLabelVisible: badgeCount > 0,
                    label: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: DesignColors.error,
                    child: Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected
                          ? context.brand.primary
                          : context.text.tertiary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? context.brand.primary
                            : context.text.secondary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
