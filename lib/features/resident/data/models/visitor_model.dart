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
  });

  factory VisitorModel.fromJson(Map<String, dynamic> json) {
    return VisitorModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      visitDate: json['visitDate'] != null
          ? DateTime.tryParse(json['visitDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      visitTime: json['visitTime'] as String?,
      purpose: json['purpose'] as String?,
      status: json['status'] as String? ?? 'pending',
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'] as String)
          : null,
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'] as String)
          : null,
      vehicleNumber: json['vehicleNumber'] as String?,
      photo: json['photo'] as String?,
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
    };
  }
}
