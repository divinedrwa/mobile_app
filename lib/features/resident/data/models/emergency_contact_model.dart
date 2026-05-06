/// Emergency Contact model
class EmergencyContactModel {
  final String? id;
  final String name;
  final String relationship;
  final String phone;
  final String? alternatePhone;
  final String? address;

  EmergencyContactModel({
    this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.alternatePhone,
    this.address,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      alternatePhone: json['alternatePhone'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      if (alternatePhone != null) 'alternatePhone': alternatePhone,
      if (address != null) 'address': address,
    };
  }
}
