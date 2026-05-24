class GarbageCollectionEvent {
  const GarbageCollectionEvent({
    required this.id,
    required this.entryTime,
    this.exitTime,
    this.notes,
    required this.gateName,
  });

  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final String? notes;
  final String gateName;

  bool get isInside => exitTime == null;

  Duration? get duration {
    final end = exitTime ?? DateTime.now();
    return end.difference(entryTime);
  }

  factory GarbageCollectionEvent.fromJson(Map<String, dynamic> json) {
    return GarbageCollectionEvent(
      id: json['id']?.toString() ?? '',
      entryTime: json['entryTime'] is String
          ? (DateTime.tryParse(json['entryTime'] as String) ?? DateTime.now())
          : DateTime.now(),
      exitTime: json['exitTime'] is String
          ? DateTime.tryParse(json['exitTime'] as String)
          : null,
      notes: json['notes'] as String?,
      gateName: (json['gateName'] as String?) ??
          (json['gate'] is Map
              ? ((json['gate'] as Map)['name']?.toString() ?? '')
              : ''),
    );
  }
}

class GarbageCollectionStatus {
  const GarbageCollectionStatus({
    required this.isInside,
    this.activeEvent,
  });

  final bool isInside;
  final GarbageCollectionEvent? activeEvent;

  factory GarbageCollectionStatus.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? json['activeEvent'];
    return GarbageCollectionStatus(
      isInside: json['isInside'] == true || event != null,
      activeEvent: event is Map
          ? GarbageCollectionEvent.fromJson(Map<String, dynamic>.from(event))
          : null,
    );
  }
}
