import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../admin/presentation/pages/admin_dashboard_screen.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/resident_data_refresh.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Main shell for resident app with modern bottom navigation
class ResidentShell extends ConsumerWidget {
  const ResidentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRole.admin;
    final hasVilla = user?.villaId != null &&
        (user?.villaId?.isNotEmpty ?? false);

    // Admin without villa → admin-only mode (single tab, no bottom nav)
    final adminOnly = isAdmin && !hasVilla;

    if (adminOnly) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          SystemNavigator.pop();
        },
        child: const Scaffold(
          body: AdminDashboardScreen(),
        ),
      );
    }

    // Admin with villa → 4 tabs; Resident → 3 tabs
    final profileIndex = isAdmin ? 3 : 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentTab != 0) {
          ref.read(currentTabProvider.notifier).state = 0;
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.surface.background,
        body: IndexedStack(
          index: currentTab,
          children: [
            const HomeScreen(),
            const CommunityScreen(),
            if (isAdmin) const AdminDashboardScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: EdgeInsets.fromLTRB(
            context.spacing.s16,
            0,
            context.spacing.s16,
            context.spacing.s12,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  isSelected: currentTab == 0,
                  badgeCount: unreadCount,
                ),
                _buildNavItem(
                  context,
                  ref,
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: 'Community',
                  index: 1,
                  isSelected: currentTab == 1,
                ),
                if (isAdmin)
                  _buildNavItem(
                    context,
                    ref,
                    icon: Icons.admin_panel_settings_outlined,
                    selectedIcon: Icons.admin_panel_settings_rounded,
                    label: 'Admin',
                    index: 2,
                    isSelected: currentTab == 2,
                  ),
                _buildNavItem(
                  context,
                  ref,
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: profileIndex,
                  isSelected: currentTab == profileIndex,
                ),
              ],
            ),
          ),
        ),
      ),
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
