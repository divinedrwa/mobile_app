import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/action_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import 'admin_dashboard_tokens.dart';

/// B3 — Quick-action grids extracted from [AdminDashboardScreen].
class AdminDashboardQuickActions extends StatelessWidget {
  const AdminDashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          context,
          title: 'Operations',
          subtitle: 'Day-to-day management',
          items: [
            AdminQuickAction(Icons.account_balance_wallet, 'Maintenance Actions',
                ActionColors.brand, '/resident/admin-maintenance-actions'),
            AdminQuickAction(Icons.calendar_month_outlined, 'Billing Cycles',
                ActionColors.success, '/resident/admin-billing-cycles'),
            AdminQuickAction(Icons.payment_outlined, 'Payment Methods', ActionColors.info,
                '/resident/admin-payment-methods'),
            AdminQuickAction(Icons.report_problem_outlined, 'Complaints', ActionColors.danger,
                '/resident/admin-complaints'),
            AdminQuickAction(Icons.notifications_active_outlined, 'Reminders',
                ActionColors.warning, '/resident/admin-reminders'),
            AdminQuickAction(Icons.account_balance_wallet_outlined, 'Expenses',
                ActionColors.brand, '/resident/admin-expenses'),
            AdminQuickAction(Icons.campaign_outlined, 'Notices', ActionColors.info,
                '/resident/admin-notices'),
            AdminQuickAction(Icons.inventory_2_outlined, 'Parcels', ActionColors.secondary,
                '/resident/admin-parcels'),
            AdminQuickAction(Icons.currency_rupee_rounded, 'UPI Verifications',
                ActionColors.accent, '/resident/admin-upi-verifications'),
            AdminQuickAction(Icons.construction_rounded, 'Special Projects',
                ActionColors.brand, '/resident/admin-special-projects'),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          context,
          title: 'People & Property',
          subtitle: 'Users, units, and configuration',
          items: [
            AdminQuickAction(Icons.people_outlined, 'Residents', ActionColors.brand,
                '/resident/admin-residents'),
            AdminQuickAction(Icons.home_work_outlined, 'Properties', ActionColors.secondary,
                '/resident/admin-villas'),
            AdminQuickAction(Icons.person_add_outlined, 'Invite Users', ActionColors.accent,
                '/resident/admin-invitations'),
            AdminQuickAction(Icons.badge_outlined, 'Staff', ActionColors.success,
                '/resident/admin-staff'),
            AdminQuickAction(Icons.manage_accounts_outlined, 'Users & Roles', ActionColors.info,
                '/resident/admin-roles'),
            AdminQuickAction(Icons.groups_outlined, 'Visitors', ActionColors.accent,
                '/resident/admin-visitors'),
            AdminQuickAction(Icons.schedule_rounded, 'Guard Shifts', ActionColors.secondary,
                '/resident/admin-guard-shifts'),
            AdminQuickAction(Icons.shield_rounded, 'Patrols', ActionColors.brand,
                '/resident/admin-patrols'),
            AdminQuickAction(Icons.report_outlined, 'Incidents', ActionColors.danger,
                '/resident/admin-incidents'),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          context,
          title: 'Insights & Analytics',
          subtitle: 'Reports and data views',
          items: [
            AdminQuickAction(Icons.analytics_outlined, 'Gate Analytics', ActionColors.info,
                '/resident/admin-gate-analytics'),
            AdminQuickAction(Icons.bar_chart_rounded, 'Complaint Analytics',
                ActionColors.danger, '/resident/admin-complaint-analytics'),
            AdminQuickAction(Icons.account_balance_outlined, 'Reconciliation',
                ActionColors.success, '/resident/admin-reconciliation'),
            AdminQuickAction(Icons.local_parking, 'Parking', ActionColors.secondary,
                '/resident/admin-parking'),
            AdminQuickAction(Icons.water_outlined, 'Water Analytics', ActionColors.info,
                '/resident/admin-water-analytics'),
            AdminQuickAction(Icons.upload_file_outlined, 'Data Tools', ActionColors.neutral,
                '/resident/admin-data-tools'),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          context,
          title: 'More Tools',
          subtitle: 'Additional utilities',
          items: [
            AdminQuickAction(Icons.water_drop_outlined, 'Gate Utilities', ActionColors.success,
                '/resident/admin-gate-utilities'),
            AdminQuickAction(Icons.directions_car_outlined, 'Register Vehicle',
                ActionColors.secondary, '/resident/admin-add-vehicle'),
            AdminQuickAction(Icons.notifications_active, 'Push Notify', ActionColors.warning,
                '/resident/admin-push-notifications'),
            AdminQuickAction(Icons.folder_open_outlined, 'Documents', ActionColors.info,
                '/resident/admin-documents'),
            AdminQuickAction(Icons.view_carousel_outlined, 'Banners', ActionColors.brand,
                '/resident/admin-banners'),
            AdminQuickAction(Icons.sos_rounded, 'SOS Alerts', ActionColors.danger,
                '/resident/admin-sos'),
            AdminQuickAction(Icons.how_to_vote_outlined, 'Polls', ActionColors.brand,
                '/resident/admin-polls'),
            AdminQuickAction(Icons.fitness_center_outlined, 'Amenities', ActionColors.warning,
                '/resident/admin-amenities'),
            AdminQuickAction(Icons.account_balance_wallet_outlined, 'Bank Accounts',
                ActionColors.info, '/resident/admin-bank-accounts'),
            AdminQuickAction(Icons.settings_outlined, 'Settings', ActionColors.neutral,
                '/resident/admin-settings'),
          ],
        ),
      ],
    );
  }

  Widget _section(
    BuildContext ctx, {
    required String title,
    required String subtitle,
    required List<AdminQuickAction> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: DesignColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.25,
          children: items.map((a) => _tile(ctx, a)).toList(),
        ),
      ],
    );
  }

  Widget _tile(BuildContext ctx, AdminQuickAction a) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(kAdminDashRadiusMd),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: adminDashCardShadow(0.04),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kAdminDashRadiusMd),
          onTap: () {
            HapticFeedback.lightImpact();
            ctx.push(a.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: a.color.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(a.icon, color: a.color, size: 19),
                ),
                const SizedBox(height: 5),
                Text(
                  a.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                    height: 1.15,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
