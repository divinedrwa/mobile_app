import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_skeletons.dart';

/// Read-only list of society-approved internal vehicles for gate verification.
class GuardApprovedVehiclesPage extends ConsumerStatefulWidget {
  const GuardApprovedVehiclesPage({super.key});

  @override
  ConsumerState<GuardApprovedVehiclesPage> createState() =>
      _GuardApprovedVehiclesPageState();
}

class _GuardApprovedVehiclesPageState extends ConsumerState<GuardApprovedVehiclesPage> {
  final _query = TextEditingController();
  String _debouncedQuery = '';
  String _category = 'ALL';
  String _vehicleType = 'ALL';
  Timer? _debounceTimer;

  String get _filterKey => '$_debouncedQuery|$_category|$_vehicleType';

  bool get _hasActiveFilters =>
      _debouncedQuery.isNotEmpty ||
      _category != 'ALL' ||
      _vehicleType != 'ALL';

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

  void _clearFilters() {
    _query.clear();
    setState(() {
      _debouncedQuery = '';
      _category = 'ALL';
      _vehicleType = 'ALL';
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(guardApprovedVehiclesProvider(_filterKey));

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Approved vehicles',
            style: GuardTokens.headingStyle(context),
          ),
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
                    icon: Icons.verified_user_rounded,
                    title: 'Internal registry',
                    subtitle:
                        'Search plate, last digits (5670), villa, slot, or owner label',
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  TextField(
                    controller: _query,
                    decoration: InputDecoration(
                      hintText: 'Plate, digits, villa, slot…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _query.clear();
                                setState(() => _debouncedQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          GuardTokens.radiusButton,
                        ),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    inputFormatters: [LengthLimitingTextInputFormatter(24)],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: GuardTokens.g2),
                  _FilterRow(
                    label: 'Category',
                    chips: const [
                      ('ALL', 'All'),
                      ('RESIDENT', 'Resident'),
                      ('VISITOR', 'Visitor'),
                      ('OTHER', 'Other'),
                    ],
                    selected: _category,
                    onSelected: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: GuardTokens.g1),
                  _FilterRow(
                    label: 'Type',
                    chips: const [
                      ('ALL', 'All'),
                      ('TWO_WHEELER', '2W'),
                      ('FOUR_WHEELER', '4W'),
                      ('BICYCLE', 'Cycle'),
                    ],
                    selected: _vehicleType,
                    onSelected: (v) => setState(() => _vehicleType = v),
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: GuardTokens.g1),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                        label: const Text('Clear filters'),
                      ),
                    ),
                  ],
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
                        guardApprovedVehiclesProvider(_filterKey),
                      ),
                    ),
                  ),
                ),
                data: (result) {
                  final rows = result.vehicles;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          GuardTokens.padScreen,
                          GuardTokens.g2,
                          GuardTokens.padScreen,
                          0,
                        ),
                        child: Text(
                          _resultLabel(result),
                          style: GuardTokens.bodyStyle(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: GuardTokens.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: rows.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    GuardTokens.padScreen,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.directions_car_filled_outlined,
                                        size: 52,
                                        color: GuardTokens.textSecondary
                                            .withValues(alpha: 0.85),
                                      ),
                                      const SizedBox(height: GuardTokens.g2),
                                      Text(
                                        'No matches',
                                        style: GuardTokens.headingStyle(context),
                                      ),
                                      const SizedBox(height: GuardTokens.g1),
                                      Text(
                                        'Try different digits, villa, or filters.',
                                        textAlign: TextAlign.center,
                                        style: GuardTokens.bodyStyle(context),
                                      ),
                                      if (_hasActiveFilters) ...[
                                        const SizedBox(height: GuardTokens.g2),
                                        OutlinedButton(
                                          onPressed: _clearFilters,
                                          child: const Text('Clear filters'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(
                                    guardApprovedVehiclesProvider(_filterKey),
                                  );
                                  await ref.read(
                                    guardApprovedVehiclesProvider(_filterKey)
                                        .future,
                                  );
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    GuardTokens.padScreen,
                                    GuardTokens.g2,
                                    GuardTokens.padScreen,
                                    GuardTokens.g3,
                                  ),
                                  itemCount: rows.length,
                                  itemBuilder: (_, i) => _VehicleCard(
                                    row: rows[i],
                                    highlightQuery: _debouncedQuery,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultLabel(GuardApprovedVehiclesData result) {
    if (_hasActiveFilters) {
      if (result.total > result.count) {
        return 'Showing ${result.count} of ${result.total} matches';
      }
      return '${result.count} match${result.count == 1 ? '' : 'es'}';
    }
    return '${result.total} approved vehicle${result.total == 1 ? '' : 's'}';
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.chips,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, String)> chips;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GuardTokens.bodyStyle(context).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GuardTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(chip.$2),
                    selected: selected == chip.$1,
                    onSelected: (_) => onSelected(chip.$1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.row,
    required this.highlightQuery,
  });

  final GuardApprovedVehicleRow row;
  final String highlightQuery;

  Color _categoryColor(BuildContext context) {
    switch (row.registrationCategory.toUpperCase()) {
      case 'VISITOR':
        return GuardTokens.warning;
      case 'OTHER':
        return const Color(0xFF6D28D9);
      default:
        return GuardTokens.success;
    }
  }

  IconData _vehicleIcon() {
    switch ((row.vehicleType ?? '').toUpperCase()) {
      case 'TWO_WHEELER':
        return Icons.two_wheeler;
      case 'BICYCLE':
        return Icons.pedal_bike;
      case 'FOUR_WHEELER':
        return Icons.directions_car_outlined;
      default:
        return Icons.directions_car_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: GuardTokens.g2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.g2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _categoryColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_vehicleIcon(), color: _categoryColor(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          row.registrationNumber,
                          style: GuardTokens.headingStyle(context).copyWith(
                            fontSize: 18,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _categoryColor(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          row.categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _categoryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (row.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(row.subtitle, style: GuardTokens.bodyStyle(context)),
                  ],
                  if (row.notes != null && row.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.notes!.trim(),
                      style: GuardTokens.bodyStyle(context).copyWith(
                        color: GuardTokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
