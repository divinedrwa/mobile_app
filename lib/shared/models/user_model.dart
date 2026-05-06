import '../../core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';

/// User data model
class UserModel {
  final String id;
  final String name;
  final String email;
  /// Society email alerts — server field; toggled in Settings.
  final bool notifyEmail;
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
    this.phone,
    required this.username,
    required this.role,
    this.residentType,
    required this.societyId,
    this.societyName,
    this.villaId,
    this.villaNumber,
    this.villaBlock,
    this.photoUrl,
    this.moveInDate,
    this.moveOutDate,
    required this.isActive,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        notifyEmail: json['notifyEmail'] as bool? ?? false,
        phone: json['phone']?.toString(),
        username: json['username']?.toString() ?? '',
        role: UserRole.fromString(json['role']?.toString() ?? 'RESIDENT'),
        residentType: json['residentType'] != null
            ? ResidentType.fromString(json['residentType'] as String)
            : null,
        societyId: json['societyId']?.toString() ?? '',
        societyName: _parseSocietyName(json),
        villaId: json['villaId']?.toString(),
        villaNumber: json['villaNumber']?.toString() ??
            json['flatNumber']?.toString() ??
            json['unitNumber']?.toString() ??
            json['unitNo']?.toString() ??
            json['villa']?['villaNumber']?.toString() ??
            json['villa']?['number']?.toString(),
        villaBlock: _parseVillaBlock(json),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'notifyEmail': notifyEmail,
      'phone': phone,
      'username': username,
      'role': role.value,
      'residentType': residentType?.value,
      'societyId': societyId,
      'societyName': societyName,
      'villaId': villaId,
      'villaNumber': villaNumber,
      'villaBlock': villaBlock,
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
    String? phone,
    String? username,
    UserRole? role,
    ResidentType? residentType,
    String? societyId,
    String? societyName,
    String? villaId,
    String? villaNumber,
    String? villaBlock,
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
      phone: phone ?? this.phone,
      username: username ?? this.username,
      role: role ?? this.role,
      residentType: residentType ?? this.residentType,
      societyId: societyId ?? this.societyId,
      societyName: societyName ?? this.societyName,
      villaId: villaId ?? this.villaId,
      villaNumber: villaNumber ?? this.villaNumber,
      villaBlock: villaBlock ?? this.villaBlock,
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
