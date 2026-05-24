class DirectoryResident {
  const DirectoryResident({
    required this.userId,
    required this.name,
    this.villaNumber,
    this.block,
    this.phoneMasked,
  });

  final String userId;
  final String name;
  final String? villaNumber;
  final String? block;
  final String? phoneMasked;

  String get flatLabel {
    final parts = <String>[];
    if (block != null && block!.isNotEmpty) parts.add(block!);
    if (villaNumber != null && villaNumber!.isNotEmpty) parts.add(villaNumber!);
    return parts.join('-');
  }

  factory DirectoryResident.fromJson(Map<String, dynamic> json) {
    return DirectoryResident(
      userId: json['userId']?.toString() ?? '',
      name: (json['name'] as String?) ?? '',
      villaNumber: json['villaNumber'] as String?,
      block: json['block'] as String?,
      phoneMasked: json['phoneMasked'] as String?,
    );
  }
}
