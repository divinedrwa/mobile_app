class VehicleLogEntry {
  const VehicleLogEntry({
    required this.id,
    required this.registrationNumber,
    required this.kind,
    required this.entryAt,
    this.exitAt,
    this.guardName,
    this.notes,
  });

  final String id;
  final String registrationNumber;
  final String kind;
  final DateTime entryAt;
  final DateTime? exitAt;
  final String? guardName;
  final String? notes;

  bool get isInside => exitAt == null;

  Duration get duration {
    final end = exitAt ?? DateTime.now();
    return end.difference(entryAt);
  }

  factory VehicleLogEntry.fromJson(Map<String, dynamic> json) {
    return VehicleLogEntry(
      id: json['id']?.toString() ?? '',
      registrationNumber: (json['registrationNumber'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'VISITOR',
      entryAt: json['entryAt'] is String
          ? (DateTime.tryParse(json['entryAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      exitAt: json['exitAt'] is String
          ? DateTime.tryParse(json['exitAt'] as String)
          : null,
      guardName: json['guardName'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
