import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/widgets/enterprise_ui.dart';

class AdminIncidentsScreen extends ConsumerStatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  ConsumerState<AdminIncidentsScreen> createState() =>
      _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends ConsumerState<AdminIncidentsScreen> {
  String? _severityFilter;

  Future<void> _refresh() async {
    ref.invalidate(adminIncidentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(adminIncidentsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Incident Reports',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: incidentsAsync.when(
          loading: () => const _IncidentsSkeleton(),
          error: (e, _) => Center(
            child: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Failed to load incidents',
              subtitle: userFacingMessage(e),
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (data) {
            final incidents =
                (data['incidents'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];
            final total = data['total'] as int? ?? incidents.length;

            if (incidents.isEmpty) {
              return Center(
                child: EmptyStateWidget(
                  icon: Icons.report_outlined,
                  title: 'No incidents reported',
                  subtitle:
                      'Incident reports from guards will appear here.',
                ),
              );
            }

            final filtered = _applyFilter(incidents);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        '$total total incidents',
                        style: DesignTypography.bodySmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _filterChip('All', null),
                      const SizedBox(width: 8),
                      _filterChip('Critical', 'CRITICAL'),
                      const SizedBox(width: 8),
                      _filterChip('High', 'HIGH'),
                      const SizedBox(width: 8),
                      _filterChip('Medium', 'MEDIUM'),
                      const SizedBox(width: 8),
                      _filterChip('Low', 'LOW'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: EmptyStateWidget(
                            icon: Icons.filter_list_off,
                            title: 'No matches',
                            subtitle: 'Try a different severity filter.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _IncidentCard(
                            incident: filtered[i],
                            onResolved: _refresh,
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? severity) {
    final selected = _severityFilter == severity;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _severityFilter = severity),
    );
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> incidents,
  ) {
    if (_severityFilter == null) return incidents;
    return incidents
        .where((i) =>
            (i['severity']?.toString() ?? '').toUpperCase() == _severityFilter)
        .toList();
  }
}

class _IncidentCard extends ConsumerWidget {
  const _IncidentCard({
    required this.incident,
    required this.onResolved,
  });

  final Map<String, dynamic> incident;
  final Future<void> Function() onResolved;

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final id = incident['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as resolved?'),
        content: const Text(
          'This incident will be marked resolved for your records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(adminIncidentRepositoryProvider).resolveIncident(id);
      ref.invalidate(adminIncidentsProvider);
      await onResolved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident marked as resolved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingMessage(e)),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = incident['title']?.toString() ?? 'Untitled';
    final description = incident['description']?.toString() ?? '';
    final severity =
        (incident['severity']?.toString() ?? 'MEDIUM').toUpperCase();
    final location = incident['location']?.toString() ?? '';
    final guard = incident['guard'] is Map ? incident['guard'] as Map : {};
    final guardName = guard['name']?.toString() ?? 'Unknown';
    final resolved = incident['resolvedAt'] != null;

    final Color sevColor;
    final IconData sevIcon;
    switch (severity) {
      case 'CRITICAL':
        sevColor = const Color(0xFFDC2626);
        sevIcon = Icons.error_rounded;
      case 'HIGH':
        sevColor = const Color(0xFFEA580C);
        sevIcon = Icons.warning_rounded;
      case 'LOW':
        sevColor = const Color(0xFF16A34A);
        sevIcon = Icons.info_rounded;
      default:
        sevColor = const Color(0xFFCA8A04);
        sevIcon = Icons.warning_amber_rounded;
    }

    String timeStr = '';
    final created = incident['createdAt'];
    if (created != null) {
      final dt = DateTime.tryParse(created.toString());
      if (dt != null) {
        timeStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(sevIcon, color: sevColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: DesignTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reported by $guardName',
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: DesignColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: DesignTypography.bodySmall.copyWith(
                              color: DesignColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _severityLabel(severity),
                        style: DesignTypography.bodySmall.copyWith(
                          color: sevColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (resolved) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                    ] else ...[
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _resolve(context, ref),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Resolve'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _severityLabel(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return 'Critical';
      case 'HIGH':
        return 'High';
      case 'LOW':
        return 'Low';
      default:
        return 'Medium';
    }
  }
}

class _IncidentsSkeleton extends StatelessWidget {
  const _IncidentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerBox(height: 100, borderRadius: 12),
        ),
      ),
    );
  }
}
