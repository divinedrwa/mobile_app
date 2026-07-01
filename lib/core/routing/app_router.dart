import 'package:flutter/foundation.dart';
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
import '../../features/resident/presentation/pages/maintenance/upi_payment_screen.dart';
import '../../features/resident/presentation/pages/maintenance/payment_method_selection_screen.dart';
import '../../features/resident/presentation/pages/maintenance/razorpay_payment_screen.dart';
import '../../features/resident/presentation/pages/maintenance/phonepe_payment_screen.dart';
import '../../features/resident/presentation/pages/maintenance/payment_pending_verification_screen.dart';
import '../../features/resident/presentation/pages/maintenance/payment_success_screen.dart';
import '../../features/admin/presentation/pages/admin_upi_verifications_screen.dart';
import '../../features/resident/presentation/pages/amenities_screen.dart';
import '../../features/resident/presentation/pages/complaint_screen.dart';
import '../../features/resident/presentation/pages/my_complaints_screen.dart';
import '../../features/resident/presentation/pages/amenity_booking_history_screen.dart';
import '../../features/resident/presentation/pages/visitor_approval_requests_screen.dart';
import '../../features/resident/presentation/pages/visitor_approval_detail_screen.dart';
import '../../features/resident/presentation/pages/my_pre_approved_visitors_screen.dart';
import '../../features/resident/presentation/pages/visitor_hub_screen.dart';
import '../../features/resident/presentation/pages/visitor_history_screen.dart';
import '../../features/resident/presentation/pages/resident_overview_screen.dart';
import '../../features/resident/presentation/pages/society_expenses_screen.dart';
import '../../features/resident/presentation/pages/expense_detail_screen.dart';
import '../../features/admin/presentation/pages/admin_complaints_screen.dart';
import '../../features/admin/presentation/pages/admin_expenses_screen.dart';
import '../../features/admin/presentation/pages/admin_notices_screen.dart';
import '../../features/admin/presentation/pages/admin_parcels_screen.dart';
import '../../features/admin/presentation/pages/admin_reminders_screen.dart';
import '../../features/admin/presentation/pages/admin_role_management_screen.dart';
import '../../features/admin/presentation/pages/admin_maintenance_hub_screen.dart';
import '../../features/admin/presentation/pages/admin_gate_utilities_screen.dart';
import '../../features/admin/presentation/pages/admin_sos_screen.dart';
import '../../features/admin/presentation/pages/admin_guard_shifts_screen.dart';
import '../../features/admin/presentation/pages/admin_polls_screen.dart';
import '../../features/admin/presentation/pages/admin_staff_screen.dart';
import '../../features/admin/presentation/pages/admin_residents_screen.dart';
import '../../features/admin/presentation/pages/admin_villas_screen.dart';
import '../../features/admin/presentation/pages/admin_invitations_screen.dart';
import '../../features/admin/presentation/pages/admin_society_settings_screen.dart';
import '../../features/admin/presentation/pages/admin_gate_analytics_screen.dart';
import '../../features/admin/presentation/pages/admin_reconciliation_screen.dart';
import '../../features/admin/presentation/pages/admin_complaint_analytics_screen.dart';
import '../../features/admin/presentation/pages/admin_parking_screen.dart';
import '../../features/admin/presentation/pages/admin_data_tools_screen.dart';
import '../../features/admin/presentation/pages/admin_amenities_screen.dart';
import '../../features/admin/presentation/pages/admin_bank_accounts_screen.dart';
import '../../features/admin/presentation/pages/admin_water_analytics_screen.dart';
import '../../features/admin/presentation/pages/admin_patrols_screen.dart';
import '../../features/admin/presentation/pages/admin_incidents_screen.dart';
import '../../features/admin/presentation/pages/admin_maintenance_actions_screen.dart';
import '../../features/admin/presentation/pages/admin_outstanding_dues_screen.dart';
import '../../features/admin/presentation/pages/admin_villa_history_screen.dart';
import '../../features/resident/presentation/pages/utilities_screen.dart';
import '../../features/resident/presentation/pages/incidents_screen.dart';
import '../../features/resident/presentation/pages/notices_list_screen.dart';
import '../../features/resident/presentation/pages/parcel_management_screen.dart';
import '../../features/resident/presentation/pages/vehicle_log_screen.dart';
import '../../features/resident/presentation/pages/community_directory_screen.dart';
import '../../features/resident/presentation/pages/special_projects/special_projects_screen.dart';
import '../../features/resident/presentation/pages/special_projects/special_project_detail_screen.dart';
import '../../features/resident/presentation/pages/special_projects/admin_special_projects_screen.dart';
import '../../features/resident/presentation/pages/special_projects/admin_special_project_detail_screen.dart';
import '../../features/resident/presentation/pages/special_projects/admin_create_special_project_screen.dart';
import '../../features/guard/presentation/router/guard_routes.dart';

