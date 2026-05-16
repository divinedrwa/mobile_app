class ExpenseCategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? type;

  const ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.type,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Uncategorized',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      type: json['type'] as String?,
    );
  }
}
