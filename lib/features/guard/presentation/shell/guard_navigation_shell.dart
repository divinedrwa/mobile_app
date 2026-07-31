import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_haptics.dart';
import '../../../../core/telemetry/app_analytics_service.dart';
import '../../../../core/telemetry/app_analytics_tab_paths.dart';
import '../../../../core/utils/foreground_polling_mixin.dart';
import '../../../../core/utils/responsive.dart';
import '../../../resident/data/providers/notification_provider.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_offline_sync_notifier.dart';
import '../../data/guard_data_refresh.dart';
import '../providers/guard_providers.dart';

/// Bottom navigation shell for guard — separate from [ResidentShell].
class GuardNavigationShell extends ConsumerStatefulWidget {
  const GuardNavigationShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<GuardNavigationShell> createState() =>
      _GuardNavigationShellState();
}

class _GuardNavigationShellState extends ConsumerState<GuardNavigationShell>
    with ForegroundPollingMixin {
  @override
  Duration get pollInterval => const Duration(seconds: 15);

  @override
  void onPollTick() {
    refreshGuardShiftContext(ref);
    ref.invalidate(guardActiveVisitorsTabProvider);
  }

  @override
  void initState() {
    super.initState();
    startForegroundPolling();
  }

  @override
  void dispose() {
    stopForegroundPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GuardTokens.darkSurface : GuardTokens.surfaceCard;
    final barBg = isDark ? GuardTokens.darkCard : Colors.white;
    final unread = ref.watch(unreadCountProvider);
    final activeBadge = ref.watch(guardLiveQueueCountsProvider)?.activeTabBadgeCount ?? 0;
    final wide = isWideScreen(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.shell.currentIndex != 0) {
          widget.shell.goBranch(0);
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
                          unread: unread,
                          activeBadge: activeBadge,
                          barBg: barBg,
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          child: WebContentConstraint(child: widget.shell),
                        ),
                      ],
                    )
                  : widget.shell,
            ),
            const _OfflineSyncStrip(),
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
                      selectedIndex: widget.shell.currentIndex,
                      onDestinationSelected: (index) {
                        DesignHaptics.selection();
                        unawaited(
                          AppAnalyticsService.logTabScreen(
                            AppAnalyticsTabPaths.guardTab(index),
                          ),
                        );
                        widget.shell.goBranch(index);
                      },
                      destinations: [
                        const NavigationDestination(
                          icon: Icon(Icons.space_dashboard_outlined),
                          selectedIcon:
                              Icon(Icons.space_dashboard_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: _GuardTabBadgeIcon(
                            count: activeBadge,
                            outlined: true,
                          ),
                          selectedIcon: _GuardTabBadgeIcon(
                            count: activeBadge,
                            outlined: false,
                          ),
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

  Widget _buildNavigationRail({
    required Color barBg,
    required int unread,
    required int activeBadge,
  }) {
    return NavigationRail(
      selectedIndex: widget.shell.currentIndex,
      onDestinationSelected: (index) {
        DesignHaptics.selection();
        unawaited(
          AppAnalyticsService.logTabScreen(
            AppAnalyticsTabPaths.guardTab(index),
          ),
        );
        widget.shell.goBranch(index);
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
        NavigationRailDestination(
          icon: _GuardTabBadgeIcon(count: activeBadge, outlined: true),
          selectedIcon: _GuardTabBadgeIcon(count: activeBadge, outlined: false),
          label: const Text('Active'),
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

class _GuardTabBadgeIcon extends StatelessWidget {
  const _GuardTabBadgeIcon({
    required this.count,
    required this.outlined,
  });

  final int count;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final icon = outlined
        ? Icons.sensor_door_outlined
        : Icons.sensor_door_rounded;
    return Badge(
      isLabelVisible: count > 0,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: GuardTokens.warning,
      child: Icon(icon),
    );
  }
}

/// Slim banner above the nav bar when offline mutations are pending sync.
class _OfflineSyncStrip extends ConsumerWidget {
  const _OfflineSyncStrip();

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
