import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_model.dart';
import '../../../resident/data/models/expense_category_model.dart';
import '../../../resident/data/models/expense_model.dart';
import '../../../resident/data/models/notice_model.dart';
import '../models/admin_dashboard_model.dart';
import '../repositories/admin_complaint_repository.dart';
import '../repositories/admin_dashboard_repository.dart';
import '../repositories/admin_expense_repository.dart';
import '../repositories/admin_gate_utilities_repository.dart';
import '../repositories/admin_guard_shift_repository.dart';
import '../repositories/admin_maintenance_repository.dart';
import '../repositories/admin_notice_repository.dart';
import '../repositories/admin_parcel_repository.dart';
import '../repositories/admin_poll_repository.dart';
import '../repositories/admin_sos_repository.dart';
import '../repositories/admin_staff_repository.dart';
import '../repositories/admin_user_repository.dart';
// New repositories (Tier 1–3)
import '../repositories/admin_resident_management_repository.dart';
import '../repositories/admin_villa_repository.dart';
import '../repositories/admin_invitation_repository.dart';
import '../repositories/admin_society_settings_repository.dart';
import '../repositories/admin_gate_analytics_repository.dart';
import '../repositories/admin_app_analytics_repository.dart';
import '../repositories/admin_reconciliation_repository.dart';
import '../repositories/admin_complaint_analytics_repository.dart';
import '../repositories/admin_parking_repository.dart';
import '../repositories/admin_data_tools_repository.dart';
import '../repositories/admin_amenity_repository.dart';
import '../repositories/admin_bank_account_repository.dart';
import '../repositories/admin_upi_payment_repository.dart';
import '../repositories/admin_water_analytics_repository.dart';
import '../repositories/admin_patrol_repository.dart';
import '../repositories/admin_incident_repository.dart';
import '../repositories/admin_payment_method_repository.dart';
import '../repositories/admin_billing_cycle_repository.dart';
import '../repositories/admin_visitor_repository.dart';
import '../repositories/admin_notification_repository.dart';
import '../repositories/admin_document_repository.dart';
import '../repositories/admin_banner_repository.dart';
import '../../../resident/data/models/upi_payment_model.dart';

// ── Dashboard ─────────────────────────────────────────────────────────

final adminDashboardRepositoryProvider =
    Provider<AdminDashboardRepository>((ref) => AdminDashboardRepository());

final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboardModel>((ref) async {
  return ref.watch(adminDashboardRepositoryProvider).getDashboard();
});

// ── User management ───────────────────────────────────────────────────

final adminUserRepositoryProvider =
    Provider<AdminUserRepository>((ref) => AdminUserRepository());

/// Filter by role for user list (null = All).
final adminUserRoleFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Fetches society users, optionally filtered by role.
final adminUsersProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repo = ref.watch(adminUserRepositoryProvider);
  final role = ref.watch(adminUserRoleFilterProvider);
  return repo.getUsers(role: role);
});

// ── Complaints ────────────────────────────────────────────────────────

final adminComplaintRepositoryProvider =
    Provider<AdminComplaintRepository>((ref) => AdminComplaintRepository());

/// Status filter for complaint list (null = All).
final adminComplaintStatusFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Fetches admin complaints, optionally filtered by status.
final adminComplaintsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminComplaintRepositoryProvider);
  final status = ref.watch(adminComplaintStatusFilterProvider);
  return repo.getAdminComplaints(status: status);
});

/// 30-day complaint analytics summary.
final complaintAnalyticsSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref
      .watch(adminComplaintRepositoryProvider)
      .getComplaintAnalyticsSummary();
});

// ── Expenses ──────────────────────────────────────────────────────────

final adminExpenseRepositoryProvider =
    Provider<AdminExpenseRepository>((ref) => AdminExpenseRepository());

/// Filter state for admin expense list.
class AdminExpenseFilter {
  final String? categoryId;

  const AdminExpenseFilter({this.categoryId});

  AdminExpenseFilter copyWith({
    String? categoryId,
    bool clearCategoryId = false,
  }) {
    return AdminExpenseFilter(
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    );
  }
}

final adminExpenseFilterProvider =
    StateProvider.autoDispose<AdminExpenseFilter>(
        (ref) => const AdminExpenseFilter());

