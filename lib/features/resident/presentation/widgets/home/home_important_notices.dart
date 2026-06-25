import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/tap_scale.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/notice_model.dart';
import '../../pages/notice_detail_screen.dart';
import 'home_notice_feed.dart';
import 'home_shared.dart';
import 'home_skeletons.dart';

const double _kNoticeCardHeight = 138;
const double _kNoticeCardGap = 10;
const double _kNoticeCardWidthFactor = 0.82;

class HomeImportantNotices extends StatefulWidget {
  const HomeImportantNotices({
    super.key,
    required this.noticesState,
    required this.onViewAll,
    required this.onRetry,
  });

  final AsyncValue<List<NoticeModel>> noticesState;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;

  @override
  State<HomeImportantNotices> createState() => _HomeImportantNoticesState();
}

class _HomeImportantNoticesState extends State<HomeImportantNotices> {
  final _railController = ScrollController();
  var _railPage = 0;

  @override
  void initState() {
    super.initState();
    _railController.addListener(_onRailScroll);
  }

  @override
  void dispose() {
    _railController.removeListener(_onRailScroll);
    _railController.dispose();
    super.dispose();
  }

  double _cardWidth(BuildContext context) {
    final contentW = MediaQuery.sizeOf(context).width - (kHomePadH * 2);
    return contentW * _kNoticeCardWidthFactor;
  }

  void _onRailScroll() {
    if (!_railController.hasClients) return;
    final cardWidth = _cardWidth(context);
    final page =
        (_railController.offset / (cardWidth + _kNoticeCardGap)).round();
    if (page != _railPage && mounted) {
      setState(() => _railPage = page);
    }
  }

  void _openNotice(NoticeModel notice) {
    DesignHaptics.selection();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(notice: notice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notices = widget.noticesState.valueOrNull ?? const <NoticeModel>[];
    final preview = recentNoticesForHome(notices);
    final showViewAll = hasMoreNoticesThanHomePreview(notices.length);

    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: BorderRadius.circular(kHomeRadiusLg),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: homeCardShadow(0.04),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            totalCount: notices.length,
            isLoading: widget.noticesState.isLoading,
            onViewAll: showViewAll ? widget.onViewAll : null,
          ),
          const SizedBox(height: 10),
          widget.noticesState.when(
            loading: () => _LoadingRail(cardWidth: _cardWidth(context)),
            error: (_, _) => _InlineEmpty(
              message: 'Could not load notices',
              onRetry: widget.onRetry,
            ),
            data: (_) {
              if (preview.isEmpty) {
                return _InlineEmpty(
                  message: 'No notices published yet',
                  onRetry: widget.onRetry,
                );
              }

              final activeIndex =
                  _railPage.clamp(0, preview.length - 1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NoticeRail(
                    controller: _railController,
                    cardWidth: _cardWidth(context),
                    notices: preview,
                    onTap: _openNotice,
                  ),
                  if (preview.length > 1) ...[
                    const SizedBox(height: 8),
                    _RailFooter(
                      activeIndex: activeIndex,
                      total: preview.length,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.totalCount,
    this.isLoading = false,
    this.onViewAll,
  });

  final int totalCount;
  final bool isLoading;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kHomePurple.withValues(alpha: 0.14),
                kHomePurpleLight,
              ],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: kHomePurple.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.campaign_rounded,
            size: 19,
            color: kHomePurple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Important Notices',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: DesignColors.textPrimary,
                  letterSpacing: -0.35,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              if (isLoading)
                const HomeSectionSubtitleSkeleton()
              else
                Text(
                  totalCount > 0
                      ? '$totalCount society update${totalCount == 1 ? '' : 's'}'
                      : 'Society updates & reminders',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: DesignColors.textSecondary,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
        if (onViewAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                DesignHaptics.selection();
                onViewAll!();
              },
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kHomePurpleLight,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: kHomePurple.withValues(alpha: 0.14)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: kHomePurple,
                        letterSpacing: -0.1,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: kHomePurple,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingRail extends StatelessWidget {
  const _LoadingRail({required this.cardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    Widget block(double h, {double? w, double r = 8}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF1),
      highlightColor: const Color(0xFFF6F8FA),
      child: SizedBox(
        height: _kNoticeCardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: _kNoticeCardGap),
          itemBuilder: (_, _) => Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DesignColors.borderLight),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    block(34, w: 34, r: 10),
                    const Spacer(),
                    block(18, w: 52, r: 10),
                  ],
                ),
                const SizedBox(height: 10),
                block(14),
                const SizedBox(height: 6),
                block(11),
                const SizedBox(height: 4),
                block(11, w: cardWidth * 0.7),
                const Spacer(),
                block(10, w: 72, r: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface.elevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.surface.border.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 18,
            color: context.text.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.text.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: kHomePurple,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRail extends StatelessWidget {
  const _NoticeRail({
    required this.controller,
    required this.cardWidth,
    required this.notices,
    required this.onTap,
  });

  final ScrollController controller;
  final double cardWidth;
  final List<NoticeModel> notices;
  final void Function(NoticeModel notice) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kNoticeCardHeight,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: notices.length,
        separatorBuilder: (_, _) => const SizedBox(width: _kNoticeCardGap),
        itemBuilder: (context, index) {
          return SizedBox(
            width: cardWidth,
            child: _NoticeCard(
              notice: notices[index],
              onTap: () => onTap(notices[index]),
            ),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.onTap});

  final NoticeModel notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = resolveNoticeVisualStyle(notice);
    final preview = noticePreviewText(notice.content);
    final timeLabel = noticeCardTimeLabel(notice);
    final showNewBadge =
        notice.isNew && style.tier == NoticeVisualTier.normal;
    final cardBg = noticeCardBackground(style);
    final cardBorder = style.foreground.withValues(alpha: 0.22);

    return TapScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: cardBg,
              ),
              boxShadow: homeCardShadow(0.03),
            ),
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        style.icon,
                        size: 15,
                        color: style.foreground,
                      ),
                    ),
                    const SizedBox(width: 7),
                    if (showNewBadge) ...[
                      _MetaChip(
                        label: 'NEW',
                        fg: kHomePurple,
                        bg: Colors.white.withValues(alpha: 0.78),
                      ),
                      const SizedBox(width: 5),
                    ],
                    _MetaChip(
                      label: style.statusLabel,
                      fg: style.foreground,
                      bg: Colors.white.withValues(alpha: 0.78),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: style.foreground.withValues(alpha: 0.55),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: DesignColors.textPrimary,
                    height: 1.1,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preview.isNotEmpty
                      ? preview
                      : 'Tap to read the full notice.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: DesignColors.textSecondary.withValues(alpha: 0.95),
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      style.tier == NoticeVisualTier.overdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                      size: 11,
                      color: style.foreground.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        timeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: style.tier == NoticeVisualTier.overdue ||
                                  style.tier == NoticeVisualTier.urgent
                              ? style.foreground
                              : DesignColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
          color: fg,
          height: 1,
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({
    required this.activeIndex,
    required this.total,
  });

  final int activeIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${activeIndex + 1} of $total',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.text.tertiary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: 10),
        ...List.generate(total, (i) {
          final active = i == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: active ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: active
                  ? kHomePurple
                  : kHomePurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ],
    );
  }
}
