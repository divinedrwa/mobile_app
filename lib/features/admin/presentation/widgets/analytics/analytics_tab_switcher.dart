import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_tokens.dart';

/// One entry in the Analytics hub's tab switcher.
class AnalyticsTab {
  const AnalyticsTab({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}

/// The 5 analytics screens, in hub order. Kept in one place so every screen's
/// switcher (and the dashboard entry point) stays in sync.
const List<AnalyticsTab> kAdminAnalyticsTabs = [
  AnalyticsTab(
    label: 'Overview',
    icon: Icons.insights_rounded,
    route: '/resident/admin-app-analytics',
  ),
  AnalyticsTab(
    label: 'Gate & Visitors',
    icon: Icons.analytics_outlined,
    route: '/resident/admin-gate-analytics',
  ),
  AnalyticsTab(
    label: 'Complaints',
    icon: Icons.bar_chart_rounded,
    route: '/resident/admin-complaint-analytics',
  ),
  AnalyticsTab(
    label: 'Water',
    icon: Icons.water_outlined,
    route: '/resident/admin-water-analytics',
  ),
  AnalyticsTab(
    label: 'Reconciliation',
    icon: Icons.account_balance_outlined,
    route: '/resident/admin-reconciliation',
  ),
];

/// Horizontal, scrollable segmented switcher shown at the top of every
/// analytics screen so admins can hop between Overview / Gate / Complaints /
/// Water / Reconciliation without returning to the dashboard each time.
/// Replaces the previous pattern of 5 disconnected screens only reachable
/// individually from Quick Actions.
class AnalyticsTabSwitcher extends StatelessWidget {
  const AnalyticsTabSwitcher({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kAdminAnalyticsTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = kAdminAnalyticsTabs[i];
          final isActive = tab.route == currentRoute;
          return _chip(context, tab, isActive);
        },
      ),
    );
  }

  Widget _chip(BuildContext context, AnalyticsTab tab, bool isActive) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isActive
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.pushReplacement(tab.route);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? DesignColors.primary : DesignColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? DesignColors.primary : DesignColors.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                size: 14,
                color: isActive ? Colors.white : DesignColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                tab.label,
                style: DesignTypography.captionSmall.copyWith(
                  color: isActive ? Colors.white : DesignColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
