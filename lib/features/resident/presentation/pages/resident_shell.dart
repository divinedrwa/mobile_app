import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import 'community_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Main shell for resident app with modern bottom navigation
class ResidentShell extends ConsumerWidget {
  const ResidentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentTab != 0) {
          ref.read(currentTabProvider.notifier).state = 0;
          return;
        }
        // Home tab: close app gracefully instead of popping shell route.
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentTab,
          children: [
            HomeScreen(),
            CommunityScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context,
                    ref,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    index: 0,
                    isSelected: currentTab == 0,
                  ),
                  _buildNavItem(
                    context,
                    ref,
                    icon: Icons.people_rounded,
                    label: 'Community',
                    index: 1,
                    isSelected: currentTab == 1,
                  ),
                  _buildNavItem(
                    context,
                    ref,
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    index: 2,
                    isSelected: currentTab == 2,
                  ),
                ],
              ),
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
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(currentTabProvider.notifier).state = index,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? DesignColors.primary : DesignColors.tertiary,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? DesignColors.primary : DesignColors.tertiary,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: isSelected ? 4 : 0,
                width: isSelected ? 32 : 0,
                decoration: BoxDecoration(
                  color: DesignColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
