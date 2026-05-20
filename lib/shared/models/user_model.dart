import '../../core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

/// User data model
class UserModel {
  final String id;
  final String name;
  final String email;
  /// Society email alerts — server field; toggled in Settings.
  final bool notifyEmail;
  /// FCM push notifications — server field; toggled in Settings.
  final bool notifyPush;
  final String? phone;
  final String username;
  final UserRole role;
  final ResidentType? residentType;
  final String societyId;
  /// From `society.name` or `societyName` in API JSON; null before first profile sync.
  final String? societyName;
  final String? villaId;
  final String? villaNumber;
  /// From `villa.block` when the API includes nested `villa`.
  final String? villaBlock;
  /// Billing / floor-plan unit from `/residents/me` (`user.unitId`).
  final String? unitId;
  final String? unitCode;
  /// `unit.label` when nested `unit` is present.
  final String? unitLabel;
  /// Denormalized on `/residents/me` (block · villa number).
  final String? propertyDisplayName;
  /// Denormalized on `/residents/me` (typically `unit.label`).
  final String? unitDisplayName;
  /// Denormalized on `/residents/me` (Owner / Tenant / Family member).
  final String? occupantRoleLabel;
  /// Maintenance billing role from `/residents/me` (PRIMARY, EXCLUDED, etc.).
  final String? maintenanceBillingRole;
  /// Server path or absolute URL for profile image (`/uploads/avatars/...`).
  final String? photoUrl;
  final DateTime? moveInDate;
  final DateTime? moveOutDate;
  final bool isActive;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.notifyEmail = false,
    this.notifyPush = true,
    this.phone,
    required this.username,
    required this.role,
    this.residentType,
    required this.societyId,
    this.societyName,
    this.villaId,
    this.villaNumber,
    this.villaBlock,
    this.unitId,
    this.unitCode,
    this.unitLabel,
    this.propertyDisplayName,
    this.unitDisplayName,
    this.occupantRoleLabel,
    this.maintenanceBillingRole,
    this.photoUrl,
    this.moveInDate,
    this.moveOutDate,
    required this.isActive,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      final unitRaw = json['unit'];
      Map<String, dynamic>? unitMap;
      if (unitRaw is Map) {
        unitMap = Map<String, dynamic>.from(unitRaw);
      }
      final unitIdFromUser = json['unitId']?.toString();
      final linkedUnitId = json['linkedUnitId']?.toString();

      return UserModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        notifyEmail: json['notifyEmail'] as bool? ?? false,
        notifyPush: json['notifyPush'] as bool? ?? true,
        phone: json['phone']?.toString(),
        username: json['username']?.toString() ?? '',
        role: UserRole.fromString(json['role']?.toString() ?? 'RESIDENT'),
        residentType: json['residentType'] != null
            ? ResidentType.fromString(json['residentType'] as String)
            : null,
        societyId: json['societyId']?.toString() ?? '',
        societyName: _parseSocietyName(json),
        villaId: json['villaId']?.toString() ??
            json['linkedPropertyId']?.toString(),
        villaNumber: json['villaNumber']?.toString() ??
            json['flatNumber']?.toString() ??
            json['unitNumber']?.toString() ??
            json['unitNo']?.toString() ??
            json['villa']?['villaNumber']?.toString() ??
            json['villa']?['number']?.toString(),
        villaBlock: _parseVillaBlock(json),
        unitId: unitMap?['id']?.toString() ?? unitIdFromUser ?? linkedUnitId,
        unitCode: unitMap?['unitCode']?.toString(),
        unitLabel: unitMap?['label']?.toString(),
        propertyDisplayName: json['propertyDisplayName']?.toString(),
        unitDisplayName: json['unitDisplayName']?.toString(),
        occupantRoleLabel: json['occupantRoleLabel']?.toString(),
        maintenanceBillingRole: json['maintenanceBillingRole']?.toString(),
        photoUrl: json['photoUrl']?.toString(),
        moveInDate: json['moveInDate'] != null
            ? DateTime.tryParse(json['moveInDate'] as String)
            : null,
        moveOutDate: json['moveOutDate'] != null
            ? DateTime.tryParse(json['moveOutDate'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
    } catch (e) {
      debugPrint('❌ Error parsing UserModel: $e');
      debugPrint('❌ JSON data: $json');
      rethrow;
    }
  }

