import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../data/models/notice_model.dart';
import 'home_shared.dart';

/// Max recent notices shown on the home horizontal rail.
const int kHomeNoticeRailMaxItems = 5;

/// Visual urgency derived from API fields: priority, isUrgent, category, expiresAt.
enum NoticeVisualTier {
  overdue,
  urgent,
  important,
  normal,
  low,
}

class NoticeVisualStyle {
  const NoticeVisualStyle({
    required this.tier,
    required this.statusLabel,
    required this.foreground,
    required this.background,
    required this.icon,
  });

  final NoticeVisualTier tier;
  final String statusLabel;
  final Color foreground;
  final Color background;
  final IconData icon;
}

List<NoticeModel> recentNoticesForHome(List<NoticeModel> notices) {
  return notices.take(kHomeNoticeRailMaxItems).toList(growable: false);
}

bool hasMoreNoticesThanHomePreview(int totalCount) {
  return totalCount > kHomeNoticeRailMaxItems;
}

String noticePreviewText(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

NoticeVisualTier resolveNoticeVisualTier(NoticeModel notice) {
  if (notice.expiresAt != null && notice.isExpired) {
    return NoticeVisualTier.overdue;
  }
  if (notice.isUrgent ||
      notice.priority == NoticePriority.urgent ||
      notice.category == NoticeCategory.emergency) {
    return NoticeVisualTier.urgent;
  }
  if (notice.priority == NoticePriority.high) {
    return NoticeVisualTier.important;
  }
  if (notice.priority == NoticePriority.low) {
    return NoticeVisualTier.low;
  }
  return NoticeVisualTier.normal;
}

String _categoryLabel(NoticeCategory category) {
  switch (category) {
    case NoticeCategory.general:
      return 'GENERAL';
    case NoticeCategory.maintenance:
      return 'MAINTENANCE';
    case NoticeCategory.event:
      return 'EVENT';
    case NoticeCategory.emergency:
      return 'EMERGENCY';
    case NoticeCategory.announcement:
      return 'ANNOUNCEMENT';
    case NoticeCategory.meeting:
      return 'MEETING';
  }
}

IconData _categoryIcon(NoticeCategory category) {
  switch (category) {
    case NoticeCategory.maintenance:
      return Icons.home_repair_service_outlined;
    case NoticeCategory.emergency:
      return Icons.emergency_outlined;
    case NoticeCategory.event:
      return Icons.event_available_outlined;
    case NoticeCategory.meeting:
      return Icons.groups_outlined;
    case NoticeCategory.announcement:
      return Icons.campaign_outlined;
    case NoticeCategory.general:
      return Icons.article_outlined;
  }
}

NoticeVisualStyle resolveNoticeVisualStyle(NoticeModel notice) {
  final tier = resolveNoticeVisualTier(notice);
  final icon = _categoryIcon(notice.category);

  switch (tier) {
    case NoticeVisualTier.overdue:
      return NoticeVisualStyle(
        tier: tier,
        statusLabel: 'OVERDUE',
        foreground: const Color(0xFF9F1239),
        background: const Color(0xFFFFE4E6),
        icon: Icons.event_busy_rounded,
      );
    case NoticeVisualTier.urgent:
      return NoticeVisualStyle(
        tier: tier,
        statusLabel: 'URGENT',
        foreground: const Color(0xFFB91C1C),
        background: const Color(0xFFFECDD3),
        icon: Icons.priority_high_rounded,
      );
    case NoticeVisualTier.important:
      return NoticeVisualStyle(
        tier: tier,
        statusLabel: 'IMPORTANT',
        foreground: const Color(0xFFC2410C),
        background: const Color(0xFFFFEDD5),
        icon: icon,
      );
    case NoticeVisualTier.low:
      return NoticeVisualStyle(
        tier: tier,
        statusLabel: 'LOW',
        foreground: const Color(0xFF64748B),
        background: const Color(0xFFE2E8F0),
        icon: icon,
      );
    case NoticeVisualTier.normal:
      return NoticeVisualStyle(
        tier: tier,
        statusLabel: _categoryLabel(notice.category),
        foreground: const Color(0xFF2563EB),
        background: const Color(0xFFDBEAFE),
        icon: icon,
      );
  }
}

/// Full-card gradient fill from priority palette.
List<Color> noticeCardBackground(NoticeVisualStyle style) {
  final mid = Color.lerp(style.background, Colors.white, 0.28)!;
  final end = Color.lerp(style.background, Colors.white, 0.52)!;
  return [style.background, mid, end];
}

String noticeCardTimeLabel(NoticeModel notice) {
  final expiresAt = notice.expiresAt;
  if (expiresAt != null && notice.isExpired) {
    return 'Expired ${homeTimeAgo(expiresAt)}';
  }
  if (expiresAt != null) {
    final days = expiresAt.difference(DateTime.now()).inDays;
    if (days == 0) return 'Expires today';
    if (days > 0 && days <= 14) {
      return 'Expires in $days day${days == 1 ? '' : 's'}';
    }
  }
  return 'Posted ${homeTimeAgo(notice.publishedAt)}';
}
