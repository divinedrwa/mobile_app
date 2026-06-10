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
final residentQuickActionsOverflow = [
  const QuickAction(
    id: 'maintenance_expenses',
    label: 'Maintenance & expenses',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF1565C0),
    route: '/resident/maintenance-payment',
  ),
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

/// “View all” bottom sheet — shortcuts not on the home grid (by id), even if lists overlap later.
final List<QuickAction> residentQuickActionsViewAll = [
  for (final a in residentQuickActionsOverflow)
    if (!residentHomeQuickActionsGrid.any((h) => h.id == a.id)) a,
];
