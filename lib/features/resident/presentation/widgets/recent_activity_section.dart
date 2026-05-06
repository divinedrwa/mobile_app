import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_spacing.dart';
import '../pages/notifications_center_screen.dart';

/// Recent activity section showing last few activities
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context) {
    // Lightweight preview shown on home.
    final activities = [
      ActivityItem(
        icon: Icons.person,
        iconColor: Colors.blue,
        title: 'John Doe checked in',
        subtitle: 'Guest • 2:30 PM',
        time: '2 hours ago',
      ),
      ActivityItem(
        icon: Icons.local_shipping,
        iconColor: Colors.orange,
        title: 'Amazon delivery received',
        subtitle: 'Parcel • At gate',
        time: '4 hours ago',
      ),
      ActivityItem(
        icon: Icons.payment,
        iconColor: Colors.green,
        title: 'Maintenance payment reminder',
        subtitle: 'Due on May 1',
        time: '1 day ago',
      ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📊 Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => residentNotificationsEntry,
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: activity.iconColor.withValues(alpha: 0.1),
                child: Icon(
                  activity.icon,
                  color: activity.iconColor,
                  size: 20,
                ),
              ),
              title: Text(activity.title),
              subtitle: Text(activity.subtitle),
              trailing: Text(
                activity.time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ).animate().fadeIn(
              duration: 300.ms,
              delay: ((index + 1) * 100).ms,
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Model for activity item
class ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  
  ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
