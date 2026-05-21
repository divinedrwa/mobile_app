import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/guard_models.dart';
import '../../../resident/data/models/parcel_model.dart';

class GuardRepository {
  GuardRepository({Dio? dio}) : _override = dio;

  final Dio? _override;
  Dio get _dio => _override ?? DioClient.dio;

  /// Picks the map that actually contains dashboard fields — supports `{ data: { … } }`
  /// and double-wrapped payloads without mistaking unrelated `data` values.
  Map<String, dynamic> _resolveDashboardMap(Map<String, dynamic> map) {
    bool looksLikeDashboard(Map<String, dynamic> m) =>
        m.containsKey('guard') ||
        m.containsKey('todayStats') ||
        m.containsKey('today_stats') ||
        m.containsKey('activeSOS') ||
        m.containsKey('active_sos') ||
        m.containsKey('currentShift') ||
        m.containsKey('current_shift');

    if (looksLikeDashboard(map)) return map;

    final nested = map['data'];
    if (nested is Map) {
      final n = Map<String, dynamic>.from(nested);
      if (looksLikeDashboard(n)) return n;
      final inner = n['data'];
      if (inner is Map) {
        final i = Map<String, dynamic>.from(inner);
        if (looksLikeDashboard(i)) return i;
      }
    }
    return map;
  }

