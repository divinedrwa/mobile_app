import '../../../../core/constants/app_constants.dart';

/// SOS alert — resident view (`/residents/my-sos`, `/residents/sos/active`, `/sos-alerts`).
class SOSAlertModel {
  final String? id;
  final SOSType type;
  final String? description;
  final String? location;
  final double? latitude;
  final double? longitude;
  final SOSStatus status;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? inProgressAt;
  final DateTime? resolvedAt;
  final String? cancelReason;
  final String? assignedGuardId;
  final String? assignedGuardName;
  final String? assignedGuardPhone;

  SOSAlertModel({
    this.id,
    required this.type,
    this.description,
    this.location,
    this.latitude,
    this.longitude,
    this.status = SOSStatus.created,
    this.createdAt,
    this.acknowledgedAt,
    this.inProgressAt,
    this.resolvedAt,
    this.cancelReason,
    this.assignedGuardId,
    this.assignedGuardName,
    this.assignedGuardPhone,
  });

  static SOSType _parseType(String? raw) {
    final v = raw?.toUpperCase().trim() ?? '';
    return SOSType.values.firstWhere(
      (e) => e.value == v,
      orElse: () {
        if (v == 'THEFT') return SOSType.security;
        return SOSType.other;
      },
    );
  }

  static SOSStatus _parseStatus(String? raw) {
    final v = raw?.toUpperCase().trim() ?? '';
    return SOSStatus.values.firstWhere(
      (e) => e.value == v,
      orElse: () => SOSStatus.created,
    );
  }

  factory SOSAlertModel.fromJson(Map<String, dynamic> json) {
    final g = json['assignedGuard'];
    Map<String, dynamic>? gm;
    if (g is Map) gm = Map<String, dynamic>.from(g);

    return SOSAlertModel(
      id: json['id']?.toString(),
      type: _parseType(
        json['type']?.toString() ?? json['emergencyType']?.toString(),
      ),
      description: (json['description'] ?? json['message'])?.toString(),
      location: json['location']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: _parseStatus(json['status']?.toString()),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      inProgressAt: json['inProgressAt'] != null
          ? DateTime.tryParse(json['inProgressAt'].toString())
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      cancelReason: json['cancelReason']?.toString(),
      assignedGuardId: gm?['id']?.toString(),
      assignedGuardName: gm?['name']?.toString(),
      assignedGuardPhone: gm?['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'emergencyType': type.value,
      if (description != null) 'message': description,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'status': status.value,
    };
  }
}
