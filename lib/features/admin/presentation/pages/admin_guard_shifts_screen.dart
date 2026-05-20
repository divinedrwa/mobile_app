import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/widgets/enterprise_ui.dart';

/// Admin screen for managing guard shifts.
class AdminGuardShiftsScreen extends ConsumerStatefulWidget {
  const AdminGuardShiftsScreen({super.key});

  @override
  ConsumerState<AdminGuardShiftsScreen> createState() =>
      _AdminGuardShiftsScreenState();
}

class _AdminGuardShiftsScreenState
    extends ConsumerState<AdminGuardShiftsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminGuardShiftsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(adminGuardShiftsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Guard Shifts',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon:
                const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0EA5E9),
        onPressed: () => _showCreateSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: shiftsAsync.when(
          loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: ShimmerWrap(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 20, width: 120, borderRadius: DesignRadius.sm),
                    const SizedBox(height: 12),
                    ...List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                    )),
                  ],
                ),
              ),
            ),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: EmptyStateWidget(
                icon: Icons.error_outline_rounded,
                title: 'Failed to load shifts',
                subtitle: userFacingMessage(e),
                iconColor: DesignColors.error,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            ),
          ]),
          data: (shifts) => _buildBody(shifts),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> shifts) {
    if (shifts.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: EmptyStateWidget(
            icon: Icons.schedule_rounded,
            title: 'No shifts configured',
            subtitle: 'Tap + to create a new shift for your guards.',
            iconColor: const Color(0xFF0EA5E9),
          ),
        ),
      ]);
    }

    // Group shifts by gate
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in shifts) {
      final gate = s['gate'] as Map<String, dynamic>?;
      final gateName = gate?['name']?.toString() ?? 'Unassigned';
      grouped.putIfAbsent(gateName, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: grouped.entries.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: EnterpriseSectionHeader(
              title: entry.key,
              subtitle: '${entry.value.length} shift${entry.value.length == 1 ? '' : 's'}',
            ),
          ),
          ...entry.value.map(_shiftCard),
        ];
      }).toList(),
    );
  }

  Widget _shiftCard(Map<String, dynamic> shift) {
    final id = shift['id']?.toString() ?? '';
    final guard = shift['guard'] as Map<String, dynamic>?;
    final guardName =
        guard?['name']?.toString() ?? guard?['username']?.toString() ?? 'Unknown';
    final shiftType = shift['shiftType']?.toString() ?? '';
    final startDt = DateTime.tryParse(shift['startTime']?.toString() ?? '');
    final endDt = DateTime.tryParse(shift['endTime']?.toString() ?? '');
    final isRecurring = shift['isRecurring'] == true;

    final typeConfig = _shiftTypeConfig(shiftType);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: typeConfig.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeConfig.icon, color: typeConfig.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(guardName,
                          style: DesignTypography.label
                              .copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: typeConfig.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeConfig.label,
                        style: DesignTypography.captionSmall.copyWith(
                          color: typeConfig.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: DesignColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTimeOfDay(startDt)} - ${_formatTimeOfDay(endDt)}',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                    ),
                    if (isRecurring) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.repeat,
                          size: 12, color: DesignColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('Recurring',
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textTertiary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 20, color: DesignColors.textTertiary),
            onSelected: (v) {
              if (v == 'edit') _showEditSheet(context, shift);
              if (v == 'delete') _confirmDelete(id);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shift'),
        content: const Text('Are you sure you want to delete this shift?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(adminGuardShiftRepositoryProvider)
                    .deleteShift(id);
                ref.invalidate(adminGuardShiftsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Shift deleted'),
                    backgroundColor: DesignColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(userFacingMessage(e)),
                    backgroundColor: DesignColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShiftFormSheet(onSaved: _refresh),
    );
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> shift) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShiftFormSheet(shift: shift, onSaved: _refresh),
    );
  }

  static _ShiftType _shiftTypeConfig(String type) {
    switch (type.toUpperCase()) {
      case 'MORNING':
        return const _ShiftType(
            'Morning', Icons.wb_sunny_outlined, Color(0xFFF59E0B));
      case 'AFTERNOON':
        return const _ShiftType(
            'Afternoon', Icons.wb_sunny, Color(0xFFF97316));
      case 'EVENING':
        return const _ShiftType(
            'Evening', Icons.wb_twilight, Color(0xFF8B5CF6));
      case 'NIGHT':
        return const _ShiftType(
            'Night', Icons.nights_stay_outlined, Color(0xFF3B82F6));
      default:
        return const _ShiftType(
            'Shift', Icons.schedule, Color(0xFF0EA5E9));
    }
  }

  /// Format a DateTime to a readable time string (e.g. "06:00 AM").
  static String _formatTimeOfDay(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    final h = local.hour;
    final m = local.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }
}

