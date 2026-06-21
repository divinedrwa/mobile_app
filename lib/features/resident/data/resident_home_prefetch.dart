import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/content_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/utilities_provider.dart';
import '../presentation/providers/visitor_provider.dart';

/// Starts resident home API fetches in parallel (non-blocking).
void prefetchResidentHomeData(WidgetRef ref) {
  final user = ref.read(authProvider).user;
  if (user == null || user.role == UserRole.guard) return;

  // Warm critical home providers — each resolves independently.
  ref.read(residentDashboardProvider.future);
  ref.read(noticesProvider.future);
  ref.read(pendingMaintenanceProvider.future);
  ref.read(residentBillingCycleProvider.future);
  ref.read(activeBannersProvider.future);
  ref.read(waterSupplyStatusProvider.future);
  ref.read(garbageCollectionActiveProvider.future);
  ref.read(visitorApprovalRequestsProvider('pending').future);
  ref.read(notificationProvider);
}

/// Prefetch community sub-tabs when the user opens Community (lazy tabs still benefit).
void prefetchCommunityTabData(WidgetRef ref, {int activeTab = 0}) {
  ref.read(noticesProvider.future);
  if (activeTab == 1 || activeTab == 0) {
    ref.read(pollsProvider.future);
  }
  if (activeTab == 2 || activeTab == 1) {
    ref.read(eventsProvider.future);
  }
  if (activeTab == 3 || activeTab == 2) {
    ref.read(documentsProvider.future);
  }
}
