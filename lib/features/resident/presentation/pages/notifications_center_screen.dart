import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/notification_model.dart';
import '../../data/providers/notification_provider.dart';
import '../widgets/notification_skeleton.dart';

/// In-app notification history (push + server-persisted rows). Used by residents and guards.
class NotificationsCenterScreen extends ConsumerStatefulWidget {
  const NotificationsCenterScreen({
    super.key,
    this.title = 'Notifications',
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  ConsumerState<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState
    extends ConsumerState<NotificationsCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static final _timeFull = DateFormat('MMM d · h:mm a');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Deep links from push payload stored in `UserNotification.data`.
  bool _navigateFromInlineData(NotificationModel n) {
    final data = n.data;
    if (data == null) return false;
    final normalized = <String, String>{
      for (final e in data.entries) e.key: e.value?.toString() ?? '',
    };
    return NotificationService().applyNavigationFromPushData(
      normalized,
      openDetails: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final notificationsState = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
              Text(
                widget.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.text.secondary,
                  height: 1.2,
                ),
              )
            else if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.brand.primary,
                  height: 1.2,
                ),
              ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () async {
                  final pageContext = context;
                  final error = await ref
                      .read(notificationProvider.notifier)
                      .markAllAsRead();
                  if (!pageContext.mounted || error != null) return;
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('All marked as read'),
                    ),
                  );
                },
                child: const Text('Clear all'),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: context.surface.border.withValues(alpha: 0.5),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: context.brand.primary,
              labelColor: context.brand.primary,
              unselectedLabelColor: context.text.secondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('All'),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadChip(count: unreadCount, scheme: scheme),
                      ],
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mark_email_unread_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Unread'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: notificationsState.when(
        data: (notifications) {
          final unreadList = notifications.where((n) => !n.isRead).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              notifications.isEmpty
                  ? _emptyScrollableRefresh(
                      child: _buildEmptyState(scheme, isDark),
                    )
                  : _buildNotificationsList(notifications, scheme, isDark: isDark),
              unreadList.isEmpty
                  ? _emptyScrollableRefresh(
                      child: _buildNoUnreadState(scheme),
                    )
                  : _buildNotificationsList(unreadList, scheme, isDark: isDark),
            ],
          );
        },
        loading: () => const NotificationSkeleton(),
        error: (error, stack) => _ErrorState(
          scheme: scheme,
          onRetry: () => ref.invalidate(notificationProvider),
        ),
      ),
    );
  }

  Widget _emptyScrollableRefresh({required Widget child}) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () =>
          ref.read(notificationProvider.notifier).fetchNotifications(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openNotificationAction(NotificationModel notification) async {
    final raw = notification.actionUrl?.trim();
    if (raw == null || raw.isEmpty) return;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not open link'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final path = raw.startsWith('/') ? raw : '/$raw';
    try {
      unawaited(context.push(path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not open: $path'),
          ),
        );
      }
    }
  }

  Widget _buildNotificationsList(
    List<NotificationModel> notifications,
    ColorScheme scheme, {
    required bool isDark,
  }) {
    // Group by Today / Yesterday / Earlier
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <String, List<NotificationModel>>{};
    for (final n in notifications) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final label = d.isAtSameMomentAs(today)
          ? 'Today'
          : d.isAtSameMomentAs(yesterday)
              ? 'Yesterday'
              : 'Earlier';
      (grouped[label] ??= []).add(n);
    }

    final sections = <String>[];
    for (final key in ['Today', 'Yesterday', 'Earlier']) {
      if (grouped.containsKey(key)) sections.add(key);
    }

    // Flatten into a mixed list of headers + cards
    final items = <_NotifListItem>[];
    int cardIndex = 0;
    for (final section in sections) {
      items.add(_NotifListItem.header(section));
      for (final n in grouped[section]!) {
        items.add(_NotifListItem.card(n, cardIndex++));
      }
    }

    return RefreshIndicator(
      color: scheme.primary,
      onRefresh: () =>
          ref.read(notificationProvider.notifier).fetchNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          DesignSpacing.lg,
          DesignSpacing.md,
          DesignSpacing.lg,
          DesignSpacing.xl,
        ),
        itemCount: items.length,
        separatorBuilder: (context, i) => SizedBox(
          height: items[i].isHeader ? 4 : 10,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.isHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                item.headerLabel!,
                style: DesignTypography.labelSmall.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            );
          }
          return _buildNotificationCard(
            item.notification!,
            item.cardIndex!,
            scheme,
            isDark,
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationModel notification,
    int index,
    ColorScheme scheme,
    bool isDark,
  ) {
    final now = DateTime.now();
    final difference = now.difference(notification.createdAt);
    final timeAgo = _formatTimeAgo(difference);
    final fullStamp = _timeFull.format(notification.createdAt);

    final accent = notification.type.color;
    final cardBg = notification.isRead
        ? (isDark ? scheme.surfaceContainer : scheme.surface)
        : (isDark
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : scheme.primary.withValues(alpha: 0.06));

    final borderColor = notification.isRead
        ? scheme.outline.withValues(alpha: 0.28)
        : scheme.primary.withValues(alpha: isDark ? 0.45 : 0.35);

    final typeLabel =
        notification.type.value.replaceAll('_', ' ').toUpperCase();

    return Dismissible(
      key: ValueKey('notification-${notification.id}-$index'),
      direction: notification.isRead
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: DesignSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: DesignRadius.borderXL,
        ),
        child: Icon(Icons.mark_email_read_rounded, color: scheme.onPrimary),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DesignSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: DesignRadius.borderXL,
        ),
        child: Icon(Icons.delete_outline_rounded, color: scheme.onError),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right = mark as read (don't actually dismiss)
          if (!notification.isRead && notification.id.isNotEmpty) {
            await ref
                .read(notificationProvider.notifier)
                .markAsRead(notification.id);
          }
          return false; // Don't remove from list
        }
        return true; // Allow delete
      },
      onDismissed: (_) {
        ref
            .read(notificationProvider.notifier)
            .deleteNotification(notification.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('Removed from this list'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  ref.read(notificationProvider.notifier).fetchNotifications(),
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DesignRadius.borderXL,
          onTap: () async {
            if (!mounted) return;
            if (!notification.isRead && notification.id.isNotEmpty) {
              await ref
                  .read(notificationProvider.notifier)
                  .markAsRead(notification.id);
            }
            if (_navigateFromInlineData(notification)) return;
            await _openNotificationAction(notification);
          },
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: DesignRadius.borderXL,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(DesignSpacing.md + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: DesignRadius.borderLG,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(notification.type.icon, color: accent, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title.isEmpty
                                    ? 'Update'
                                    : notification.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: notification.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: scheme.onSurface,
                                      height: 1.25,
                                    ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                margin: const EdgeInsets.only(left: 6, top: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary
                                          .withValues(alpha: 0.45),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeAgo,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  ' · $fullStamp',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.85),
                                      ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                typeLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: accent,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                            if (_navigateFromInlineDataPreview(notification))
                              Text(
                                'Tap to open',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: DesignAnimations.staggerFor(index))
        .fadeIn(duration: 240.ms)
        .slideY(begin: DesignAnimations.slideNormal, end: 0, curve: Curves.easeOutCubic);
  }

  bool _navigateFromInlineDataPreview(NotificationModel n) {
    final t = n.data?['type']?.toString() ?? '';
    return NotificationService.applyNavigationFromPushDataPreview(t);
  }

  Widget _buildEmptyState(ColorScheme scheme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.8 : 1),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visitor requests, notices, and alerts will appear here so you never miss an update.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUnreadState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded, size: 72, color: scheme.tertiary),
            const SizedBox(height: 20),
            Text(
              "You're all caught up",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No unread messages. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(Duration difference) {
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(DateTime.now().subtract(difference));
  }
}

class _UnreadChip extends StatelessWidget {
  const _UnreadChip({required this.count, required this.scheme});

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.scheme,
    required this.onRetry,
  });

  final ColorScheme scheme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'Couldn’t load notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight union for building a mixed header + card list.
class _NotifListItem {
  final String? headerLabel;
  final NotificationModel? notification;
  final int? cardIndex;

  const _NotifListItem._({this.headerLabel, this.notification, this.cardIndex});

  factory _NotifListItem.header(String label) =>
      _NotifListItem._(headerLabel: label);

  factory _NotifListItem.card(NotificationModel n, int index) =>
      _NotifListItem._(notification: n, cardIndex: index);

  bool get isHeader => headerLabel != null;
}

/// Resident shell preset — use for home, community, and activity shortcuts.
const residentNotificationsEntry = NotificationsCenterScreen(
  title: 'Notifications',
  subtitle: 'Visitors, notices, payments, maintenance, and society updates',
);

