import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_admit_by_otp_sheet.dart';
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
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter by visitor name, phone, flat (block/number) or OTP so a guard can
  /// find one visitor among 50–1000 pre-approvals without endless scrolling.
  List<GuardPreApprovedEntry> _filter(List<GuardPreApprovedEntry> rows) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((e) {
      final flat = [e.block, e.villaNumber]
          .whereType<String>()
          .join('-')
          .toLowerCase();
      return e.name.toLowerCase().contains(q) ||
          e.phone.toLowerCase().contains(q) ||
          (e.otp?.toLowerCase().contains(q) ?? false) ||
          flat.contains(q);
    }).toList(growable: false);
  }

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
        data: (rows) {
          if (rows.isEmpty) {
            return RefreshIndicator.adaptive(
              color: GuardTokens.guardAccentDeep,
              onRefresh: _onRefresh,
              child: _buildEmptyBody(context),
            );
          }
          final filtered = _filter(rows);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen, 10, GuardTokens.padScreen, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final admitted = await showAdmitByOtpSheet(context);
                      if (admitted && context.mounted) {
                        _onRefresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Visitor admitted.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.password_rounded, size: 18),
                    label: const Text('Admit by OTP'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen, 8, GuardTokens.padScreen, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, flat or OTP',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator.adaptive(
                  color: GuardTokens.guardAccentDeep,
                  onRefresh: _onRefresh,
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(GuardTokens.padScreen),
                          children: [
                            SizedBox(
                                height: MediaQuery.paddingOf(context).top + 24),
                            GuardEmptyPlaceholder(
                              icon: Icons.search_off_rounded,
                              title: 'No matches',
                              message:
                                  'No pre-approved visitor matches "$_query".',
                            ),
                          ],
                        )
                      : GuardPreApprovedEntriesListContent(
                          rows: filtered,
                          focusId: focusId,
                          onEntryTap: _openArrival,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
