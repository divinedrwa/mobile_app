import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for viewing all society parcels.
///
/// Shows a pending-count hero, status filter chips, and a flat list
/// of parcels with status badges and a quick-update action.
class AdminParcelsScreen extends ConsumerStatefulWidget {
  const AdminParcelsScreen({super.key});

  @override
  ConsumerState<AdminParcelsScreen> createState() =>
      _AdminParcelsScreenState();
}

class _AdminParcelsScreenState extends ConsumerState<AdminParcelsScreen>
    with WidgetsBindingObserver {
  String? _statusFilter; // null = All
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(adminParcelsProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(adminParcelsProvider);
    try {
      await ref.read(adminParcelsProvider.future);
    } catch (e) {
      debugPrint('AdminParcelsScreen._refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(adminParcelsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Society Parcels',
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
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: parcelsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
            child: ShimmerWrap(
              child: Column(
                children: [
                  const ShimmerBox(height: 100, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 16),
                  const ShimmerBox(height: 56, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 56, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 56, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 56, borderRadius: DesignRadius.md),
                ],
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Failed to load parcels',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (data) => _buildBody(data),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    final rawParcels =
        (data['parcels'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];
    final pendingCount = (data['pendingCount'] as num?)?.toInt() ?? 0;

    // Parse into models for display.
    final allParcels =
        rawParcels.map((e) => _AdminParcel.fromJson(e)).toList();

    // Apply local status filter.
    var filtered = _statusFilter == null
        ? allParcels
        : allParcels.where((p) => p.status == _statusFilter).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.description.toLowerCase().contains(_searchQuery) ||
            p.villaNumber.toLowerCase().contains(_searchQuery) ||
            p.ownerName.toLowerCase().contains(_searchQuery) ||
            p.courier.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        // ── Hero ──
        _buildHero(allParcels.length, pendingCount),
        const SizedBox(height: AppSpacing.lg),

        // ── Filter chips ──
        _buildFilterChips(allParcels),
        const SizedBox(height: AppSpacing.sm),
        AdminSearchField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          hint: 'Search by description, villa, courier…',
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── List ──
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: 'No parcels found',
              subtitle: _statusFilter != null
                  ? 'No parcels match the selected filter.'
                  : 'There are no parcels for this society yet.',
            ),
          )
        else
          ...filtered.asMap().entries.map((e) => _parcelCard(e.value, e.key)),
      ],
    );
  }

  // ── Hero card ───────────────────────────────────────────────────────

  Widget _buildHero(int total, int pending) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: DesignColors.secondaryGradient,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: DesignElevation.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total parcels',
                  style: DesignTypography.headingL
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$pending pending collection',
                  style: DesignTypography.caption
                      .copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pending > 0
                  ? DesignColors.warning.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: pending > 0 ? DesignColors.warning : Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────

  Widget _buildFilterChips(List<_AdminParcel> all) {
    final counts = <String?, int>{null: all.length};
    for (final p in all) {
      counts[p.status] = (counts[p.status] ?? 0) + 1;
    }

    const labels = <String?, String>{
      null: 'All',
      'PENDING': 'Pending',
      'RECEIVED': 'Received',
      'DELIVERED': 'Delivered',
      'COLLECTED': 'Collected',
    };

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = labels.entries.elementAt(index);
          final count = counts[entry.key] ?? 0;
          final isSelected = _statusFilter == entry.key;

          return ChoiceChip(
            label: Text('${entry.value} ($count)'),
            selected: isSelected,
            onSelected: (_) => setState(() => _statusFilter = entry.key),
            selectedColor: DesignColors.primary,
            backgroundColor: DesignColors.surfaceSoft,
            labelStyle: DesignTypography.labelSmall.copyWith(
              color: isSelected ? Colors.white : DesignColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? DesignColors.primary
                  : DesignColors.borderLight,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.full),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  // ── Parcel card ─────────────────────────────────────────────────────

  Widget _parcelCard(_AdminParcel parcel, [int index = 0]) {
    final statusColor = _statusColor(parcel.status);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parcel.description,
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (parcel.villaNumber.isNotEmpty)
                      'Villa ${parcel.villaNumber}',
                    if (parcel.ownerName.isNotEmpty) parcel.ownerName,
                    if (parcel.courier.isNotEmpty) parcel.courier,
                    _timeAgo(parcel.receivedAt),
                  ].join(' \u00b7 '),
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge + action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusLabel(parcel.status),
                  style: DesignTypography.captionSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              if (parcel.status == 'PENDING' || parcel.status == 'RECEIVED')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () => _showStatusSheet(parcel),
                    child: Text(
                      'Update',
                      style: DesignTypography.captionSmall.copyWith(
                        color: DesignColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _showStatusSheet(_AdminParcel parcel) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateParcelStatusSheet(
        parcel: parcel,
        onUpdated: _refresh,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return DesignColors.warning;
      case 'RECEIVED':
        return DesignColors.info;
      case 'DELIVERED':
        return DesignColors.primary;
      case 'COLLECTED':
        return DesignColors.accent;
      default:
        return DesignColors.textSecondary;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'RECEIVED':
        return 'Received';
      case 'DELIVERED':
        return 'Delivered';
      case 'COLLECTED':
        return 'Collected';
      default:
        return status;
    }
  }

  static String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Lightweight model for admin parcel (includes villa info the resident
// model doesn't have).
// ═══════════════════════════════════════════════════════════════════════

class _AdminParcel {
  final String id;
  final String description;
  final String status;
  final String courier;
  final String villaNumber;
  final String ownerName;
  final DateTime? receivedAt;

  const _AdminParcel({
    required this.id,
    required this.description,
    required this.status,
    required this.courier,
    required this.villaNumber,
    required this.ownerName,
    this.receivedAt,
  });

  factory _AdminParcel.fromJson(Map<String, dynamic> json) {
    final villa = json['villa'] as Map<String, dynamic>?;
    return _AdminParcel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? 'Parcel',
      status: json['status']?.toString() ?? 'PENDING',
      courier: json['deliveryService']?.toString() ??
          json['senderName']?.toString() ??
          '',
      villaNumber: villa?['villaNumber']?.toString() ?? '',
      ownerName: villa?['ownerName']?.toString() ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Update Parcel Status Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _UpdateParcelStatusSheet extends ConsumerStatefulWidget {
  const _UpdateParcelStatusSheet({
    required this.parcel,
    required this.onUpdated,
  });

  final _AdminParcel parcel;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_UpdateParcelStatusSheet> createState() =>
      _UpdateParcelStatusSheetState();
}

class _UpdateParcelStatusSheetState
    extends ConsumerState<_UpdateParcelStatusSheet> {
  late String _selected;
  bool _submitting = false;

  static const _statuses = <String, String>{
    'PENDING': 'Pending',
    'RECEIVED': 'Received',
    'DELIVERED': 'Delivered',
    'COLLECTED': 'Collected',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.parcel.status;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(adminParcelRepositoryProvider)
          .updateParcelStatus(widget.parcel.id, status: _selected);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Parcel updated to ${_statuses[_selected] ?? _selected}'),
          backgroundColor: DesignColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e, 'Update failed')),
          backgroundColor: DesignColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignRadius.md)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
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
            Text('Update Parcel Status', style: DesignTypography.headingM),
            const SizedBox(height: 4),
            Text(
              widget.parcel.description,
              style: DesignTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Status options
            ..._statuses.entries.map((e) => RadioListTile<String>(
                  title: Text(e.value, style: DesignTypography.body),
                  value: e.key,
                  groupValue: _selected,
                  onChanged: (v) {
                    if (v != null) setState(() => _selected = v);
                  },
                  activeColor: DesignColors.primary,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
