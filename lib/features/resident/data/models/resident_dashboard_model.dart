/// Response from `GET /residents/dashboard`.
class ResidentDashboardStats {
  const ResidentDashboardStats({
    required this.pendingMaintenance,
    required this.activeComplaints,
    required this.pendingParcels,
    required this.upcomingBookings,
  });

  final int pendingMaintenance;
  final int activeComplaints;
  final int pendingParcels;
  final int upcomingBookings;

  factory ResidentDashboardStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ResidentDashboardStats(
        pendingMaintenance: 0,
        activeComplaints: 0,
        pendingParcels: 0,
        upcomingBookings: 0,
      );
    }
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    // Backend may send total as `totalComplaints` or legacy `activeComplaints`
    final complaintTotal = json['totalComplaints'] ?? json['activeComplaints'];
    return ResidentDashboardStats(
      pendingMaintenance: n(json['pendingMaintenance']),
      activeComplaints: n(complaintTotal),
      pendingParcels: n(json['pendingParcels']),
      upcomingBookings: n(json['upcomingBookings']),
    );
  }
}

class ResidentDashboardModel {
  const ResidentDashboardModel({required this.stats, required this.fund});

  final ResidentDashboardStats stats;
  final ResidentFundSnapshot fund;

  factory ResidentDashboardModel.fromJson(Map<String, dynamic> json) {
    final statsRaw = json['stats'];
    final fundRaw = json['fund'];
    return ResidentDashboardModel(
      stats: ResidentDashboardStats.fromJson(
        statsRaw is Map<String, dynamic> ? statsRaw : null,
      ),
      fund: ResidentFundSnapshot.fromJson(
        fundRaw is Map<String, dynamic> ? fundRaw : null,
      ),
    );
  }
}

class ResidentFundSnapshot {
  const ResidentFundSnapshot({
    required this.currentBalance,
    required this.allTimeCollected,
    required this.allTimeSpent,
    required this.month,
    required this.year,
    required this.monthCollected,
    required this.monthSpent,
    required this.monthNet,
    required this.additionalMergedInflowMonth,
    required this.additionalMergedInflowAllTime,
  });

  final double currentBalance;
  final double allTimeCollected;
  final double allTimeSpent;
  final int month;
  final int year;
  final double monthCollected;
  final double monthSpent;
  final double monthNet;
  final double additionalMergedInflowMonth;
  final double additionalMergedInflowAllTime;

  factory ResidentFundSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ResidentFundSnapshot(
        currentBalance: 0,
        allTimeCollected: 0,
        allTimeSpent: 0,
        month: 0,
        year: 0,
        monthCollected: 0,
        monthSpent: 0,
        monthNet: 0,
        additionalMergedInflowMonth: 0,
        additionalMergedInflowAllTime: 0,
      );
    }
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    int i(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return ResidentFundSnapshot(
      currentBalance: d(json['currentBalance']),
      allTimeCollected: d(json['allTimeCollected']),
      allTimeSpent: d(json['allTimeSpent']),
      month: i(json['month']),
      year: i(json['year']),
      monthCollected: d(json['monthCollected']),
      monthSpent: d(json['monthSpent']),
      monthNet: d(json['monthNet']),
      additionalMergedInflowMonth: d(json['additionalMergedInflowMonth']),
      additionalMergedInflowAllTime: d(json['additionalMergedInflowAllTime']),
    );
  }
}
