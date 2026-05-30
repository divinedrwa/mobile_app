class WaterRequestModel {
  const WaterRequestModel({
    required this.id,
    required this.gateId,
    required this.gateName,
    required this.requestType,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedByName,
    this.resolvedAt,
    this.resolvedNote,
  });

  final String id;
  final String gateId;
  final String gateName;
  final String requestType; // TURN_ON | TURN_OFF
  final String reason;
  final String status; // PENDING | FULFILLED | REJECTED
  final DateTime createdAt;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? resolvedNote;

  bool get isPending => status == 'PENDING';
  bool get isFulfilled => status == 'FULFILLED';
  bool get isRejected => status == 'REJECTED';
  bool get isTurnOn => requestType == 'TURN_ON';

  factory WaterRequestModel.fromJson(Map<String, dynamic> json) {
    final gate = json['gate'] as Map?;
    final resolver = json['resolvedBy'] as Map?;
    return WaterRequestModel(
      id: json['id']?.toString() ?? '',
      gateId: json['gateId']?.toString() ?? '',
      gateName: gate?['name']?.toString() ?? json['gateName']?.toString() ?? '',
      requestType: json['requestType']?.toString() ?? 'TURN_ON',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] is String
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      resolvedByName: resolver?['name']?.toString() ?? json['resolvedByName']?.toString(),
      resolvedAt: json['resolvedAt'] is String
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      resolvedNote: json['resolvedNote']?.toString(),
    );
  }
}
