import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
import '../models/resident_dashboard_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);

/// Resident home dashboard stats (`GET /residents/dashboard`).
final residentDashboardProvider =
    FutureProvider<ResidentDashboardModel>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getDashboard();
});
