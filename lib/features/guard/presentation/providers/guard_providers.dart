import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/guard_repository.dart';
import '../../data/models/guard_models.dart';
import '../../../resident/data/models/parcel_model.dart';
import '../../../../shared/utils/provider_cache.dart';

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
  cacheFor(ref, const Duration(minutes: 15));
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
  cacheFor(ref, const Duration(hours: 1));
  return ref.read(guardRepositoryProvider).getVillasForSociety();
});

/// Flat list of individual residents derived from villas.
/// Each entry = one person the guard can select as a visitor/delivery target.
/// Includes ADMIN users who have a villa assigned (admin-cum-resident).
final guardResidentsPickerProvider =
    FutureProvider.autoDispose<List<ResidentPickerItem>>((ref) async {
  final villas = await ref.watch(guardVillasProvider.future);
  final residents = <ResidentPickerItem>[];
  for (final v in villas) {
    for (final r in v.residents) {
      final role = (r.role ?? '').toUpperCase();
      if (role == 'GUARD' || role == 'SUPER_ADMIN') continue;
      if (r.name.isEmpty) continue;
      residents.add(ResidentPickerItem.fromVillaAndResident(v, r));
    }
  }
  return residents;
});

/// Search query → masked resident rows (guard-only API).
final guardResidentsDirectoryProvider = FutureProvider.autoDispose
    .family<List<ResidentDirectoryRow>, String>(
  (ref, query) async {
    cacheFor(ref, const Duration(minutes: 10));
    return ref.read(guardRepositoryProvider).getResidentsDirectory(
          query: query.trim().isEmpty ? null : query.trim(),
        );
  },
);

/// Filter key: `query|category|vehicleType` (ALL = no filter).
final guardApprovedVehiclesProvider = FutureProvider.autoDispose
    .family<GuardApprovedVehiclesData, String>(
  (ref, filterKey) async {
    cacheFor(ref, const Duration(minutes: 10));
    final parts = filterKey.split('|');
    final query = parts.isNotEmpty ? parts[0] : '';
    final category = parts.length > 1 ? parts[1] : 'ALL';
    final vehicleType = parts.length > 2 ? parts[2] : 'ALL';
    return ref.read(guardRepositoryProvider).getApprovedVehicles(
          query: query.trim().isEmpty ? null : query.trim(),
          category: category == 'ALL' ? null : category,
          vehicleType: vehicleType == 'ALL' ? null : vehicleType,
        );
  },
);

final guardGateVehicleTodayProvider =
    FutureProvider.autoDispose<List<GuardVehicleEntry>>((ref) async {
  return ref.read(guardRepositoryProvider).getGateVehicleToday();
});

final guardVehicleLogsProvider =
    FutureProvider.autoDispose.family<List<GuardVehicleEntry>, String>(
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

/// Today's patrol entries (`GET /guards/patrols-today`).
final guardPatrolsTodayProvider =
    FutureProvider.autoDispose<List<GuardPatrolRow>>((ref) async {
  return ref.read(guardRepositoryProvider).getPatrolsToday();
});

/// Recent patrols (`GET /guards/my-patrols`).
final guardMyPatrolsProvider =
    FutureProvider.autoDispose<List<GuardPatrolRow>>((ref) async {
  cacheFor(ref, const Duration(minutes: 10));
  return ref.read(guardRepositoryProvider).getMyPatrols();
});

final guardMyShiftsProvider =
    FutureProvider.autoDispose<List<GuardShiftRow>>((ref) async {
  cacheFor(ref, const Duration(minutes: 30));
  return ref.read(guardRepositoryProvider).getMyShifts();
});
