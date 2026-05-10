import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/pre_approved_visitor_model.dart';
import '../models/visitor_model.dart';

/// Repository for visitor-related API calls
class VisitorRepository {
  final DioClient _dioClient;

  VisitorRepository(this._dioClient);

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
          message: map['message'] as String? ?? 'Pre-approve response missing data',
        );
      }
      final normalized = Map<String, dynamic>.from(pre);
      final otp = map['otp']?.toString();
      if (otp != null && otp.isNotEmpty && normalized['otp'] == null) {
        normalized['otp'] = otp;
      }
      return PreApprovedVisitorModel.fromJson(normalized);
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to pre-approve visitor');
    }
  }

  /// Get pre-approved visitors for the logged-in resident’s flat (newest first).
  /// [limit] maps to backend `?limit=` (capped 1–500).
  Future<List<PreApprovedVisitorModel>> getPreApprovedVisitors({
    int limit = 200,
  }) async {
    try {
      final capped = limit.clamp(1, 500);
      final response = await _dioClient.get(
        ApiEndpoints.preApprovedVisitors,
        queryParameters: {'limit': capped},
      );

      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final visitorsList = map['preApproved'] as List? ?? [];

      final out = <PreApprovedVisitorModel>[];
      for (final item in visitorsList) {
        if (item is! Map) continue;
        try {
          out.add(
            PreApprovedVisitorModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        } catch (_) {
          // Skip malformed row; rest of list still renders.
        }
      }
      return out;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch pre-approved visitors');
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

  /// Get visitor history
  Future<List<VisitorModel>> getVisitorHistory() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.myVisitors);
      final list = response.data['visitors'] as List? ?? [];
      return list.whereType<Map>().map((raw) {
        final json = Map<String, dynamic>.from(raw);
        final checkInRaw = json['checkInTime'] ?? json['checkInAt'];
        json['visitDate'] = checkInRaw ?? json['createdAt'];
        json['checkInTime'] = checkInRaw;
        json['checkOutTime'] = json['checkOutTime'] ?? json['checkOutAt'];

        final checkIn = checkInRaw != null
            ? DateTime.tryParse(checkInRaw.toString())
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

        return VisitorModel.fromJson(json);
      }).toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch visitor history');
    }
  }

  /// Gate requests where the guard asked for your flat’s approval.
  Future<List<Map<String, dynamic>>> getVisitorApprovalRequests({
    String filter = 'all',
  }) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.visitorApprovalRequests,
        queryParameters: {'filter': filter},
      );
      final list = response.data['visitors'] as List? ?? [];
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
}