  Future<GuardDashboardData> getDashboard() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardDashboard);
      final data = response.data;
      if (kDebugMode) debugPrint('[GuardDash] raw type=${data.runtimeType}');
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }
      if (map == null) {
        if (kDebugMode) debugPrint('[GuardDash] response is not a Map — aborting');
        throw const FormatException('Invalid dashboard response');
      }
      if (kDebugMode) debugPrint('[GuardDash] top-level keys=${map.keys.toList()}');
      final payload = _resolveDashboardMap(map);
      if (kDebugMode) debugPrint('[GuardDash] resolved keys=${payload.keys.toList()}');
      final result = GuardDashboardData.fromJson(payload);
      if (kDebugMode) {
        debugPrint('[GuardDash] parsed: guard=${result.guardName}, '
            'gate=${result.gateName}, gateId=${result.gateId}, '
            'stats=(v:${result.todayStats.visitors},p:${result.todayStats.parcels},'
            'i:${result.todayStats.incidents},pat:${result.todayStats.patrols}), '
            'sos=${result.activeSos.length}');
      }
      return result;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[GuardDash] DioException: ${e.message} '
            'status=${e.response?.statusCode} body=${e.response?.data}');
      }
      throw mapDioException(e, 'Failed to load guard dashboard');
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    } catch (e, st) {
      if (kDebugMode) debugPrint('[GuardDash] unexpected: $e\n$st');
      throw ServerException(
        message: 'Could not read guard dashboard data.',
        data: e,
      );
    }
  }

  /// `GET /guards/my-gate` — `null` when no active shift / gate (HTTP 404).
  Future<GuardMyGateData?> getMyGate() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardMyGate);
      final data = response.data;
      if (data is! Map) return null;
      final parsed =
          GuardMyGateData.fromJson(Map<String, dynamic>.from(data));
      if (parsed.gateId.isEmpty) return null;
      return parsed;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw mapDioException(e, 'Could not load gate assignment');
    }
  }

  Future<List<GuardShiftRow>> getMyShifts({int days = 7}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.guardMyShifts,
        queryParameters: {'days': days},
      );
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['shifts'] as List? ?? [];
      final out = <GuardShiftRow>[];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          out.add(GuardShiftRow.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load shifts');
    }
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? _asJsonMap(dynamic x) {
    if (x is Map<String, dynamic>) return x;
    if (x is Map) return Map<String, dynamic>.from(x);
    return null;
  }

  /// Reads the first matching list-of-maps from the payload (`data` unwrap included).
  List<Map<String, dynamic>> _takeMapList(dynamic payload, List<String> keys) {
    List<Map<String, dynamic>> coerceList(dynamic listish) {
      if (listish is List) {
        return listish
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (listish is Map) {
        return [Map<String, dynamic>.from(listish)];
      }
      return [];
    }

    if (payload is List) return coerceList(payload);
    List<Map<String, dynamic>>? fromMap(Map<String, dynamic>? m) {
      if (m == null) return null;
      for (final k in keys) {
        final v = m[k];
        if (v is List || v is Map) return coerceList(v);
      }
      return null;
    }

    final root = _asJsonMap(payload);
    if (root != null) {
      final direct = fromMap(root);
      if (direct != null && direct.isNotEmpty) return direct;

      final nestedData = root['data'];
      if (nestedData is List) return coerceList(nestedData);

      final nested = _asJsonMap(nestedData);
      final inner = fromMap(nested);
      if (inner != null && inner.isNotEmpty) return inner;

      final innerList = nested?['results'] ?? nested?['items'];
      if (innerList is List || innerList is Map) return coerceList(innerList);
    }
    return [];
  }

  GuardVisitorRow? _visitorRowFromMapSafe(Map<String, dynamic> raw) {
    try {
      final row = GuardVisitorRow.fromJson(raw);
      return row.id.isEmpty ? null : row;
    } catch (_) {
      return null;
    }
  }

  List<GuardVisitorRow> _visitorRows(List<Map<String, dynamic>> maps) {
    final out = <GuardVisitorRow>[];
    for (final m in maps) {
      final row = _visitorRowFromMapSafe(m);
      if (row != null) out.add(row);
    }
    return out;
  }

  ParcelModel? _parcelFromMapSafe(Map<String, dynamic> raw) {
    try {
      return ParcelModel.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  List<ParcelModel> _parcelModels(List<Map<String, dynamic>> maps) {
    final out = <ParcelModel>[];
    for (final m in maps) {
      final p = _parcelFromMapSafe(m);
      if (p != null) out.add(p);
    }
    return out;
  }

  Map<String, dynamic> _normalizeGateVehicleEntry(Map<String, dynamic> raw) {
    dynamic exitRaw = raw['exitAt'] ?? raw['exitedAt'] ?? raw['checkOutAt'];
    if (exitRaw is String && exitRaw.trim().isEmpty) exitRaw = null;

    final villaDyn = raw['villa'];
    Map<String, dynamic>? villaMap;
    if (villaDyn is Map) villaMap = Map<String, dynamic>.from(villaDyn);

    final reg = raw['registrationNumber']?.toString() ??
        raw['plate']?.toString() ??
        raw['vehicleNumber']?.toString() ??
        '';

    return {
      ...raw,
      'id': raw['id']?.toString(),
      'registrationNumber': reg,
      'kind': raw['kind']?.toString() ?? '',
      'exitAt': exitRaw,
      'villa': villaMap,
    };
  }

  Future<List<GuardVisitorRow>> getTodayVisitors({DateTime? from, DateTime? to}) async {
    try {
      final qp = <String, dynamic>{
        if (from != null) 'from': _ymd(from),
        if (to != null) 'to': _ymd(to),
      };
      final response = await _dio.get(
        ApiEndpoints.guardMyVisitors,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final maps = _takeMapList(
        response.data,
        const [
          'visitors',
          'pendingVisitors',
          'records',
          'items',
          'results',
          'rows',
        ],
      );
      return _visitorRows(maps);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load visitors');
    }
  }

  Future<List<GuardVisitorRow>> getPendingVisitors() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardPendingVisitors);
      final maps = _takeMapList(
        response.data,
        const [
          'visitors',
          'pendingVisitors',
          'records',
          'items',
          'results',
          'rows',
        ],
      );
      return _visitorRows(maps);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load pending visitors');
    }
  }

  Future<List<VillaPickerItem>> getVillasForSociety() async {
    try {
      final response = await _dio.get(ApiEndpoints.societyVillas);
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['villas'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => VillaPickerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load villas');
    }
  }

  Future<Map<String, dynamic>> checkInVisitor({
    required String name,
    required String phone,
    required List<Map<String, dynamic>> visitTargets,
    required String visitorTypeApi,
    String? purpose,
    String? vehicleNumber,
    /// Optional data URL (`data:image/...;base64,...`) or server-supported reference.
    String? photo,
    /// When true, residents must approve before the guest is admitted (`APPROVED` then guard confirms).
    bool awaitResidentApproval = true,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardVisitorCheckIn,
        data: {
          'name': name,
          'phone': phone,
          'visitTargets': visitTargets,
          'visitorType': visitorTypeApi,
          if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
          if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
            'vehicleNumber': vehicleNumber.trim(),
          if (photo != null && photo.trim().isNotEmpty) 'photo': photo.trim(),
          'awaitResidentApproval': awaitResidentApproval,
        },
      );
      final data = response.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return const {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Check-in failed');
    }
  }

  Future<void> confirmVisitorEntryAfterApproval(String visitorId) async {
    try {
      await _dio.post(
        ApiEndpoints.guardVisitorConfirmEntry,
        data: {'visitorId': visitorId},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not confirm entry');
    }
  }

  Future<void> checkOutVisitor(String visitorId) async {
    try {
      await _dio.post(
        ApiEndpoints.guardVisitorCheckOut,
        data: {'visitorId': visitorId},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Check-out failed');
    }
  }

  /// Notifies residents (`POST /water-supply/toggle`).
  Future<void> toggleWaterSupply({
    required String gateId,
    required bool turnedOn,
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.waterSupplyToggle,
        data: {
          'gateId': gateId,
          'turnedOn': turnedOn,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(
        e,
        turnedOn ? 'Could not turn water supply on' : 'Could not turn water supply off',
      );
    }
  }

  /// Notifies residents (`POST /garbage-collection/entry`).
  Future<void> logGarbageCollectorEntry({
    required String gateId,
    String? notes,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.garbageCollectionEntry,
        data: {
          'gateId': gateId,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not log garbage collector entry');
    }
  }

  Future<void> respondToSos({
    required String alertId,
    required String status,
  }) async {
    try {
      if (status == 'IN_PROGRESS') {
        await _dio.patch(ApiEndpoints.sosAlertStart(alertId));
        return;
      }
      await _dio.post(
        ApiEndpoints.guardSosResponse,
        data: {'alertId': alertId, 'status': status},
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not update SOS');
    }
  }

  /// `GET /guards/active-alerts` — full active SOS list (no dashboard cap).
  Future<List<GuardSosRow>> getActiveAlerts() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardActiveAlerts);
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['alerts'] as List? ?? [];
      final out = <GuardSosRow>[];
      for (final raw in list.whereType<Map>()) {
        try {
          final row = GuardSosRow.fromJson(Map<String, dynamic>.from(raw));
          if (row.id.isNotEmpty) out.add(row);
        } catch (_) {}
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load SOS alerts');
    }
  }

  Future<List<ParcelModel>> getTodayParcels({DateTime? from, DateTime? to}) async {
    try {
      final qp = <String, dynamic>{
        if (from != null) 'from': _ymd(from),
        if (to != null) 'to': _ymd(to),
      };
      final response = await _dio.get(
        ApiEndpoints.guardMyParcels,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final maps = _takeMapList(
        response.data,
        const [
          'parcels',
          'pendingParcels',
          'parcelList',
          'pending',
          'items',
          'results',
        ],
      );
      return _parcelModels(maps);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load parcels');
    }
  }

  Future<List<ParcelModel>> getPendingParcels() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardParcelsPending);
      final maps = _takeMapList(
        response.data,
        const [
          'parcels',
          'pendingParcels',
          'parcelList',
          'pending',
          'items',
          'results',
        ],
      );
      return _parcelModels(maps);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load pending parcels');
    }
  }

  Future<void> logParcelReceived({
    required String villaId,
    String? deliveryService,
    String? trackingNumber,
    String? senderName,
    String? description,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.guardParcelReceived,
        data: {
          'villaId': villaId,
          if (deliveryService != null && deliveryService.trim().isNotEmpty)
            'deliveryService': deliveryService.trim(),
          if (trackingNumber != null && trackingNumber.trim().isNotEmpty)
            'trackingNumber': trackingNumber.trim(),
          if (senderName != null && senderName.trim().isNotEmpty)
            'senderName': senderName.trim(),
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not log parcel');
    }
  }

  Future<void> markParcelCollected(String parcelId) async {
    try {
      await _dio.patch(ApiEndpoints.guardParcelDelivered(parcelId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not update parcel');
    }
  }

  Future<void> startPatrol({required String location, String? notes}) async {
    try {
      await _dio.post(
        ApiEndpoints.guardStartPatrol,
        data: {
          'location': location,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not start patrol');
    }
  }

  Future<void> logPatrolCheckpoint({
    required String location,
    String? notes,
    bool issuesFound = false,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.guardPatrolCheckpoint,
        data: {
          'location': location,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'issuesFound': issuesFound,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not log checkpoint');
    }
  }

  Future<List<GuardPatrolRow>> getMyPatrols({int days = 7}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.guardMyPatrols,
        queryParameters: {'days': days},
      );
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['patrols'] as List? ?? [];
      final out = <GuardPatrolRow>[];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          out.add(GuardPatrolRow.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load patrols');
    }
  }

  Future<List<GuardPatrolRow>> getPatrolsToday() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardPatrolsToday);
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['patrols'] as List? ?? [];
      final out = <GuardPatrolRow>[];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          out.add(GuardPatrolRow.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {}
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load today\'s patrols');
    }
  }

  Future<Map<String, dynamic>> createGuardIncident({
    required String title,
    required String description,
    String? location,
    String? severity,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardIncidents,
        data: {
          'title': title,
          'description': description,
          if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
          if (severity != null && severity.trim().isNotEmpty) 'severity': severity.trim(),
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not log incident');
    }
  }

  Future<void> postSocBroadcast({
    required String kind,
    String? note,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.guardSocBroadcast,
        data: {
          'kind': kind,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not broadcast');
    }
  }

  Future<Map<String, dynamic>> logGateVehicleEntry({
    required String registrationNumber,
    required String kind,
    String? villaId,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardGateVehicleEntry,
        data: {
          'registrationNumber': registrationNumber,
          'kind': kind,
          if (villaId != null && villaId.trim().isNotEmpty) 'villaId': villaId.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not log vehicle');
    }
  }

  Future<void> markGateVehicleExit(String entryId) async {
    try {
      await _dio.patch(ApiEndpoints.guardGateVehicleExit(entryId));
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not mark exit');
    }
  }

  Future<List<GuardVehicleEntry>> getGateVehicleToday({DateTime? from, DateTime? to}) async {
    try {
      final qp = <String, dynamic>{
        if (from != null) 'from': _ymd(from),
        if (to != null) 'to': _ymd(to),
      };
      final response = await _dio.get(
        ApiEndpoints.guardGateVehicleToday,
        queryParameters: qp.isEmpty ? null : qp,
      );
      final maps = _takeMapList(
        response.data,
        const [
          'entries',
          'records',
          'vehicles',
          'gateVehicleLedger',
          'items',
          'results',
        ],
      );
      final normalized = maps.map(_normalizeGateVehicleEntry).toList();
      final out = <GuardVehicleEntry>[];
      for (final m in normalized) {
        try {
          out.add(GuardVehicleEntry.fromJson(m));
        } catch (_) {}
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load vehicle log');
    }
  }

  Future<List<ResidentDirectoryRow>> getResidentsDirectory({String? query}) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.guardResidentsDirectory,
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      final data = response.data;
      if (data is! Map) return [];
      final map = Map<String, dynamic>.from(data);
      final list = map['residents'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => ResidentDirectoryRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load directory');
    }
  }

  Future<Map<String, dynamic>> verifyVisitorOtp({
    required String otp,
    required String villaId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardVisitorOtpVerify,
        data: {'otp': otp, 'villaId': villaId},
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map.containsKey('verified')) {
          return map;
        }
      }
      throw mapDioException(e, 'OTP verification failed');
    }
  }

  Future<Map<String, dynamic>> approveVisitorEntry({
    required String otp,
    required String villaId,
    String? visitorName,
    String? visitorPhone,
    String? purpose,
    String? vehicleNumber,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardVisitorApproveEntry,
        data: {
          'otp': otp,
          'villaId': villaId,
          if (visitorName != null && visitorName.trim().isNotEmpty)
            'visitorName': visitorName.trim(),
          if (visitorPhone != null && visitorPhone.trim().isNotEmpty)
            'visitorPhone': visitorPhone.trim(),
          if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
          if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
            'vehicleNumber': vehicleNumber.trim(),
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map.containsKey('admitted') || map.containsKey('verified')) {
          return map;
        }
      }
      throw mapDioException(e, 'Could not admit visitor');
    }
  }

  Future<void> notifyVisitorAtGate({
    required String villaId,
    required String visitorName,
    required String visitorPhone,
    String? message,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.guardVisitorEntryNotify,
        data: {
          'villaId': villaId,
          'visitorName': visitorName,
          'visitorPhone': visitorPhone,
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not notify resident');
    }
  }

  Future<List<GuardPreApprovedEntry>> getPreApprovedEntries() async {
    try {
      final response = await _dio.get(ApiEndpoints.guardPreApprovedEntries);
      final data = response.data;
      if (data == null) return [];
      final maps = _takeMapList(
        data,
        const [
          'preApproved',
          'preApprovedVisitors',
          'visitors',
          'items',
          'results',
        ],
      );
      final out = <GuardPreApprovedEntry>[];
      for (final raw in maps) {
        try {
          final entry = GuardPreApprovedEntry.fromJson(raw);
          if (entry.id.isEmpty) continue;
          out.add(entry);
        } catch (_) {
          continue;
        }
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load expected visitors');
    }
  }

  Future<Map<String, dynamic>> admitPreApprovedEntry(String preApprovedId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.guardPreApprovedAdmit,
        data: {'preApprovedId': preApprovedId},
      );
      final data = response.data;
      return data is Map<String, dynamic> ? data : {};
    } on DioException catch (e) {
      final raw = e.response?.data;
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        if (map.containsKey('admitted') || map.containsKey('message')) {
          return map;
        }
      }
      throw mapDioException(e, 'Could not admit visitor');
    }
  }
}
