part of '../admin_dashboard_screen.dart';

extension _AdminDashboardActivityPart on _AdminDashboardScreenState {
  Widget _buildRecentActivity(
    BuildContext ctx,
    AsyncValue<List<NotificationModel>> notificationsState,
  ) {
    final notifications =
        notificationsState.valueOrNull ?? const <NotificationModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DesignColors.textPrimary,
                letterSpacing: -0.35,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => residentNotificationsEntry,
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: DesignColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All >',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kAdminDashRadiusLg),
            boxShadow: adminDashCardShadow(),
          ),
          clipBehavior: Clip.antiAlias,
          child: notificationsState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: PickerSkeleton(itemCount: 3),
            ),
            error: (_, __) => _emptyActivityBlock(
              ctx,
              message: 'Could not load recent activity',
              onRetry: () => ref.invalidate(notificationProvider),
            ),
            data: (_) {
              if (notifications.isEmpty) {
                return _emptyActivityBlock(
                  ctx,
                  message: 'No recent activity yet',
                  onRetry: () => ref.invalidate(notificationProvider),
                );
              }
              final latest = notifications.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < latest.length; i++) ...[
                    _activityRow(
                      icon: latest[i].type.icon,
                      iconBg: latest[i].type.color.withValues(alpha: 0.12),
                      iconColor: latest[i].type.color,
                      title: latest[i].title,
                      subtitle:
                          '${latest[i].message} \u00b7 ${adminDashTimeAgo(latest[i].createdAt)}',
                      status: latest[i].isRead ? 'Seen' : 'New',
                      statusColor:
                          latest[i].isRead ? DesignColors.textSecondary : ActionColors.accent,
                      onTap: () {
                        Navigator.of(ctx).push(
                          MaterialPageRoute<void>(
                            builder: (_) => residentNotificationsEntry,
                          ),
                        );
                      },
                    ),
                    if (i != latest.length - 1)
                      Divider(
                          height: 1, color: DesignColors.borderLight),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activityRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    final chipColor = statusColor ?? ActionColors.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyActivityBlock(
    BuildContext ctx, {
    required String message,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 36,
            color: DesignColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DesignColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
