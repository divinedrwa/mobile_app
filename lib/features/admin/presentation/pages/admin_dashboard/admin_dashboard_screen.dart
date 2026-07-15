import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/action_colors.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/screen_skeletons.dart';
import '../../../../../core/widgets/animated_counter.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../resident/data/models/notification_model.dart';
import '../../../../resident/data/providers/dashboard_provider.dart';
import '../../../../resident/data/providers/notification_provider.dart';
import '../../../../resident/presentation/pages/notifications_center_screen.dart';
import '../../../../resident/presentation/widgets/home/home_society_finances.dart';
import '../../../../resident/data/providers/maintenance_provider.dart';
import '../../../data/models/admin_dashboard_model.dart';
import '../../../data/providers/admin_providers.dart';
import '../../widgets/admin_dashboard_quick_actions.dart';
import '../../widgets/admin_dashboard_tokens.dart';

// ═════════════════════════════════════════════════════════════════════

part 'parts/admin_dashboard_hero.part.dart';
part 'parts/admin_dashboard_sections.part.dart';
part 'parts/admin_dashboard_activity.part.dart';
part 'parts/admin_dashboard_loading.part.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Future<void> _handleRefresh() async {
    invalidateAdminHomeFinanceProviders(ref);
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminOutstandingDuesProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(adminUpiStatsProvider);
    ref.invalidate(adminBillingCyclesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardProvider);
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: DesignColors.primary,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(context, user?.name, user?.societyName, unread),
              Padding(
                padding: const EdgeInsets.fromLTRB(kAdminDashPadH, 14, kAdminDashPadH, 100),
                child: Builder(builder: (context) {
                  final data = dashboardAsync.valueOrNull;
                  final isInitialLoad = dashboardAsync.isLoading && data == null;
                  final hasError = dashboardAsync.hasError && data == null;
                  if (isInitialLoad) return _skeleton();
                  if (hasError) return _error();
                  if (data != null) return _body(context, data);
                  return _skeleton();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
