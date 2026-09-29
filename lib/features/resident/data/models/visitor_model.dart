/// Visitor model (enhanced for history)
class VisitorModel {
  final String? id;
  final String name;
  final String phone;
  final DateTime visitDate;
  final String? visitTime;
  final String? purpose;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? vehicleNumber;
  final String? photo;
  final DateTime? expectedCheckoutAt;
  final DateTime? overstayNotifiedAt;
  final bool? isOverstay;
  final bool wrongEntryReported;

  /// Closed automatically because the guard never marked exit; [checkOutTime] is
  /// the closing time, not a real exit.
  final bool exitNotMarked;

  VisitorModel({
    this.id,
    required this.name,
    required this.phone,
    required this.visitDate,
    this.visitTime,
    this.purpose,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.vehicleNumber,
    this.photo,
    this.expectedCheckoutAt,
    this.overstayNotifiedAt,
    this.isOverstay,
    this.wrongEntryReported = false,
    this.exitNotMarked = false,
  });

  /// True when still inside and past expected checkout (server flag or local).
  bool get overstayActive {
    if (isOverstay == true) return true;
    if (checkOutTime != null) return false;
    final statusNorm = status.trim().toUpperCase();
    if (statusNorm != 'CHECKED_IN') return false;
    final expected = expectedCheckoutAt;
    if (expected == null) return overstayNotifiedAt != null;
    return expected.toLocal().isBefore(DateTime.now());
  }

  factory VisitorModel.fromJson(Map<String, dynamic> json) {
    final purposeRaw = json['purpose']?.toString().trim();
    final checkInStr =
        json['checkInTime']?.toString() ?? json['checkInAt']?.toString();
    final checkInParsed = checkInStr != null
        ? DateTime.tryParse(checkInStr)
        : null;

    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return VisitorModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      visitDate: json['visitDate'] != null
          ? DateTime.tryParse(json['visitDate'].toString()) ??
              checkInParsed ??
              DateTime.now()
          : checkInParsed ?? DateTime.now(),
      visitTime: json['visitTime'] as String?,
      purpose:
          (purposeRaw != null && purposeRaw.isNotEmpty) ? purposeRaw : null,
      status: (json['status'] as String? ?? 'pending').trim(),
      checkInTime: checkInParsed ??
          (json['checkInAt'] != null
              ? DateTime.tryParse(json['checkInAt'].toString())
              : null),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'].toString())
          : (json['checkOutAt'] != null
                ? DateTime.tryParse(json['checkOutAt'].toString())
                : null),
      vehicleNumber: json['vehicleNumber'] as String?,
      photo: json['photo'] as String?,
      expectedCheckoutAt: parseDt(json['expectedCheckoutAt']),
      overstayNotifiedAt: parseDt(json['overstayNotifiedAt']),
      isOverstay: json['isOverstay'] is bool ? json['isOverstay'] as bool : null,
      wrongEntryReported: json['wrongEntryReported'] == true ||
          json['wrongEntryReport'] != null,
      exitNotMarked: json['exitNotMarked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'visitDate': visitDate.toIso8601String(),
      if (visitTime != null) 'visitTime': visitTime,
      if (purpose != null) 'purpose': purpose,
      'status': status,
      if (checkInTime != null) 'checkInTime': checkInTime!.toIso8601String(),
      if (checkOutTime != null) 'checkOutTime': checkOutTime!.toIso8601String(),
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
      if (photo != null) 'photo': photo,
      if (expectedCheckoutAt != null)
        'expectedCheckoutAt': expectedCheckoutAt!.toIso8601String(),
      if (overstayNotifiedAt != null)
        'overstayNotifiedAt': overstayNotifiedAt!.toIso8601String(),
      if (isOverstay != null) 'isOverstay': isOverstay,
      'wrongEntryReported': wrongEntryReported,
      'exitNotMarked': exitNotMarked,
    };
  }

  VisitorModel copyWith({
    bool? wrongEntryReported,
    bool? isOverstay,
  }) {
    return VisitorModel(
      id: id,
      name: name,
      phone: phone,
      visitDate: visitDate,
      visitTime: visitTime,
      purpose: purpose,
      status: status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      vehicleNumber: vehicleNumber,
      photo: photo,
      expectedCheckoutAt: expectedCheckoutAt,
      overstayNotifiedAt: overstayNotifiedAt,
      isOverstay: isOverstay ?? this.isOverstay,
      wrongEntryReported: wrongEntryReported ?? this.wrongEntryReported,
      exitNotMarked: exitNotMarked,
    );
  }
}
