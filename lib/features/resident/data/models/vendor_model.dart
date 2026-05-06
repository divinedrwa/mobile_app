class VendorModel {
  final String id;
  final String name;
  final String category;
  final String phone;
  final String? email;
  final String? description;
  final bool isApproved;

  const VendorModel({
    required this.id,
    required this.name,
    required this.category,
    required this.phone,
    this.email,
    this.description,
    required this.isApproved,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    return VendorModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      category: (json['category'] ?? 'OTHER').toString(),
      phone: (json['phone'] ?? '').toString().trim(),
      email: json['email']?.toString().trim(),
      description: json['description']?.toString().trim(),
      isApproved: json['isApproved'] == true,
    );
  }
}
