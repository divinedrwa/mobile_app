import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/utils/phone_launch.dart' show launchDial, maskPhone;
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_flat_picker.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_skeletons.dart';

class _DirectoryFlatGroup {
  const _DirectoryFlatGroup({
    required this.key,
    required this.label,
    required this.residents,
  });

  final String key;
  final String label;
  final List<ResidentDirectoryRow> residents;
}

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
  String? _blockFilter;
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

  List<_DirectoryFlatGroup> _groupFlats(List<ResidentDirectoryRow> rows) {
    final map = <String, _DirectoryFlatGroup>{};
    for (final r in rows) {
      final key =
          (r.villaId != null && r.villaId!.isNotEmpty) ? r.villaId! : r.flatLabel;
      final existing = map[key];
      if (existing != null) {
        map[key] = _DirectoryFlatGroup(
          key: key,
          label: existing.label,
          residents: [...existing.residents, r],
        );
      } else {
        map[key] = _DirectoryFlatGroup(
          key: key,
          label: r.flatLabel,
          residents: [r],
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return list;
  }

  String? _blockFromLabel(String label) {
    final m = RegExp(r'^([A-Za-z]+)[\s-]').firstMatch(label.trim());
    return m?.group(1)?.toUpperCase();
  }

  List<String> _blocks(List<_DirectoryFlatGroup> flats) {
    final set = <String>{};
    for (final f in flats) {
      final b = _blockFromLabel(f.label);
      if (b != null && b.isNotEmpty) set.add(b);
    }
    return set.toList()..sort();
  }

  List<_DirectoryFlatGroup> _visibleFlats(List<_DirectoryFlatGroup> flats) {
    final q = _debouncedQuery.trim().toLowerCase();
    return flats.where((f) {
      if (q.isNotEmpty) {
        final inFlat = f.label.toLowerCase().contains(q);
        final inName =
            f.residents.any((r) => r.name.toLowerCase().contains(q));
        if (!inFlat && !inName) return false;
      }
      if (_blockFilter != null) {
        return _blockFromLabel(f.label) == _blockFilter;
      }
      return true;
    }).toList();
  }

  Future<void> _openFlatSheet(_DirectoryFlatGroup flat) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              GuardTokens.padScreen,
              0,
              GuardTokens.padScreen,
              GuardTokens.g3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Flat ${flat.label}',
                  style: GuardTokens.headingStyle(ctx),
                ),
                const SizedBox(height: GuardTokens.g1),
                Text(
                  '${flat.residents.length} resident${flat.residents.length == 1 ? '' : 's'}',
                  style: GuardTokens.captionStyle(ctx),
                ),
                const SizedBox(height: GuardTokens.g2),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: flat.residents.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: GuardTokens.g2),
                    itemBuilder: (_, i) {
                      final r = flat.residents[i];
                      return _ResidentActionCard(
                        row: r,
                        initials: _initials(r.name),
                        index: i,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            icon: Icon(Icons.close_rounded),
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
                        'Search by name or flat — tap a flat tile for approval or call',
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      hintText: 'e.g. A-101, Rahul',
                      prefixIcon: Icon(Icons.search_rounded),
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

                  final flats = _groupFlats(rows);
                  final blocks = _blocks(flats);
                  final visible = _visibleFlats(flats);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        guardResidentsDirectoryProvider(_debouncedQuery),
                      );
                      await ref.read(
                        guardResidentsDirectoryProvider(_debouncedQuery).future,
                      );
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        GuardTokens.padScreen,
                        GuardTokens.g2,
                        GuardTokens.padScreen,
                        GuardTokens.g3,
                      ),
                      children: [
                        if (_debouncedQuery.isEmpty && blocks.isNotEmpty) ...[
                          SizedBox(
                            height: 34,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: const Text('All'),
                                    selected: _blockFilter == null,
                                    onSelected: (_) =>
                                        setState(() => _blockFilter = null),
                                  ),
                                ),
                                for (final b in blocks)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(b),
                                      selected: _blockFilter == b,
                                      onSelected: (_) =>
                                          setState(() => _blockFilter = b),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: GuardTokens.g2),
                        ],
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No flats match your search.',
                                style: GuardTokens.bodyStyle(context),
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 130,
                              mainAxisExtent: 58,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final f = visible[i];
                              final subtitle = f.residents.length == 1
                                  ? f.residents.first.name
                                  : '${f.residents.length} residents';
                              return GuardFlatGridTile(
                                label: f.label.replaceFirst(
                                  RegExp(r'^Flat\s+', caseSensitive: false),
                                  '',
                                ),
                                subtitle: subtitle,
                                selected: false,
                                onTap: () => _openFlatSheet(f),
                              ).animate(
                                delay: DesignAnimations.staggerFor(i),
                              ).fadeIn(duration: 200.ms).slideY(begin: 0.04);
                            },
                          ),
                      ],
                    ),
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

class _ResidentActionCard extends StatelessWidget {
  const _ResidentActionCard({
    required this.row,
    required this.initials,
    required this.index,
  });

  final ResidentDirectoryRow row;
  final String initials;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        side: BorderSide(
          color: isDark
              ? GuardTokens.darkBorder.withValues(alpha: 0.85)
              : GuardTokens.borderSubtle.withValues(alpha: 0.9),
        ),
      ),
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
              radius: 22,
              backgroundColor: GuardTokens.guardAccent.withValues(alpha: 0.16),
              foregroundColor: GuardTokens.guardAccentDeep,
              child: Text(
                initials,
                style: TextStyle(
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
                    style: GuardTokens.headingStyle(context).copyWith(
                      fontSize: GuardTokens.body + 1,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (row.phoneMasked != null &&
                      row.phoneMasked!.trim().isNotEmpty)
                    Text(
                      row.phoneMasked!,
                      style: GuardTokens.captionStyle(context),
                    ),
                ],
              ),
            ),
            IconButton.filledTonal(
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () {
                final residentPhone = row.phone?.trim() ?? '';
                final q = <String, String>{
                  'name': row.name,
                  if (row.villaId != null && row.villaId!.isNotEmpty)
                    'villaId': row.villaId!,
                  if (residentPhone.isNotEmpty) 'residentPhone': residentPhone,
                };
                Navigator.of(context).pop();
                context.push(GuardRoutes.visitorApprovalWithQuery('dir', q));
              },
              icon: Icon(
                Icons.verified_user_outlined,
                color: GuardTokens.guardAccentDeep,
              ),
              tooltip: 'Check in visitor for ${row.name}',
            ),
            IconButton.outlined(
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
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
              icon: Icon(
                Icons.phone_outlined,
                color: GuardTokens.guardAccentDeep,
              ),
              tooltip: 'Call ${row.name}',
            ),
          ],
        ),
      ),
    ).animate(delay: DesignAnimations.staggerFor(index))
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.04);
  }
}
