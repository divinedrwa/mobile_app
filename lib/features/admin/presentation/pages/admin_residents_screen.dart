import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing society residents.
class AdminResidentsScreen extends ConsumerStatefulWidget {
  const AdminResidentsScreen({super.key});

  @override
  ConsumerState<AdminResidentsScreen> createState() =>
      _AdminResidentsScreenState();
}

class _AdminResidentsScreenState extends ConsumerState<AdminResidentsScreen> {
  String? _statusFilter; // null = All
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminResidentOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(adminResidentOverviewProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Residents',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _buildStatsHero(overviewAsync),
            const SizedBox(height: 12),
            AdminSearchField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              hint: 'Search by name, villa, phone…',
            ),
            const SizedBox(height: 12),
            _buildResidentList(overviewAsync),
          ],
        ),
      ),
    );
  }

  // ── Stats hero ──

  Widget _buildStatsHero(AsyncValue<Map<String, dynamic>> overviewAsync) {
    return overviewAsync.when(
      loading: () => ShimmerWrap(
        child: ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (overview) {
        final stats = (overview['statistics'] as Map?) ?? const {};
        final total = _toInt(stats['totalResidents']);
        final active = _toInt(stats['activeResidents']);
        final owners = _toInt(stats['owners']);
        final tenants = _toInt(stats['tenants']);
        final occupancy = _toDouble(stats['occupancyRate']);
        final newThisMonth = _toInt(stats['newThisMonth']);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$total Residents',
                    style: DesignTypography.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${occupancy.round()}% occupied',
                      style: DesignTypography.captionSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _heroChip(Icons.check_circle_outline, '$active active'),
                  const SizedBox(width: 12),
                  _heroChip(Icons.home_outlined, '$owners owners'),
                  const SizedBox(width: 12),
                  _heroChip(Icons.key_outlined, '$tenants tenants'),
                ],
              ),
              if (newThisMonth > 0) ...[
                const SizedBox(height: 8),
                _heroChip(Icons.person_add_outlined, '$newThisMonth new this month'),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: DesignTypography.captionSmall.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Resident list ──

  Widget _buildResidentList(AsyncValue<Map<String, dynamic>> overviewAsync) {
    return overviewAsync.when(
      loading: () => ShimmerWrap(
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
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load residents',
          subtitle: 'Something went wrong. Please try again.',
          iconColor: DesignColors.error,
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      ),
      data: (data) {
        final residents = (data['residents'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];

        // Filter chips
        final allCount = residents.length;
        final activeCount = residents.where((r) => r['isActive'] == true).length;
        final inactiveCount = allCount - activeCount;

        var filtered = _statusFilter == null
            ? residents
            : _statusFilter == 'ACTIVE'
                ? residents.where((r) => r['isActive'] == true).toList()
                : residents.where((r) => r['isActive'] != true).toList();

        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((r) {
            final name = (r['name'] ?? r['username'] ?? '').toString().toLowerCase();
            final phone = (r['phone'] ?? '').toString().toLowerCase();
            final villa = (r['villa'] as Map<String, dynamic>?)?['villaNumber']?.toString().toLowerCase() ?? '';
            final email = (r['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) ||
                phone.contains(_searchQuery) ||
                villa.contains(_searchQuery) ||
                email.contains(_searchQuery);
          }).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(null, 'All', allCount),
                  const SizedBox(width: 8),
                  _filterChip('ACTIVE', 'Active', activeCount),
                  const SizedBox(width: 8),
                  _filterChip('INACTIVE', 'Inactive', inactiveCount),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.people_outlined,
                  title: 'No residents found',
                  subtitle: _statusFilter != null
                      ? 'No residents match the selected filter.'
                      : 'Residents will appear here once added.',
                  iconColor: const Color(0xFF0D9488),
                ),
              )
            else
              ...filtered.map(_residentCard),
          ],
        );
      },
    );
  }

  Widget _filterChip(String? value, String label, int count) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: DesignColors.surfaceSoft,
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0D9488) : DesignColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _residentCard(Map<String, dynamic> r) {
    final name = r['name']?.toString() ?? r['username']?.toString() ?? '';
    final role = r['type']?.toString() ?? r['role']?.toString() ?? '';
    final villa = r['villa'] as Map<String, dynamic>?;
    final villaNumber = villa?['villaNumber']?.toString() ?? '';
    final phone = r['phone']?.toString() ?? '';
    final isActive = r['isActive'] == true;

    final roleColor = role.toUpperCase().contains('TENANT')
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF7C3AED);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: () => _showResidentSheet(r),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF0D9488),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
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
                      child: Text(
                        name,
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (role.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatRole(role),
                          style: DesignTypography.captionSmall.copyWith(
                            color: roleColor,
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
                    if (villaNumber.isNotEmpty) 'Villa $villaNumber',
                    if (phone.isNotEmpty) phone,
                  ].join(' \u00b7 '),
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Tooltip(
            message: isActive ? 'Active' : 'Inactive',
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? DesignColors.primary : DesignColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResidentSheet(Map<String, dynamic> r) {
    final name = r['name']?.toString() ?? r['username']?.toString() ?? '';
    final email = r['email']?.toString() ?? '';
    final phone = r['phone']?.toString() ?? '';
    final role = r['type']?.toString() ?? r['role']?.toString() ?? '';
    final isActive = r['isActive'] == true;
    final villa = r['villa'] as Map<String, dynamic>?;
    final villaNumber = villa?['villaNumber']?.toString() ?? '';
    final id = r['id']?.toString() ?? '';

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
              if (villaNumber.isNotEmpty)
                _detailRow(Icons.home_outlined, 'Villa', villaNumber),
              if (role.isNotEmpty)
                _detailRow(Icons.badge_outlined, 'Role', _formatRole(role)),
              if (email.isNotEmpty)
                _detailRow(Icons.email_outlined, 'Email', email),
              if (phone.isNotEmpty)
                _detailRow(Icons.phone_outlined, 'Phone', phone),
              const SizedBox(height: 16),
              if (isActive)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleMoveOut(id),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Move Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignColors.error,
                      side: const BorderSide(color: DesignColors.error),
                    ),
                  ),
                ),
              if (!isActive)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _handleReactivate(id),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reactivate'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMoveOut(String residentId) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm move-out'),
        content: const Text(
          'This resident will be marked as moved out and lose access. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DesignColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(adminResidentManagementRepositoryProvider)
          .moveOut(residentId: residentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resident moved out successfully')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _handleReactivate(String residentId) async {
    Navigator.of(context).pop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm reactivation'),
        content: const Text(
          'This will restore the resident\'s access to the society app. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(adminResidentManagementRepositoryProvider)
          .reactivate(residentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resident reactivated successfully')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
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

  static String _formatRole(String role) {
    if (role.isEmpty) return '';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
