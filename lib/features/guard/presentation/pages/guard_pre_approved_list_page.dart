import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_pre_approved_entries_list.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(guardPreApprovedEntriesProvider);
    });
  }

  Future<void> _onRefresh() async {
    ref.invalidate(guardPreApprovedEntriesProvider);
    await ref.read(guardPreApprovedEntriesProvider.future);
  }

  void _openArrival(GuardPreApprovedEntry entry) {
    context.push(GuardRoutes.preApprovedArrival, extra: entry);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guardPreApprovedEntriesProvider);
    final focusId = GoRouterState.of(context).uri.queryParameters['focus'];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
        title: Text(
          'Pre-approved visitors',
          style: GuardTokens.headingStyle(context),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(GuardTokens.padScreen),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userFacingMessage(e, 'Could not load list.'),
                  style: GuardTokens.bodyStyle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GuardTokens.g2),
                FilledButton(
                  onPressed: _onRefresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (rows) => RefreshIndicator.adaptive(
          onRefresh: _onRefresh,
          child: GuardPreApprovedEntriesListContent(
            rows: rows,
            focusId: focusId,
            onEntryTap: _openArrival,
          ),
        ),
      ),
    );
  }
}
