import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/quick_action_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../pages/amenities_screen.dart';
import '../../pages/amenity_booking_history_screen.dart';
import '../../pages/complaint_screen.dart';
import '../../pages/parcel_management_screen.dart';
import '../../pages/sos_screen.dart';
import '../../pages/vendors_staff_screen.dart';
import '../../pages/visitor_history_screen.dart';
import '../../providers/resident_tab_provider.dart';

class HomeQuickActions extends ConsumerWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuickActionsHeader(context, ref),
        const SizedBox(height: 10),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: 80,
          ),
          itemCount: residentHomeQuickActionsGrid.length + 1,
          itemBuilder: (context, index) {
            if (index == residentHomeQuickActionsGrid.length) {
              return _quickActionTile(context, ref, moreQuickAction);
            }
            return _quickActionTile(
                context, ref, residentHomeQuickActionsGrid[index]);
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionsHeader(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.text.primary,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Most used features at your fingertips',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.text.secondary,
                  ),
            ),
          ],
        ),
        InkWell(
          onTap: () => _showAllQuickActionsSheet(context, ref),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: DesignColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: DesignColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickActionTile(
      BuildContext context, WidgetRef ref, QuickAction action) {
    return Container(
      decoration: DesignComponents.cardDecoration(
        color: context.surface.defaultSurface,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DesignRadius.borderLG,
          onTap: () {
            DesignHaptics.selection();
            _openQuickAction(context, ref, action);
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(action.icon, color: action.color, size: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.text.primary,
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

  void _openQuickAction(
      BuildContext context, WidgetRef ref, QuickAction action) {
    switch (action.id) {
      case 'parcels':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const ParcelManagementScreen()),
        );
        return;
      case 'visitor_history':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const VisitorHistoryScreen()),
        );
        return;
      case 'amenity_bookings':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) =>
                  const AmenityBookingHistoryScreen()),
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
          MaterialPageRoute<void>(
              builder: (_) => const SOSScreen()),
        );
        return;
      case 'amenities':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const AmenitiesScreen()),
        );
        return;
      case 'complaint':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const ComplaintScreen()),
        );
        return;
      case 'daily_help':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const VendorsStaffScreen()),
        );
        return;
      case 'more':
        _showAllQuickActionsSheet(context, ref);
        return;
      default:
        if (action.route.isNotEmpty) {
          context.push(action.route);
        }
        return;
    }
  }

  void _showAllQuickActionsSheet(BuildContext context, WidgetRef ref) {
    final userExcluded =
        ref.read(authProvider).user?.isBillingExcluded ?? false;
    final cycleExcluded =
        ref.read(residentBillingCycleProvider).maybeWhen(
              data: (c) => c.maintenanceBillingExcluded,
              orElse: () => false,
            );
    final excluded = userExcluded || cycleExcluded;
    final viewAllActions = excluded
        ? residentQuickActionsViewAll
            .where((a) => a.id != 'maintenance_expenses')
            .toList()
        : residentQuickActionsViewAll;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
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
                const Text(
                  'Additional shortcuts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'These are not on your home quick row',
                  style: TextStyle(
                      fontSize: 13,
                      color: DesignColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (viewAllActions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No extra shortcuts right now.',
                      style: TextStyle(
                          fontSize: 14,
                          color: DesignColors.textSecondary),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: viewAllActions.map((action) {
                      return SizedBox(
                        width:
                            (MediaQuery.of(ctx).size.width - 60) / 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openQuickAction(context, ref, action);
                          },
                          icon: Icon(action.icon,
                              color: action.color, size: 18),
                          label: Text(
                            action.label,
                            style: const TextStyle(
                              color: DesignColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            side: const BorderSide(
                                color: DesignColors.borderLight),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
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