/// Expense categories for admin.
final adminExpenseCategoriesProvider =
    FutureProvider.autoDispose<List<ExpenseCategoryModel>>((ref) async {
  final raw =
      await ref.watch(adminExpenseRepositoryProvider).getAdminCategories();
  return raw.map((e) => ExpenseCategoryModel.fromJson(e)).toList();
});

/// Admin expenses list, filtered by category.
final adminExpensesProvider =
    FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  final repo = ref.watch(adminExpenseRepositoryProvider);
  final filter = ref.watch(adminExpenseFilterProvider);
  final raw = await repo.getAdminExpenses(categoryId: filter.categoryId);
  return raw.map((e) => ExpenseModel.fromJson(e)).toList();
});

// ── Notices ───────────────────────────────────────────────────────────

final adminNoticeRepositoryProvider =
    Provider<AdminNoticeRepository>((ref) => AdminNoticeRepository());

/// Admin notices list.
final adminNoticesProvider =
    FutureProvider.autoDispose<List<NoticeModel>>((ref) async {
  final raw = await ref.watch(adminNoticeRepositoryProvider).getAdminNotices();
  final list = raw['notices'] as List? ?? const [];
  return list
      .whereType<Map>()
      .map((e) => NoticeModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

// ── Parcels ───────────────────────────────────────────────────────────

final adminParcelRepositoryProvider =
    Provider<AdminParcelRepository>((ref) => AdminParcelRepository());

/// Admin parcels (raw map with `parcels` array + `pendingCount`).
final adminParcelsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminParcelRepositoryProvider).getAdminParcels();
});

// ── Maintenance / Reminders ───────────────────────────────────────────

final adminMaintenanceRepositoryProvider =
    Provider<AdminMaintenanceRepository>(
        (ref) => AdminMaintenanceRepository());

/// Admin-specific filter state (separate from resident filter).
class AdminMaintenanceFilter {
  const AdminMaintenanceFilter({
    required this.month,
    required this.year,
    this.maintenanceCollectionCycleId,
    this.financialYearId,
  });

  final int month;
  final int year;
  final String? maintenanceCollectionCycleId;
  final String? financialYearId;

  AdminMaintenanceFilter copyWith({
    int? month,
    int? year,
    String? maintenanceCollectionCycleId,
    String? financialYearId,
    bool clearCollectionCycleId = false,
    bool clearFinancialYearId = false,
    bool clearBillingCycleId = false,
  }) {
    return AdminMaintenanceFilter(
      month: month ?? this.month,
      year: year ?? this.year,
      maintenanceCollectionCycleId: clearCollectionCycleId
          ? null
          : (maintenanceCollectionCycleId ??
              this.maintenanceCollectionCycleId),
      financialYearId: clearFinancialYearId
          ? null
          : (financialYearId ?? this.financialYearId),
    );
  }
}

/// Admin maintenance filter — autoDispose so state doesn't bleed.
final adminMaintenanceFilterProvider =
    StateProvider.autoDispose<AdminMaintenanceFilter>((ref) {
  final now = DateTime.now();
  return AdminMaintenanceFilter(month: now.month, year: now.year);
});

/// Admin financial dashboard data for the selected filter.
final adminMaintenanceDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(adminMaintenanceFilterProvider);
  return ref
      .watch(adminMaintenanceRepositoryProvider)
      .getFinancialDashboard(
        month: filter.month,
        year: filter.year,
        maintenanceCollectionCycleId: filter.maintenanceCollectionCycleId,
      );
});

/// Admin collection financial years.
final adminCollectionFinancialYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminMaintenanceRepositoryProvider)
      .getCollectionFinancialYears();
});

/// Admin collection cycles for a given financial year.
final adminCollectionCyclesForFYProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
        (ref, financialYearId) async {
  if (financialYearId.isEmpty) return [];
  return ref
      .watch(adminMaintenanceRepositoryProvider)
      .getCollectionCyclesForFY(financialYearId);
});

/// Admin outstanding dues (cross-cycle view).
final adminOutstandingDuesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref
      .watch(adminMaintenanceRepositoryProvider)
      .getOutstandingDues();
});

/// Admin villa payment history for a single villa.
final adminVillaHistoryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, villaId) async {
  if (villaId.isEmpty) return {};
  return ref
      .watch(adminMaintenanceRepositoryProvider)
      .getVillaHistory(villaId);
});

