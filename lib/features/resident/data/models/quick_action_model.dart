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

// —— Home grid (2×3). Order is product-defined; no “More” tile for now. ——
// To restore More later: append [moreQuickAction] here and move shortcuts into
// [residentQuickActionsOverflow], then open the sheet from the More tile.

final residentHomeQuickActionsGrid = [
  const QuickAction(
    id: 'visitor_history',
    label: 'Visitor history',
    icon: Icons.history_outlined,
    color: Color(0xFF00897B),
    route: '/resident/visitor-history',
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
    id: 'sos',
    label: 'SOS',
    icon: Icons.emergency,
    color: Color(0xFFE53935),
    route: '/resident/sos',
  ),
  const QuickAction(
    id: 'amenities',
    label: 'Amenities',
    icon: Icons.pool,
    color: Color(0xFF43A047),
    route: '/resident/amenities',
  ),
  const QuickAction(
    id: 'amenity_bookings',
    label: 'Amenity bookings',
    icon: Icons.event_note_outlined,
    color: Color(0xFF7E57C2),
    route: '/resident/amenity-bookings',
  ),
];

/// Reserved for a future “More” sheet — not on the home grid until you add [moreQuickAction] back.
final residentQuickActionsOverflow = [
  const QuickAction(
    id: 'parcels',
    label: 'Parcels',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF2563EB),
    route: '/resident/parcels',
  ),
  const QuickAction(
    id: 'maintenance_expenses',
    label: 'Maintenance & expenses',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF1565C0),
    route: '/resident/maintenance-payment',
  ),
  const QuickAction(
    id: 'community',
    label: 'Community & notices',
    icon: Icons.campaign_outlined,
    color: Color(0xFFFF6D00),
    route: '',
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
