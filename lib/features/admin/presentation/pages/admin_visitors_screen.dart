import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin society-wide visitor log.
class AdminVisitorsScreen extends ConsumerStatefulWidget {
  const AdminVisitorsScreen({super.key});

  @override
  ConsumerState<AdminVisitorsScreen> createState() =>
      _AdminVisitorsScreenState();
}

class _AdminVisitorsScreenState extends ConsumerState<AdminVisitorsScreen> {
  final _searchCtl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminVisitorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final visitorsAsync = ref.watch(adminVisitorsProvider);
    final statusFilter = ref.watch(adminVisitorStatusFilterProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Visitors',
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
        onPressed: _openCheckInSheet,
        backgroundColor: DesignColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.how_to_reg_rounded),
        label: const Text('Check in visitor'),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: visitorsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  5,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load visitors',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (data) {
            final visitors = (data['visitors'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                [];
            final todayCount = data['todayCount'] as int? ?? 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.today_outlined,
                          color: DesignColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '$todayCount visitors today',
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AdminSearchField(
                  controller: _searchCtl,
                  hint: 'Search name or phone…',
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      ref.read(adminVisitorSearchProvider.notifier).state = v;
                    });
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', null, statusFilter),
                      _filterChip('Active', 'active', statusFilter),
                      _filterChip('Checked out', 'checked_out', statusFilter),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (visitors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: 'No visitors found',
                      subtitle: 'Try adjusting your search or filters.',
                    ),
                  )
                else
                  ...visitors.map((v) => _visitorTile(v)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? DesignColors.error : null,
    ));
  }

  Future<void> _openCheckInSheet() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdminCheckInSheet(),
    );
    if (done == true) {
      _refresh();
      _toast('Visitor checked in');
    }
  }

  Future<void> _openActions(Map<String, dynamic> v) async {
    final id = v['id']?.toString();
    if (id == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(v['name']?.toString() ?? 'Visitor',
                  style: DesignTypography.headingM),
              subtitle: Text(v['phone']?.toString() ?? ''),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: DesignColors.error),
              title: Text('Delete record',
                  style: TextStyle(color: DesignColors.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete visitor record?'),
        content: const Text(
            'This permanently removes the entry from the visitor log.'),
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
    try {
      await ref.read(adminVisitorRepositoryProvider).deleteVisitor(id);
      _refresh();
      _toast('Visitor record deleted');
    } catch (e) {
      _toast(userFacingMessage(e), error: true);
    }
  }

  Widget _filterChip(String label, String? value, String? current) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          ref.read(adminVisitorStatusFilterProvider.notifier).state = value;
        },
        selectedColor: DesignColors.primary.withValues(alpha: 0.15),
        checkmarkColor: DesignColors.primary,
      ),
    );
  }

  Widget _visitorTile(Map<String, dynamic> v) {
    final name = v['name']?.toString() ?? 'Visitor';
    final phone = v['phone']?.toString() ?? '';
    final purpose = v['purpose']?.toString() ?? '';
    final checkOut = v['checkOutAt'];
    final status = v['status']?.toString().toUpperCase() ?? '';
    final isActive = checkOut == null &&
        (status.isEmpty ||
            status == 'CHECKED_IN' ||
            status == 'PENDING_APPROVAL' ||
            status == 'APPROVED');
    final String badge;
    if (checkOut != null) {
      badge = v['exitNotMarked'] == true ? 'Exit not marked' : 'Out';
    } else if (status == 'PENDING_APPROVAL') {
      badge = 'Waiting';
    } else if (status == 'APPROVED') {
      badge = 'Approved';
    } else if (status == 'DENIED') {
      badge = 'Rejected';
    } else if (status == 'CANCELLED') {
      badge = 'Expired';
    } else {
      badge = 'Inside';
    }
    final gate = v['gate'] is Map
        ? (v['gate'] as Map)['name']?.toString() ?? ''
        : '';

    String timeStr = '';
    try {
      final checkIn = DateTime.parse(v['checkInAt']?.toString() ?? '').toLocal();
      timeStr = DateFormat('d MMM, h:mm a').format(checkIn.toLocal());
    } catch (_) {}

    final villas = <String>[];
    final vv = v['villaVisits'];
    if (vv is List) {
      for (final item in vv) {
        if (item is Map && item['villa'] is Map) {
          final vn = item['villa']['villaNumber']?.toString();
          if (vn != null) villas.add(vn);
        }
      }
    }

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: () => _openActions(v),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isActive ? DesignColors.success : DesignColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive ? Icons.person_outline : Icons.logout,
              color: isActive ? DesignColors.success : DesignColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: DesignTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                      )),
                if (villas.isNotEmpty)
                  Text('Villa: ${villas.join(', ')}',
                      style: DesignTypography.captionSmall),
                if (gate.isNotEmpty || timeStr.isNotEmpty)
                  Text(
                    [gate, timeStr].where((s) => s.isNotEmpty).join(' · '),
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                if (purpose.isNotEmpty)
                  Text(purpose,
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.textSecondary,
                      )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? DesignColors.success : DesignColors.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? DesignColors.success : DesignColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCheckInSheet extends ConsumerStatefulWidget {
  const _AdminCheckInSheet();

  @override
  ConsumerState<_AdminCheckInSheet> createState() => _AdminCheckInSheetState();
}

class _AdminCheckInSheetState extends ConsumerState<_AdminCheckInSheet> {
  static const _types = <String, String>{
    'GUEST': 'Guest',
    'DELIVERY': 'Delivery',
    'CAB': 'Cab',
    'SERVICE_PROVIDER': 'Service provider',
    'VENDOR': 'Vendor',
  };

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  final _purpose = TextEditingController();
  final _villaSearch = TextEditingController();
  final Set<String> _villaIds = {};
  String _type = 'GUEST';
  String? _gateId;
  String _villaQuery = '';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _vehicle, _purpose, _villaSearch]) {
      c.dispose();
    }
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
      await ref.read(adminVisitorRepositoryProvider).checkInVisitor(
            villaIds: _villaIds.toList(),
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            purpose: _purpose.text.trim(),
            visitorType: _type,
            gateId: _gateId,
            vehicleNumber: _vehicle.text,
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

  @override
  Widget build(BuildContext context) {
    final villasAsync = ref.watch(adminVillasProvider);
    final gatesAsync = ref.watch(adminGatesProvider);
    final gates = gatesAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    if (_gateId == null && gates.isNotEmpty) {
      _gateId = gates.first['id']?.toString();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
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
              Text('Check in visitor', style: DesignTypography.headingM),
              const SizedBox(height: 4),
              Text(
                'The visitor is recorded as inside immediately, without resident approval.',
                style: DesignTypography.captionSmall
                    .copyWith(color: DesignColors.textSecondary),
              ),
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
                decoration: const InputDecoration(labelText: 'Visitor type'),
                items: _types.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purpose,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Purpose *'),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'At least 3 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicle,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    const InputDecoration(labelText: 'Vehicle number (optional)'),
              ),
              if (gates.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _gateId,
                  decoration: const InputDecoration(labelText: 'Gate'),
                  items: gates
                      .map((g) => DropdownMenuItem(
                            value: g['id']?.toString(),
                            child: Text(g['name']?.toString() ?? 'Gate'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _gateId = v),
                ),
              ],
              const SizedBox(height: 16),
              Text('Visiting villas * (${_villaIds.length} selected)',
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              AdminSearchField(
                controller: _villaSearch,
                hint: 'Search villa…',
                onChanged: (v) =>
                    setState(() => _villaQuery = v.trim().toLowerCase()),
              ),
              villasAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Text('Could not load villas',
                    style: TextStyle(color: DesignColors.error)),
                data: (villas) {
                  final filtered = villas.where((v) {
                    if (_villaQuery.isEmpty) return true;
                    return '${v['villaNumber']} ${v['block']} ${v['ownerName']}'
                        .toLowerCase()
                        .contains(_villaQuery);
                  }).toList();
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: filtered.map((v) {
                        final id = v['id']?.toString() ?? '';
                        final num = v['villaNumber']?.toString() ?? '';
                        final block = v['block']?.toString() ?? '';
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _villaIds.contains(id),
                          title: Text(block.isNotEmpty ? '$block · $num' : num),
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
                child: Text(_submitting ? 'Checking in…' : 'Check in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
