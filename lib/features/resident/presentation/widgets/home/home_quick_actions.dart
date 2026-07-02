import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/quick_action_model.dart';
import '../../pages/amenities_screen.dart';
import '../../pages/amenity_booking_history_screen.dart';
import '../../pages/complaint_screen.dart';
import '../../pages/parcel_management_screen.dart';
import '../../pages/sos_screen.dart';
import '../../pages/vendors_staff_screen.dart';
import '../../pages/visitor_history_screen.dart';
import '../../providers/resident_tab_provider.dart';
import 'home_hero_quick_actions.dart';
import 'home_shared.dart';

class HomeQuickActions extends ConsumerStatefulWidget {
  const HomeQuickActions({super.key, this.showHeroRow = true});

  final bool showHeroRow;

  @override
  ConsumerState<HomeQuickActions> createState() => _HomeQuickActionsState();
}

class _HomeQuickActionsState extends ConsumerState<HomeQuickActions> {
  bool _moreExpanded = false;

  void _toggleMoreRow() {
    DesignHaptics.selection();
    setState(() => _moreExpanded = !_moreExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final row1 = residentHomeIconRowBelowHero;
    final row2 = residentHomeIconRowExpand;
    assert(row1.length == kHomeQuickActionsRow1Count);
    assert(row2.length == kHomeQuickActionsRow2Count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuickActionsHeader(context),
        if (widget.showHeroRow) ...[
          const SizedBox(height: 10),
          const HomeQuickActionsHeroRow(),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < row1.length; i++) ...[
              if (i > 0) SizedBox(width: kHomeQuickActionRowGap),
              Expanded(
                child: HomeQuickActionIconTile(
                  action: row1[i],
                  onTap: () {
                    DesignHaptics.selection();
                    _openQuickAction(context, ref, row1[i]);
                  },
                ),
              ),
            ],
            const SizedBox(width: kHomeQuickActionRowGap),
            Expanded(
              child: HomeMoreExpandTile(
                expanded: _moreExpanded,
                onTap: _toggleMoreRow,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _moreExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < row2.length; i++) ...[
                        if (i > 0) SizedBox(width: kHomeQuickActionRowGap),
                        Expanded(
                          child: HomeQuickActionIconTile(
                            action: row2[i],
                            onTap: () {
                              DesignHaptics.selection();
                              _openQuickAction(context, ref, row2[i]);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildQuickActionsHeader(BuildContext context) {
    return Column(
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
      default:
        if (action.route.isNotEmpty) {
          context.push(action.route);
        }
        return;
    }
  }
}
