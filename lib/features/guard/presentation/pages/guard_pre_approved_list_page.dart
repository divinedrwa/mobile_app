import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_empty_placeholder.dart';
import '../widgets/guard_pre_approved_entries_list.dart';
import '../widgets/guard_skeletons.dart';
import '../../ui/guard_tokens.dart';

/// Full-screen pre-approved list (e.g. from notification). Rows have no admit button — tap opens arrival.
class GuardPreApprovedListPage extends ConsumerStatefulWidget {
  const GuardPreApprovedListPage({super.key});

  @override
  ConsumerState<GuardPreApprovedListPage> createState() =>
      _GuardPreApprovedListPageState();
}

class _GuardPreApprovedListPageState
    extends ConsumerState<GuardPreApprovedListPage> {
  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(GuardRoutes.dashboard);
  }

  Future<void> _onRefresh() async {
    ref.invalidate(guardPreApprovedEntriesProvider);
    await ref.read(guardPreApprovedEntriesProvider.future);
  }

  void _openArrival(GuardPreApprovedEntry entry) {
    context.push(GuardRoutes.preApprovedArrival, extra: entry);
  }

  Widget _buildErrorBody(BuildContext context, Object e) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(GuardTokens.padScreen),
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + 48),
        GuardEmptyPlaceholder(
          icon: Icons.cloud_off_rounded,
          iconColor: GuardTokens.warning,
          title: 'Could not load list',
          message: userFacingMessage(e, 'Check your connection and try again.'),
          actionLabel: 'Retry',
          onAction: _onRefresh,
        ),
      ],
    );
  }

  Widget _buildEmptyBody(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(GuardTokens.padScreen),
      children: [
        SizedBox(height: MediaQuery.paddingOf(context).top + 48),
        const GuardEmptyPlaceholder(
          icon: Icons.event_available_rounded,
          title: 'No pre-approved visitors',
          message:
              'When residents pre-approve guests via the app, they appear here for quick gate admission.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guardPreApprovedEntriesProvider);
    final focusId = GoRouterState.of(context).uri.queryParameters['focus'];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Go back',
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _handleBack,
        ),
        title: Text(
          'Pre-approved visitors',
          style: GuardTokens.headingStyle(context).copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: async.when(
        loading: () => const GuardListSkeleton(),
        error: (e, _) => _buildErrorBody(context, e),
        data: (rows) => RefreshIndicator.adaptive(
          color: GuardTokens.guardAccentDeep,
          onRefresh: _onRefresh,
          child: rows.isEmpty
              ? _buildEmptyBody(context)
              : GuardPreApprovedEntriesListContent(
                  rows: rows,
                  focusId: focusId,
                  onEntryTap: _openArrival,
                ),
        ),
      ),
    );
  }
}