// ── Gate Utilities ───────────────────────────────────────────────────

final adminGateUtilitiesRepositoryProvider =
    Provider<AdminGateUtilitiesRepository>(
        (ref) => AdminGateUtilitiesRepository());

/// All society gates (used by gate utilities + shift creation).
final adminGatesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminGateUtilitiesRepositoryProvider).getGates();
});

/// Water supply status for all gates.
final adminWaterSupplyStatusProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminGateUtilitiesRepositoryProvider)
      .getWaterSupplyStatus();
});

/// Pending resident water supply requests (society-wide).
final adminPendingWaterRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminGateUtilitiesRepositoryProvider)
      .getPendingWaterRequests();
});

/// Water supply events, optionally filtered by gate.
final adminWaterSupplyEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, gateId) async {
  return ref
      .watch(adminGateUtilitiesRepositoryProvider)
      .getWaterSupplyEvents(gateId: gateId);
});

/// Garbage collection active status for a gate.
final adminGarbageActiveProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, gateId) async {
  return ref
      .watch(adminGateUtilitiesRepositoryProvider)
      .getGarbageActive(gateId: gateId);
});

/// Garbage collection events, optionally filtered by gate.
final adminGarbageEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, gateId) async {
  return ref
      .watch(adminGateUtilitiesRepositoryProvider)
      .getGarbageEvents(gateId: gateId);
});

// ── SOS Alerts ───────────────────────────────────────────────────────

final adminSosRepositoryProvider =
    Provider<AdminSosRepository>((ref) => AdminSosRepository());

/// SOS stats (admin only).
final adminSosStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminSosRepositoryProvider).getSosStats();
});

/// SOS alerts, optionally filtered by status.
final adminSosAlertsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String?>((ref, status) async {
  return ref.watch(adminSosRepositoryProvider).getSosAlerts(status: status);
});

// ── Guard Shifts ─────────────────────────────────────────────────────

final adminGuardShiftRepositoryProvider =
    Provider<AdminGuardShiftRepository>(
        (ref) => AdminGuardShiftRepository());

/// All guard shifts.
final adminGuardShiftsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminGuardShiftRepositoryProvider).getShifts();
});

/// Guards list for shift creation (users with GUARD role).
final adminGuardsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final users = await ref
      .watch(adminUserRepositoryProvider)
      .getUsers(role: 'GUARD');
  return users
      .map((u) => {
            'id': u.id,
            'name': u.name.isNotEmpty ? u.name : u.username,
            'username': u.username,
          })
      .toList();
});

// ── Polls ────────────────────────────────────────────────────────────

final adminPollRepositoryProvider =
    Provider<AdminPollRepository>((ref) => AdminPollRepository());

/// All polls.
final adminPollsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminPollRepositoryProvider).getPolls();
});

// ── Staff ────────────────────────────────────────────────────────────

final adminStaffRepositoryProvider =
    Provider<AdminStaffRepository>((ref) => AdminStaffRepository());

/// All staff members.
final adminStaffListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminStaffRepositoryProvider).getStaff();
});

// ═════════════════════════════════════════════════════════════════════
// NEW FEATURES — Tier 1
// ═════════════════════════════════════════════════════════════════════

// ── Resident Management ──────────────────────────────────────────────

final adminResidentManagementRepositoryProvider =
    Provider<AdminResidentManagementRepository>(
        (ref) => AdminResidentManagementRepository());

final adminResidentOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminResidentManagementRepositoryProvider).getOverview();
});

final adminResidentStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref
      .watch(adminResidentManagementRepositoryProvider)
      .getStatistics();
});

// ── Villa / Property Management ──────────────────────────────────────

final adminVillaRepositoryProvider =
    Provider<AdminVillaRepository>((ref) => AdminVillaRepository());

final adminVillasProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminVillaRepositoryProvider).getVillas();
});

// ── Invitations ──────────────────────────────────────────────────────

final adminInvitationRepositoryProvider =
    Provider<AdminInvitationRepository>(
        (ref) => AdminInvitationRepository());

final adminInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminInvitationRepositoryProvider).getInvitations();
});

// ── Society Settings ─────────────────────────────────────────────────

final adminSocietySettingsRepositoryProvider =
    Provider<AdminSocietySettingsRepository>(
        (ref) => AdminSocietySettingsRepository());

final adminSocietySettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminSocietySettingsRepositoryProvider).getSettings();
});

// ═════════════════════════════════════════════════════════════════════
// NEW FEATURES — Tier 2
// ═════════════════════════════════════════════════════════════════════

// ── Gate Analytics ───────────────────────────────────────────────────

final adminGateAnalyticsRepositoryProvider =
    Provider<AdminGateAnalyticsRepository>(
        (ref) => AdminGateAnalyticsRepository());

final adminGateAnalyticsOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminGateAnalyticsRepositoryProvider).getOverview();
});

final adminGateAnalyticsVisitorStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref
      .watch(adminGateAnalyticsRepositoryProvider)
      .getVisitorStatistics();
});

final adminGateAnalyticsPeakHoursProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminGateAnalyticsRepositoryProvider).getPeakHours();
});

final adminGateAnalyticsDailyTrendProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminGateAnalyticsRepositoryProvider).getDailyTrend();
});

// ── App usage analytics (first-party) ────────────────────────────────

final adminAppAnalyticsRepositoryProvider =
    Provider<AdminAppAnalyticsRepository>((ref) => AdminAppAnalyticsRepository());

final adminAppAnalyticsSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getSummary(days: 30);
});

final adminAppAnalyticsDailyTrendProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getDailyTrend(days: 14);
});

final adminAppAnalyticsScreensProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getTopScreens();
});

final adminAppAnalyticsFlowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getFlows();
});

final adminAppAnalyticsActiveUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getActiveUsers();
});

final adminAppAnalyticsUserEngagementProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminAppAnalyticsRepositoryProvider).getUserEngagement();
});

// ── Financial Reconciliation ─────────────────────────────────────────

final adminReconciliationRepositoryProvider =
    Provider<AdminReconciliationRepository>(
        (ref) => AdminReconciliationRepository());

final adminReconciliationSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminReconciliationRepositoryProvider).getSummary();
});

final adminReconciliationAlertsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminReconciliationRepositoryProvider).getAlerts();
});

// ── Complaint Analytics (Advanced) ───────────────────────────────────

final adminComplaintAnalyticsRepositoryProvider =
    Provider<AdminComplaintAnalyticsRepository>(
        (ref) => AdminComplaintAnalyticsRepository());

final adminComplaintAnalyticsSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref
      .watch(adminComplaintAnalyticsRepositoryProvider)
      .getSummary();
});

final adminComplaintAnalyticsByCategoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminComplaintAnalyticsRepositoryProvider)
      .getByCategory();
});

final adminComplaintAnalyticsPendingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminComplaintAnalyticsRepositoryProvider)
      .getPending();
});

final adminComplaintAnalyticsTrendProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminComplaintAnalyticsRepositoryProvider)
      .getTrend();
});

// ── Vehicle & Parking ────────────────────────────────────────────────

final adminParkingRepositoryProvider =
    Provider<AdminParkingRepository>((ref) => AdminParkingRepository());

final adminParkingOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminParkingRepositoryProvider).getOverview();
});

final adminParkingVehiclesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminParkingRepositoryProvider).getVehicles();
});

// ═════════════════════════════════════════════════════════════════════
// NEW FEATURES — Tier 3
// ═════════════════════════════════════════════════════════════════════

// ── Data Tools (Import/Export) ───────────────────────────────────────

final adminDataToolsRepositoryProvider =
    Provider<AdminDataToolsRepository>(
        (ref) => AdminDataToolsRepository());

// ── Amenities ────────────────────────────────────────────────────────

final adminAmenityRepositoryProvider =
    Provider<AdminAmenityRepository>((ref) => AdminAmenityRepository());

final adminAmenitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminAmenityRepositoryProvider).getAmenities();
});

// ── Bank Accounts ────────────────────────────────────────────────────

final adminBankAccountRepositoryProvider =
    Provider<AdminBankAccountRepository>(
        (ref) => AdminBankAccountRepository());

final adminBankAccountsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminBankAccountRepositoryProvider).getBankAccounts();
});

// ── Water Supply Analytics ───────────────────────────────────────────

final adminWaterAnalyticsRepositoryProvider =
    Provider<AdminWaterAnalyticsRepository>(
        (ref) => AdminWaterAnalyticsRepository());

