import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/notice_model.dart';
import 'home_shared.dart';

class HomeImportantNotices extends StatelessWidget {
  const HomeImportantNotices({
    super.key,
    required this.noticesState,
    required this.onViewAll,
    required this.onNoticesTap,
    required this.onRetry,
  });

  final AsyncValue<List<NoticeModel>> noticesState;
  final VoidCallback onViewAll;
  final VoidCallback onNoticesTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notices =
        noticesState.valueOrNull ?? const <NoticeModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(title: 'Important Notices', onViewAll: onViewAll),
        const SizedBox(height: 6),
        noticesState.when(
          loading: () => ShimmerWrap(
            child: ShimmerBox(height: 56, borderRadius: DesignRadius.xl),
          ),
          error: (_, _) => HomeEmptyBlock(
            message: 'Could not load notices',
            onRetry: onRetry,
          ),
          data: (_) {
            if (notices.isEmpty) {
              return HomeEmptyBlock(
                message: 'No notices published yet',
                onRetry: onRetry,
              );
            }
            final top = notices.take(2).toList();
            const borderLight = DesignColors.borderLight;
            return Material(
              color: context.surface.defaultSurface,
              borderRadius: DesignRadius.borderLG,
              elevation: 0,
              shadowColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: DesignRadius.borderLG,
                  border: Border.all(
                      color: DesignColors.borderLight),
                  boxShadow: DesignElevation.sm,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < top.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1,
                            thickness: 1,
                            color: borderLight),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            DesignHaptics.selection();
                            onNoticesTap();
                          },
                          child: _buildNoticeCard(
                            context,
                            title: top[i].title,
                            content: top[i].content,
                            date: homeTimeAgo(top[i].publishedAt),
                            accentColor: top[i].isUrgent
                                ? DesignColors.error
                                : DesignColors.primary,
                            showUrgentBadge: top[i].isUrgent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNoticeCard(
    BuildContext context, {
    required String title,
    required String content,
    required String date,
    required Color accentColor,
    required bool showUrgentBadge,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3.5, color: accentColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.campaign_outlined,
                        size: 17, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (showUrgentBadge) ...[
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'URGENT',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: DesignColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: DesignColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.text.secondary
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: DesignColors.textTertiary
                        .withValues(alpha: 0.65),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
