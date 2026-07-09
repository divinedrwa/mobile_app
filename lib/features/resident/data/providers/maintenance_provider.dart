import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/billing_cycle_current_model.dart';
import '../models/expense_breakdown_model.dart';
import '../models/maintenance_due_model.dart';
import '../../../../shared/utils/resident_capabilities.dart';
import '../repositories/maintenance_repository.dart';
import '../utils/payment_mode.dart';
import 'dashboard_provider.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(),
);

/// Synchronous cold-start seed for pending maintenance dues, read from the
/// persistent cache written after each successful [pendingMaintenanceProvider]
/// fetch. Lets the home maintenance card paint cached dues instead of a
/// skeleton before the network resolves.
final pendingMaintenanceSeedProvider =
    Provider<List<MaintenanceDueModel>?>((ref) {
  return readPendingMaintenanceSeed();
});

/// Single cached source for the (heavy) financial-dashboard endpoint, keyed by
/// period + cycle. All dashboard-consuming providers derive from this so the
/// hub card, cycle-detail and year-review screens share one fetch instead of
/// each re-downloading the same payload.
final financialDashboardProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    ({
      int month,
      int year,
      String? billingCycleId,
      String? collectionCycleId,
    })>((ref, key) async {
  cacheFor(ref, const Duration(minutes: 2));
  return ref.watch(maintenanceRepositoryProvider).getFinancialDashboard(
        month: key.month,
        year: key.year,
        billingCycleId: key.billingCycleId,
        maintenanceCollectionCycleId: key.collectionCycleId,
      );
});

/// Refresh all resident maintenance billing providers after a payment settles
/// or admin updates payment status.
void invalidateMaintenancePaymentProviders(WidgetRef ref) {
  ref.invalidate(pendingMaintenanceProvider);
  ref.invalidate(outstandingDuesProvider);
  ref.invalidate(maintenanceHistoryProvider);
  ref.invalidate(residentBillingCycleProvider);
  ref.invalidate(residentExpenseBreakdownProvider);
  ref.invalidate(residentDashboardProvider);
}

/// Refresh fund balance, maintenance dashboard, and home finances after
/// society expenses are created, updated, or deleted.
void invalidateSocietyFinanceProviders(WidgetRef ref) {
  ref.invalidate(maintenanceDashboardProvider);
  ref.invalidate(residentDashboardProvider);
  ref.invalidate(residentExpenseBreakdownProvider);
  invalidateMaintenancePaymentProviders(ref);
}

/// Per-cycle insight for the cycle-detail screen: the per-home expense split
/// (same as the hub card) plus the resident's actual payment mode — both from
/// a single dashboard fetch for the cycle's month.
class CycleInsight {
  const CycleInsight({required this.breakdown, this.paymentMode});
  final ExpenseBreakdown breakdown;
  final String? paymentMode;
}

final cycleInsightProvider = FutureProvider.autoDispose
    .family<CycleInsight, ({int month, int year})>((ref, key) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  cacheFor(ref, const Duration(minutes: 2));
  final user = ref.watch(authProvider.select((s) => s.user));
  if (!userCanViewResidentBilling(user)) {
    return CycleInsight(breakdown: ExpenseBreakdown.empty());
  }
  final dash = await ref.watch(financialDashboardProvider((
    month: key.month,
    year: key.year,
    billingCycleId: null,
    collectionCycleId: null,
  )).future);
  return CycleInsight(
    breakdown: ExpenseBreakdown.fromDashboard(dash, allowFallback: false),
    paymentMode: paymentModeForVilla(dash, user?.villaId),
  );
});

final outstandingDuesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      // Billing data changes rarely and is explicitly invalidated after a
      // payment (invalidateMaintenancePaymentProviders) — so a short TTL just
      // forced needless re-fetches (and skeletons) on every back-navigation.
      cacheFor(ref, const Duration(minutes: 3));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) return {};
      return ref.watch(maintenanceRepositoryProvider).getOutstandingDues();
    });

final pendingMaintenanceProvider =
    FutureProvider.autoDispose<List<MaintenanceDueModel>>((ref) async {
      // Re-fetch when profile/villa/billing role changes (admin+resident accounts).
      ref.watch(
        authProvider.select(
          (s) => '${s.user?.id}:${s.user?.villaId}:${s.user?.maintenanceBillingRole}',
        ),
      );
      cacheFor(ref, const Duration(minutes: 3));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) return [];
      return ref.watch(maintenanceRepositoryProvider).getPendingMaintenance();
    });

final maintenanceHistoryProvider =
    FutureProvider.autoDispose<List<MaintenanceDueModel>>((ref) async {
      ref.watch(authProvider.select((s) => s.user?.id));
      cacheFor(ref, const Duration(minutes: 3));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) return [];
      return ref.watch(maintenanceRepositoryProvider).getMaintenanceHistory();
    });

