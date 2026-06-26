import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/notice_model.dart';
import '../home/home_shared.dart';
import 'community_ui.dart';

/// Shared notice row — home preview + community notices list.
class CommunityNoticeTile extends StatelessWidget {
  const CommunityNoticeTile({
    super.key,
    required this.notice,
    required this.onTap,
    this.compact = false,
  });

  final NoticeModel notice;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _categoryStyle(notice.category, notice.isUrgent);
    final preview = _previewText(notice.content);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 10 : 12, 12, compact ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(style.icon, size: compact ? 18 : 20, color: style.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (notice.isUrgent)
                          _badge('URGENT', const Color(0xFFD32F2F), const Color(0xFFFFEBEE)),
                        if (notice.isPinned)
                          _badge('PINNED', const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
                        if (notice.isNew && !notice.isUrgent)
                          _badge('NEW', DesignColors.primary,
                              DesignColors.primary.withValues(alpha: 0.1)),
                        _badge(
                          humanizeNoticeCategory(notice.category).toUpperCase(),
                          style.foreground,
                          style.background,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notice.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 14 : 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.text.primary,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (preview.isNotEmpty && !compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: context.text.secondary.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: context.text.tertiary),
                        const SizedBox(width: 4),
                        Text(
                          homeTimeAgo(notice.publishedAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.text.tertiary,
                          ),
                        ),
                        if (notice.attachmentUrl != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.attach_file_rounded,
                            size: 13,
                            color: context.brand.primary.withValues(alpha: 0.85),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.text.tertiary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
          color: fg,
        ),
      ),
    );
  }

  static String _previewText(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static _CategoryStyle _categoryStyle(NoticeCategory category, bool urgent) {
    if (urgent) {
      return const _CategoryStyle(
        icon: Icons.warning_amber_rounded,
        foreground: Color(0xFFC62828),
        background: Color(0xFFFFEBEE),
      );
    }
    switch (category) {
      case NoticeCategory.maintenance:
        return const _CategoryStyle(
          icon: Icons.home_repair_service_outlined,
          foreground: Color(0xFFE65100),
          background: Color(0xFFFFF3E0),
        );
      case NoticeCategory.emergency:
        return const _CategoryStyle(
          icon: Icons.emergency_outlined,
          foreground: Color(0xFFC62828),
          background: Color(0xFFFFEBEE),
        );
      case NoticeCategory.event:
        return const _CategoryStyle(
          icon: Icons.celebration_outlined,
          foreground: Color(0xFF6A1B9A),
          background: Color(0xFFF3E5F5),
        );
      case NoticeCategory.meeting:
        return const _CategoryStyle(
          icon: Icons.groups_outlined,
          foreground: Color(0xFF1565C0),
          background: Color(0xFFE3F2FD),
        );
      case NoticeCategory.announcement:
        return _CategoryStyle(
          icon: Icons.campaign_outlined,
          foreground: DesignColors.primary,
          background: Color(0xFFE8F5E9),
        );
      case NoticeCategory.general:
        return const _CategoryStyle(
          icon: Icons.info_outline_rounded,
          foreground: Color(0xFF546E7A),
          background: Color(0xFFECEFF1),
        );
    }
  }
}

class _CategoryStyle {
  const _CategoryStyle({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
}
