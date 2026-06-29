import 'package:flutter/material.dart';

import '../../../../core/theme/action_colors.dart';
import '../../../../core/theme/design_tokens.dart';

/// Model for quick action cards on home screen
class QuickAction {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const QuickAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

// —— Home layout: hero (3) + row 1 (4 + More = 5 slots) + row 2 (5). ——

const int kHomeQuickActionsRow1Count = 4;
const int kHomeQuickActionsRow2Count = 5;

/// Row 1 under hero — exactly 4 shortcuts; More is the 5th slot in the UI.
List<QuickAction> get residentHomeIconRowBelowHero {
  final items = residentHomeSecondaryActionsGrid
      .where((a) => a.id != 'more')
      .toList(growable: false);
  assert(items.length >= kHomeQuickActionsRow1Count);
  return items.sublist(0, kHomeQuickActionsRow1Count);
}

/// Row 2 when More is expanded — exactly 5 shortcuts.
List<QuickAction> get residentHomeIconRowExpand {
  final notices = residentHomeSecondaryActionsGrid
      .firstWhere((a) => a.id == 'community');
  final row = [
    notices,
    ...residentHomeHeroOverflowActions,
    ...residentQuickActionsOverflow,
  ];
  assert(row.length == kHomeQuickActionsRow2Count);
  return row;
}

// —— Full catalog (legacy grid reference). ——

List<QuickAction> get residentHomeQuickActionsGrid => [
      QuickAction(
        id: 'visitor_history',
        label: 'Visitor entry',
        icon: Icons.person_add_alt_1_rounded,
        color: ActionColors.brand,
        route: '/resident/pre-approve-visitor',
      ),
      QuickAction(
        id: 'complaint',
        label: 'Complaint',
        icon: Icons.report_problem_outlined,
        color: ActionColors.warning,
        route: '/resident/complaint',
      ),
      QuickAction(
        id: 'daily_help',
        label: 'Vendors',
        icon: Icons.cleaning_services,
        color: ActionColors.brand,
        route: '/resident/daily-help',
      ),
      QuickAction(
        id: 'amenities',
        label: 'Amenity booking',
        icon: Icons.pool,
        color: ActionColors.success,
        route: '/resident/amenities',
      ),
      QuickAction(
        id: 'sos',
        label: 'SOS',
        icon: Icons.emergency,
        color: ActionColors.danger,
        route: '/resident/sos',
      ),
      QuickAction(
        id: 'parcels',
        label: 'Parcel',
        icon: Icons.inventory_2_outlined,
        color: ActionColors.secondary,
        route: '/resident/parcels',
      ),
      QuickAction(
        id: 'amenity_bookings',
        label: 'Facility booking',
        icon: Icons.event_note_outlined,
        color: ActionColors.info,
        route: '/resident/amenity-bookings',
      ),
      QuickAction(
        id: 'community',
        label: 'Society notices',
        icon: Icons.campaign_outlined,
        color: ActionColors.accent,
        route: '',
      ),
      QuickAction(
        id: 'special_projects',
        label: 'Projects',
        icon: Icons.construction_rounded,
        color: ActionColors.brand,
        route: '/resident/special-projects',
      ),
    ];

/// Overflow actions shown in the “More” bottom sheet.
List<QuickAction> get residentQuickActionsOverflow => [
      QuickAction(
        id: 'utilities',
        label: 'Utilities',
        icon: Icons.water_drop_outlined,
        color: ActionColors.info,
        route: '/resident/utilities',
      ),
      QuickAction(
        id: 'directory',
        label: 'Directory',
        icon: Icons.people_outline_rounded,
        color: ActionColors.brand,
        route: '/resident/directory',
      ),
      QuickAction(
        id: 'vehicle_log',
        label: 'Vehicle Log',
        icon: Icons.directions_car_outlined,
        color: ActionColors.secondary,
        route: '/resident/vehicle-log',
      ),
    ];

QuickAction get moreQuickAction => QuickAction(
      id: 'more',
      label: 'More',
      icon: Icons.more_horiz,
      color: ActionColors.neutral,
      route: '/resident/more',
    );

QuickAction get residentHomeVisitorEntryAction => QuickAction(
      id: 'visitor_entry',
      label: 'GatePass+',
      icon: Icons.person_add_alt_1_rounded,
      color: DesignColors.primary,
      route: '/resident/visitor-hub',
    );

List<QuickAction> get residentHomeHeroOverflowActions => [
      QuickAction(
        id: 'special_projects',
        label: 'Projects',
        icon: Icons.construction_rounded,
        color: DesignColors.primary,
        route: '/resident/special-projects',
      ),
    ];

List<QuickAction> get residentHomeSecondaryActionsGrid => [
      QuickAction(
        id: 'parcels',
        label: 'Parcel',
        icon: Icons.inventory_2_outlined,
        color: DesignColors.success,
        route: '/resident/parcels',
      ),
      QuickAction(
        id: 'amenity_bookings',
        label: 'Facility Booking',
        icon: Icons.event_note_outlined,
        color: DesignColors.primary,
        route: '/resident/amenity-bookings',
      ),
      QuickAction(
        id: 'daily_help',
        label: 'Vendors',
        icon: Icons.badge_outlined,
        color: DesignColors.info,
        route: '/resident/daily-help',
      ),
      QuickAction(
        id: 'amenities',
        label: 'Amenity Booking',
        icon: Icons.pool_rounded,
        color: DesignColors.success,
        route: '/resident/amenities',
      ),
      QuickAction(
        id: 'community',
        label: 'Notices',
        icon: Icons.campaign_outlined,
        color: DesignColors.primary,
        route: '',
      ),
      moreQuickAction,
    ];

const Set<String> residentHomeOnScreenQuickActionIds = {
  'visitor_entry',
  'sos',
  'complaint',
  'parcels',
  'amenity_bookings',
  'daily_help',
  'amenities',
  'community',
  'special_projects',
  'utilities',
  'directory',
  'vehicle_log',
};

List<QuickAction> get residentQuickActionsCatalog {
  final seen = <String>{};
  final out = <QuickAction>[];
  void add(QuickAction a) {
    if (seen.add(a.id)) out.add(a);
  }

  add(residentHomeVisitorEntryAction);
  for (final a in residentHomeQuickActionsGrid) {
    add(a);
  }
  for (final a in residentHomeSecondaryActionsGrid) {
    if (a.id != 'more') add(a);
  }
  for (final a in residentHomeHeroOverflowActions) {
    add(a);
  }
  for (final a in residentQuickActionsOverflow) {
    add(a);
  }
  return out;
}

List<QuickAction> residentQuickActionsOffHomeSection() => [
      for (final a in residentQuickActionsCatalog)
        if (!residentHomeOnScreenQuickActionIds.contains(a.id)) a,
    ];

List<QuickAction> residentQuickActionsMoreSheet() {
  final seen = <String>{};
  final out = <QuickAction>[];
  for (final a in [
    ...residentHomeHeroOverflowActions,
    ...residentQuickActionsOverflow,
  ]) {
    if (!residentHomeOnScreenQuickActionIds.contains(a.id) && seen.add(a.id)) {
      out.add(a);
    }
  }
  return out;
}
