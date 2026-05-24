class BannerModel {
  const BannerModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.actionUrl,
    required this.type,
    required this.priority,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? actionUrl;
  final String type;
  final int priority;
  final DateTime? startDate;
  final DateTime? endDate;

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      actionUrl: json['actionUrl'] as String?,
      type: (json['type'] as String?) ?? 'ANNOUNCEMENT',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      startDate: json['startDate'] is String
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] is String
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
    );
  }
}
