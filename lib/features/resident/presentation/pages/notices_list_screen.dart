import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/notice_model.dart';
import '../../data/providers/content_provider.dart';
import '../widgets/community/community_notice_tile.dart';
import '../widgets/community/community_ui.dart';
import 'notice_detail_screen.dart';

final noticeCategoryFilterProvider = StateProvider<NoticeCategory?>(
  (ref) => null,
);

final noticeSearchQueryProvider = StateProvider<String>((ref) => '');

class NoticesListScreen extends ConsumerWidget {
  const NoticesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(noticeCategoryFilterProvider);
    final searchQuery = ref.watch(noticeSearchQueryProvider);
    final noticesState = ref.watch(noticesProvider);

    final filterLabels = [
      'All',
      ...NoticeCategory.values.map(humanizeNoticeCategory),
    ];
    final selectedIndex = selectedCategory == null
        ? 0
        : NoticeCategory.values.indexOf(selectedCategory) + 1;

    return ColoredBox(
      color: context.surface.background,
      child: Column(
        children: [
          CommunitySearchField(
            hint: 'Search notices…',
            query: searchQuery,
            onChanged: (v) =>
                ref.read(noticeSearchQueryProvider.notifier).state = v,
          ),
          CommunityFilterChipRow(
            labels: filterLabels,
            selectedIndex: selectedIndex,
            onSelected: (i) {
              ref.read(noticeCategoryFilterProvider.notifier).state =
                  i == 0 ? null : NoticeCategory.values[i - 1];
            },
          ),
          Expanded(
            child: CommunityListBody<List<NoticeModel>>(
              asyncValue: noticesState,
              onRetry: () => ref.invalidate(noticesProvider),
              emptyIcon: Icons.campaign_outlined,
              emptyTitle: 'No notices posted',
              emptySubtitle:
                  'Important announcements from your society will appear here.',
              errorTitle: 'Could not load notices',
              dataBuilder: (notices) {
                var filtered = selectedCategory == null
                    ? notices
                    : notices.where((n) => n.category == selectedCategory).toList();

                if (searchQuery.trim().isNotEmpty) {
                  filtered = filtered
                      .where(
                        (n) => communityMatchesQuery(
                          searchQuery,
                          [n.title, n.content, humanizeNoticeCategory(n.category)],
                        ),
                      )
                      .toList();
                }

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 48),
                      EmptyStateWidget(
                        icon: Icons.campaign_outlined,
                        title: 'No notices match',
                        subtitle: 'Try a different search or filter.',
                      ),
                    ],
                  );
                }

                final pinned = filtered.where((n) => n.isPinned).toList();
                final urgent = filtered
                    .where((n) => n.isUrgent && !n.isPinned)
                    .toList();
                final regular = filtered
                    .where((n) => !n.isUrgent && !n.isPinned)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(noticesProvider),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      context.spacing.s16,
                      context.spacing.s12,
                      context.spacing.s16,
                      context.spacing.s16,
                    ),
                    children: [
                      if (pinned.isNotEmpty) ...[
                        const EnterpriseSectionHeader(
                          title: 'Pinned',
                          subtitle: 'Important notices kept at the top',
                        ),
                        SizedBox(height: context.spacing.s12),
                        _noticeCard(context, pinned),
                        SizedBox(height: context.spacing.s16),
                      ],
                      if (urgent.isNotEmpty) ...[
                        const EnterpriseSectionHeader(
                          title: 'Urgent',
                          subtitle: 'Immediate communication that may affect access or safety',
                        ),
                        SizedBox(height: context.spacing.s12),
                        _noticeCard(context, urgent),
                        SizedBox(height: context.spacing.s16),
                      ],
                      if (regular.isNotEmpty) ...[
                        const EnterpriseSectionHeader(
                          title: 'All notices',
                          subtitle: 'Announcements, reminders, and society updates',
                        ),
                        SizedBox(height: context.spacing.s12),
                        _noticeCard(context, regular),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard(BuildContext context, List<NoticeModel> notices) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        borderRadius: DesignRadius.borderXL,
        border: Border.all(color: context.surface.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < notices.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.surface.border.withValues(alpha: 0.7),
                indent: 16,
                endIndent: 16,
              ),
            CommunityNoticeTile(
              notice: notices[i],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NoticeDetailScreen(notice: notices[i]),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
