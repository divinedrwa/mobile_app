import 'package:flutter/material.dart';

const double kAdminDashPadH = 18;
const double kAdminDashSectionGap = 20;
const double kAdminDashRadiusLg = 16;
const double kAdminDashRadiusMd = 14;

List<BoxShadow> adminDashCardShadow([double opacity = 0.06]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

String adminDashGreeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Late Night';
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  if (h < 21) return 'Good Evening';
  return 'Good Night';
}

String adminDashTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class AdminDashboardVLine extends StatelessWidget {
  const AdminDashboardVLine({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: color.withValues(alpha: 0.65));
  }
}

class AdminQuickAction {
  const AdminQuickAction(this.icon, this.label, this.color, this.route);
  final IconData icon;
  final String label;
  final Color color;
  final String route;
}
