Map<String, dynamic>? _jsonMap(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

int _jsonInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? 0;
}

List<dynamic> _jsonList(dynamic v) {
  if (v == null) return const [];
  if (v is List) return v;
  return const [];
}

String? _jsonString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Dashboard payload from `GET /guards/my-dashboard`
class GuardDashboardData {
  GuardDashboardData({
    required this.guardName,
    this.gateName,
    this.gateId,
    required this.todayStats,
    required this.activeSos,
  });

  final String? guardName;
  final String? gateName;
  /// From active shift — required for water / garbage gate APIs.
  final String? gateId;
  final GuardTodayStats todayStats;
  final List<GuardSosRow> activeSos;

  factory GuardDashboardData.fromJson(Map<String, dynamic> json) {
    final guard = _jsonMap(json['guard']);
    final shift = _jsonMap(json['currentShift'] ?? json['current_shift']);
    final gate = _jsonMap(shift?['gate']);

    final stats =
        _jsonMap(json['todayStats'] ?? json['today_stats']) ?? <String, dynamic>{};

    final sosList =
        _jsonList(json['activeSOS'] ?? json['active_sos'] ?? json['alerts']);
    final activeSos = <GuardSosRow>[];
    for (final raw in sosList) {
      final m = _jsonMap(raw);
      if (m == null) continue;
      try {
        final row = GuardSosRow.fromJson(m);
        if (row.id.isNotEmpty) activeSos.add(row);
      } catch (_) {
        // Skip malformed SOS rows so the rest of the dashboard still loads.
      }
    }

    return GuardDashboardData(
      guardName: _jsonString(guard?['name']) ?? _jsonString(guard?['fullName']),
      gateName: _jsonString(gate?['name']),
      gateId: _jsonString(gate?['id']),
      todayStats: GuardTodayStats(
        visitors: _jsonInt(stats['visitors']),
        parcels: _jsonInt(stats['parcels']),
        incidents: _jsonInt(stats['incidents']),
        patrols: _jsonInt(stats['patrols']),
      ),
      activeSos: activeSos,
    );
  }
}

/// `GET /guards/my-gate` — current shift gate (404 when no active shift).
class GuardMyGateData {
  const GuardMyGateData({
    required this.gateId,
    required this.name,
    this.location,
    this.shiftStart,
    this.shiftEnd,
  });

  final String gateId;
  final String name;
  final String? location;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;

  factory GuardMyGateData.fromJson(Map<String, dynamic> json) {
    final gateRaw = json['gate'];
    final shiftRaw = json['shift'];
    final gate = gateRaw is Map ? Map<String, dynamic>.from(gateRaw) : <String, dynamic>{};
    final shift = shiftRaw is Map ? Map<String, dynamic>.from(shiftRaw) : null;

    DateTime? parseT(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return DateTime.tryParse(v.toString());
    }

    return GuardMyGateData(
      gateId: gate['id']?.toString() ?? '',
      name: gate['name'] as String? ?? '',
      location: gate['location'] as String?,
      shiftStart: parseT(shift?['startTime']),
      shiftEnd: parseT(shift?['endTime']),
    );
  }
}

class GuardTodayStats {
  GuardTodayStats({
    required this.visitors,
    required this.parcels,
    required this.incidents,
    required this.patrols,
  });

  final int visitors;
  final int parcels;
  final int incidents;
  final int patrols;
}

