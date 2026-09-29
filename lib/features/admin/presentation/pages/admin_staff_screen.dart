import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing society staff.
class AdminStaffScreen extends ConsumerStatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  ConsumerState<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends ConsumerState<AdminStaffScreen> {
  String? _typeFilter; // null = All
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  static const _staffTypes = [
    'MAID',
    'COOK',
    'DRIVER',
    'NANNY',
    'GARDENER',
    'OTHER',
  ];

  Future<void> _refresh() async {
    ref.invalidate(adminStaffListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(adminStaffListProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Staff',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon:
                Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add staff'),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: staffAsync.when(
          loading: () => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ShimmerWrap(
                child: Column(
                  children: List.generate(
                    6,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                    ),
                  ),
                ),
              ),
            ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load staff',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (staff) => _buildBody(staff),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> staff) {
    // Local filter
    var filtered = _typeFilter == null
        ? staff
        : staff.where((s) =>
            s['type']?.toString().toUpperCase() == _typeFilter).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        final type = (s['type'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            type.contains(_searchQuery);
      }).toList();
    }

    // Count per type
    final typeCounts = <String?, int>{null: staff.length};
    for (final s in staff) {
      final t = s['type']?.toString().toUpperCase();
      typeCounts[t] = (typeCounts[t] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _staffTypes.length + 1, // +1 for "All"
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _chipItem(null, 'All', typeCounts[null] ?? 0);
              }
              final type = _staffTypes[index - 1];
              return _chipItem(
                  type, _formatType(type), typeCounts[type] ?? 0);
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminSearchField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          hint: 'Search by name, phone…',
        ),
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.badge_outlined,
              title: 'No staff found',
              subtitle: _typeFilter != null
                  ? 'No staff match the selected filter.'
                  : 'Staff members will appear here once added.',
              iconColor: DesignColors.success,
            ),
          )
        else
          ...filtered.asMap().entries.map((e) => _staffCard(e.value, e.key)),
      ],
    );
  }

  Widget _chipItem(String? type, String label, int count) {
    final isSelected = _typeFilter == type;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = type),
      selectedColor: DesignColors.success,
      backgroundColor: DesignColors.surfaceSoft,
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? DesignColors.success
            : DesignColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignRadius.full)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _staffCard(Map<String, dynamic> staff, [int index = 0]) {
    final name = staff['name']?.toString() ?? '';
    final type = staff['type']?.toString() ?? '';
    final phone = staff['phone']?.toString() ?? '';
    final isActive = staff['isActive'] != false;
    final assignments =
        (staff['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final villaNames = assignments
        .map((a) {
          final villa = a['villa'] as Map<String, dynamic>?;
          return villa?['villaNumber']?.toString() ?? '';
        })
        .where((v) => v.isNotEmpty)
        .toList();

    final typeColor = _typeColor(type.toUpperCase());

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: () => _showDetailSheet(staff),
      child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: DesignTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatType(type),
                          style: DesignTypography.captionSmall.copyWith(
                            color: typeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (phone.isNotEmpty) phone,
                      if (villaNames.isNotEmpty)
                        'Villas: ${villaNames.join(', ')}',
                    ].join(' \u00b7 '),
                    style: DesignTypography.captionSmall
                        .copyWith(color: DesignColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isActive)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: DesignColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _showDetailSheet(Map<String, dynamic> staff) {
    final name = staff['name']?.toString() ?? '';
    final type = staff['type']?.toString() ?? '';
    final phone = staff['phone']?.toString() ?? '';
    final address = staff['address']?.toString();
    final isActive = staff['isActive'] != false;
    final assignments =
        (staff['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: DesignTypography.headingM),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? DesignColors.primary.withValues(alpha: 0.12)
                          : DesignColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DesignRadius.full),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Inactive',
                      style: DesignTypography.labelSmall.copyWith(
                        color:
                            isActive ? DesignColors.primary : DesignColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _detailRow(Icons.work_outline, 'Type', _formatType(type)),
              if (phone.isNotEmpty)
                _detailRow(Icons.phone_outlined, 'Phone', phone),
              if (address != null && address.isNotEmpty)
                _detailRow(Icons.location_on_outlined, 'Address', address),
              if (assignments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Assigned Villas',
                    style: DesignTypography.labelSmall
                        .copyWith(color: DesignColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: assignments.map((a) {
                    final villa = a['villa'] as Map<String, dynamic>?;
                    final villaNum =
                        villa?['villaNumber']?.toString() ?? 'N/A';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesignColors.surfaceSoft,
                        borderRadius:
                            BorderRadius.circular(DesignRadius.full),
                        border:
                            Border.all(color: DesignColors.borderLight),
                      ),
                      child: Text('Villa $villaNum',
                          style: DesignTypography.captionSmall.copyWith(
                              fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: isActive
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DesignColors.error,
                          side: BorderSide(color: DesignColors.error),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _removeStaff(staff);
                        },
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Remove staff'),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _reactivateStaff(staff);
                        },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reactivate'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? DesignColors.error : null,
      ),
    );
  }

  Future<void> _removeStaff(Map<String, dynamic> staff) async {
    final id = staff['id']?.toString();
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text(
          '${staff['name'] ?? 'This staff member'} will be marked inactive and '
          'unassigned from all villas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: DesignColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminStaffRepositoryProvider).deactivateStaff(id);
      ref.invalidate(adminStaffListProvider);
      _toast('Staff member removed');
    } catch (e) {
      _toast(userFacingMessage(e), error: true);
    }
  }

  Future<void> _reactivateStaff(Map<String, dynamic> staff) async {
    final id = staff['id']?.toString();
    if (id == null) return;
    try {
      await ref.read(adminStaffRepositoryProvider).updateStaff(id, isActive: true);
      ref.invalidate(adminStaffListProvider);
      _toast('Staff member reactivated. Assign villas again if needed.');
    } catch (e) {
      _toast(userFacingMessage(e), error: true);
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateStaffSheet(staffTypes: _staffTypes),
    );
    if (created == true) {
      ref.invalidate(adminStaffListProvider);
      _toast('Staff registered');
    }
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DesignColors.textTertiary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textTertiary)),
          Expanded(
            child: Text(value,
                style: DesignTypography.bodySmall
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static String _formatType(String type) {
    if (type.isEmpty) return '';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'MAID':
        return DesignColors.primary;
      case 'COOK':
        return const Color(0xFFF97316);
      case 'DRIVER':
        return DesignColors.info;
      case 'NANNY':
        return const Color(0xFFEC4899);
      case 'GARDENER':
        return DesignColors.success;
      default:
        return DesignColors.success;
    }
  }
}

class _CreateStaffSheet extends ConsumerStatefulWidget {
  const _CreateStaffSheet({required this.staffTypes});

  final List<String> staffTypes;

  @override
  ConsumerState<_CreateStaffSheet> createState() => _CreateStaffSheetState();
}

class _CreateStaffSheetState extends ConsumerState<_CreateStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _villaSearch = TextEditingController();
  late String _type = widget.staffTypes.first;
  final Set<String> _villaIds = {};
  String _villaQuery = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _villaSearch.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_villaIds.isEmpty) {
      setState(() => _error = 'Select at least one villa');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(adminStaffRepositoryProvider).createStaff(
            name: _name.text.trim(),
            type: _type,
            phone: _phone.text.trim(),
            villaIds: _villaIds.toList(),
            address: _address.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  static String _villaLabel(Map<String, dynamic> v) {
    final num = v['villaNumber']?.toString().trim() ?? '';
    final block = v['block']?.toString().trim() ?? '';
    return block.isNotEmpty && num.isNotEmpty ? '$block · $num' : num;
  }

  @override
  Widget build(BuildContext context) {
    final villasAsync = ref.watch(adminVillasProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
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
              Text('Register staff', style: DesignTypography.headingM),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone *'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  return (t.length < 10 || t.length > 15)
                      ? 'Enter a 10–15 digit phone number'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type *'),
                items: widget.staffTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0] + t.substring(1).toLowerCase()),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 16),
              Text(
                'Villas * (${_villaIds.length} selected)',
                style: DesignTypography.label.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AdminSearchField(
                controller: _villaSearch,
                hint: 'Search villa…',
                onChanged: (v) => setState(() => _villaQuery = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 4),
              villasAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Could not load villas',
                  style: TextStyle(color: DesignColors.error),
                ),
                data: (villas) {
                  final filtered = villas.where((v) {
                    if (_villaQuery.isEmpty) return true;
                    final hay = '${v['villaNumber']} ${v['block']} ${v['ownerName']}'
                        .toLowerCase();
                    return hay.contains(_villaQuery);
                  }).toList();
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: filtered.map((v) {
                        final id = v['id']?.toString() ?? '';
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _villaIds.contains(id),
                          title: Text(_villaLabel(v)),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _villaIds.add(id);
                            } else {
                              _villaIds.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: DesignColors.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Saving…' : 'Register staff'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
