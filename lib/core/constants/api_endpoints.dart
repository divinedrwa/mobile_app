/// API Endpoints for all features
///
/// Base URL for HTTP client: use [AppConstants.baseUrl] (not this placeholder).
class ApiEndpoints {
  /// Dev default when reading this file only; live requests use [AppConstants.baseUrl].
  static const String baseUrl = 'https://gatepass-v037.onrender.com/api';
  
  // Authentication
  static const String login = '/auth/login';
  /// Public societies for login picker (`GET`).
  static const String publicSocieties = '/public/societies';
  /// Public: complete onboarding with admin-issued invitation token (`POST`).
  static const String registerWithInvitation = '/auth/register-with-invitation';
  static const String logout = '/auth/logout';

  /// Register or refresh FCM token (authenticated). Keeps token in sync after refresh.
  static const String notificationsRegisterDevice = '/notifications/devices';
  static const String notificationsRemoveDevice = '/notifications/devices/remove';
  /// Backend: GET/PATCH/PUT/DELETE `/residents/me` — profile & soft-deactivate (DELETE).
  static const String profile = '/residents/me';

  /// Authenticated resident: `PATCH` body `{ currentPassword, newPassword }`.
  static const String changePassword = '/residents/change-password';
  
  // Resident - Dashboard
  static const String dashboard = '/residents/dashboard';
  static const String banners = '/banners/active/list';
  static const String vendors = '/vendors';
  
  // Resident - Maintenance
  static const String myMaintenance = '/residents/my-maintenance';
  static const String maintenanceHistory = '/residents/my-maintenance';
  static const String paymentHistory = '/residents/my-maintenance';
  static const String outstandingDues = '/residents/outstanding-dues';
  static const String sendVillaReminder = '/maintenance-management/send-villa-reminder';

  /// SaaS billing cycle (UTC windows; status from server): `GET /v1/cycles/current?societyId=&billingCycleId=`
  static String billingCyclesCurrent({
    required String societyId,
    String? billingCycleId,
  }) {
    final q = <String, String>{
      'societyId': societyId,
      if (billingCycleId != null && billingCycleId.isNotEmpty)
        'billingCycleId': billingCycleId,
    };
    return '/v1/cycles/current?${Uri(queryParameters: q).query}';
  }

  /// `POST /v1/payments/create-order`
  static const String billingCreateOrder = '/v1/payments/create-order';

  /// Financial years for billing (`GET /v1/financial-years`) — admin + resident.
  static const String billingFinancialYears = '/v1/financial-years';

  /// Billing cycles in a financial year (`GET /v1/billing-cycles?financialYearId=`).
  static const String billingCyclesForYear = '/v1/billing-cycles';

  /// Resolve cycle → financial year (`GET /v1/billing-cycles/context?billingCycleId=`).
  static const String billingCycleContext = '/v1/billing-cycles/context';
  
  // Resident - Complaints
  static const String myComplaints = '/residents/my-complaints';
  static const String createComplaint = '/residents/complaints';
  static String complaintById(String id) => '/residents/complaints/$id';
  
  // Resident - Visitors
  static const String myVisitors = '/residents/my-visitors';
  /// Guard walk-in requests pending resident approve/reject.
  static const String visitorApprovalRequests = '/residents/visitor-approval-requests';
  static String visitorApprovalRequestDetail(String id) =>
      '/residents/visitor-approval-requests/$id';
  static String visitorApprovalApprove(String id) =>
      '/residents/visitor-approval-requests/$id/approve';
  static String visitorApprovalReject(String id) =>
      '/residents/visitor-approval-requests/$id/reject';
  /// GET list — backend: `GET /residents/my-pre-approved-visitors` (alias `/my-pre-approved`).
  /// Optional query: `limit` (1–500, default 200). Scoped to authenticated resident’s villa via JWT.
  static const String preApprovedVisitors = '/residents/my-pre-approved-visitors';
  /// POST body: `name`, `phone` (≥10 digits), optional `purpose`, optional `validUntil` (ISO-8601, future),
  /// optional `visitorType` enum. Villa comes from JWT — do not send `villaId` / resident id in body.
  static const String preApproveVisitor = '/residents/pre-approve-visitor';
  /// DELETE — backend: DELETE /residents/pre-approved/:id
  static String preApprovedById(String id) => '/residents/pre-approved/$id';
  
  // Resident - Parcels
  static const String myParcels = '/residents/my-parcels';
  static String parcelById(String id) => '/residents/my-parcels/$id';
  
  // Resident - Amenities
  static const String amenities = '/residents/my-amenities';
  static const String myBookings = '/residents/my-bookings';
  static const String createBooking = '/residents/my-bookings';
  static String cancelBooking(String id) => '/residents/my-bookings/$id';
  
