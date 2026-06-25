import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/complaint_provider.dart';
import '../widgets/list_skeleton.dart';

/// Lists complaints from GET /residents/my-complaints with pagination.
class MyComplaintsScreen extends ConsumerStatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  ConsumerState<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends ConsumerState<MyComplaintsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedComplaintsProvider.notifier).loadMore();
    }
  }

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return DesignColors.success;
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'OPEN':
      default:
        return DesignColors.primary;
    }
  }

  static String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return 'In progress';
      case 'RESOLVED':
        return 'Resolved';
      case 'OPEN':
        return 'Open';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pState = ref.watch(paginatedComplaintsProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: context.text.primary,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Complaints',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Track your submitted issues',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New complaint',
            onPressed: () => context.push('/resident/complaint'),
            icon: Icon(Icons.add_rounded, color: context.brand.primary, size: 26),
          ),
        ],
      ),
      body: _buildBody(context, pState),
    );
  }

  Widget _buildBody(BuildContext context, dynamic pState) {
    if (pState.isInitialLoad) {
      return const ListSkeleton();
    }

    if (pState.error != null && pState.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.s16),
        child: EnterpriseInfoBanner(
          icon: Icons.report_problem_outlined,
          title: 'Could not load complaints',
          message: pState.error!,
          tone: EnterpriseTone.danger,
          actionLabel: 'Retry',
          onAction: () => ref.read(paginatedComplaintsProvider.notifier).refresh(),
        ),
      );
    }

    final items = pState.items;

    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'No complaints filed',
        subtitle: 'That\'s a good sign! If something comes up, you can file a complaint from the home screen.',
        iconColor: DesignColors.success,
        actionLabel: 'File a complaint',
        onAction: () => context.push('/resident/complaint'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(paginatedComplaintsProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          context.spacing.s16,
          context.spacing.s16,
          context.spacing.s16,
          context.spacing.s32,
        ),
        itemCount: items.length + (pState.hasMore || pState.isLoadingMore ? 1 : 0) + 2,
        itemBuilder: (context, index) {
          // Header items
          if (index == 0) {
            return const EnterpriseInfoBanner(
              icon: Icons.assignment_outlined,
              title: 'Track service issues clearly',
              message: 'Review what has been filed, what is being worked on, and what has already been resolved.',
              tone: EnterpriseTone.info,
            );
          }
          if (index == 1) {
            return Padding(
              padding: EdgeInsets.only(top: context.spacing.s24, bottom: context.spacing.s12),
              child: EnterpriseSectionHeader(
                title: 'Complaint history',
                subtitle: '${pState.total} ${pState.total == 1 ? 'issue' : 'issues'} recorded for your home',
              ),
            );
          }

          final itemIndex = index - 2;

          // Load more indicator
          if (itemIndex >= items.length) {
            if (pState.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (pState.hasMore) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () => ref.read(paginatedComplaintsProvider.notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final item = items[itemIndex];
          return _ComplaintCard(
            item: item,
            color: _statusColor(item.status),
            statusLabel: _statusLabel(item.status),
          ).animate().fadeIn(
                duration: 250.ms,
                delay: DesignAnimations.staggerFor(itemIndex),
              );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.item,
    required this.color,
    required this.statusLabel,
  });

  final dynamic item;
  final Color color;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.report_problem_outlined, color: color),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    item.category,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(item.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.sm),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
