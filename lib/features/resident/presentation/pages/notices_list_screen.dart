import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/notice_model.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/content_provider.dart';
import 'notice_detail_screen.dart';

/// Provider for selected notice category filter
final noticeCategoryFilterProvider = StateProvider<NoticeCategory?>(
  (ref) => null,
);

/// Modern Professional Notices List Screen
class NoticesListScreen extends ConsumerWidget {
  const NoticesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(noticeCategoryFilterProvider);
    final noticesState = ref.watch(noticesProvider);

    return ColoredBox(
      color: context.surface.background,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.s16,
              vertical: context.spacing.s12,
            ),
            decoration: BoxDecoration(
              color: context.surface.defaultSurface,
              border: Border(
                bottom: BorderSide(color: context.surface.border),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    context,
                    ref,
                    label: 'All',
                    category: null,
                    isSelected: selectedCategory == null,
                  ),
                  const SizedBox(width: 8),
                  ...NoticeCategory.values.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        context,
                        ref,
                        label: category.value,
                        category: category,
                        isSelected: selectedCategory == category,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: noticesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: EdgeInsets.all(context.spacing.s16),
                child: EnterpriseInfoBanner(
                  icon: Icons.campaign_outlined,
                  title: 'Could not load notices',
                  message: error.toString(),
                  tone: EnterpriseTone.danger,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(noticesProvider),
                ),
              ),
              data: (notices) {
                final filteredNotices = selectedCategory == null
                    ? notices
                    : notices
                          .where((n) => n.category == selectedCategory)
                          .toList();
                final urgentNotices = filteredNotices
                    .where((n) => n.isUrgent)
                    .toList();
                final regularNotices = filteredNotices
                    .where((n) => !n.isUrgent)
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(noticesProvider),
                  child: filteredNotices.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            context.spacing.s16,
                            context.spacing.s16,
                            context.spacing.s16,
                            context.spacing.s32,
                          ),
                          children: [
                            if (urgentNotices.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'Urgent notices',
                                'Immediate communication that may affect access or safety',
                              ),
                              SizedBox(height: context.spacing.s12),
                              ...urgentNotices.map(
                                (notice) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: context.spacing.s12,
                                  ),
                                  child: _buildModernNoticeCard(
                                    context,
                                    notice,
                                    isUrgent: true,
                                  ),
                                ),
                              ),
                              SizedBox(height: context.spacing.s24),
                            ],
                            if (regularNotices.isNotEmpty) ...[
                              _buildSectionHeader(
                                context,
                                'All Notices',
                                'Announcements, reminders, and society updates',
                              ),
                              SizedBox(height: context.spacing.s12),
                              ...regularNotices.map(
                                (notice) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: context.spacing.s12,
                                  ),
                                  child: _buildModernNoticeCard(
                                    context,
                                    notice,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
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

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required NoticeCategory? category,
    required bool isSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : context.text.secondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        ref.read(noticeCategoryFilterProvider.notifier).state = category;
      },
      backgroundColor: context.surface.background,
      selectedColor: context.brand.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: DesignRadius.borderXL,
        side: BorderSide(
          color: isSelected ? context.brand.primary : context.surface.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return EnterpriseSectionHeader(
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildModernNoticeCard(
    BuildContext context,
    NoticeModel notice, {
    bool isUrgent = false,
  }) {
    final borderColor = isUrgent
        ? context.state.denied.solid.withValues(alpha: 0.24)
        : context.surface.border;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoticeDetailScreen(notice: notice),
          ),
        );
      },
      borderRadius: DesignRadius.borderXL,
      child: Container(
        padding: const EdgeInsets.all(DesignSpacing.lg),
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: DesignRadius.borderXL,
          border: Border.all(color: borderColor, width: isUrgent ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                if (isUrgent) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          size: 14,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (notice.isNew) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (notice.audienceScope == 'SELECTED') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FOR YOU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _getRelativeDate(notice.publishedAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.text.secondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              notice.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: context.text.primary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Content Preview
            Text(
              notice.content,
              style: TextStyle(
                fontSize: 14,
                color: context.text.secondary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            if (notice.attachmentUrl != null) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 16,
                    color: DesignColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Attachment included',
                    style: TextStyle(
                      fontSize: 13,
                      color: DesignColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 50.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.campaign_outlined,
      title: 'No notices posted',
      subtitle: 'Important announcements from your society will appear here.',
    );
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}
