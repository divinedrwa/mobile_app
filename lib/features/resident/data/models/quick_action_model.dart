import 'package:flutter/material.dart';

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

// —— Home grid (2×5). 10 items displayed; “More” tile at position 9. ——

final residentHomeQuickActionsGrid = [
  // Row 1
  const QuickAction(
    id: 'visitor_history',
    label: 'Visitor entry',
    icon: Icons.person_add_alt_1_rounded,
    color: Color(0xFF00897B),
    route: '/resident/pre-approve-visitor',
  ),
  const QuickAction(
    id: 'complaint',
    label: 'Complaint',
    icon: Icons.report_problem_outlined,
    color: Color(0xFFFF9800),
    route: '/resident/complaint',
  ),
  const QuickAction(
    id: 'daily_help',
    label: 'Vendors',
    icon: Icons.cleaning_services,
    color: Color(0xFF8B5CF6),
    route: '/resident/daily-help',
  ),
  const QuickAction(
    id: 'amenities',
    label: 'Amenity booking',
    icon: Icons.pool,
    color: Color(0xFF43A047),
    route: '/resident/amenities',
  ),
  const QuickAction(
    id: 'sos',
    label: 'SOS',
    icon: Icons.emergency,
    color: Color(0xFFE53935),
    route: '/resident/sos',
  ),
  // Row 2
  const QuickAction(
    id: 'parcels',
    label: 'Parcel',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF2563EB),
    route: '/resident/parcels',
  ),
  const QuickAction(
    id: 'amenity_bookings',
    label: 'Facility booking',
    icon: Icons.event_note_outlined,
    color: Color(0xFF7E57C2),
    route: '/resident/amenity-bookings',
  ),
  const QuickAction(
    id: 'community',
    label: 'Society notices',
    icon: Icons.campaign_outlined,
    color: Color(0xFFFF6D00),
    route: '',
  ),
  const QuickAction(
    id: 'special_projects',
    label: 'Projects',
    icon: Icons.construction_rounded,
    color: Color(0xFF7C3AED),
    route: '/resident/special-projects',
  ),
];

/// Overflow actions shown in the “More” bottom sheet.
/// Maintenance is excluded here — owners reach it via the home maintenance card.
final residentQuickActionsOverflow = [
  const QuickAction(
    id: 'utilities',
    label: 'Utilities',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF0288D1),
    route: '/resident/utilities',
  ),
  const QuickAction(
    id: 'directory',
    label: 'Directory',
    icon: Icons.people_outline_rounded,
    color: Color(0xFF00897B),
    route: '/resident/directory',
  ),
  const QuickAction(
    id: 'incidents',
    label: 'Incidents',
    icon: Icons.shield_outlined,
    color: Color(0xFFD84315),
    route: '/resident/incidents',
  ),
  const QuickAction(
    id: 'vehicle_log',
    label: 'Vehicle Log',
    icon: Icons.directions_car_outlined,
    color: Color(0xFF5C6BC0),
    route: '/resident/vehicle-log',
  ),
];

/// “More” tile — keep for future use; omit from [residentHomeQuickActionsGrid] until needed.
const moreQuickAction = QuickAction(
  id: 'more',
  label: 'More',
  icon: Icons.more_horiz,
  color: Color(0xFF78909C),
  route: '/resident/more',
);

/// Hero card — Visitor Entry (left card in quick-actions row).
const residentHomeVisitorEntryAction = QuickAction(
  id: 'visitor_entry',
  label: 'GatePass+',
  icon: Icons.person_add_alt_1_rounded,
  color: Color(0xFF6C5CE7),
  route: '/resident/visitor-hub',
);

/// Hero row overflow (not shown as separate tiles on the new home layout).
final residentHomeHeroOverflowActions = [
  const QuickAction(
    id: 'special_projects',
    label: 'Projects',
    icon: Icons.construction_rounded,
    color: Color(0xFF7C3AED),
    route: '/resident/special-projects',
  ),
];

/// Secondary icon row under hero cards (mock: Parcel … More).
final residentHomeSecondaryActionsGrid = [
  const QuickAction(
    id: 'parcels',
    label: 'Parcel',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF16A34A),
    route: '/resident/parcels',
  ),
  const QuickAction(
    id: 'amenity_bookings',
    label: 'Facility Booking',
    icon: Icons.event_note_outlined,
    color: Color(0xFF7C3AED),
    route: '/resident/amenity-bookings',
  ),
  const QuickAction(
    id: 'daily_help',
    label: 'Vendors',
    icon: Icons.badge_outlined,
    color: Color(0xFF2563EB),
    route: '/resident/daily-help',
  ),
  const QuickAction(
    id: 'amenities',
    label: 'Amenity Booking',
    icon: Icons.pool_rounded,
    color: Color(0xFF16A34A),
    route: '/resident/amenities',
  ),
  const QuickAction(
    id: 'community',
    label: 'Notices',
    icon: Icons.campaign_outlined,
    color: Color(0xFF7C3AED),
    route: '',
  ),
  moreQuickAction,
];

/// Action ids pinned on the home quick-actions section (hero row + icon row).
const Set<String> residentHomeOnScreenQuickActionIds = {
  'visitor_entry',
  'sos',
  'complaint',
  'parcels',
  'amenity_bookings',
  'daily_help',
  'amenities',
  'community',
};

/// Full resident shortcut catalog (deduped by id).
final List<QuickAction> residentQuickActionsCatalog = () {
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
}();

/// Shortcuts not pinned on the home quick-actions UI (for View All sheet).
List<QuickAction> residentQuickActionsOffHomeSection() => [
      for (final a in residentQuickActionsCatalog)
        if (!residentHomeOnScreenQuickActionIds.contains(a.id)) a,
    ];

/// Overflow shortcuts for the “More” tile (not on hero or icon row).
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
