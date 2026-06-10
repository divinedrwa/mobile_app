import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/notification_model.dart';
import '../../pages/notifications_center_screen.dart';
import 'home_shared.dart';

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity({
    super.key,
    required this.notificationsState,
    required this.onRetry,
  });

  final AsyncValue<List<NotificationModel>> notificationsState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notifications = notificationsState.valueOrNull ??
        const <NotificationModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Recent Activity',
          onViewAll: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => residentNotificationsEntry),
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          decoration: DesignComponents.cardDecoration(
            color: context.surface.defaultSurface,
          ),
          clipBehavior: Clip.antiAlias,
          child: notificationsState.when(
            loading: () => ShimmerWrap(
              child: Column(
                children: List.generate(3, (_) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ShimmerBox(height: 56, borderRadius: DesignRadius.lg),
                )),
              ),
            ),
            error: (_, _) => HomeEmptyBlock(
              message: 'Could not load recent activity',
              onRetry: onRetry,
            ),
            data: (_) {
              if (notifications.isEmpty) {
                return HomeEmptyBlock(
                  message: 'No recent activity yet',
                  onRetry: onRetry,
                );
              }
              final latest = notifications.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < latest.length; i++) ...[
                    _activityRow(
                      context,
                      icon: latest[i].type.icon,
                      iconBg: latest[i]
                          .type
                          .color
                          .withValues(alpha: 0.12),
                      iconColor: latest[i].type.color,
                      title: latest[i].title,
                      subtitle:
                          '${latest[i].message} • ${homeTimeAgo(latest[i].createdAt)}',
                      status: latest[i].isRead
                          ? 'Seen'
                          : 'New',
                      statusColor: latest[i].isRead
                          ? context.text.secondary
                          : kHomeGreen,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                residentNotificationsEntry,
                          ),
                        );
                      },
                    ),
                    if (i != latest.length - 1)
                      const Divider(
                          height: 1,
                          color: DesignColors.borderLight),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activityRow(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    final isSeen = status == 'Seen';
    final chipColor = isSeen ? DesignColors.textTertiary : (statusColor ?? kHomeGreen);
    final chipBg = isSeen ? DesignColors.surfaceSoft : const Color(0xFFE8F5E9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? () {
          DesignHaptics.selection();
          onTap();
        } : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius:
                      BorderRadius.circular(kHomeRadiusSm),
                ),
                child: Icon(icon,
                    color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: DesignColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: chipColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: DesignColors.textTertiary,
                    size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
