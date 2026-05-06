/// Resident complaint row from GET /residents/my-complaints
class ComplaintListItem {
  const ComplaintListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;

  factory ComplaintListItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return ComplaintListItem(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'General',
      status: (json['status'] as String?) ?? 'OPEN',
      createdAt: created is String
          ? (DateTime.tryParse(created) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