final adminWaterAnalyticsDaysProvider =
    StateProvider.autoDispose<int>((ref) => 30);

final adminWaterAnalyticsOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final days = ref.watch(adminWaterAnalyticsDaysProvider);
  return ref
      .watch(adminWaterAnalyticsRepositoryProvider)
      .getOverview(days: days);
});

final adminWaterAnalyticsDailyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final days = ref.watch(adminWaterAnalyticsDaysProvider);
  return ref
      .watch(adminWaterAnalyticsRepositoryProvider)
      .getDailyUsage(days: days);
});

final adminWaterAnalyticsHourlyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminWaterAnalyticsRepositoryProvider)
      .getHourlyPattern(days: 30);
});

final adminWaterAnalyticsGateProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref
      .watch(adminWaterAnalyticsRepositoryProvider)
      .getGatePerformance(days: 30);
});

// ── UPI Payment Verifications ───────────────────────────────────────

final adminUpiPaymentRepositoryProvider =
    Provider<AdminUpiPaymentRepository>(
        (ref) => AdminUpiPaymentRepository());

/// UPI status filter for the verifications screen.
final adminUpiStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'PENDING');

/// UPI payment submissions filtered by current status selection.
final adminPendingUpiPaymentsProvider =
    FutureProvider.autoDispose<List<UpiPaymentModel>>((ref) async {
  final status = ref.watch(adminUpiStatusFilterProvider);
  return ref
      .watch(adminUpiPaymentRepositoryProvider)
      .getSubmissions(status: status);
});

/// UPI stats (pending / verified / rejected counts).
final adminUpiStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminUpiPaymentRepositoryProvider).getStats();
});

// ── Guard Patrols (Admin) ───────────────────────────────────────────

final adminPatrolRepositoryProvider =
    Provider<AdminPatrolRepository>((ref) => AdminPatrolRepository());

/// All guard patrols for the society.
final adminPatrolsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminPatrolRepositoryProvider).getPatrols();
});

// ── Incidents (Admin) ───────────────────────────────────────────────

final adminIncidentRepositoryProvider =
    Provider<AdminIncidentRepository>((ref) => AdminIncidentRepository());

/// All incidents for the society.
final adminIncidentsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminIncidentRepositoryProvider).getIncidents();
});

// ── Payment Methods (Admin) ─────────────────────────────────────────

final adminPaymentMethodRepositoryProvider =
    Provider<AdminPaymentMethodRepository>(
        (ref) => AdminPaymentMethodRepository());

final adminPaymentMethodsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminPaymentMethodRepositoryProvider).getPaymentMethods();
});

// ── Billing Cycles v1 (Admin) ─────────────────────────────────────────

final adminBillingCycleRepositoryProvider =
    Provider<AdminBillingCycleRepository>(
        (ref) => AdminBillingCycleRepository());

final adminBillingCyclesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminBillingCycleRepositoryProvider).getCycles();
});

// ── Visitors (Admin) ─────────────────────────────────────────────────

final adminVisitorRepositoryProvider =
    Provider<AdminVisitorRepository>((ref) => AdminVisitorRepository());

final adminVisitorSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

final adminVisitorStatusFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final adminVisitorsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(adminVisitorRepositoryProvider);
  final search = ref.watch(adminVisitorSearchProvider);
  final status = ref.watch(adminVisitorStatusFilterProvider);
  return repo.getVisitors(
    search: search.isEmpty ? null : search,
    status: status,
  );
});

// ── Push Notifications (Admin) ────────────────────────────────────────

final adminNotificationRepositoryProvider =
    Provider<AdminNotificationRepository>(
        (ref) => AdminNotificationRepository());

final adminNotificationDiagnosticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(adminNotificationRepositoryProvider).getDiagnostics();
});

// ── Documents (Admin) ─────────────────────────────────────────────────

final adminDocumentRepositoryProvider =
    Provider<AdminDocumentRepository>((ref) => AdminDocumentRepository());

final adminDocumentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminDocumentRepositoryProvider).getDocuments();
});

// ── Banners (Admin) ───────────────────────────────────────────────────

final adminBannerRepositoryProvider =
    Provider<AdminBannerRepository>((ref) => AdminBannerRepository());

final adminBannersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(adminBannerRepositoryProvider).getBanners();
});
