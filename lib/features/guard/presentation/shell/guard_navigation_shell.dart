import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_haptics.dart';
import '../../../../core/telemetry/app_analytics_service.dart';
import '../../../../core/telemetry/app_analytics_tab_paths.dart';
import '../../../../core/utils/responsive.dart';
import '../../../resident/data/providers/notification_provider.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_offline_sync_notifier.dart';

/// Bottom navigation shell for guard — separate from [ResidentShell].
class GuardNavigationShell extends ConsumerWidget {
  const GuardNavigationShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GuardTokens.darkSurface : GuardTokens.surfaceCard;
    final barBg = isDark ? GuardTokens.darkCard : Colors.white;
    final unread = ref.watch(unreadCountProvider);
    final wide = isWideScreen(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (shell.currentIndex != 0) {
          shell.goBranch(0);
          return;
        }
        if (!kIsWeb) SystemNavigator.pop();
      },
      child: Material(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        _buildNavigationRail(
                          context,
                          barBg: barBg,
                          unread: unread,
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(child: WebContentConstraint(child: shell)),
                      ],
                    )
                  : shell,
            ),
            _OfflineSyncStrip(),
            if (!wide)
              Material(
                elevation: 2,
                shadowColor: Colors.black12,
                color: barBg,
                child: SafeArea(
                  top: false,
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 64,
                      backgroundColor: barBg,
                      indicatorColor:
                          GuardTokens.guardAccent.withValues(alpha: 0.16),
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      labelTextStyle:
                          WidgetStateProperty.resolveWith((states) {
                        final selected =
                            states.contains(WidgetState.selected);
                        return TextStyle(
                          fontSize: GuardTokens.caption,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? GuardTokens.guardAccentDeep
                              : GuardTokens.textSecondary,
                        );
                      }),
                      iconTheme:
                          WidgetStateProperty.resolveWith((states) {
                        final selected =
                            states.contains(WidgetState.selected);
                        return IconThemeData(
                          color: selected
                              ? GuardTokens.guardAccentDeep
                              : GuardTokens.textSecondary,
                          size: 24,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: shell.currentIndex,
                      onDestinationSelected: (index) {
                        DesignHaptics.selection();
                        unawaited(
                          AppAnalyticsService.logTabScreen(
                            AppAnalyticsTabPaths.guardTab(index),
                          ),
                        );
                        shell.goBranch(index);
                      },
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.space_dashboard_outlined),
                          selectedIcon:
                              Icon(Icons.space_dashboard_rounded),
                          label: 'Home',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.sensor_door_outlined),
                          selectedIcon: Icon(Icons.sensor_door_rounded),
                          label: 'Active',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon:
                              Icon(Icons.receipt_long_rounded),
                          label: 'Logs',
                        ),
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(fontSize: 10),
                            ),
                            child: Icon(
                                Icons.person_outline_rounded),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(fontSize: 10),
                            ),
                            child:
                                Icon(Icons.person_rounded),
                          ),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail(
    BuildContext context, {
    required Color barBg,
    required int unread,
  }) {
    return NavigationRail(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (index) {
        DesignHaptics.selection();
        unawaited(
          AppAnalyticsService.logTabScreen(AppAnalyticsTabPaths.guardTab(index)),
        );
        shell.goBranch(index);
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: barBg,
      selectedIconTheme: IconThemeData(color: GuardTokens.themedAccentDeep),
      unselectedIconTheme: IconThemeData(color: GuardTokens.themedAccent),
      selectedLabelTextStyle: TextStyle(
        fontSize: GuardTokens.caption,
        fontWeight: FontWeight.w700,
        color: GuardTokens.themedAccentDeep,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: GuardTokens.caption,
        fontWeight: FontWeight.w500,
        color: GuardTokens.themedAccent,
      ),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard_rounded),
          label: Text('Home'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.sensor_door_outlined),
          selectedIcon: Icon(Icons.sensor_door_rounded),
          label: Text('Active'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: Text('Logs'),
        ),
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(fontSize: 10),
            ),
            child: Icon(Icons.person_outline_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: unread > 0,
            label: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(fontSize: 10),
            ),
            child: Icon(Icons.person_rounded),
          ),
          label: const Text('Profile'),
        ),
      ],
    );
  }
}

/// Slim banner above the nav bar when offline mutations are pending sync.
class _OfflineSyncStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(offlineSyncProvider);
    if (sync.pendingCount == 0) return const SizedBox.shrink();

    return Material(
      color: GuardTokens.warningMuted,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (sync.syncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.cloud_upload_outlined, size: 18, color: GuardTokens.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sync.syncing
                    ? 'Syncing...'
                    : '${sync.pendingCount} offline ${sync.pendingCount == 1 ? 'action' : 'actions'} pending',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (!sync.syncing)
              GestureDetector(
                onTap: () => ref.read(offlineSyncProvider.notifier).syncAll(),
                child: Text(
                  'Sync now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: GuardTokens.themedAccentDeep,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
