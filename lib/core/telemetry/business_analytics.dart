import 'dart:async';

import 'app_analytics_service.dart';
import 'firebase_analytics_helper.dart';

/// Named business events for admin adoption / growth analytics.
/// Each action is stored as `ACTION` on the backend and mirrored to Firebase.
abstract class BusinessAnalytics {
  BusinessAnalytics._();

  static const preApproveVisitor = 'resident_pre_approve_visitor';
  static const complaintSubmit = 'resident_complaint_submit';
  static const maintenancePayment = 'resident_maintenance_payment';
  static const amenityBooking = 'resident_amenity_booking';
  static const pollVote = 'resident_poll_vote';
  static const noticePublish = 'admin_notice_publish';
  static const billingCyclePublish = 'admin_billing_cycle_publish';
  static const expenseAdd = 'admin_expense_add';
  static const guardQrScan = 'guard_qr_scan';

  static Future<void> track(
    String action, {
    Map<String, dynamic>? properties,
    bool success = true,
  }) async {
    unawaited(
      AppAnalyticsService.logAction(
        action,
        properties: {...?properties, 'success': success},
      ),
    );
    unawaited(
      FirebaseAnalyticsHelper.logBusinessAction(
        action: action,
        success: success,
        properties: properties,
      ),
    );
  }

  static Future<void> trackError(
    String name, {
    Map<String, dynamic>? properties,
  }) async {
    unawaited(AppAnalyticsService.logError(name, properties: properties));
    unawaited(
      FirebaseAnalyticsHelper.logCustomEvent(
        name: 'app_error',
        parameters: {
          'error_name': name,
          if (properties != null)
            ...properties.map(
              (k, v) => MapEntry(k, v is num || v is String ? v : v.toString()),
            ),
        },
      ),
    );
  }
}
