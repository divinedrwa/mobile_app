import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/utils/phone_launch.dart' show launchDial, maskPhone;
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_skeletons.dart';

class GuardResidentsDirectoryPage extends ConsumerStatefulWidget {
  const GuardResidentsDirectoryPage({super.key});

  @override
  ConsumerState<GuardResidentsDirectoryPage> createState() =>
      _GuardResidentsDirectoryPageState();
}

class _GuardResidentsDirectoryPageState
    extends ConsumerState<GuardResidentsDirectoryPage> {
  final _query = TextEditingController();
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final q = _query.text.trim();
      if (q != _debouncedQuery) {
        setState(() => _debouncedQuery = q);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  static String _initials(String name) {
    final list = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) return '?';
    String uc(String w) => w.isEmpty ? '' : w[0].toUpperCase();
    if (list.length == 1) {
      final s = list.single;
      return s.isEmpty ? '?' : uc(s);
    }
    return '${uc(list.first)}${uc(list.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(guardResidentsDirectoryProvider(_debouncedQuery));

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text('Residents', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GuardTokens.padScreen,
                GuardTokens.g2,
                GuardTokens.padScreen,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GuardScreenSectionHeader(
                    icon: Icons.apartment_rounded,
                    title: 'Directory',
                    subtitle:
                        'Search by name or flat — tap approval or call when needed',
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      hintText: 'e.g. A-101, Rahul',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          GuardTokens.radiusButton,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const GuardDirectorySkeleton(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  child: Center(
                    child: GuardInlineErrorBanner(
                      message: userFacingMessage(e),
                      onRetry: () => ref.invalidate(
                        guardResidentsDirectoryProvider(_debouncedQuery),
                      ),
                    ),
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(GuardTokens.padScreen),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 52,
                              color: GuardTokens.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            const SizedBox(height: GuardTokens.g2),
                            Text(
                              'No matches',
                              style: GuardTokens.headingStyle(context),
                            ),
                            const SizedBox(height: GuardTokens.g1),
                            Text(
                              'Try another name or flat number.',
                              textAlign: TextAlign.center,
                              style: GuardTokens.bodyStyle(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      GuardTokens.padScreen,
                      GuardTokens.g2,
                      GuardTokens.padScreen,
                      GuardTokens.g3,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return _ResidentCard(row: r, initials: _initials(r.name));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.row, required this.initials});

  final ResidentDirectoryRow row;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GuardTokens.g2,
          vertical: GuardTokens.g2 + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: GuardTokens.guardAccent.withValues(alpha: 0.16),
              foregroundColor: GuardTokens.guardAccentDeep,
              child: Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: GuardTokens.title,
                ),
              ),
            ),
            const SizedBox(width: GuardTokens.g2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: GuardTokens.headingStyle(
                      context,
                    ).copyWith(fontSize: GuardTokens.body + 1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: GuardTokens.g1,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GuardTokens.g1,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusChip,
                          ),
                        ),
                        child: Text(
                          'Flat ${row.flatLabel}',
                          style: GuardTokens.captionStyle(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (row.phoneMasked != null &&
                          row.phoneMasked!.trim().isNotEmpty)
                        Text(
                          row.phoneMasked!,
                          style: GuardTokens.captionStyle(context),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: GuardTokens.g1),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () {
                    final residentPhone = row.phone?.trim() ?? '';
                    final q = <String, String>{
                      'name': row.name,
                      if (row.villaId != null && row.villaId!.isNotEmpty)
                        'villaId': row.villaId!,
                      // Forward the resident's phone so the approval screen
                      // can dial directly without bouncing back to the
                      // directory. Read on the approval side by
                      // [_GuardVisitorApprovalPageState._callResident].
                      if (residentPhone.isNotEmpty)
                        'residentPhone': residentPhone,
                    };
                    context.push(
                      GuardRoutes.visitorApprovalWithQuery('dir', q),
                    );
                  },
                  icon: const Icon(
                    Icons.verified_user_outlined,
                    color: GuardTokens.guardAccentDeep,
                  ),
                  tooltip: 'Check in visitor for ${row.name}',
                ),
                const SizedBox(height: GuardTokens.g1),
                IconButton.outlined(
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () async {
                    final display = row.phoneMasked?.trim().isNotEmpty == true
                        ? row.phoneMasked!
                        : maskPhone(row.phone);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Call resident?'),
                        content: Text('Dial ${row.name} at $display?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final ok = await launchDial(row.phone);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            row.phoneMasked != null &&
                                    row.phoneMasked!.trim().isNotEmpty
                                ? 'Cannot dial — check number format (${row.phoneMasked})'
                                : 'Phone not available',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.phone_outlined,
                    color: GuardTokens.guardAccentDeep,
                  ),
                  tooltip: 'Call ${row.name}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

