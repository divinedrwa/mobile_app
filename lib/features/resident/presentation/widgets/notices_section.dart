import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_animations.dart';
import '../pages/notices_list_screen.dart';

/// Notices section showing recent announcements
class NoticesSection extends StatelessWidget {
  const NoticesSection({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace hardcoded dummy data with real notices from the API
    // (e.g. via a Riverpod provider fetching from /residents/notices).
    // Keeping static placeholders for now to avoid breaking the home UI.
    final notices = [
      NoticeItem(
        title: 'Water supply off tomorrow',
        time: '2 hours ago',
        isUrgent: true,
      ),
      NoticeItem(
        title: 'Parking lot maintenance on Sunday',
        time: '1 day ago',
        isUrgent: false,
      ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📢 Notices',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NoticesListScreen(),
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
          itemCount: notices.length,
          itemBuilder: (context, index) {
            final notice = notices[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: ListTile(
                leading: Icon(
                  notice.isUrgent ? Icons.error : Icons.info,
                  color: notice.isUrgent ? AppColors.error : AppColors.primary,
                ),
                title: Text(notice.title),
                subtitle: Text(notice.time),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NoticesListScreen(),
                    ),
                  );
                },
              ),
            ).animate().fadeIn(
              duration: DesignAnimations.durationEntrance,
              delay: DesignAnimations.staggerFor(index),
            );
          },
        ),
      ],
    );
  }
}

/// Model for notice item
class NoticeItem {
  final String title;
  final String time;
  final bool isUrgent;
  
  NoticeItem({
    required this.title,
    required this.time,
    required this.isUrgent,
  });
}
