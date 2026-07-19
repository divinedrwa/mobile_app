import 'dart:async';

import 'analytics_catalog.dart';
import 'app_analytics_service.dart';
import 'firebase_analytics_helper.dart';
import 'telemetry_safe.dart';

/// Dual-write business events: custom backend (primary) + Firebase Analytics (mirror).
abstract class BusinessAnalytics {
  BusinessAnalytics._();

  static const preApproveVisitor = AnalyticsCatalog.preApproveVisitor;
  static const complaintSubmit = AnalyticsCatalog.complaintSubmit;
  static const maintenancePayment = AnalyticsCatalog.maintenancePayment;
  static const amenityBooking = AnalyticsCatalog.amenityBooking;
  static const pollVote = AnalyticsCatalog.pollVote;
  static const noticePublish = AnalyticsCatalog.noticePublish;
  static const billingCyclePublish = AnalyticsCatalog.billingCyclePublish;
  static const expenseAdd = AnalyticsCatalog.expenseAdd;
  static const guardQrScan = AnalyticsCatalog.guardQrScan;

  static Future<void> track(
    String action, {
    Map<String, dynamic>? properties,
    bool success = true,
  }) async {
    runTelemetrySafe(
      () => AppAnalyticsService.logAction(
        action,
        properties: {...?properties, 'success': success},
      ),
      label: 'action',
    );
    runTelemetrySafe(
      () => FirebaseAnalyticsHelper.logBusinessAction(
        action: action,
        success: success,
        properties: properties,
      ),
      label: 'firebaseAction',
    );
  }

  static Future<void> trackError(
    String name, {
    Map<String, dynamic>? properties,
  }) async {
    runTelemetrySafe(
      () => AppAnalyticsService.logError(name, properties: properties),
      label: 'error',
    );
    runTelemetrySafe(
      () => FirebaseAnalyticsHelper.logCustomEvent(
        name: 'app_error',
        parameters: {
          'error_name': name,
          if (properties != null)
            ...properties.map(
              (k, v) => MapEntry(k, v is num || v is String ? v : v.toString()),
            ),
        },
      ),
      label: 'firebaseError',
    );
  }
}
