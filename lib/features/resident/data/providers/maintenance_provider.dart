import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/billing_cycle_current_model.dart';
import '../models/maintenance_due_model.dart';
import '../repositories/maintenance_repository.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(),
);

final pendingMaintenanceProvider = FutureProvider<List<MaintenanceDueModel>>((
  ref,
) async {
  return ref.watch(maintenanceRepositoryProvider).getPendingMaintenance();
});

final maintenanceHistoryProvider = FutureProvider<List<MaintenanceDueModel>>((
  ref,
) async {
  return ref.watch(maintenanceRepositoryProvider).getMaintenanceHistory();
});

/// Server-driven billing window for residents (`GET /v1/cycles/current`). Skips fetch for admins.
final residentBillingCycleProvider =
    FutureProvider.autoDispose<BillingCycleCurrent>((ref) async {
      final user = ref.watch(authProvider).user;
      if (user == null || user.role == UserRole.admin) {
        return BillingCycleCurrent.fromJson(const {});
      }
      final sid = user.societyId;
      if (sid.isEmpty) {
        return BillingCycleCurrent.fromJson(const {});
      }
      final billingCycleId =
          ref.watch(maintenanceDashboardFilterProvider).billingCycleId;
      return ref.watch(maintenanceRepositoryProvider).getCurrentBillingCycle(
            sid,
            billingCycleId: billingCycleId,
          );
    });

/// Financial years for billing period selection (admin + resident).
final billingFinancialYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = ref.watch(authProvider).user;
      if (user == null) return [];
      if (user.role != UserRole.admin && user.role != UserRole.resident) {
        return [];
      }
      return ref.watch(maintenanceRepositoryProvider).getBillingFinancialYears();
    });

/// Billing cycles for a financial year (only months where a cycle was created).
final billingCyclesForFinancialYearProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, financialYearId) async {
      if (financialYearId.isEmpty) {
        return {'financialYear': null, 'cycles': <Map<String, dynamic>>[]};
      }
      return ref
          .watch(maintenanceRepositoryProvider)
          .getBillingCyclesForFinancialYear(financialYearId);
    });

class MaintenancePaymentNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  MaintenancePaymentNotifier(this._repository)
    : super(const AsyncValue.data(null));

  final MaintenanceRepository _repository;

  Future<Map<String, dynamic>?> createOrder({
    required String cycleId,
    String? idempotencyKey,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repository.createBillingOrder(
        cycleId: cycleId,
        idempotencyKey: idempotencyKey,
      );
      state = AsyncValue.data(response);
      return response;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final maintenancePaymentProvider =
    StateNotifierProvider<
      MaintenancePaymentNotifier,
      AsyncValue<Map<String, dynamic>?>
    >(
      (ref) =>
          MaintenancePaymentNotifier(ref.watch(maintenanceRepositoryProvider)),
    );

/// Fetches `yearlyBreakdown` (12-month financial summary) for a given
/// calendar year. Used by the Year Review tab which may need data from
/// multiple calendar years when a FY spans two (e.g. Apr 2025 – Mar 2026).
final yearlyBreakdownForYearProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, year) async {
      final user = ref.watch(authProvider).user;
      final isAdmin = user?.role == UserRole.admin;
      final dashboard = await ref
          .watch(maintenanceRepositoryProvider)
          .getFinancialDashboard(
            month: 1,
            year: year,
            isAdmin: isAdmin,
          );
      return ((dashboard['yearlyBreakdown'] ?? const []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });

class MaintenanceDashboardFilter {
  const MaintenanceDashboardFilter({
    required this.month,
    required this.year,
    this.maintenanceCollectionCycleId,
    this.financialYearId,
    this.billingCycleId,
  });

  final int month;
  final int year;

  /// Optional society maintenance billing period (`MaintenanceCollectionCycle` id).
  final String? maintenanceCollectionCycleId;

  /// Selected financial year (`FinancialYear.id`) — aligns with web billing UI.
  final String? financialYearId;

  /// Selected `BillingCycle.id` for the period (month exists only if cycle was created).
  final String? billingCycleId;

  MaintenanceDashboardFilter copyWith({
    int? month,
    int? year,
    String? maintenanceCollectionCycleId,
    String? financialYearId,
    String? billingCycleId,
    bool clearCollectionCycleId = false,
    bool clearFinancialYearId = false,
    bool clearBillingCycleId = false,
  }) {
    return MaintenanceDashboardFilter(
      month: month ?? this.month,
      year: year ?? this.year,
      maintenanceCollectionCycleId: clearCollectionCycleId
          ? null
          : (maintenanceCollectionCycleId ?? this.maintenanceCollectionCycleId),
      financialYearId: clearFinancialYearId
          ? null
          : (financialYearId ?? this.financialYearId),
      billingCycleId: clearBillingCycleId
          ? null
          : (billingCycleId ?? this.billingCycleId),
    );
  }
}

final maintenanceDashboardFilterProvider =
    StateProvider<MaintenanceDashboardFilter>((ref) {
      final now = DateTime.now();
      return MaintenanceDashboardFilter(month: now.month, year: now.year);
    });

final maintenanceDashboardProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final filter = ref.watch(maintenanceDashboardFilterProvider);
  final user = ref.watch(authProvider).user;
  final isAdmin = user?.role == UserRole.admin;
  return ref
      .watch(maintenanceRepositoryProvider)
      .getFinancialDashboard(
        month: filter.month,
        year: filter.year,
        isAdmin: isAdmin,
        maintenanceCollectionCycleId: filter.maintenanceCollectionCycleId,
      );
});