/// Server-driven billing window (`GET /v1/cycles/current`) for residents and admins with a villa.
final residentBillingCycleProvider =
    FutureProvider.autoDispose<BillingCycleCurrent>((ref) async {
      ref.watch(
        authProvider.select(
          (s) => '${s.user?.id}:${s.user?.villaId}:${s.user?.maintenanceBillingRole}',
        ),
      );
      cacheFor(ref, const Duration(minutes: 3));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) {
        return BillingCycleCurrent.fromJson(const {});
      }
      final sid = user!.societyId;
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

/// A billing cycle the resident picked for the "Where your money goes" card.
/// `null` (the default) means "auto" — the current/latest cycle with data.
class ExpenseCycleSelection {
  const ExpenseCycleSelection({
    required this.financialYearId,
    required this.billingCycleId,
    required this.month,
    required this.year,
  });

  final String financialYearId;
  final String billingCycleId;
  final int month;
  final int year;
}

/// Holds the resident's chosen cycle for the expense card. Resets to null
/// (auto) on logout-driven rebuilds since it's autoDispose-adjacent state.
final selectedExpenseCycleProvider =
    StateProvider<ExpenseCycleSelection?>((ref) => null);

/// Society expense split + paying-member count for the "Where your money goes"
/// card, scoped to the selected cycle (or the current/latest cycle by default).
/// Reads `monthlyExpenseBreakdown` / `yearlyBreakdown` for amounts and
/// `residentsSummary.totalResidents` for the per-member divisor.
final residentExpenseBreakdownProvider =
    FutureProvider.autoDispose<ExpenseBreakdown>((ref) async {
      ref.watch(authProvider.select((s) => s.user?.id));
      cacheFor(ref, const Duration(minutes: 2));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) return ExpenseBreakdown.empty();

      final selection = ref.watch(selectedExpenseCycleProvider);

      if (selection != null) {
        // Explicit cycle: show exactly that cycle's data (no month fallback).
        final dashboard = await ref.watch(financialDashboardProvider((
          month: selection.month,
          year: selection.year,
          billingCycleId: selection.billingCycleId,
          collectionCycleId: null,
        )).future);
        return ExpenseBreakdown.fromDashboard(dashboard, allowFallback: false)
            .copyWith(billingCycleId: selection.billingCycleId);
      }

      // Default: current month, falling back to the latest month with data.
      final now = DateTime.now();
      final dashboard = await ref.watch(financialDashboardProvider((
        month: now.month,
        year: now.year,
        billingCycleId: null,
        collectionCycleId: null,
      )).future);
      final initial = ExpenseBreakdown.fromDashboard(dashboard);

      // The member-count divisor (residentsSummary) is for the *requested*
      // month. The current month often has no billing cycle yet — so its count
      // is every villa (exclusions not applied) while the expenses we show came
      // from an earlier month via fallback. Re-fetch that earlier month so the
      // divisor reflects ITS cycle (which excludes excluded homes) and lines up
      // with the expenses being displayed.
      if (initial.hasData &&
          (initial.month != now.month || initial.year != now.year)) {
        final aligned = await ref.watch(financialDashboardProvider((
          month: initial.month,
          year: initial.year,
          billingCycleId: null,
          collectionCycleId: null,
        )).future);
        final alignedBreakdown =
            ExpenseBreakdown.fromDashboard(aligned, allowFallback: false);
        if (alignedBreakdown.hasData) return alignedBreakdown;
      }
      return initial;
    });

/// Financial years for billing period selection (admin + resident).
final billingFinancialYearsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      cacheFor(ref, const Duration(minutes: 5));
      final user = ref.watch(authProvider.select((s) => s.user));
      if (!userCanViewResidentBilling(user)) return [];
      return ref.watch(maintenanceRepositoryProvider).getBillingFinancialYears();
    });

/// Billing cycles for a financial year (only months where a cycle was created).
/// Draft (unpublished) cycles are excluded — they belong on admin billing setup.
final billingCyclesForFinancialYearProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, financialYearId) async {
      cacheFor(ref, const Duration(minutes: 5));
      if (financialYearId.isEmpty) {
        return {'financialYear': null, 'cycles': <Map<String, dynamic>>[]};
      }
      final body = await ref
          .watch(maintenanceRepositoryProvider)
          .getBillingCyclesForFinancialYear(financialYearId);
      final raw = body['cycles'];
      if (raw is List) {
        body['cycles'] = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((c) => c['publishedAt'] != null)
            .toList();
      }
      return body;
    });

class MaintenancePaymentNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  MaintenancePaymentNotifier(this._repository)
    : super(const AsyncValue.data(null));

  final MaintenanceRepository _repository;

  Future<Map<String, dynamic>?> createOrder({
    String? cycleId,
    bool payAllPending = false,
    String? idempotencyKey,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _repository.createBillingOrder(
        cycleId: cycleId,
        payAllPending: payAllPending,
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
      final dashboard = await ref.watch(financialDashboardProvider((
        month: 1,
        year: year,
        billingCycleId: null,
        collectionCycleId: null,
      )).future);
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
  return ref.watch(financialDashboardProvider((
    month: filter.month,
    year: filter.year,
    billingCycleId: filter.billingCycleId,
    collectionCycleId: filter.maintenanceCollectionCycleId,
  )).future);
});

