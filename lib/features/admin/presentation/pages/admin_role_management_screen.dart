import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for viewing society users and changing their roles.
///
/// Shows a filterable user list with role badges and an action
/// to change a user's role via bottom sheet.
class AdminRoleManagementScreen extends ConsumerStatefulWidget {
  const AdminRoleManagementScreen({super.key});

  @override
  ConsumerState<AdminRoleManagementScreen> createState() =>
      _AdminRoleManagementScreenState();
}

class _AdminRoleManagementScreenState
    extends ConsumerState<AdminRoleManagementScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(adminUsersProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(adminUsersProvider);
    try {
      await ref.read(adminUsersProvider.future);
    } catch (e) {
      debugPrint('AdminRoleManagementScreen._refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final roleFilter = ref.watch(adminUserRoleFilterProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Manage Roles',
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
        child: usersAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
            child: ShimmerWrap(
              child: Column(
                children: [
                  const ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 16),
                  const ShimmerBox(height: 64, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 64, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 64, borderRadius: DesignRadius.md),
                  const SizedBox(height: 12),
                  const ShimmerBox(height: 64, borderRadius: DesignRadius.md),
                ],
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Failed to load users',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (users) => _buildBody(users, roleFilter),
        ),
      ),
    );
  }

  Widget _buildBody(List<UserModel> users, String? roleFilter) {
    // Count by role for chips.
    final counts = <String?, int>{null: users.length};
    for (final u in users) {
      final r = u.role.value;
      counts[r] = (counts[r] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        // ── Summary hero ──
        _buildHero(users),
        const SizedBox(height: AppSpacing.lg),

        // ── Role filter chips ──
        _buildRoleChips(counts, roleFilter),
        const SizedBox(height: AppSpacing.lg),

        // ── User list ──
        if (users.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'No users found',
              subtitle: roleFilter != null
                  ? 'No users match the selected role filter.'
                  : 'There are no users in this society yet.',
            ),
          )
        else
          ...users.map(_userCard),
      ],
    );
  }

  // ── Hero card ───────────────────────────────────────────────────────

  Widget _buildHero(List<UserModel> users) {
    final admins = users.where((u) => u.role.isAdminLike).length;
    final residents = users.where((u) => u.role == UserRole.resident).length;
    final guards = users.where((u) => u.role == UserRole.guard).length;
    final active = users.where((u) => u.isActive).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: DesignColors.primaryGradient,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        boxShadow: DesignElevation.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${users.length} users',
            style: DesignTypography.headingL
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '$active active',
            style:
                DesignTypography.caption.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroPill('Admins', admins),
              const SizedBox(width: 8),
              _heroPill('Residents', residents),
              const SizedBox(width: 8),
              _heroPill('Guards', guards),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: DesignTypography.captionSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Role filter chips ───────────────────────────────────────────────

  Widget _buildRoleChips(Map<String?, int> counts, String? activeFilter) {
    const labels = <String?, String>{
      null: 'All',
      'ADMIN': 'Admin',
      'RESIDENT': 'Resident',
      'GUARD': 'Guard',
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
          final isSelected = activeFilter == entry.key;

          return ChoiceChip(
            label: Text('${entry.value} ($count)'),
            selected: isSelected,
            onSelected: (_) {
              ref.read(adminUserRoleFilterProvider.notifier).state =
                  entry.key;
            },
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

  // ── User card ───────────────────────────────────────────────────────

  Widget _userCard(UserModel user) {
    final roleColor = _roleColor(user.role);
    final property = user.effectivePropertyDisplay ?? '';
    final inactive = !user.isActive;

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: DesignTypography.bodyMedium.copyWith(
                color: roleColor,
                fontWeight: FontWeight.w700,
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
                    Flexible(
                      child: Text(
                        user.name,
                        style: DesignTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: inactive
                              ? DesignColors.textTertiary
                              : DesignColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (inactive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: DesignColors.textTertiary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'INACTIVE',
                          style: DesignTypography.captionSmall.copyWith(
                            color: DesignColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    user.email,
                    if (property.isNotEmpty) property,
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
          // Role badge + change action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _roleLabel(user.role),
                  style: DesignTypography.captionSmall.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => _showChangeRoleSheet(user),
                child: Text(
                  'Change Role',
                  style: DesignTypography.captionSmall.copyWith(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangeRoleSheet(UserModel user) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeRoleSheet(
        user: user,
        onUpdated: _refresh,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  static Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.residentCumAdmin:
        return DesignColors.warning;
      case UserRole.resident:
        return DesignColors.primary;
      case UserRole.guard:
        return DesignColors.info;
      case UserRole.superAdmin:
        return DesignColors.error;
    }
  }

  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.residentCumAdmin:
        return 'ADMIN · RESIDENT';
      case UserRole.resident:
        return 'RESIDENT';
      case UserRole.guard:
        return 'GUARD';
      case UserRole.superAdmin:
        return 'SUPER ADMIN';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Change Role Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _ChangeRoleSheet extends ConsumerStatefulWidget {
  const _ChangeRoleSheet({
    required this.user,
    required this.onUpdated,
  });

  final UserModel user;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_ChangeRoleSheet> createState() => _ChangeRoleSheetState();
}

class _ChangeRoleSheetState extends ConsumerState<_ChangeRoleSheet> {
  late String _selected;
  bool _submitting = false;

  static const _roles = <String, String>{
    'ADMIN': 'Admin',
    'RESIDENT': 'Resident',
    'GUARD': 'Guard',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.user.role.value;
  }

  Future<void> _submit() async {
    if (_submitting || _selected == widget.user.role.value) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(adminUserRepositoryProvider)
          .updateUserRole(widget.user.id, role: _selected);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.user.name} is now ${_roles[_selected] ?? _selected}'),
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
    final isChanged = _selected != widget.user.role.value;

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
            Text('Change Role', style: DesignTypography.headingM),
            const SizedBox(height: 4),
            Text(
              '${widget.user.name} (${widget.user.email})',
              style: DesignTypography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            ..._roles.entries.map((e) => RadioListTile<String>(
                  title: Text(e.value, style: DesignTypography.body),
                  subtitle: e.key == widget.user.role.value
                      ? Text('Current role',
                          style: DesignTypography.caption)
                      : null,
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
                  backgroundColor: isChanged ? DesignColors.primary : DesignColors.textTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                ),
                onPressed: isChanged && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Change', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
