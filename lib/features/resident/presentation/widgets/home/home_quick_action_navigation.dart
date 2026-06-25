import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/quick_action_model.dart';
import '../../pages/amenities_screen.dart';
import '../../pages/amenity_booking_history_screen.dart';
import '../../pages/complaint_screen.dart';
import '../../pages/parcel_management_screen.dart';
import '../../pages/sos_screen.dart';
import '../../pages/vendors_staff_screen.dart';
import '../../providers/resident_tab_provider.dart';

/// Shared navigation for home quick-action tiles (hero row + icon grid + sheets).
abstract final class HomeQuickActionNavigation {
  static void open(
    BuildContext context,
    WidgetRef ref,
    QuickAction action,
  ) {
    switch (action.id) {
      case 'parcels':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ParcelManagementScreen(),
          ),
        );
        return;
      case 'visitor_history':
        // Legacy tile: go to hub or history depending on configured route.
        context.push(
          action.route.isNotEmpty ? action.route : '/resident/visitor-history',
        );
        return;
      case 'visitor_entry':
      case 'gatepass':
        context.push(
          action.route.isNotEmpty ? action.route : '/resident/visitor-hub',
        );
        return;
      case 'amenity_bookings':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AmenityBookingHistoryScreen(),
          ),
        );
        return;
      case 'maintenance_expenses':
        context.push('/resident/maintenance-payment');
        return;
      case 'community':
        openCommunityTab(ref);
        return;
      case 'sos':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SOSScreen()),
        );
        return;
      case 'amenities':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AmenitiesScreen(),
          ),
        );
        return;
      case 'complaint':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ComplaintScreen(),
          ),
        );
        return;
      case 'daily_help':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const VendorsStaffScreen(),
          ),
        );
        return;
      case 'more':
        showOverflowSheet(context, ref);
        return;
      default:
        if (action.route.isNotEmpty) {
          context.push(action.route);
        }
        return;
    }
  }

  static void showOverflowSheet(BuildContext context, WidgetRef ref) {
    _showSheet(
      context,
      ref,
      residentQuickActionsMoreSheet(),
      title: 'More shortcuts',
    );
  }

  static void showViewAllSheet(BuildContext context, WidgetRef ref) {
    final actions = residentQuickActionsOffHomeSection()
        .where((a) => a.id != 'maintenance_expenses')
        .toList();
    _showSheet(context, ref, actions, title: 'All quick actions');
  }

  static void _showSheet(
    BuildContext context,
    WidgetRef ref,
    List<QuickAction> actions, {
    required String title,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: DesignColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (actions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No shortcuts right now.',
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: actions.map((action) {
                      return SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 60) / 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            open(context, ref, action);
                          },
                          icon: Icon(action.icon, color: action.color, size: 18),
                          label: Text(
                            action.label,
                            style: const TextStyle(
                              color: DesignColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            side: const BorderSide(
                              color: DesignColors.borderLight,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
