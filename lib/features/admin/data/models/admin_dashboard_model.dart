/// Aggregated stats shown on the admin dashboard tab.
class AdminDashboardModel {
  const AdminDashboardModel({
    required this.todayVisitors,
    required this.pendingParcels,
    required this.openComplaints,
    required this.totalExpected,
    required this.totalCollected,
    required this.collectionRate,
    required this.paidCount,
    required this.unpaidCount,
  });

  final int todayVisitors;
  final int pendingParcels;
  final int openComplaints;
  final double totalExpected;
  final double totalCollected;
  final double collectionRate;
  final int paidCount;
  final int unpaidCount;
}