/// App-wide router configuration with role-based navigation
class AppRouter {
  static GoRouter router(WidgetRef ref, {required ChangeNotifier refreshListenable}) {
    return GoRouter(
      navigatorKey: appRootNavigatorKey,
      debugLogDiagnostics: kDebugMode,
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
            // User on /login but never picked a society → send to picker.
            if (isLogin && !hasLoginSociety) {
              return '/society-select';
            }
            // User landed on an app route (e.g. after session expiry) →
            // send to /login if they already chose a society, else picker.
            if (!isSplash && !isSocietySelect && !isLogin) {
              return hasLoginSociety ? '/login' : '/society-select';
            }
          }

          if (isAuthenticated) {
            final role = user.role;

            // Mobile app doesn't support super-admin. Force logout to
            // prevent an infinite redirect loop (authenticated → /login →
            // still authenticated → /login …).
            if (role == UserRole.superAdmin) {
              Future.microtask(
                () => ref.read(authProvider.notifier).logout(),
              );
              return null;
            }

            if (role == UserRole.resident && (isGuardRoute || isAdminRoute)) {
              return '/resident';
            }
            // Block plain residents from admin sub-screens inside resident shell.
            if (role == UserRole.resident && loc.startsWith('/resident/admin')) {
              return '/resident';
            }
            // Block tenants from accessing society expenses.
            if (role == UserRole.resident &&
                user.isTenant &&
                loc.startsWith('/resident/expenses')) {
              return '/resident';
            }
            if (role == UserRole.guard && (isResidentRoute || isAdminRoute)) {
              return '/guard/dashboard';
            }
            // Admin shares the resident shell — only block guard routes.
            if (role.isAdminLike && isGuardRoute) {
              return '/resident';
            }

            if (isLogin || isSocietySelect) {
              switch (role) {
                case UserRole.superAdmin:
                  return null; // microtask logout handles it above
                case UserRole.resident:
                  return '/resident';
                case UserRole.guard:
                  return '/guard/dashboard';
                case UserRole.admin:
                  return '/resident';
                case UserRole.residentCumAdmin:
                  return '/resident';
              }
            }
          }

          return null;
        } catch (e) {
          debugPrint('GoRouter redirect error: $e');
          final sid = StorageService.getPreferredLoginSocietyId()?.trim() ?? '';
          return sid.isNotEmpty ? '/login' : '/society-select';
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
                GoRoute(
                  path: 'upi-pay',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return UpiPaymentScreen(
                      amount: double.tryParse(q['amount'] ?? ''),
                      month: int.tryParse(q['month'] ?? ''),
                      year: int.tryParse(q['year'] ?? ''),
                      cycleId: q['cycleId'],
                      remark: q['remark'],
                      vpa: q['vpa'],
                      qrCodeUrl: q['qrCodeUrl'],
                      payeeName: q['payeeName'],
                      upiPayUri: q['upiPayUri'],
                      bankQr: q['bankQr'] == 'true',
                    );
                  },
                ),
                GoRoute(
                  path: 'pay',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return PaymentMethodSelectionScreen(
                      amount: double.tryParse(q['amount'] ?? '0') ?? 0,
                      month: int.tryParse(q['month'] ?? '1') ?? 1,
                      year: int.tryParse(q['year'] ?? '') ?? DateTime.now().year,
                      cycleId: q['cycleId'],
                      remark: q['remark'],
                      payAllPending: q['payAll'] == 'true',
                    );
                  },
                ),
                GoRoute(
                  path: 'razorpay-pay',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return RazorpayPaymentScreen(
                      cycleId: q['cycleId'] ?? '',
                      amount: double.tryParse(q['amount'] ?? '0') ?? 0,
                      month: int.tryParse(q['month'] ?? '1') ?? 1,
                      year: int.tryParse(q['year'] ?? '') ?? DateTime.now().year,
                      payAllPending: q['payAll'] == 'true',
                    );
                  },
                ),
                GoRoute(
                  path: 'phonepe-pay',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return PhonePePaymentScreen(
                      cycleId: q['cycleId'] ?? '',
                      amount: double.tryParse(q['amount'] ?? '0') ?? 0,
                      month: int.tryParse(q['month'] ?? '1') ?? 1,
                      year: int.tryParse(q['year'] ?? '') ?? DateTime.now().year,
                      payAllPending: q['payAll'] == 'true',
                    );
                  },
                ),
                GoRoute(
                  path: 'payment-pending',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return PaymentPendingVerificationScreen(
                      transactionId: q['txnId'] ?? '',
                      paymentMethod: q['method'] ?? 'Online',
                      gateway: q['gateway'] ?? 'phonepe',
                      amount: double.tryParse(q['amount'] ?? '0') ?? 0,
                      periodLabel: q['period'],
                      payAllPending: q['payAll'] == 'true',
                      platformFee:
                          double.tryParse(q['platformFee'] ?? '0') ?? 0,
                      platformFeeGst:
                          double.tryParse(q['platformFeeGst'] ?? '0') ?? 0,
                      totalPaid:
                          double.tryParse(q['totalPaid'] ?? '0') ?? 0,
                    );
                  },
                ),
                GoRoute(
                  path: 'payment-success',
                  builder: (context, state) {
                    final q = state.uri.queryParameters;
                    return PaymentSuccessScreen(
                      amount: double.tryParse(q['amount'] ?? '0') ?? 0,
                      platformFee:
                          double.tryParse(q['platformFee'] ?? '0') ?? 0,
                      platformFeeGst:
                          double.tryParse(q['platformFeeGst'] ?? '0') ?? 0,
                      totalPaid:
                          double.tryParse(q['totalPaid'] ?? '0') ?? 0,
                      transactionId: q['txnId'],
                      paymentMethod: q['method'] ?? 'Online',
                      billingPeriod: q['period'],
                      payAllPending: q['payAll'] == 'true',
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'maintenance-payment',
              builder: (context, state) {
                final tab = int.tryParse(
                    state.uri.queryParameters['tab'] ?? '');
                return MaintenancePaymentScreen(initialTab: tab);
              },
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
              path: 'visitor-hub',
              builder: (context, state) => const VisitorHubScreen(),
            ),
            GoRoute(
              path: 'visitor-history',
              builder: (context, state) => VisitorHistoryScreen(
                statusFilter: state.uri.queryParameters['status'],
              ),
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
              path: 'expenses',
              builder: (context, state) {
                final month = int.tryParse(
                    state.uri.queryParameters['month'] ?? '');
                final year = int.tryParse(
                    state.uri.queryParameters['year'] ?? '');
                return SocietyExpensesScreen(
                  initialMonth: month,
                  initialYear: year,
                );
              },
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ExpenseDetailScreen(
                    expenseId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'overview',
              builder: (context, state) => const ResidentOverviewScreen(),
            ),
            GoRoute(
              path: 'utilities',
              builder: (context, state) => const UtilitiesScreen(),
            ),
            GoRoute(
              path: 'incidents',
              builder: (context, state) => const IncidentsScreen(),
            ),
            GoRoute(
              path: 'vehicle-log',
              builder: (context, state) => const VehicleLogScreen(),
            ),
            GoRoute(
              path: 'directory',
              builder: (context, state) => const CommunityDirectoryScreen(),
            ),
            GoRoute(
              path: 'notices',
              builder: (context, state) => const NoticesListScreen(),
            ),
            GoRoute(
              path: 'parcels',
              builder: (context, state) => const ParcelManagementScreen(),
            ),
            // Special Projects (resident + admin)
            GoRoute(
              path: 'special-projects',
              builder: (context, state) => const SpecialProjectsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) => SpecialProjectDetailScreen(
                    projectId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'admin-special-projects',
              builder: (context, state) =>
                  const AdminSpecialProjectsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) =>
                      const AdminCreateSpecialProjectScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      AdminSpecialProjectDetailScreen(
                    projectId: state.pathParameters['id'] ?? '',
                  ),
                ),
              ],
            ),
            // Admin placeholder routes (Phase 1)
            GoRoute(
              path: 'admin-mark-payment',
              builder: (context, state) =>
                  const AdminMaintenanceHubScreen(),
            ),
            GoRoute(
              path: 'admin-complaints',
              builder: (context, state) =>
                  const AdminComplaintsScreen(),
            ),
            GoRoute(
              path: 'admin-reminders',
              builder: (context, state) =>
                  const AdminRemindersScreen(),
            ),
            GoRoute(
              path: 'admin-expenses',
              builder: (context, state) =>
                  const AdminExpensesScreen(),
            ),
            GoRoute(
              path: 'admin-notices',
              builder: (context, state) =>
                  const AdminNoticesScreen(),
            ),
            GoRoute(
              path: 'admin-parcels',
              builder: (context, state) =>
                  const AdminParcelsScreen(),
            ),
            GoRoute(
              path: 'admin-roles',
              builder: (context, state) =>
                  const AdminRoleManagementScreen(),
            ),
            GoRoute(
              path: 'admin-gate-utilities',
              builder: (context, state) =>
                  const AdminGateUtilitiesScreen(),
            ),
            GoRoute(
              path: 'admin-sos',
              builder: (context, state) =>
                  const AdminSosScreen(),
            ),
            GoRoute(
              path: 'admin-guard-shifts',
              builder: (context, state) =>
                  const AdminGuardShiftsScreen(),
            ),
            GoRoute(
              path: 'admin-patrols',
              builder: (context, state) =>
                  const AdminPatrolsScreen(),
            ),
            GoRoute(
              path: 'admin-incidents',
              builder: (context, state) =>
                  const AdminIncidentsScreen(),
            ),
            GoRoute(
              path: 'admin-polls',
              builder: (context, state) =>
                  const AdminPollsScreen(),
            ),
            GoRoute(
              path: 'admin-staff',
              builder: (context, state) =>
                  const AdminStaffScreen(),
            ),
            // Tier 1 — new admin screens
            GoRoute(
              path: 'admin-residents',
              builder: (context, state) =>
                  const AdminResidentsScreen(),
            ),
            GoRoute(
              path: 'admin-villas',
              builder: (context, state) =>
                  const AdminVillasScreen(),
            ),
            GoRoute(
              path: 'admin-invitations',
              builder: (context, state) =>
                  const AdminInvitationsScreen(),
            ),
            GoRoute(
              path: 'admin-settings',
              builder: (context, state) =>
                  const AdminSocietySettingsScreen(),
            ),
            // Tier 2 — analytics & insights
            GoRoute(
              path: 'admin-gate-analytics',
              builder: (context, state) =>
                  const AdminGateAnalyticsScreen(),
            ),
            GoRoute(
              path: 'admin-reconciliation',
              builder: (context, state) =>
                  const AdminReconciliationScreen(),
            ),
            GoRoute(
              path: 'admin-complaint-analytics',
              builder: (context, state) =>
                  const AdminComplaintAnalyticsScreen(),
            ),
            GoRoute(
              path: 'admin-parking',
              builder: (context, state) =>
                  const AdminParkingScreen(),
            ),
            // Tier 3 — tools & extras
            GoRoute(
              path: 'admin-data-tools',
              builder: (context, state) =>
                  const AdminDataToolsScreen(),
            ),
            GoRoute(
              path: 'admin-amenities',
              builder: (context, state) =>
                  const AdminAmenitiesScreen(),
            ),
            GoRoute(
              path: 'admin-bank-accounts',
              builder: (context, state) =>
                  const AdminBankAccountsScreen(),
            ),
            GoRoute(
              path: 'admin-water-analytics',
              builder: (context, state) =>
                  const AdminWaterAnalyticsScreen(),
            ),
            GoRoute(
              path: 'admin-upi-verifications',
              builder: (context, state) =>
                  const AdminUpiVerificationsScreen(),
            ),
            GoRoute(
              path: 'admin-maintenance-actions',
              builder: (context, state) =>
                  const AdminMaintenanceActionsScreen(),
            ),
            GoRoute(
              path: 'admin-outstanding-dues',
              builder: (context, state) =>
                  const AdminOutstandingDuesScreen(),
            ),
            GoRoute(
              path: 'admin-villa-history/:villaId',
              builder: (context, state) => AdminVillaHistoryScreen(
                villaId: state.pathParameters['villaId'] ?? '',
              ),
            ),
          ],
        ),
        
        GuardRouteModule.section(),
        
        // Admin users share the resident shell — role-specific UI (Outstanding
        // tab, send reminders, etc.) is gated by `isAdmin` checks inside screens.
        GoRoute(
          path: '/admin',
          redirect: (context, state) => '/resident',
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
