class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    this.location,
    this.photoUrl,
    this.resolvedAt,
    required this.createdAt,
    this.reportedByName,
  });

  final String id;
  final String title;
  final String description;
  final String severity;
  final String? location;
  final String? photoUrl;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? reportedByName;

  bool get isResolved => resolvedAt != null;

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      severity: (json['severity'] as String?) ?? 'LOW',
      location: json['location'] as String?,
      photoUrl: json['photoUrl'] as String?,
      resolvedAt: json['resolvedAt'] is String
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      createdAt: json['createdAt'] is String
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      reportedByName: json['reportedByName'] as String? ??
          (json['reportedBy'] is Map
              ? (json['reportedBy'] as Map)['name']?.toString()
              : null),
    );
  }
}
