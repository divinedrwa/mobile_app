import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
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
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Report incident'),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _IncidentCard(
                            incident: filtered[i],
                            onResolved: _refresh,
                            onTap: () => _openForm(existing: filtered[i]),
                          ).animate(delay: DesignAnimations.staggerFor(i)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IncidentFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    ref.invalidate(adminIncidentsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (result) {
        'deleted' => 'Incident deleted',
        'updated' => 'Incident updated',
        _ => 'Incident reported',
      }),
      behavior: SnackBarBehavior.floating,
    ));
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
    this.onTap,
  });

  final Map<String, dynamic> incident;
  final Future<void> Function() onResolved;
  final VoidCallback? onTap;

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final id = incident['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: DesignColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_outline_rounded, color: DesignColors.primary, size: 28)),
              SizedBox(height: 16),
              Text('Mark as resolved?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text('This incident will be marked resolved for your records.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.primary, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
        sevColor = DesignColors.error;
        sevIcon = Icons.error_rounded;
      case 'HIGH':
        sevColor = const Color(0xFFEA580C);
        sevIcon = Icons.warning_rounded;
      case 'LOW':
        sevColor = DesignColors.accent;
        sevIcon = Icons.info_rounded;
      default:
        sevColor = const Color(0xFFCA8A04);
        sevIcon = Icons.warning_amber_rounded;
    }

    String timeStr = '';
    final created = incident['createdAt'];
    if (created != null) {
      final dt = DateTime.tryParse(created.toString())?.toLocal();
      if (dt != null) {
        timeStr =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
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
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: DesignColors.accent,
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

/// Pops 'created', 'updated' or 'deleted' on success.
class _IncidentFormSheet extends ConsumerStatefulWidget {
  const _IncidentFormSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_IncidentFormSheet> createState() => _IncidentFormSheetState();
}

class _IncidentFormSheetState extends ConsumerState<_IncidentFormSheet> {
  static const _severities = <String, String>{
    'LOW': 'Low',
    'MEDIUM': 'Medium',
    'HIGH': 'High',
    'CRITICAL': 'Critical',
  };

  final _formKey = GlobalKey<FormState>();
  late final _title =
      TextEditingController(text: widget.existing?['title']?.toString() ?? '');
  late final _description = TextEditingController(
      text: widget.existing?['description']?.toString() ?? '');
  late final _location = TextEditingController(
      text: widget.existing?['location']?.toString() ?? '');
  late String _severity = _severities.containsKey(widget.existing?['severity'])
      ? widget.existing!['severity'] as String
      : 'MEDIUM';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  String get _id => widget.existing?['id']?.toString() ?? '';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(adminIncidentRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateIncident(
          _id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          severity: _severity,
          location: _location.text,
        );
      } else {
        await repo.createIncident(
          title: _title.text.trim(),
          description: _description.text.trim(),
          severity: _severity,
          location: _location.text,
        );
      }
      if (mounted) Navigator.pop(context, _isEdit ? 'updated' : 'created');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete incident?'),
        content: const Text('This removes the incident report permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: DesignColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminIncidentRepositoryProvider).deleteIncident(_id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Text(_isEdit ? 'Edit incident' : 'Report incident',
                  style: DesignTypography.headingM),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'At least 3 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'At least 10 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: _severities.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: DesignColors.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy
                    ? 'Saving…'
                    : (_isEdit ? 'Save changes' : 'Report incident')),
              ),
              if (_isEdit)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: DesignColors.error),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete incident'),
                ),
            ],
          ),
        ),
      ),
    );
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
