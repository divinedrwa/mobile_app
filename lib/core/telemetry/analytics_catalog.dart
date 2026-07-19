/// Unified analytics catalog — mirrors backend `analyticsCatalog.ts`.
/// Every id is dual-written to custom backend + Firebase Analytics.
abstract class AnalyticsCatalog {
  AnalyticsCatalog._();

  static const preApproveVisitor = 'resident_pre_approve_visitor';
  static const complaintSubmit = 'resident_complaint_submit';
  static const maintenancePayment = 'resident_maintenance_payment';
  static const amenityBooking = 'resident_amenity_booking';
  static const pollVote = 'resident_poll_vote';
  static const noticePublish = 'admin_notice_publish';
  static const billingCyclePublish = 'admin_billing_cycle_publish';
  static const expenseAdd = 'admin_expense_add';
  static const guardQrScan = 'guard_qr_scan';

  static const allActionIds = [
    preApproveVisitor,
    complaintSubmit,
    maintenancePayment,
    amenityBooking,
    pollVote,
    noticePublish,
    billingCyclePublish,
    expenseAdd,
    guardQrScan,
  ];
}
