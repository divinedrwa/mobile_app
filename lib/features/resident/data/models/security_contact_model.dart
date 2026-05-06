class SecurityContactModel {
  final String id;
  final String name;
  final String phone;

  const SecurityContactModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory SecurityContactModel.fromJson(Map<String, dynamic> json) {
    return SecurityContactModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }
}
