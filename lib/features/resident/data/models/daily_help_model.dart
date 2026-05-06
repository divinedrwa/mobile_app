/// Daily Help/Staff model
class DailyHelpModel {
  final String? id;
  final String? assignmentId;
  final String name;
  final String type;
  final String phone;
  final String? photo;
  final String? timings;
  final bool isActive;

  DailyHelpModel({
    this.id,
    this.assignmentId,
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
      assignmentId: json['assignmentId'] as String?,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photo: json['photo'] as String?,
      timings: json['timings'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (assignmentId != null) 'assignmentId': assignmentId,
      'name': name,
      'type': type,
      'phone': phone,
      if (photo != null) 'photo': photo,
      if (timings != null) 'timings': timings,
      'isActive': isActive,
    };
  }
}
