import '../../../../core/constants/app_constants.dart';

/// Pre-approved visitor model
class PreApprovedVisitorModel {
  final String? id;
  final String? villaId;
  final String name;
  final String phone;
  final VisitorType type;
  final String? purpose;
  final DateTime visitDate;
  final String? visitTime;

  /// Set from [TimeOfDay] when submitting the form so `validUntil` is correct for any locale.
  final int? visitTimeHour;
  final int? visitTimeMinute;
  final String? passcode;
  final String? qrCode;
  final DateTime? passcodeExpiry;
  final bool isFrequent;
  final String? notes;
  final DateTime? createdAt;

  final String? flatLabel;

  PreApprovedVisitorModel({
    this.id,
    this.villaId,
    required this.name,
    required this.phone,
    required this.type,
    this.purpose,
    required this.visitDate,
    this.visitTime,
    this.visitTimeHour,
    this.visitTimeMinute,
    this.passcode,
    this.qrCode,
    this.passcodeExpiry,
    this.isFrequent = false,
    this.notes,
    this.createdAt,
    this.flatLabel,
  });

  factory PreApprovedVisitorModel.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['visitorType'] ?? json['type'];
    final typeStr = typeRaw is String ? typeRaw : typeRaw?.toString();
    final normalized = typeStr == 'SERVICE'
        ? 'SERVICE_PROVIDER'
        : typeStr;
    final type = VisitorType.values.firstWhere(
      (e) => e.value == normalized,
      orElse: () => VisitorType.guest,
    );

    DateTime resolvedVisitDate;
    if (json['visitDate'] != null) {
      resolvedVisitDate = DateTime.parse(json['visitDate'] as String);
    } else if (json['validUntil'] != null) {
      resolvedVisitDate = DateTime.parse(json['validUntil'] as String);
    } else if (json['validFrom'] != null) {
      resolvedVisitDate = DateTime.parse(json['validFrom'] as String);
    } else {
      resolvedVisitDate = DateTime.now();
    }

    return PreApprovedVisitorModel(
      id: json['id']?.toString(),
      villaId: json['villaId']?.toString(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      type: type,
      purpose: json['purpose'] as String?,
      visitDate: resolvedVisitDate,
      visitTime: json['visitTime'] as String?,
      passcode: json['otp'] as String? ?? json['passcode'] as String?,
      qrCode: json['qrCode'] as String?,
      visitTimeHour: null,
      visitTimeMinute: null,
      passcodeExpiry: json['passcodeExpiry'] != null
          ? DateTime.parse(json['passcodeExpiry'] as String)
          : (json['validUntil'] != null
                ? DateTime.tryParse(json['validUntil'].toString())
                : null),
      isFrequent: (json['isFrequent'] ?? json['isRecurring']) as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      flatLabel: _flatLabelFromJson(json),
    );
  }

  static String? _flatLabelFromJson(Map<String, dynamic> json) {
    final villa = json['villa'];
    if (villa is! Map) return null;
    final m = Map<String, dynamic>.from(villa);
    final block = m['block']?.toString().trim();
    final num = m['villaNumber']?.toString().trim();
    if (num == null || num.isEmpty) return null;
    if (block != null && block.isNotEmpty) return '$block · $num';
    return num;
  }

  /// Full model JSON (e.g. local cache). Not the same as [toPreApproveRequest].
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (villaId != null) 'villaId': villaId,
      'name': name,
      'phone': phone,
      'visitorType': type.value,
      'purpose': purpose,
      'visitDate': visitDate.toIso8601String(),
      if (visitTime != null) 'visitTime': visitTime,
      'isFrequent': isFrequent,
      if (notes != null) 'notes': notes,
      if (passcode != null) 'passcode': passcode,
    };
  }

  /// Body for POST `/residents/pre-approve-visitor` (matches backend zod schema).
  Map<String, dynamic> toPreApproveRequest() {
    final nameTrim = name.trim();
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');

    final purposeParts = <String>[];
    if (purpose != null && purpose!.trim().isNotEmpty) {
      purposeParts.add(purpose!.trim());
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      purposeParts.add(notes!.trim());
    }
    final combinedPurpose = purposeParts.isEmpty
        ? null
        : purposeParts.join(' | ');

    final h = visitTimeHour ?? 23;
    final m = visitTimeMinute ?? 59;
    var validUntilLocal = DateTime(
      visitDate.year,
      visitDate.month,
      visitDate.day,
      h,
      m,
    );
    final now = DateTime.now();
    if (!validUntilLocal.isAfter(now)) {
      validUntilLocal = DateTime(
        visitDate.year,
        visitDate.month,
        visitDate.day,
        23,
        59,
        59,
      );
    }
    if (!validUntilLocal.isAfter(now)) {
      validUntilLocal = now.add(const Duration(hours: 1));
    }

    return {
      'name': nameTrim,
      'phone': phoneDigits,
      'visitorType': type.value,
      'purpose': ?combinedPurpose,
      // Zod `z.string().datetime()` requires `Z` or `±hh:mm` offset — local ISO fails.
      'validUntil': validUntilLocal.toUtc().toIso8601String(),
      // Honour the "Frequent visitor" toggle (was previously dropped).
      'isRecurring': isFrequent,
    };
  }

  PreApprovedVisitorModel copyWith({
    String? id,
    String? villaId,
    String? name,
    String? phone,
    VisitorType? type,
    String? purpose,
    DateTime? visitDate,
    String? visitTime,
    int? visitTimeHour,
    int? visitTimeMinute,
    String? passcode,
    String? qrCode,
    DateTime? passcodeExpiry,
    bool? isFrequent,
    String? notes,
    DateTime? createdAt,
    String? flatLabel,
  }) {
    return PreApprovedVisitorModel(
      id: id ?? this.id,
      villaId: villaId ?? this.villaId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      purpose: purpose ?? this.purpose,
      visitDate: visitDate ?? this.visitDate,
      visitTime: visitTime ?? this.visitTime,
      visitTimeHour: visitTimeHour ?? this.visitTimeHour,
      visitTimeMinute: visitTimeMinute ?? this.visitTimeMinute,
      passcode: passcode ?? this.passcode,
      qrCode: qrCode ?? this.qrCode,
      passcodeExpiry: passcodeExpiry ?? this.passcodeExpiry,
      isFrequent: isFrequent ?? this.isFrequent,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      flatLabel: flatLabel ?? this.flatLabel,
    );
  }
}