  // Resident - SOS
  /// List SOS history for the signed-in resident.
  static const String sosAlerts = '/residents/my-sos';
  /// Current open SOS for the resident (`GET`).
  static const String sosActive = '/residents/sos/active';
  /// Create SOS — backend module is mounted at `/sos-alerts`.
  static const String createSOS = '/sos-alerts';
  static String sosById(String id) => '/residents/my-sos/$id';
  static String sosCancel(String id) => '/sos-alerts/$id/cancel';
  static String sosAlertStart(String id) => '/sos-alerts/$id/start';
  
  // Resident - Notices
  static const String notices = '/residents/my-notices';
  
  // Resident - Profile & Family
  static const String residentSecurityContacts = '/residents/security-contacts';
  static const String familyMembers = '/residents/my-family';
  static const String addFamilyMember = '/residents/add-family-member';
  static String updateFamilyMember(String id) => '/residents/family/$id';
  static String deleteFamilyMember(String id) => '/residents/family/$id';
  
  static const String emergencyContacts = '/residents/emergency-contacts';
  static String updateEmergencyContact(String id) => '/residents/emergency-contacts/$id';
  static String deleteEmergencyContact(String id) => '/residents/emergency-contacts/$id';
  
  static const String vehicles = '/residents/my-vehicles';
  static String updateVehicle(String id) => '/residents/vehicles/$id';
  static String deleteVehicle(String id) => '/residents/vehicles/$id';
  
  // Resident - Documents
  static const String documents = '/residents/my-documents';
  
  // Resident - Polls
  static const String polls = '/residents/my-polls';
  static String votePoll(String pollId, String optionId) => 
      '/residents/my-polls/$pollId/vote/$optionId';
  
  // Guard — backend mounts under `/api/guards` (+ `/api/water-supply/toggle`, `/api/garbage-collection/entry`).
  // Date-range APIs (`my-visitors`, `my-parcels`, `gate-vehicle/today`): omit `from`/`to` for "today",
  // or send **both** `from` and `to` as `YYYY-MM-DD` (see backend `resolveGuardLogRange`).
  static const String guardDashboard = '/guards/my-dashboard';
  static const String guardMyGate = '/guards/my-gate';
  static const String guardMyShifts = '/guards/my-shifts';
  static const String guardActiveAlerts = '/guards/active-alerts';
  static const String guardSosResponse = '/guards/sos-response';

  static const String guardVisitorCheckIn = '/guards/visitor-checkin';
  /// After residents approve (status APPROVED), guard confirms guest entered.
  static const String guardVisitorConfirmEntry = '/guards/visitor-confirm-entry';
  static const String guardVisitorCheckOut = '/guards/visitor-checkout';
  static const String guardMyVisitors = '/guards/my-visitors';
  static const String guardPendingVisitors = '/guards/pending-visitors';
  static const String guardVerifyPreApproved = '/guards/verify-pre-approved';

  static const String guardParcelReceived = '/guards/parcel-received';
  static const String guardParcelsPending = '/guards/parcels-pending';
  static String guardParcelDelivered(String id) => '/guards/parcels/$id/delivered';
  static const String guardMyParcels = '/guards/my-parcels';

  static const String guardStartPatrol = '/guards/start-patrol';
  static const String guardPatrolCheckpoint = '/guards/patrol-checkpoint';
  static const String guardMyPatrols = '/guards/my-patrols';
  static const String guardPatrolsToday = '/guards/patrols-today';
  static const String guardCreateIncident = '/guards/create-incident';
  static const String guardChecklist = '/guards/checklist';

  /// Gate vehicle ledger (see [GateVehicleLedger] in Prisma).
  static const String guardGateVehicleEntry = '/guards/gate-vehicle/entry';
  static String guardGateVehicleExit(String id) => '/guards/gate-vehicle/$id/exit';
  static const String guardGateVehicleToday = '/guards/gate-vehicle/today';

  static const String guardSocBroadcast = '/guards/soc-broadcast';
  static const String guardResidentsDirectory = '/guards/residents-directory';

  /// Validated incident — prefer over legacy [guardCreateIncident] when possible.
  static const String guardIncidents = '/guards/incidents';

  static const String guardVisitorOtpVerify = '/guards/visitor-otp-verify';
  static const String guardVisitorApproveEntry = '/guards/visitor-approve-entry';
  static const String guardVisitorEntryNotify = '/guards/visitor-entry-notify';
  /// Society-wide pre-approvals not yet admitted (`GET`); one-tap admit (`POST`).
  static const String guardPreApprovedEntries = '/guards/pre-approved-entries';
  static const String guardPreApprovedAdmit = '/guards/pre-approved-admit';

  /// Society villas for visitor check-in (same as admin list; guard JWT allowed).
  static const String societyVillas = '/villas';

  /// Guard / admin — notify residents (`POST` body: gateId, turnedOn, reason?).
  static const String waterSupplyToggle = '/water-supply/toggle';
  /// Guard / admin — log collector entry (`POST` body: gateId, notes?).
  static const String garbageCollectionEntry = '/garbage-collection/entry';
}
