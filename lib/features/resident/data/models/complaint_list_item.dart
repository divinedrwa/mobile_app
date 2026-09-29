/// Resident complaint row from GET /residents/my-complaints
class ComplaintSlaTimelineEvent {
  const ComplaintSlaTimelineEvent({
    required this.key,
    required this.label,
    required this.at,
    required this.state,
    this.detail,
  });

  final String key;
  final String label;
  final DateTime at;
  final String state;
  final String? detail;

  factory ComplaintSlaTimelineEvent.fromJson(Map<String, dynamic> json) {
    return ComplaintSlaTimelineEvent(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      at: DateTime.tryParse(json['at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      state: json['state']?.toString() ?? 'upcoming',
      detail: json['detail']?.toString(),
    );
  }
}

class ComplaintListItem {
  const ComplaintListItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.createdAt,
    this.priority,
    this.resolvedAt,
    this.slaDeadline,
    this.slaBreachNotifiedAt,
    this.photoUrl,
    this.adminNotes,
    this.updatedAt,
    this.slaTimeline = const [],
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final DateTime createdAt;
  final String? priority;
  final DateTime? resolvedAt;
  final DateTime? slaDeadline;
  final DateTime? slaBreachNotifiedAt;
  final String? photoUrl;
  final String? adminNotes;
  final DateTime? updatedAt;
  final List<ComplaintSlaTimelineEvent> slaTimeline;

  factory ComplaintListItem.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final resolved = json['resolvedAt'];
    final updated = json['updatedAt'];
    final slaDeadlineRaw = json['slaDeadline'];
    final slaBreachRaw = json['slaBreachNotifiedAt'];
    final timelineRaw = json['slaTimeline'];

    return ComplaintListItem(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'General',
      status: (json['status'] as String?) ?? 'OPEN',
      createdAt: created is String
          ? (DateTime.tryParse(created)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      priority: json['priority'] as String?,
      resolvedAt: resolved is String ? DateTime.tryParse(resolved)?.toLocal() : null,
      slaDeadline:
          slaDeadlineRaw is String ? DateTime.tryParse(slaDeadlineRaw)?.toLocal() : null,
      slaBreachNotifiedAt:
          slaBreachRaw is String ? DateTime.tryParse(slaBreachRaw)?.toLocal() : null,
      photoUrl: json['photoUrl'] as String?,
      adminNotes: json['adminNotes'] as String?,
      updatedAt: updated is String ? DateTime.tryParse(updated)?.toLocal() : null,
      slaTimeline: timelineRaw is List
          ? timelineRaw
              .whereType<Map>()
              .map((e) => ComplaintSlaTimelineEvent.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }
}