class _ShiftType {
  const _ShiftType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

// ═══════════════════════════════════════════════════════════════════════
// Create / Edit Shift Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _ShiftFormSheet extends ConsumerStatefulWidget {
  const _ShiftFormSheet({this.shift, required this.onSaved});

  final Map<String, dynamic>? shift;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends ConsumerState<_ShiftFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _guardId;
  String? _gateId;
  String _shiftType = 'MORNING';
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  bool _isRecurring = false;
  bool _submitting = false;

  bool get _isEdit => widget.shift != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.shift!;
      _guardId = (s['guard'] as Map?)?['id']?.toString() ?? s['guardId']?.toString();
      _gateId = (s['gate'] as Map?)?['id']?.toString() ?? s['gateId']?.toString();
      _shiftType = s['shiftType']?.toString() ?? 'MORNING';
      final startDt = DateTime.tryParse(s['startTime']?.toString() ?? '');
      final endDt = DateTime.tryParse(s['endTime']?.toString() ?? '');
      if (startDt != null) {
        final local = startDt.toLocal();
        _startTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
      if (endDt != null) {
        final local = endDt.toLocal();
        _endTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
      _isRecurring = s['isRecurring'] == true;
    }
  }

  /// Convert a [TimeOfDay] to an ISO 8601 datetime string using today's date.
  String _timeToIso(TimeOfDay t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute)
        .toUtc()
        .toIso8601String();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    if (_guardId == null || _gateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select guard and gate'),
        backgroundColor: DesignColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);

    try {
      final repo = ref.read(adminGuardShiftRepositoryProvider);
      if (_isEdit) {
        await repo.updateShift(
          widget.shift!['id'].toString(),
          guardId: _guardId,
          gateId: _gateId,
          shiftType: _shiftType,
          startTime: _timeToIso(_startTime),
          endTime: _timeToIso(_endTime),
          isRecurring: _isRecurring,
        );
      } else {
        await repo.createShift(
          guardId: _guardId!,
          gateId: _gateId!,
          shiftType: _shiftType,
          startTime: _timeToIso(_startTime),
          endTime: _timeToIso(_endTime),
          isRecurring: _isRecurring,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Shift updated' : 'Shift created'),
        backgroundColor: DesignColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFacingMessage(e)),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardsAsync = ref.watch(adminGuardsProvider);
    final gatesAsync = ref.watch(adminGatesProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: DesignColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_isEdit ? 'Edit Shift' : 'Create Shift',
                    style: DesignTypography.headingM),
                const SizedBox(height: 20),

                // Guard dropdown
                Text('Guard', style: DesignTypography.labelSmall),
                const SizedBox(height: 6),
                guardsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) =>
                      Text('Failed to load guards', style: DesignTypography.bodySmall),
                  data: (guards) => DropdownButtonFormField<String>(
                    value: _guardId,
                    decoration: DesignComponents.inputDecoration(hint: 'Select guard'),
                    items: guards.map((g) {
                      final gid = g['id']?.toString() ?? '';
                      final name = g['name']?.toString() ?? g['username']?.toString() ?? '';
                      return DropdownMenuItem(value: gid, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => _guardId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Gate dropdown
                Text('Gate', style: DesignTypography.labelSmall),
                const SizedBox(height: 6),
                gatesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) =>
                      Text('Failed to load gates', style: DesignTypography.bodySmall),
                  data: (gates) => DropdownButtonFormField<String>(
                    value: _gateId,
                    decoration: DesignComponents.inputDecoration(hint: 'Select gate'),
                    items: gates.map((g) {
                      final gid = g['id']?.toString() ?? '';
                      final name = g['name']?.toString() ?? '';
                      return DropdownMenuItem(value: gid, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => _gateId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Shift type chips
                Text('Shift Type', style: DesignTypography.labelSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['MORNING', 'AFTERNOON', 'EVENING', 'NIGHT']
                      .map((t) => ChoiceChip(
                            label: Text(t[0] + t.substring(1).toLowerCase()),
                            selected: _shiftType == t,
                            onSelected: (_) =>
                                setState(() => _shiftType = t),
                            selectedColor: const Color(0xFF0EA5E9),
                            labelStyle: TextStyle(
                              color: _shiftType == t
                                  ? Colors.white
                                  : DesignColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Time pickers
                Row(
                  children: [
                    Expanded(
                      child: _timePicker('Start', _startTime, () => _pickTime(true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _timePicker('End', _endTime, () => _pickTime(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Recurring toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Recurring', style: DesignTypography.label),
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                  activeTrackColor: const Color(0xFF0EA5E9),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: DesignComponents.primaryButtonStyle.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(
                          Color(0xFF0EA5E9)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEdit ? 'Update' : 'Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: DesignColors.borderLight),
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time,
                size: 16, color: DesignColors.textTertiary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textTertiary)),
                Text(time.format(context),
                    style: DesignTypography.label
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
