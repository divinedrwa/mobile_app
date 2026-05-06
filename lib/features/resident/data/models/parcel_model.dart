/// Parcel model
class ParcelModel {
  final String? id;
  final String trackingNumber;
  final String courier;
  final ParcelStatus status;
  final DateTime? receivedAt;
  final DateTime? collectedAt;
  final String? collectedBy;
  final String? notes;
  final String? photo;

  ParcelModel({
    this.id,
    required this.trackingNumber,
    required this.courier,
    required this.status,
    this.receivedAt,
    this.collectedAt,
    this.collectedBy,
    this.notes,
    this.photo,
  });

  factory ParcelModel.fromJson(Map<String, dynamic> json) {
    final collectedAtRaw = json['collectedAt'] ?? json['deliveredAt'];
    final courierName = (json['courier'] as String?) ??
        (json['deliveryService'] as String?) ??
        (json['senderName'] as String?) ??
        'Parcel';

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is String && v.trim().isEmpty) return null;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ParcelModel(
      id: json['id']?.toString(),
      trackingNumber: json['trackingNumber'] as String? ?? '',
      courier: courierName,
      status: ParcelStatus.fromString(json['status'] as String? ?? 'pending'),
      receivedAt: parseDt(json['receivedAt']) ?? parseDt(json['createdAt']),
      collectedAt: parseDt(collectedAtRaw),
      collectedBy: json['collectedBy'] as String?,
      notes: json['notes'] as String?,
      photo: json['photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'trackingNumber': trackingNumber,
      'courier': courier,
      'status': status.value,
      if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
      if (collectedAt != null) 'collectedAt': collectedAt!.toIso8601String(),
      if (collectedBy != null) 'collectedBy': collectedBy,
      if (notes != null) 'notes': notes,
      if (photo != null) 'photo': photo,
    };
  }
}

/// Parcel status enum
enum ParcelStatus {
  pending('pending', 'Pending Collection'),
  collected('collected', 'Collected'),
  returned('returned', 'Returned');

  final String value;
  final String label;

  const ParcelStatus(this.value, this.label);

  static ParcelStatus fromString(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'pending':
      case 'received':
        return ParcelStatus.pending;
      case 'collected':
      case 'delivered':
        return ParcelStatus.collected;
      case 'returned':
        return ParcelStatus.returned;
      default:
        return ParcelStatus.pending;
    }
  }
}
