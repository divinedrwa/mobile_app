import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_navigator_keys.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/presentation/pages/branded_splash_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/society_selection_screen.dart';
import '../../core/utils/storage_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/resident/presentation/pages/resident_shell.dart';
import '../../features/resident/presentation/pages/pre_approve_visitor_screen.dart';
import '../../features/resident/presentation/pages/sos_screen.dart';
import '../../features/resident/presentation/pages/active_sos_screen.dart';
import '../../features/resident/presentation/pages/maintenance_payment_screen.dart';
import '../../features/resident/presentation/pages/maintenance/cycle_detail_screen.dart';
import '../../features/resident/presentation/pages/maintenance/maintenance_history_screen.dart';
import '../../features/resident/presentation/pages/maintenance/maintenance_hub_screen.dart';
import '../../features/resident/presentation/pages/maintenance/my_dues_screen.dart';
import '../../features/resident/presentation/pages/amenities_screen.dart';
import '../../features/resident/presentation/pages/complaint_screen.dart';
import '../../features/resident/presentation/pages/my_complaints_screen.dart';
import '../../features/resident/presentation/pages/amenity_booking_history_screen.dart';
import '../../features/resident/presentation/pages/visitor_approval_requests_screen.dart';
import '../../features/resident/presentation/pages/visitor_approval_detail_screen.dart';
import '../../features/resident/presentation/pages/my_pre_approved_visitors_screen.dart';
import '../../features/resident/presentation/pages/resident_overview_screen.dart';
import '../../features/guard/presentation/router/guard_routes.dart';

/// App-wide router configuration with role-based navigation
class AppRouter {
  static GoRouter router(WidgetRef ref, {required ChangeNotifier refreshListenable}) {
    return GoRouter(
      navigatorKey: appRootNavigatorKey,
      debugLogDiagnostics: true,
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        try {
          final user = ref.read(authProvider).user;
          final isAuthenticated = user != null;
          final loc = state.matchedLocation;
          final isSplash = loc == '/';
          final isLogin = loc == '/login';
          final isSocietySelect = loc == '/society-select';
          final isGuardRoute = loc.startsWith('/guard');
          final isAdminRoute = loc.startsWith('/admin');
          final isResidentRoute = loc.startsWith('/resident');

          if (isSplash) return null;

          if (!isAuthenticated) {
            final preferredSid = StorageService.getPreferredLoginSocietyId()?.trim();
            final hasLoginSociety = preferredSid != null && preferredSid.isNotEmpty;
            if (isLogin && !hasLoginSociety) {
              return '/society-select';
            }
            if (!isSplash && !isSocietySelect && !isLogin) {
              return '/society-select';
            }
          }

          if (isAuthenticated) {
            final role = user.role;

            if (role == UserRole.superAdmin) {
              return '/login';
            }

            if (role == UserRole.resident && (isGuardRoute || isAdminRoute)) {
              return '/resident';
            }
            if (role == UserRole.guard && (isResidentRoute || isAdminRoute)) {
              return '/guard/dashboard';
            }
            if (role == UserRole.admin && (isResidentRoute || isGuardRoute)) {
              return '/admin';
            }

            if (isLogin) {
              switch (role) {
                case UserRole.superAdmin:
                  return '/login';
                case UserRole.resident:
                  return '/resident';
                case UserRole.guard:
                  return '/guard/dashboard';
                case UserRole.admin:
                  return '/admin';
              }
            }
          }

          return null;
        } catch (e) {
          debugPrint('GoRouter redirect error: $e');
          return '/society-select';
        }
      },
      routes: [
        // Splash Screen
        GoRoute(
          path: '/',
          builder: (context, state) => const BrandedSplashScreen(),
        ),
        
        // Login Screen
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        GoRoute(
          path: '/society-select',
          builder: (context, state) => const SocietySelectionScreen(),
        ),

        // Resident App Routes
        GoRoute(
          path: '/resident',
          builder: (context, state) => const ResidentShell(),
          routes: [
            GoRoute(
              path: 'pre-approve-visitor',
              builder: (context, state) => const PreApproveVisitorScreen(),
            ),
            GoRoute(
              path: 'my-pre-approved-visitors',
              builder: (context, state) =>
                  const MyPreApprovedVisitorsScreen(),
            ),
            GoRoute(
              path: 'sos',
              builder: (context, state) => const SOSScreen(),
              routes: [
                GoRoute(
                  path: 'active',
                  builder: (context, state) => const ActiveSOSScreen(),
                ),
              ],
            ),
            // Resident maintenance hub. Lands on the redesigned overview;
            // admins are routed back to MaintenancePaymentScreen inside the
            // hub itself (the multi-tab finance view stays available until
            // its own redesign lands).
            GoRoute(
              path: 'maintenance',
              builder: (context, state) => const MaintenanceHubScreen(),
              routes: [
                GoRoute(
                  path: 'history',
                  builder: (context, state) => const MaintenanceHistoryScreen(),
                ),
                GoRoute(
                  path: 'dues',
                  builder: (context, state) => const MyDuesScreen(),
                ),
                GoRoute(
                  path: 'cycle/:cycleId',
                  builder: (context, state) => CycleDetailScreen(
                    cycleId: state.pathParameters['cycleId'] ?? '',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'maintenance-payment',
              builder: (context, state) => const MaintenancePaymentScreen(),
            ),
            GoRoute(
              path: 'amenities',
              builder: (context, state) => const AmenitiesScreen(),
            ),
            GoRoute(
              path: 'complaint',
              builder: (context, state) => const ComplaintScreen(),
            ),
            GoRoute(
              path: 'my-complaints',
              builder: (context, state) => const MyComplaintsScreen(),
            ),
            GoRoute(
              path: 'amenity-bookings',
              builder: (context, state) => const AmenityBookingHistoryScreen(),
            ),
            GoRoute(
              path: 'visitor-requests',
              builder: (context, state) => const VisitorApprovalRequestsScreen(),
            ),
            GoRoute(
              path: 'visitor-requests/:id',
              builder: (context, state) {
                final id = state.pathParameters['id'] ?? '';
                return VisitorApprovalDetailScreen(visitorId: id);
              },
            ),
            GoRoute(
              path: 'overview',
              builder: (context, state) => const ResidentOverviewScreen(),
            ),
          ],
        ),
        
        GuardRouteModule.section(),
        
        // Admin App Routes (Placeholder for future)
        GoRoute(
          path: '/admin',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('Admin App - Coming Soon'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple [ChangeNotifier] the host widget uses to tell [GoRouter] to
/// re-evaluate its redirect (e.g. after auth state changes).
class RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
