import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/guard_repository.dart';
import '../../data/models/guard_models.dart';
import '../../../resident/data/models/parcel_model.dart';

/// Pending-visitor API first, then fills gaps from [getTodayVisitors] (same source
/// as dashboard live feed) so Active → Visitors matches home after "View all".
List<GuardVisitorRow> _mergePendingWithTodayForActiveTab({
  required List<GuardVisitorRow> pendingFromApi,
  required List<GuardVisitorRow> todayRows,
}) {
  final seen = <String>{};
  final out = <GuardVisitorRow>[];
  for (final v in pendingFromApi) {
    if (v.id.isEmpty || seen.contains(v.id)) continue;
    if (!v.isEligibleForActiveEntriesTab) continue;
    out.add(v);
    seen.add(v.id);
  }
  for (final v in todayRows) {
    if (v.id.isEmpty || seen.contains(v.id)) continue;
    if (!v.isEligibleForActiveEntriesTab) continue;
    out.add(v);
    seen.add(v.id);
  }
  return out;
}

final guardRepositoryProvider = Provider<GuardRepository>((ref) {
  return GuardRepository();
});

final guardDashboardProvider =
    FutureProvider.autoDispose<GuardDashboardData>((ref) async {
  return ref.read(guardRepositoryProvider).getDashboard();
});

/// Current shift gate (`GET /guards/my-gate`). `null` when no assignment.
final guardMyGateProvider =
    FutureProvider.autoDispose<GuardMyGateData?>((ref) async {
  return ref.read(guardRepositoryProvider).getMyGate();
});

/// Active SOS list (`GET /guards/active-alerts`); may include more rows than dashboard.
final guardActiveAlertsProvider =
    FutureProvider.autoDispose<List<GuardSosRow>>((ref) async {
  return ref.read(guardRepositoryProvider).getActiveAlerts();
});

final guardTodayVisitorsProvider =
    FutureProvider.autoDispose<List<GuardVisitorRow>>((ref) async {
  return ref.read(guardRepositoryProvider).getTodayVisitors();
});

final guardPendingVisitorsProvider =
    FutureProvider.autoDispose<List<GuardVisitorRow>>((ref) async {
  return ref.read(guardRepositoryProvider).getPendingVisitors();
});

/// Society-wide pre-approved visitors not yet admitted (guard pick list).
final guardPreApprovedEntriesProvider =
    FutureProvider.autoDispose<List<GuardPreApprovedEntry>>((ref) async {
  return ref.read(guardRepositoryProvider).getPreApprovedEntries();
});

/// Active tab → Visitors: [getPendingVisitors] + [getPreApprovedEntries], merged with
/// today's visitors (same as home feed) so the list is not empty when APIs differ.
///
/// Loads each primary source independently so one failing API does not wipe the whole tab.
/// Throws only when **both** pending and pre-approved fetches fail.
final guardActiveVisitorsTabProvider =
    FutureProvider.autoDispose<GuardActiveVisitorsTabData>((ref) async {
  final repo = ref.read(guardRepositoryProvider);

  Object? pendingErr;
  List<GuardVisitorRow> pending = [];
  try {
    pending = await repo.getPendingVisitors();
  } catch (e) {
    pendingErr = e;
    pending = [];
  }

  Object? preErr;
  List<GuardPreApprovedEntry> preApproved = [];
  try {
    preApproved = await repo.getPreApprovedEntries();
  } catch (e) {
    preErr = e;
    preApproved = [];
  }

  List<GuardVisitorRow> mergedVisitors = pending;
  try {
    final today = await repo.getTodayVisitors();
    mergedVisitors =
        _mergePendingWithTodayForActiveTab(pendingFromApi: pending, todayRows: today);
  } catch (_) {
    mergedVisitors = _mergePendingWithTodayForActiveTab(
      pendingFromApi: pending,
      todayRows: const [],
    );
  }

  if (pendingErr != null && preErr != null) {
    throw pendingErr;
  }

  return GuardActiveVisitorsTabData(
    pendingVisitors: mergedVisitors,
    preApproved: preApproved,
    pendingVisitorsError: pendingErr,
    preApprovedError: preErr,
  );
});

/// Gate logs: pass `'today'` or `'YYYY-MM-DD_YYYY-MM-DD'`.
final guardVisitorLogsProvider =
    FutureProvider.autoDispose.family<List<GuardVisitorRow>, String>(
  (ref, key) async {
    final repo = ref.read(guardRepositoryProvider);
    if (key == 'today') return repo.getTodayVisitors();
    final parts = key.split('_');
    if (parts.length != 2) return repo.getTodayVisitors();
    final from = DateTime.parse(parts[0]);
    final to = DateTime.parse(parts[1]);
    return repo.getTodayVisitors(from: from, to: to);
  },
);

final guardTodayParcelsProvider =
    FutureProvider.autoDispose<List<ParcelModel>>((ref) async {
  return ref.read(guardRepositoryProvider).getTodayParcels();
});

final guardParcelLogsProvider =
    FutureProvider.autoDispose.family<List<ParcelModel>, String>(
  (ref, key) async {
    final repo = ref.read(guardRepositoryProvider);
    if (key == 'today') return repo.getTodayParcels();
    final parts = key.split('_');
    if (parts.length != 2) return repo.getTodayParcels();
    final from = DateTime.parse(parts[0]);
    final to = DateTime.parse(parts[1]);
    return repo.getTodayParcels(from: from, to: to);
  },
);

final guardPendingParcelsProvider =
    FutureProvider.autoDispose<List<ParcelModel>>((ref) async {
  return ref.read(guardRepositoryProvider).getPendingParcels();
});

final guardVillasProvider =
    FutureProvider.autoDispose<List<VillaPickerItem>>((ref) async {
  return ref.read(guardRepositoryProvider).getVillasForSociety();
});

/// Search query → masked resident rows (guard-only API).
final guardResidentsDirectoryProvider = FutureProvider.autoDispose
    .family<List<ResidentDirectoryRow>, String>(
  (ref, query) async {
    return ref.read(guardRepositoryProvider).getResidentsDirectory(
          query: query.trim().isEmpty ? null : query.trim(),
        );
  },
);

final guardGateVehicleTodayProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(guardRepositoryProvider).getGateVehicleToday();
});

final guardVehicleLogsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, key) async {
    final repo = ref.read(guardRepositoryProvider);
    if (key == 'today') return repo.getGateVehicleToday();
    final parts = key.split('_');
    if (parts.length != 2) return repo.getGateVehicleToday();
    final from = DateTime.parse(parts[0]);
    final to = DateTime.parse(parts[1]);
    return repo.getGateVehicleToday(from: from, to: to);
  },
);

final guardMyShiftsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(guardRepositoryProvider).getMyShifts();
});
