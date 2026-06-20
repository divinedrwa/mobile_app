class WaterSupplyStatus {
  const WaterSupplyStatus({
    required this.gateId,
    required this.gateName,
    required this.location,
    required this.status,
    this.lastChanged,
    this.reason,
  });

  final String gateId;
  final String gateName;
  final String location;
  final String status;
  final DateTime? lastChanged;
  final String? reason;

  bool get isOn => status.toUpperCase() == 'ON';

  factory WaterSupplyStatus.fromJson(Map<String, dynamic> json) {
    return WaterSupplyStatus(
      gateId: json['gateId']?.toString() ?? '',
      gateName: (json['gateName'] as String?) ??
          (json['gate'] is String ? json['gate'] as String : ''),
      location: (json['location'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'OFF',
      lastChanged: json['lastChanged'] is String
          ? DateTime.tryParse(json['lastChanged'] as String)
          : null,
      reason: json['reason'] as String?,
    );
  }
}

class WaterSupplyEvent {
  const WaterSupplyEvent({
    required this.id,
    required this.action,
    required this.turnedOn,
    this.reason,
    required this.createdAt,
    required this.gateName,
  });

  final String id;
  final String action;
  final bool turnedOn;
  final String? reason;
  final DateTime createdAt;
  final String gateName;

  factory WaterSupplyEvent.fromJson(Map<String, dynamic> json) {
    return WaterSupplyEvent(
      id: json['id']?.toString() ?? '',
      action: (json['action'] as String?) ?? '',
      turnedOn: json['turnedOn'] == true,
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] is String
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      gateName: (json['gateName'] as String?) ??
          (json['gate'] is Map
              ? ((json['gate'] as Map)['name']?.toString() ?? '')
              : ''),
    );
  }
}
