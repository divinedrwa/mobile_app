import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/notice_model.dart';
import '../../pages/notice_detail_screen.dart';
import '../community/community_notice_tile.dart';
import 'home_shared.dart';

class HomeImportantNotices extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final notices = noticesState.valueOrNull ?? const <NoticeModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeader(
          title: 'Important Notices',
          subtitle: 'Society updates & reminders',
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 10),
        noticesState.when(
          loading: () => ShimmerWrap(
            child: Column(
              children: List.generate(
                2,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                ),
              ),
            ),
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
            final remaining = notices.length - top.length;

            return Container(
              decoration: DesignComponents.cardDecoration(
                color: context.surface.defaultSurface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < top.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: context.surface.border.withValues(alpha: 0.7),
                        indent: 16,
                        endIndent: 16,
                      ),
                    CommunityNoticeTile(
                      notice: top[i],
                      compact: true,
                      onTap: () {
                        DesignHaptics.selection();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NoticeDetailScreen(notice: top[i]),
                          ),
                        );
                      },
                    ),
                  ],
                  if (remaining > 0)
                    Material(
                      color: context.brand.primary.withValues(alpha: 0.04),
                      child: InkWell(
                        onTap: () {
                          DesignHaptics.selection();
                          onViewAll();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View $remaining more notice${remaining == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.brand.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: context.brand.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
