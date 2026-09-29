import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/network/api_error_message.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/utils/persistent_list_cache.dart';
import '../models/pre_approved_visitor_model.dart';
import '../models/visitor_model.dart';

/// Persistent cache name for the resident's pre-approved visitors list.
const _preApprovedCacheName = 'pre_approved_visitors';

/// Reads the cold-start seed for pre-approved visitors from the persistent
/// cache. Re-parses the raw API item maps through [PreApprovedVisitorModel.fromJson]
/// so all fields (incl. `passcodeExpiry`, used for filtering) are preserved.
/// Returns `null` on a missing/corrupt entry — callers fall through to network.
List<PreApprovedVisitorModel>? readPreApprovedVisitorsSeed() {
  final key = PersistentListCache.scopedKey(_preApprovedCacheName);
  if (key == null) return null;
  return PersistentListCache.read<List<PreApprovedVisitorModel>>(key, (json) {
    final out = <PreApprovedVisitorModel>[];
    for (final item in json as List) {
      if (item is! Map) continue;
      try {
        out.add(
          PreApprovedVisitorModel.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // Skip malformed row; rest of cache still seeds.
      }
    }
    return out;
  });
}

/// Repository for visitor-related API calls
class VisitorRepository {
  final DioClient _dioClient;

  VisitorRepository(this._dioClient);

  bool _isResidentVillaMissing(DioException e) {
    if (e.response?.statusCode != 404) return false;
    return parseApiErrorMessage(
      e.response?.data,
      '',
    ).toLowerCase().contains('villa not assigned');
  }

  /// Pre-approve a visitor
  Future<PreApprovedVisitorModel> preApproveVisitor(
    PreApprovedVisitorModel visitor,
  ) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.preApproveVisitor,
        data: visitor.toPreApproveRequest(),
      );

      final raw = response.data;
      if (raw is! Map) {
        throw ServerException(message: 'Invalid pre-approve response');
      }
      final map = Map<String, dynamic>.from(raw);
      final pre = map['preApproved'];
      if (pre is! Map) {
        throw ServerException(
          message:
              map['message'] as String? ?? 'Pre-approve response missing data',
        );
      }
      final normalized = Map<String, dynamic>.from(pre);
      final otp = map['otp']?.toString();
      if (otp != null && otp.isNotEmpty && normalized['otp'] == null) {
        normalized['otp'] = otp;
      }
      final publicPassUrl = map['publicPassUrl']?.toString();
      if (publicPassUrl != null && publicPassUrl.isNotEmpty) {
        normalized['publicPassUrl'] = publicPassUrl;
      }
      return PreApprovedVisitorModel.fromJson(normalized);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to pre-approve visitor');
    }
  }

  /// Get pre-approved visitors for the logged-in resident's flat (newest first).
  /// [limit] maps to backend `?limit=` (capped 1-500). [offset] for pagination.
  Future<List<PreApprovedVisitorModel>> getPreApprovedVisitors({
    int limit = 200,
    int offset = 0,
  }) async {
    try {
      final capped = limit.clamp(1, 500);
      final response = await _dioClient.get(
        ApiEndpoints.preApprovedVisitors,
        queryParameters: {'limit': capped, 'offset': offset},
      );

      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final visitorsList = map['preApproved'] as List? ?? [];

      final out = <PreApprovedVisitorModel>[];
      for (final item in visitorsList) {
        if (item is! Map) continue;
        try {
          out.add(
            PreApprovedVisitorModel.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Skip malformed row; rest of list still renders.
        }
      }
      // Persist the raw API rows (only on the default first page) so the hub's
      // upcoming-visitors section paints cached content on the next cold start.
      if (offset == 0) {
        final key = PersistentListCache.scopedKey(_preApprovedCacheName);
        if (key != null) {
          await PersistentListCache.write(
            key,
            visitorsList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          );
        }
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch pre-approved visitors');
    }
  }

  /// Issue (or rotate) a public browser-pass URL for sharing from history.
  Future<String> issuePreApprovedShareLink(String id) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.preApprovedShareLink(id),
      );
      final raw = response.data;
      if (raw is! Map) {
        throw ServerException(message: 'Invalid share-link response');
      }
      final map = Map<String, dynamic>.from(raw);
      final url = map['publicPassUrl']?.toString().trim();
      if (url == null || url.isEmpty) {
        throw ServerException(
          message: map['message'] as String? ?? 'Could not create visitor pass link',
        );
      }
      return url;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to create visitor pass link');
    }
  }

  /// Invalidate the shared browser URL without cancelling the pass.
  Future<void> revokePreApprovedShareLink(String id) async {
    try {
      await _dioClient.post(ApiEndpoints.preApprovedRevokeShareLink(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to revoke share link');
    }
  }

  /// Recent opens of the public pass page (privacy-safe audit).
  Future<({int total, List<DateTime> viewedAt})> fetchPreApprovedPassViews(
    String id,
  ) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.preApprovedPassViews(id),
        queryParameters: {'limit': 10},
      );
      final raw = response.data;
      if (raw is! Map) {
        return (total: 0, viewedAt: const <DateTime>[]);
      }
      final map = Map<String, dynamic>.from(raw);
      final total = (map['total'] as num?)?.toInt() ?? 0;
      final viewsRaw = map['views'] as List? ?? const [];
      final viewedAt = viewsRaw
          .whereType<Map>()
          .map((v) => DateTime.tryParse(v['viewedAt']?.toString() ?? '')?.toLocal())
          .whereType<DateTime>()
          .toList();
      return (total: total, viewedAt: viewedAt);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load pass views');
    }
  }

  /// Delete pre-approved visitor
  Future<void> deletePreApprovedVisitor(String id) async {
    try {
      await _dioClient.delete(ApiEndpoints.preApprovedById(id));
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to delete visitor');
    }
  }

  /// Today's visitor counts for the resident hub summary card.
  Future<({int total, int checkedIn, int checkedOut})>
  getVisitorsTodaySummary() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.visitorsToday);
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      return (
        total: (summary['total'] as num?)?.toInt() ?? 0,
        checkedIn: (summary['checkedIn'] as num?)?.toInt() ?? 0,
        checkedOut: (summary['checkedOut'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      if (_isResidentVillaMissing(e)) {
        return (total: 0, checkedIn: 0, checkedOut: 0);
      }
      throw mapDioException(e, 'Failed to fetch today\'s visitor stats');
    }
  }

  /// Get visitor history
  Future<List<VisitorModel>> getVisitorHistory() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.myVisitors);
      final raw = response.data;
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final list = data['visitors'] as List? ?? [];
      return _parseVisitors(list);
    } on DioException catch (e) {
      if (_isResidentVillaMissing(e)) return [];
      throw mapDioException(e, 'Failed to fetch visitor history');
    }
  }

  /// Paginated visitor history
  Future<({List<VisitorModel> items, int total, bool hasMore})>
  getVisitorHistoryPaginated({int limit = 20, int offset = 0}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.myVisitors,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final list = data['visitors'] as List? ?? [];
      final items = _parseVisitors(list);
      final total = (data['total'] as num?)?.toInt() ?? items.length;
      final hasMore =
          data['hasMore'] as bool? ?? (offset + items.length < total);
      return (items: items, total: total, hasMore: hasMore);
    } on DioException catch (e) {
      if (_isResidentVillaMissing(e)) {
        return (items: <VisitorModel>[], total: 0, hasMore: false);
      }
      throw mapDioException(e, 'Failed to fetch visitor history');
    }
  }

  List<VisitorModel> _parseVisitors(List<dynamic> list) {
    final out = <VisitorModel>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      try {
        final json = Map<String, dynamic>.from(raw);
        final checkInRaw = json['checkInTime'] ?? json['checkInAt'];
        json['visitDate'] = checkInRaw ?? json['createdAt'];
        json['checkInTime'] = checkInRaw;
        json['checkOutTime'] = json['checkOutTime'] ?? json['checkOutAt'];

        final checkIn = checkInRaw != null
            ? DateTime.tryParse(checkInRaw.toString())?.toLocal()
            : null;
        if (checkIn != null) {
          json['visitTime'] = DateFormat('h:mm a').format(checkIn.toLocal());
        } else {
          json['visitTime'] = null;
        }

        final purpose = json['purpose']?.toString().trim();
        if (purpose == null || purpose.isEmpty) {
          json['purpose'] = null;
        } else {
          json['purpose'] = purpose;
        }

        out.add(VisitorModel.fromJson(json));
      } catch (_) {
        // Skip malformed row; rest of list still renders.
      }
    }
    return out;
  }

  /// Gate requests where the guard asked for your flat's approval.
  Future<List<Map<String, dynamic>>> getVisitorApprovalRequests({
    String filter = 'all',
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.visitorApprovalRequests,
        queryParameters: {'filter': filter},
      );
      final raw = response.data;
      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final list = data['visitors'] as List? ?? [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load visitor requests');
    }
  }

  Future<Map<String, dynamic>> getVisitorApprovalRequestDetail(
    String visitorId,
  ) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.visitorApprovalRequestDetail(visitorId),
      );
      final raw = response.data;
      if (raw is! Map) {
        throw ServerException(message: 'Invalid response');
      }
      return Map<String, dynamic>.from(raw);
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not load visitor');
    }
  }

  Future<Map<String, dynamic>> approveVisitorRequest(String visitorId) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.visitorApprovalApprove(visitorId),
      );
      final src = response.data;
      return src is Map ? Map<String, dynamic>.from(src) : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Approve failed');
    }
  }

  Future<Map<String, dynamic>> rejectVisitorRequest(String visitorId) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.visitorApprovalReject(visitorId),
      );
      final src = response.data;
      return src is Map ? Map<String, dynamic>.from(src) : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Reject failed');
    }
  }

  /// Report unexpected / wrong-flat visitor check-in.
  Future<Map<String, dynamic>> reportWrongEntry({
    required String visitorId,
    required String reason,
    String? residentNote,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.visitorWrongEntry(visitorId),
        data: {
          'reason': reason,
          if (residentNote != null && residentNote.trim().isNotEmpty)
            'residentNote': residentNote.trim(),
        },
      );
      final src = response.data;
      return src is Map ? Map<String, dynamic>.from(src) : {};
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not submit wrong-entry report');
    }
  }
}