  /// Prefer server [propertyDisplayName], else block · villa number from nested villa fields.
  String? get effectivePropertyDisplay {
    final s = propertyDisplayName?.trim();
    if (s != null && s.isNotEmpty) return s;
    final parts = <String>[];
    final b = villaBlock?.trim();
    final n = villaNumber?.trim();
    if (b != null && b.isNotEmpty) parts.add(b);
    if (n != null && n.isNotEmpty) parts.add(n);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// Prefer server [unitDisplayName], else nested unit label / code.
  String? get effectiveUnitDisplay {
    for (final raw in [unitDisplayName, unitLabel, unitCode]) {
      final s = raw?.trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  /// Prefer server [occupantRoleLabel], else [ResidentType.displayLabel] for residents.
  String? get effectiveOccupantDisplay {
    final o = occupantRoleLabel?.trim();
    if (o != null && o.isNotEmpty) return o;
    if (role == UserRole.resident && residentType != null) {
      return residentType!.displayLabel;
    }
    return null;
  }

  /// True when this resident is excluded from maintenance billing
  /// (another occupant of the same villa is the PRIMARY payer).
  bool get isBillingExcluded => maintenanceBillingRole == 'EXCLUDED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'notifyEmail': notifyEmail,
      'notifyPush': notifyPush,
      'phone': phone,
      'username': username,
      'role': role.value,
      'residentType': residentType?.value,
      'societyId': societyId,
      'societyName': societyName,
      'villaId': villaId,
      'villaNumber': villaNumber,
      'villaBlock': villaBlock,
      'unitId': unitId,
      'unitCode': unitCode,
      'unitLabel': unitLabel,
      'propertyDisplayName': propertyDisplayName,
      'unitDisplayName': unitDisplayName,
      'occupantRoleLabel': occupantRoleLabel,
      'maintenanceBillingRole': maintenanceBillingRole,
      'photoUrl': photoUrl,
      'moveInDate': moveInDate?.toIso8601String(),
      'moveOutDate': moveOutDate?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    bool? notifyEmail,
    bool? notifyPush,
    String? phone,
    String? username,
    UserRole? role,
    ResidentType? residentType,
    String? societyId,
    String? societyName,
    String? villaId,
    String? villaNumber,
    String? villaBlock,
    String? unitId,
    String? unitCode,
    String? unitLabel,
    String? propertyDisplayName,
    String? unitDisplayName,
    String? occupantRoleLabel,
    String? maintenanceBillingRole,
    String? photoUrl,
    DateTime? moveInDate,
    DateTime? moveOutDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      notifyEmail: notifyEmail ?? this.notifyEmail,
      notifyPush: notifyPush ?? this.notifyPush,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      role: role ?? this.role,
      residentType: residentType ?? this.residentType,
      societyId: societyId ?? this.societyId,
      societyName: societyName ?? this.societyName,
      villaId: villaId ?? this.villaId,
      villaNumber: villaNumber ?? this.villaNumber,
      villaBlock: villaBlock ?? this.villaBlock,
      unitId: unitId ?? this.unitId,
      unitCode: unitCode ?? this.unitCode,
      unitLabel: unitLabel ?? this.unitLabel,
      propertyDisplayName: propertyDisplayName ?? this.propertyDisplayName,
      unitDisplayName: unitDisplayName ?? this.unitDisplayName,
      occupantRoleLabel: occupantRoleLabel ?? this.occupantRoleLabel,
      maintenanceBillingRole: maintenanceBillingRole ?? this.maintenanceBillingRole,
      photoUrl: photoUrl ?? this.photoUrl,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

String? _parseSocietyName(Map<String, dynamic> json) {
  final d = json['societyName']?.toString().trim();
  if (d != null && d.isNotEmpty) return d;
  final s = json['society'];
  if (s is Map) {
    final n = s['name']?.toString().trim();
    if (n != null && n.isNotEmpty) return n;
  }
  return null;
}

String? _parseVillaBlock(Map<String, dynamic> json) {
  final d = json['villaBlock']?.toString().trim();
  if (d != null && d.isNotEmpty) return d;
  final v = json['villa'];
  if (v is Map) {
    final b = v['block']?.toString().trim();
    if (b != null && b.isNotEmpty) return b;
  }
  return null;
}
