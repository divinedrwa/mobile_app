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

class AdminPatrolsScreen extends ConsumerStatefulWidget {
  const AdminPatrolsScreen({super.key});

  @override
  ConsumerState<AdminPatrolsScreen> createState() =>
      _AdminPatrolsScreenState();
}

class _AdminPatrolsScreenState extends ConsumerState<AdminPatrolsScreen> {
  String? _statusFilter;
  String _search = '';

  Future<void> _refresh() async {
    ref.invalidate(adminPatrolsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final patrolsAsync = ref.watch(adminPatrolsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Guard Patrols',
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
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Schedule patrol'),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: patrolsAsync.when(
          loading: () => const _PatrolsSkeleton(),
          error: (e, _) => Center(
            child: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Failed to load patrols',
              subtitle: userFacingMessage(e),
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (patrols) {
            if (patrols.isEmpty) {
              return Center(
                child: EmptyStateWidget(
                  icon: Icons.shield_outlined,
                  title: 'No patrols yet',
                  subtitle: 'Tap "Schedule patrol" to assign one to a guard.',
                ),
              );
            }

            final filtered = _applyFilters(patrols);

            return Column(
              children: [
                // Search + filter chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by guard, location...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: DesignColors.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
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
                      _filterChip('In Progress', 'IN_PROGRESS'),
                      const SizedBox(width: 8),
                      _filterChip('Completed', 'COMPLETED'),
                      const SizedBox(width: 8),
                      _filterChip('Scheduled', 'SCHEDULED'),
                      const SizedBox(width: 8),
                      _filterChip('Missed', 'MISSED'),
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
                            subtitle: 'Try different search or filter.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _PatrolCard(
                            patrol: filtered[i],
                            onStatusUpdated: _refresh,
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
      builder: (_) => _PatrolFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    ref.invalidate(adminPatrolsProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(switch (result) {
        'deleted' => 'Patrol deleted',
        'updated' => 'Patrol updated',
        _ => 'Patrol scheduled',
      }),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _filterChip(String label, String? status) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> patrols,
  ) {
    var list = patrols;
    if (_statusFilter != null) {
      list = list
          .where((p) =>
              (p['status']?.toString() ?? '').toUpperCase() == _statusFilter)
          .toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) {
        final guard = p['guard'] is Map ? p['guard'] as Map : {};
        final guardName = (guard['name'] ?? '').toString().toLowerCase();
        final location =
            (p['checkpointLocation'] ?? '').toString().toLowerCase();
        final checkpoint =
            (p['checkpointName'] ?? '').toString().toLowerCase();
        return guardName.contains(q) ||
            location.contains(q) ||
            checkpoint.contains(q);
      }).toList();
    }
    return list;
  }
}

class _PatrolCard extends ConsumerWidget {
  const _PatrolCard({
    required this.patrol,
    required this.onStatusUpdated,
    this.onTap,
  });

  final Map<String, dynamic> patrol;
  final Future<void> Function() onStatusUpdated;
  final VoidCallback? onTap;

  bool get _canUpdateStatus {
    final status = (patrol['status'] ?? '').toString().toUpperCase();
    return status == 'SCHEDULED' || status == 'IN_PROGRESS';
  }

  Future<void> _showStatusSheet(BuildContext context, WidgetRef ref) async {
    final id = patrol['id']?.toString();
    if (id == null || id.isEmpty || !_canUpdateStatus) return;

    final status = (patrol['status'] ?? '').toString().toUpperCase();
    final options = <String, String>{};
    if (status == 'SCHEDULED') {
      options['IN_PROGRESS'] = 'Mark in progress';
      options['COMPLETED'] = 'Mark completed';
      options['MISSED'] = 'Mark missed';
    } else if (status == 'IN_PROGRESS') {
      options['COMPLETED'] = 'Mark completed';
      options['MISSED'] = 'Mark missed';
    }
    if (options.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Update patrol status', style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              ...options.entries.map((e) => InkWell(
                onTap: () => Navigator.of(ctx).pop(e.key),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Row(
                    children: [
                      Container(width: 36, height: 36,
                          decoration: BoxDecoration(color: DesignColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.shield_outlined, color: DesignColors.primary, size: 18)),
                      SizedBox(width: 12),
                      Expanded(child: Text(e.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DesignColors.textPrimary))),
                      Icon(Icons.chevron_right_rounded, color: DesignColors.textTertiary, size: 20),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    try {
      await ref
          .read(adminPatrolRepositoryProvider)
          .updatePatrolStatus(id, status: selected);
      ref.invalidate(adminPatrolsProvider);
      await onStatusUpdated();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patrol marked as ${_statusLabel(selected)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingMessage(e)),
            backgroundColor: DesignColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = (patrol['status'] ?? '').toString().toUpperCase();
    final checkpoint = patrol['checkpointName']?.toString() ?? '';
    final location = patrol['checkpointLocation']?.toString() ?? '';
    final notes = patrol['notes']?.toString() ?? '';
    final guard = patrol['guard'] is Map ? patrol['guard'] as Map : {};
    final guardName = guard['name']?.toString() ?? 'Unknown';
    final gate = patrol['gate'] is Map ? patrol['gate'] as Map : {};
    final gateName = gate['name']?.toString() ?? '';

    final Color statusColor;
    final IconData statusIcon;
    switch (status) {
      case 'IN_PROGRESS':
        statusColor = DesignColors.primary;
        statusIcon = Icons.directions_walk_rounded;
      case 'COMPLETED':
        statusColor = DesignColors.accent;
        statusIcon = Icons.check_circle_rounded;
      case 'MISSED':
        statusColor = DesignColors.error;
        statusIcon = Icons.cancel_rounded;
      default:
        statusColor = DesignColors.textSecondary;
        statusIcon = Icons.schedule_rounded;
    }

    final timeRaw = patrol['scheduledTime'] ?? patrol['actualTime'];
    String timeStr = '';
    if (timeRaw != null) {
      final dt = DateTime.tryParse(timeRaw.toString())?.toLocal();
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
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checkpoint.isNotEmpty ? checkpoint : 'Patrol',
                    style: DesignTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: DesignColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guardName + (gateName.isNotEmpty ? ' · $gateName' : ''),
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: DesignTypography.bodySmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (_canUpdateStatus) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showStatusSheet(context, ref),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Update'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return 'In Progress';
      case 'COMPLETED':
        return 'Completed';
      case 'MISSED':
        return 'Missed';
      case 'SCHEDULED':
        return 'Scheduled';
      default:
        return status;
    }
  }
}

/// Pops 'created', 'updated' or 'deleted' on success. Guard and gate are
/// fixed once scheduled (same as the web panel).
class _PatrolFormSheet extends ConsumerStatefulWidget {
  const _PatrolFormSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_PatrolFormSheet> createState() => _PatrolFormSheetState();
}

class _PatrolFormSheetState extends ConsumerState<_PatrolFormSheet> {
  late final _checkpoint = TextEditingController(
      text: widget.existing?['checkpointName']?.toString() ?? '');
  late final _location = TextEditingController(
      text: widget.existing?['checkpointLocation']?.toString() ?? '');
  late final _notes =
      TextEditingController(text: widget.existing?['notes']?.toString() ?? '');
  late DateTime _scheduled = DateTime.tryParse(
              widget.existing?['scheduledTime']?.toString() ?? '')
          ?.toLocal() ??
      DateTime.now().add(const Duration(hours: 1));
  String? _guardId;
  String? _gateId;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  String get _id => widget.existing?['id']?.toString() ?? '';

  @override
  void dispose() {
    _checkpoint.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final earliest = DateTime.now().subtract(const Duration(days: 30));
    final latest = DateTime.now().add(const Duration(days: 365));
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled,
      firstDate: _scheduled.isBefore(earliest) ? _scheduled : earliest,
      lastDate: _scheduled.isAfter(latest) ? _scheduled : latest,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled),
    );
    if (time == null) return;
    setState(() => _scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_checkpoint.text.trim().length < 2) {
      setState(() => _error = 'Enter the checkpoint name');
      return;
    }
    if (!_isEdit && (_guardId == null || _gateId == null)) {
      setState(() => _error = 'Select a guard and a gate');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(adminPatrolRepositoryProvider);
    final when = _scheduled.toUtc().toIso8601String();
    try {
      if (_isEdit) {
        await repo.updatePatrol(
          _id,
          checkpointName: _checkpoint.text.trim(),
          checkpointLocation: _location.text,
          scheduledTime: when,
          notes: _notes.text,
        );
      } else {
        await repo.createPatrol(
          guardId: _guardId!,
          gateId: _gateId!,
          checkpointName: _checkpoint.text.trim(),
          checkpointLocation: _location.text,
          scheduledTime: when,
          notes: _notes.text,
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
        title: const Text('Delete patrol?'),
        content: const Text('This removes the patrol permanently.'),
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
      await ref.read(adminPatrolRepositoryProvider).deletePatrol(_id);
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
    final guards = ref.watch(adminGuardsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final gates = ref.watch(adminGatesProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final when =
        '${_scheduled.day.toString().padLeft(2, '0')}/${_scheduled.month.toString().padLeft(2, '0')}/${_scheduled.year} '
        '${_scheduled.hour.toString().padLeft(2, '0')}:${_scheduled.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(_isEdit ? 'Edit patrol' : 'Schedule patrol',
                style: DesignTypography.headingM),
            const SizedBox(height: 16),
            if (!_isEdit) ...[
              DropdownButtonFormField<String>(
                initialValue: _guardId,
                decoration: const InputDecoration(labelText: 'Guard *'),
                items: guards
                    .map((g) => DropdownMenuItem(
                          value: g['id']?.toString(),
                          child: Text(g['name']?.toString() ?? 'Guard'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _guardId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gateId,
                decoration: const InputDecoration(labelText: 'Gate *'),
                items: gates
                    .map((g) => DropdownMenuItem(
                          value: g['id']?.toString(),
                          child: Text(g['name']?.toString() ?? 'Gate'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _gateId = v),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _checkpoint,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Checkpoint *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Scheduled for'),
              subtitle: Text(when),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDateTime,
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
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
                  : (_isEdit ? 'Save changes' : 'Schedule patrol')),
            ),
            if (_isEdit)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: DesignColors.error),
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete patrol'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatrolsSkeleton extends StatelessWidget {
  const _PatrolsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerWrap(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShimmerBox(height: 90, borderRadius: 12),
        ),
      ),
    );
  }
}