class GuardSosRow {
  GuardSosRow({
    required this.id,
    required this.status,
    this.residentName,
    this.residentPhone,
    this.villaNumber,
    this.emergencyType,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? residentName;
  final String? residentPhone;
  final String? villaNumber;
  final String? emergencyType;
  final DateTime? createdAt;

  factory GuardSosRow.fromJson(Map<String, dynamic> json) {
    final user = _jsonMap(json['user'] ?? json['resident']);
    final villa = _jsonMap(json['villa']);
    DateTime? parseAt(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      return DateTime.tryParse(v.toString());
    }

    return GuardSosRow(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      residentName: _jsonString(user?['name']),
      residentPhone: _jsonString(user?['phone']),
      villaNumber: _jsonString(villa?['villaNumber']) ??
          _jsonString(villa?['villa_number']),
      emergencyType: _jsonString(json['emergencyType']) ??
          _jsonString(json['emergency_type']),
      createdAt: parseAt(json['createdAt']),
    );
  }
}

/// Visitor row from guard visitor APIs (nested `villaVisits`).
class GuardVisitorRow {
  GuardVisitorRow({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    this.purpose,
    this.checkInTime,
    this.checkOutTime,
    this.villaLabel,
    this.visitorType,
  });

  final String id;
  final String name;
  final String phone;
  final String status;
  final String? purpose;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? villaLabel;
  final String? visitorType;

  bool get awaitingCheckout => checkOutTime == null;

  bool get needsResidentApproval =>
      status.trim().toUpperCase() == 'PENDING_APPROVAL';

  /// Residents approved — guard should confirm physical entry.
  bool get awaitingGuardAdmission =>
      status.trim().toUpperCase() == 'APPROVED';

  bool get entryDenied => status.trim().toUpperCase() == 'REJECTED';

  /// Same inclusion rule as backend `GET /guards/pending-visitors`, plus legacy rows
  /// (empty status) still on-site. Used to align Active tab with home live feed.
  bool get isEligibleForActiveEntriesTab {
    if (checkOutTime != null) return false;
    final s = status.trim().toUpperCase();
    if (s.isEmpty) return true;
    return s == 'PENDING_APPROVAL' ||
        s == 'APPROVED' ||
        s == 'REJECTED' ||
        s == 'CHECKED_IN' ||
        s == 'PENDING';
  }

  factory GuardVisitorRow.fromJson(Map<String, dynamic> json) {
    final vvRaw = json['villaVisits'] ?? json['villa_visits'];
    final List<dynamic>? vv = vvRaw is List
        ? vvRaw
        : vvRaw is Map
            ? [vvRaw]
            : null;
    final nums = <String>[];
    if (vv != null) {
      for (final e in vv) {
        if (e is Map && e['villa'] is Map) {
          final n = (e['villa'] as Map)['villaNumber']?.toString();
          if (n != null && n.isNotEmpty) nums.add(n);
        }
      }
    }

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      return DateTime.tryParse(v.toString());
    }

    return GuardVisitorRow(
      id: json['id']?.toString() ??
          json['visitorId']?.toString() ??
          json['visitor_id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      purpose: json['purpose'] as String?,
      checkInTime: parseDt(json['checkInTime']) ?? parseDt(json['checkInAt']),
      checkOutTime: parseDt(json['checkOutTime']) ?? parseDt(json['checkOutAt']),
      villaLabel: nums.isEmpty ? null : nums.join(', '),
      visitorType: json['visitorType']?.toString(),
    );
  }
}

class VillaPickerItem {
  VillaPickerItem({required this.id, required this.villaNumber, this.block});

  final String id;
  final String villaNumber;
  final String? block;

  factory VillaPickerItem.fromJson(Map<String, dynamic> json) {
    return VillaPickerItem(
      id: json['id']?.toString() ?? '',
      villaNumber: json['villaNumber'] as String? ?? '',
      block: json['block'] as String?,
    );
  }
}

/// Row from `GET /guards/pre-approved-entries` — resident-created expected visitors.
class GuardPreApprovedEntry {
  GuardPreApprovedEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.purpose,
    this.visitorType,
    this.validUntil,
    this.otp,
    this.villaId,
    this.block,
    this.villaNumber,
    this.approvedByName,
  });

  final String id;
  final String name;
  final String phone;
  final String? purpose;
  final String? visitorType;
  final DateTime? validUntil;
  final String? otp;
  /// Set when API includes `villa.id` (resident flat for this pre-approval).
  final String? villaId;
  final String? block;
  final String? villaNumber;
  final String? approvedByName;

  String get flatLabel {
    if (villaNumber == null || villaNumber!.isEmpty) return 'Flat';
    if (block != null && block!.isNotEmpty) {
      return '${block!} · $villaNumber';
    }
    return villaNumber!;
  }

  factory GuardPreApprovedEntry.fromJson(Map<String, dynamic> json) {
    final villa = json['villa'] as Map<String, dynamic>?;
    final by = json['approvedBy'] as Map<String, dynamic>?;
    DateTime? until;
    final vu = json['validUntil'];
    if (vu != null) {
      until = DateTime.tryParse(vu.toString());
    }
    return GuardPreApprovedEntry(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      purpose: json['purpose'] as String?,
      visitorType: json['visitorType']?.toString(),
      validUntil: until,
      otp: json['otp'] as String?,
      villaId: villa?['id']?.toString(),
      block: villa?['block'] as String?,
      villaNumber: villa?['villaNumber'] as String?,
      approvedByName: by?['name'] as String?,
    );
  }
}

/// Guard **Active → Visitors** tab: pending [Visitor] rows + resident pre-approvals not yet admitted.
class GuardActiveVisitorsTabData {
  GuardActiveVisitorsTabData({
    required this.pendingVisitors,
    required this.preApproved,
    this.pendingVisitorsError,
    this.preApprovedError,
  });

  final List<GuardVisitorRow> pendingVisitors;
  final List<GuardPreApprovedEntry> preApproved;

  /// Non-null when the pending-visitors fetch failed (list is empty).
  final Object? pendingVisitorsError;

  /// Non-null when the pre-approved-entries fetch failed.
  final Object? preApprovedError;

  bool get isEmpty => pendingVisitors.isEmpty && preApproved.isEmpty;
}

/// GET /guards/residents-directory
class ResidentDirectoryRow {
  ResidentDirectoryRow({
    required this.userId,
    required this.name,
    this.phone,
    this.phoneMasked,
    required this.flatLabel,
    this.villaId,
  });

  final String userId;
  final String name;
  /// Raw phone when API allows gate dial (guard directory).
  final String? phone;
  final String? phoneMasked;
  final String flatLabel;
  final String? villaId;

  factory ResidentDirectoryRow.fromJson(Map<String, dynamic> json) {
    return ResidentDirectoryRow(
      userId: json['userId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      phoneMasked: json['phoneMasked'] as String?,
      flatLabel: json['flatLabel'] as String? ?? '',
      villaId: json['villaId']?.toString(),
    );
  }
}
