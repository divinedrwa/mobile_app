import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_navigator_keys.dart';
import '../../ui/guard_tokens.dart';
import '../shell/guard_navigation_shell.dart';
import '../pages/guard_dashboard_page.dart';
import '../pages/guard_today_summary_page.dart';
import '../pages/guard_active_entries_page.dart';
import '../pages/guard_logs_page.dart';
import '../pages/guard_profile_page.dart';
import '../pages/guard_check_in_screen.dart';
import '../pages/guard_delivery_quick_page.dart';
import '../pages/guard_vehicle_entry_page.dart';
import '../pages/guard_emergency_page.dart';
import '../pages/guard_incident_report_page.dart';
import '../pages/guard_patrol_screen.dart';
import '../pages/guard_residents_directory_page.dart';
import '../pages/guard_shift_details_page.dart';
import '../pages/guard_visitor_approval_page.dart';
import '../pages/guard_visitor_detail_page.dart';
import '../pages/guard_qr_scan_screen.dart';
import '../pages/guard_pre_approved_list_page.dart';
import '../pages/guard_pre_approved_arrival_screen.dart';
import '../../data/models/guard_models.dart';
import '../../../resident/presentation/pages/notifications_center_screen.dart';

/// All paths under `/guard` — isolated from resident `/resident/*`.
abstract final class GuardRoutes {
  static const dashboard = '/guard/dashboard';
  static const entries = '/guard/entries';
  static const logs = '/guard/logs';
  static const profile = '/guard/profile';
  static const qrScan = '/guard/scan-qr';
  static const addVisitor = '/guard/add-visitor';
  /// Today's metrics + visitor approval breakdown.
  static const todaySummary = '/guard/today-summary';
  /// Resident-created pre-approvals — list + arrival confirmation.
  static const preApprovedList = '/guard/pre-approved';
  /// Full-screen prefilled confirmation; pass [GuardPreApprovedEntry] as `extra`.
  static const preApprovedArrival = '/guard/pre-approved-arrival';
  static const delivery = '/guard/delivery-entry';
  static const vehicle = '/guard/vehicle-entry';
  static const emergency = '/guard/emergency';
  static const incident = '/guard/incident-report';
  static const directory = '/guard/residents-directory';
  static const patrol = '/guard/patrol';
  static const shift = '/guard/shift';
  static const notifications = '/guard/notifications';
  /// Full-screen detail; pass [GuardVisitorRow] as `extra`.
  static const visitorDetail = '/guard/visitor-detail';
  static String visitorApproval(String id) => '/guard/visitor-approval/$id';

  /// Prefill visitor approval via query (`name`, `phone`, `villaId`, …).
  static String visitorApprovalWithQuery(
    String id, [
    Map<String, String>? query,
  ]) {
    if (query == null || query.isEmpty) return visitorApproval(id);
    return Uri(
      path: '/guard/visitor-approval/$id',
      queryParameters: query,
    ).toString();
  }
}

/// Stateful shell + full-screen overlays (branch navigators inherit shell; full
/// routes use [appRootNavigatorKey] via `parentNavigatorKey`).
final class GuardRouteModule {
  GuardRouteModule._();

  /// Register as child of [GoRouter] `routes:`.
  static RouteBase section() {
    return GoRoute(
      path: '/guard',
      redirect: (context, state) {
        final p = state.uri.path;
        if (p == '/guard' || p == '/guard/') {
          return GuardRoutes.dashboard;
        }
        return null;
      },
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) {
            return GuardThemeScope(
              child: GuardNavigationShell(shell: shell),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: 'dashboard',
                  builder: (context, state) => const GuardDashboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: 'entries',
                  builder: (context, state) => const GuardActiveEntriesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: 'logs',
                  builder: (context, state) => const GuardLogsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: 'profile',
                  builder: (context, state) => const GuardProfilePage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: 'scan-qr',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardQrScanScreen(),
        ),
        GoRoute(
          path: 'add-visitor',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardCheckInScreen(),
        ),
        GoRoute(
          path: 'today-summary',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardTodaySummaryPage(),
        ),
        GoRoute(
          path: 'pre-approved',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardPreApprovedListPage(),
        ),
        GoRoute(
          path: 'pre-approved-arrival',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (_, state) {
            final extra = state.extra;
            if (extra is GuardPreApprovedEntry) {
              return GuardPreApprovedArrivalScreen(entry: extra);
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Expected visitor')),
              body: const Center(
                child: Text('Open this screen from the pre-approved list.'),
              ),
            );
          },
        ),
        GoRoute(
          path: 'delivery-entry',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardDeliveryQuickPage(),
        ),
        GoRoute(
          path: 'vehicle-entry',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardVehicleEntryPage(),
        ),
        GoRoute(
          path: 'emergency',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardEmergencyPage(),
        ),
        GoRoute(
          path: 'patrol',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardPatrolScreen(),
        ),
        GoRoute(
          path: 'incident-report',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardIncidentReportPage(),
        ),
        GoRoute(
          path: 'residents-directory',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardResidentsDirectoryPage(),
        ),
        GoRoute(
          path: 'shift',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const GuardShiftDetailsPage(),
        ),
        GoRoute(
          path: 'notifications',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (context, state) => const NotificationsCenterScreen(
            title: 'Alerts & messages',
            subtitle: 'Visitor approvals, notices, and gate updates',
          ),
        ),
        GoRoute(
          path: 'visitor-detail',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (_, state) {
            final extra = state.extra;
            if (extra is GuardVisitorRow) {
              return GuardVisitorDetailPage(visitor: extra);
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Visitor')),
              body: const Center(child: Text('Open this screen from a visitor list.')),
            );
          },
        ),
        GoRoute(
          path: 'visitor-approval/:id',
          parentNavigatorKey: appRootNavigatorKey,
          builder: (_, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = _visitorApprovalArgs(state);
            return GuardVisitorApprovalPage(
              visitorId: id,
              initialExtra: extra,
            );
          },
        ),
      ],
    );
  }
}

/// Merge `state.extra` map with query params (`name`, `phone`, `villaId`, …).
Map<String, String>? _visitorApprovalArgs(GoRouterState state) {
  final out = <String, String>{};
  final raw = state.extra;
  if (raw is Map) {
    for (final e in raw.entries) {
      out[e.key.toString()] = e.value?.toString() ?? '';
    }
  }
  for (final e in state.uri.queryParameters.entries) {
    if (e.value.isNotEmpty) out[e.key] = e.value;
  }
  return out.isEmpty ? null : out;
}
