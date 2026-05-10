import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_haptics.dart';
import '../../ui/guard_tokens.dart';

/// Bottom navigation shell for guard — separate from [ResidentShell].
class GuardNavigationShell extends StatelessWidget {
  const GuardNavigationShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? GuardTokens.darkSurface : GuardTokens.surfaceCard;
    final barBg = isDark ? GuardTokens.darkCard : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (shell.currentIndex != 0) {
          shell.goBranch(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Material(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: shell),
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
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: GuardTokens.caption,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? GuardTokens.guardAccentDeep
                            : GuardTokens.textSecondary,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
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
                      shell.goBranch(index);
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        selectedIcon: Icon(Icons.space_dashboard_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.sensor_door_outlined),
                        selectedIcon: Icon(Icons.sensor_door_rounded),
                        label: 'Active',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long_rounded),
                        label: 'Logs',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
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
}
