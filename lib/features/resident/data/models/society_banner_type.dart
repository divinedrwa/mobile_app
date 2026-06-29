import 'package:flutter/material.dart';

/// Mirrors backend [BannerType] (`schema.prisma`).
enum SocietyBannerType {
  event(
    displayLabel: 'Event',
    icon: Icons.event_rounded,
    accentColor: Color(0xFF1565C0),
    allowsRegistration: true,
  ),
  announcement(
    displayLabel: 'Announcement',
    icon: Icons.campaign_outlined,
    accentColor: Color(0xFF6A1B9A),
    allowsRegistration: false,
  ),
  festival(
    displayLabel: 'Festival',
    icon: Icons.celebration_outlined,
    accentColor: Color(0xFFE65100),
    allowsRegistration: true,
  ),
  emergency(
    displayLabel: 'Emergency',
    icon: Icons.emergency_outlined,
    accentColor: Color(0xFFC62828),
    allowsRegistration: false,
  ),
  maintenance(
    displayLabel: 'Maintenance',
    icon: Icons.build_circle_outlined,
    accentColor: Color(0xFFEF6C00),
    allowsRegistration: false,
  ),
  offer(
    displayLabel: 'Offer',
    icon: Icons.local_offer_outlined,
    accentColor: Color(0xFF2E7D32),
    allowsRegistration: false,
  ),
  community(
    displayLabel: 'Community Activity',
    icon: Icons.groups_2_outlined,
    accentColor: Color(0xFF0D1B3D),
    allowsRegistration: true,
  );

  const SocietyBannerType({
    required this.displayLabel,
    required this.icon,
    required this.accentColor,
    required this.allowsRegistration,
  });

  final String displayLabel;
  final IconData icon;
  final Color accentColor;
  final bool allowsRegistration;

  /// Parses API `type` (e.g. `EVENT`, `Announcement`).
  static SocietyBannerType fromApi(dynamic raw) {
    final normalized = raw?.toString().trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'EVENT':
        return SocietyBannerType.event;
      case 'ANNOUNCEMENT':
        return SocietyBannerType.announcement;
      case 'FESTIVAL':
        return SocietyBannerType.festival;
      case 'EMERGENCY':
        return SocietyBannerType.emergency;
      case 'MAINTENANCE':
        return SocietyBannerType.maintenance;
      case 'OFFER':
        return SocietyBannerType.offer;
      case 'COMMUNITY':
        return SocietyBannerType.community;
      default:
        return SocietyBannerType.announcement;
    }
  }

  /// Stable order for grouping / filters in the Events tab.
  static const List<SocietyBannerType> tabOrder = [
    SocietyBannerType.emergency,
    SocietyBannerType.maintenance,
    SocietyBannerType.announcement,
    SocietyBannerType.event,
    SocietyBannerType.festival,
    SocietyBannerType.community,
    SocietyBannerType.offer,
  ];
}
