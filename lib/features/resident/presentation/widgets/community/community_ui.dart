import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/network/dio_exception_mapper.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/enterprise_ui.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';

/// Shared async list body for Community sub-tabs.
class CommunityListBody<T> extends StatelessWidget {
  const CommunityListBody({
    super.key,
    required this.asyncValue,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.dataBuilder,
    this.shimmerHeight = 88,
    this.shimmerCount = 4,
    this.errorTitle = 'Could not load',
  });

  final AsyncValue<T> asyncValue;
  final VoidCallback onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String errorTitle;
  final Widget Function(T data) dataBuilder;
  final double shimmerHeight;
  final int shimmerCount;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.surface.background,
      child: asyncValue.when(
        loading: () => CommunityShimmerList(
          itemHeight: shimmerHeight,
          count: shimmerCount,
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: EdgeInsets.all(context.spacing.s16),
              child: EnterpriseInfoBanner(
                icon: Icons.error_outline_rounded,
                title: errorTitle,
                message: userFacingMessage(error),
                tone: EnterpriseTone.danger,
                actionLabel: 'Retry',
                onAction: onRetry,
              ),
            ),
          ],
        ),
        data: (data) {
          return dataBuilder(data);
        },
      ),
    );
  }
}

class CommunityShimmerList extends StatelessWidget {
  const CommunityShimmerList({
    super.key,
    this.itemHeight = 88,
    this.count = 4,
  });

  final double itemHeight;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView(
        padding: EdgeInsets.all(context.spacing.s16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: List.generate(
          count,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < count - 1 ? 10 : 0),
            child: ShimmerBox(
              height: itemHeight,
              borderRadius: DesignRadius.lg,
            ),
          ),
        ),
      ),
    );
  }
}

class CommunitySearchField extends StatelessWidget {
  const CommunitySearchField({
    super.key,
    required this.hint,
    required this.query,
    required this.onChanged,
  });

  final String hint;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.s16,
        context.spacing.s8,
        context.spacing.s16,
        context.spacing.s4,
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded, color: context.text.tertiary),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  onPressed: () => onChanged(''),
                  icon: Icon(Icons.close_rounded, color: context.text.tertiary),
                )
              : null,
          filled: true,
          fillColor: context.surface.defaultSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: DesignRadius.borderXL,
            borderSide: BorderSide(color: context.surface.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: DesignRadius.borderXL,
            borderSide: BorderSide(color: context.surface.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: DesignRadius.borderXL,
            borderSide: BorderSide(color: context.brand.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class CommunityFilterChipRow extends StatelessWidget {
  const CommunityFilterChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s16,
        vertical: context.spacing.s8,
      ),
      decoration: BoxDecoration(
        color: context.surface.defaultSurface,
        border: Border(bottom: BorderSide(color: context.surface.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = selectedIndex == i;
            return Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              child: FilterChip(
                label: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : context.text.secondary,
                  ),
                ),
                selected: selected,
                onSelected: (_) => onSelected(i),
                backgroundColor: context.surface.background,
                selectedColor: context.brand.primary,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: DesignRadius.borderXL,
                  side: BorderSide(
                    color: selected
                        ? context.brand.primary
                        : context.surface.border,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            );
          }),
        ),
      ),
    );
  }
}

String humanizeNoticeCategory(NoticeCategory category) {
  switch (category) {
    case NoticeCategory.general:
      return 'General';
    case NoticeCategory.maintenance:
      return 'Maintenance';
    case NoticeCategory.event:
      return 'Events';
    case NoticeCategory.emergency:
      return 'Emergency';
    case NoticeCategory.announcement:
      return 'Announcement';
    case NoticeCategory.meeting:
      return 'Meeting';
  }
}

String humanizeDocumentCategory(DocumentCategory category) {
  switch (category) {
    case DocumentCategory.general:
      return 'General';
    case DocumentCategory.bylaws:
      return 'Bylaws';
    case DocumentCategory.minutes:
      return 'Minutes';
    case DocumentCategory.financial:
      return 'Financial';
    case DocumentCategory.policy:
      return 'Policy';
    case DocumentCategory.form:
      return 'Forms';
  }
}

bool communityMatchesQuery(String query, List<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f.toLowerCase().contains(q));
}
