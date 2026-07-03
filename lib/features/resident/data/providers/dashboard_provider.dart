import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/provider_cache.dart';
import '../repositories/dashboard_repository.dart';
import '../models/resident_dashboard_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);

/// Synchronous cold-start seed for the resident dashboard, read from the
/// persistent cache written after each successful [residentDashboardProvider]
/// fetch. Lets the home cards paint cached content instead of a skeleton.
final residentDashboardSeedProvider = Provider<ResidentDashboardModel?>((ref) {
  return readResidentDashboardSeed();
});

/// Resident home dashboard stats (`GET /residents/dashboard`).
final residentDashboardProvider =
    FutureProvider.autoDispose<ResidentDashboardModel>((ref) async {
  ref.watch(
    authProvider.select(
      (s) => '${s.user?.id}:${s.user?.villaId}:${s.user?.maintenanceBillingRole}',
    ),
  );
  cacheFor(ref, const Duration(seconds: 45));
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDashboard();
});
