import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../models/billing_cycle_current_model.dart';
import '../models/maintenance_due_model.dart';
import '../repositories/maintenance_repository.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(),
);

final pendingMaintenanceProvider = FutureProvider<List<MaintenanceDueModel>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).getPendingMaintenance();
});

final maintenanceHistoryProvider = FutureProvider<List<MaintenanceDueModel>>((ref) async {
  return ref.watch(maintenanceRepositoryProvider).getMaintenanceHistory();
});

/// Server-driven billing window for residents (`GET /v1/cycles/current`). Skips fetch for admins.
final residentBillingCycleProvider = FutureProvider.autoDispose<BillingCycleCurrent>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || user.role == UserRole.admin) {
    return BillingCycleCurrent.fromJson(const {});
  }
  final sid = user.societyId;
  if (sid.isEmpty) {
    return BillingCycleCurrent.fromJson(const {});
  }
  return ref.watch(maintenanceRepositoryProvider).getCurrentBillingCycle(sid);
});

class MaintenancePaymentNotifier extends StateNotifier<AsyncValue<void>> {
  MaintenancePaymentNotifier(this._repository) : super(const AsyncValue.data(null));

  final MaintenanceRepository _repository;

  Future<bool> pay({
    required String villaId,
    required int month,
    required int year,
    required double amount,
    required String paymentMode,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.payMaintenance(
        villaId: villaId,
        month: month,
        year: year,
        amount: amount,
        paymentMode: paymentMode,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final maintenancePaymentProvider =
    StateNotifierProvider<MaintenancePaymentNotifier, AsyncValue<void>>(
  (ref) => MaintenancePaymentNotifier(ref.watch(maintenanceRepositoryProvider)),
);

class MaintenanceDashboardFilter {
  const MaintenanceDashboardFilter({
    required this.month,
    required this.year,
  });

  final int month;
  final int year;

  MaintenanceDashboardFilter copyWith({int? month, int? year}) {
    return MaintenanceDashboardFilter(
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }
}

final maintenanceDashboardFilterProvider =
    StateProvider<MaintenanceDashboardFilter>((ref) {
  final now = DateTime.now();
  return MaintenanceDashboardFilter(month: now.month, year: now.year);
});

final maintenanceDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(maintenanceDashboardFilterProvider);
  final user = ref.watch(authProvider).user;
  final isAdmin = user?.role == UserRole.admin;
  return ref.watch(maintenanceRepositoryProvider).getFinancialDashboard(
        month: filter.month,
        year: filter.year,
        isAdmin: isAdmin,
      );
});
