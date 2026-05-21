/// Family Member model
class FamilyMemberModel {
  final String? id;
  final String name;
  final String relationship;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final String? photo;

  FamilyMemberModel({
    this.id,
    required this.name,
    required this.relationship,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.photo,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      // Backend uses 'relation', mobile uses 'relationship' - handle both
      relationship: (json['relationship'] ?? json['relation']) as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      photo: json['photo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'relationship': relationship,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (photo != null) 'photo': photo,
    };
  }
}

/// Daily Help model
class DailyHelpModel {
  final String? id;
  final String name;
  final String type;
  final String phone;
  final String? photo;
  final String? timings;
  final bool isActive;

  DailyHelpModel({
    this.id,
    required this.name,
    required this.type,
    required this.phone,
    this.photo,
    this.timings,
    this.isActive = true,
  });

  factory DailyHelpModel.fromJson(Map<String, dynamic> json) {
    return DailyHelpModel(
      id: json['id'] as String?,
      name: json['name'] as String,
      type: json['type'] as String,
      phone: json['phone'] as String,
      photo: json['photo'] as String?,
      timings: json['timings'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'phone': phone,
      if (photo != null) 'photo': photo,
      if (timings != null) 'timings': timings,
      'isActive': isActive,
    };
  }
}
