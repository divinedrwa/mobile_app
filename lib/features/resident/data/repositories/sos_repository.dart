import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../models/sos_alert_model.dart';

/// Repository for SOS — `/sos-alerts` + `/residents/*`.
class SOSRepository {
  final DioClient _dioClient;

  SOSRepository(this._dioClient);

  static String _apiEmergencyType(SOSType type) {
    switch (type) {
      case SOSType.medical:
        return 'MEDICAL';
      case SOSType.fire:
        return 'FIRE';
      case SOSType.security:
        return 'SECURITY';
      case SOSType.accident:
        return 'ACCIDENT';
      case SOSType.other:
        return 'OTHER';
    }
  }

  /// `POST /sos-alerts`
  Future<SOSAlertModel> sendSOSAlert(SOSAlertModel alert) async {
    try {
      final payload = <String, dynamic>{
        'emergencyType': _apiEmergencyType(alert.type),
        if (alert.description != null && alert.description!.trim().isNotEmpty)
          'message': alert.description!.trim(),
        if (alert.location != null && alert.location!.trim().isNotEmpty)
          'location': alert.location!.trim(),
        if (alert.latitude != null) 'latitude': alert.latitude,
        if (alert.longitude != null) 'longitude': alert.longitude,
      };

      final response = await _dioClient.post(
        ApiEndpoints.createSOS,
        data: payload,
      );

      final raw = response.data;
      if (raw is Map) {
        final inner = raw['alert'] ?? raw['data'] ?? raw;
        if (inner is Map) {
          return SOSAlertModel.fromJson(Map<String, dynamic>.from(inner));
        }
      }
      return alert;
    } on DioException catch (e) {
      final sc = e.response?.statusCode;
      if (sc == 409) {
        throw mapDioException(e, 'You already have an active SOS');
      }
      throw mapDioException(e, 'Failed to send SOS alert');
    }
  }

  /// `GET /residents/sos/active`
  Future<SOSAlertModel?> fetchActiveSos() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.sosActive);
      final raw = response.data;
      if (raw is! Map) return null;
      final a = raw['alert'];
      if (a == null) return null;
      if (a is Map) {
        return SOSAlertModel.fromJson(Map<String, dynamic>.from(a));
      }
      return null;
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to load active SOS');
    }
  }

  /// `GET /residents/my-sos` — history
  Future<List<SOSAlertModel>> getSOSAlerts() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.sosAlerts);
      final raw = response.data;
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final alertsList = map['alerts'] as List? ?? [];
      return alertsList
          .whereType<Map>()
          .map((json) => SOSAlertModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e, 'Failed to fetch SOS alerts');
    }
  }

  /// `POST /sos-alerts/:id/cancel`
  Future<SOSAlertModel> cancelSos(String id, String reason) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.sosCancel(id),
        data: {'reason': reason},
      );
      final raw = response.data;
      if (raw is Map) {
        final inner = raw['alert'];
        if (inner is Map) {
          try {
            return SOSAlertModel.fromJson(Map<String, dynamic>.from(inner));
          } catch (_) {
            // Server cancelled successfully but payload shape differed — avoid crashing UI.
            return SOSAlertModel(
              id: id,
              type: SOSType.other,
              description: reason,
              status: SOSStatus.cancelled,
            );
          }
        }
      }
      return SOSAlertModel(
        id: id,
        type: SOSType.other,
        status: SOSStatus.cancelled,
      );
    } on DioException catch (e) {
      throw mapDioException(e, 'Could not cancel SOS');
    }
  }
}
