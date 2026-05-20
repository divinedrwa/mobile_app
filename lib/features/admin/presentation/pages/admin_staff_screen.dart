import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
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

  static const _staffTypes = [
    'MAID',
    'COOK',
    'DRIVER',
    'NANNY',
    'GARDENER',
    'PLUMBER',
    'ELECTRICIAN',
    'SECURITY',
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
                const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
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
    final filtered = _typeFilter == null
        ? staff
        : staff.where((s) =>
            s['type']?.toString().toUpperCase() == _typeFilter).toList();

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
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.badge_outlined,
              title: 'No staff found',
              subtitle: _typeFilter != null
                  ? 'No staff match the selected filter.'
                  : 'Staff members will appear here once added.',
              iconColor: const Color(0xFF059669),
            ),
          )
        else
          ...filtered.map(_staffCard),
      ],
    );
  }

  Widget _chipItem(String? type, String label, int count) {
    final isSelected = _typeFilter == type;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = type),
      selectedColor: const Color(0xFF059669),
      backgroundColor: DesignColors.surfaceSoft,
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF059669)
            : DesignColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignRadius.full)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _staffCard(Map<String, dynamic> staff) {
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
                decoration: const BoxDecoration(
                  color: DesignColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
    );
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
            ],
          ),
        ),
      ),
    );
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
        return const Color(0xFF8B5CF6);
      case 'COOK':
        return const Color(0xFFF97316);
      case 'DRIVER':
        return const Color(0xFF3B82F6);
      case 'NANNY':
        return const Color(0xFFEC4899);
      case 'GARDENER':
        return const Color(0xFF10B981);
      case 'PLUMBER':
        return const Color(0xFF0EA5E9);
      case 'ELECTRICIAN':
        return const Color(0xFFF59E0B);
      case 'SECURITY':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF059669);
    }
  }
}
