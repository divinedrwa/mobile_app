import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing invitations.
class AdminInvitationsScreen extends ConsumerStatefulWidget {
  const AdminInvitationsScreen({super.key});

  @override
  ConsumerState<AdminInvitationsScreen> createState() =>
      _AdminInvitationsScreenState();
}

class _AdminInvitationsScreenState
    extends ConsumerState<AdminInvitationsScreen> {
  String? _statusFilter;

  static const _statuses = ['PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED'];

  Future<void> _refresh() async {
    ref.invalidate(adminInvitationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final invAsync = ref.watch(adminInvitationsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Invitations',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: const Color(0xFFEC4899),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Invite', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: invAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  6,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        ShimmerBox(height: 72, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load invitations',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (invitations) => _buildBody(invitations),
        ),
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> invitations) {
    // Count per status
    final counts = <String?, int>{null: invitations.length};
    for (final inv in invitations) {
      final s = inv['status']?.toString().toUpperCase();
      counts[s] = (counts[s] ?? 0) + 1;
    }

    final filtered = _statusFilter == null
        ? invitations
        : invitations
            .where((i) =>
                i['status']?.toString().toUpperCase() == _statusFilter)
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statuses.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _chipItem(null, 'All', counts[null] ?? 0);
              }
              final s = _statuses[index - 1];
              return _chipItem(s, _formatStatus(s), counts[s] ?? 0);
            },
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.person_add_outlined,
              title: 'No invitations',
              subtitle: _statusFilter != null
                  ? 'No invitations match the selected filter.'
                  : 'Tap + to send your first invitation.',
              iconColor: const Color(0xFFEC4899),
            ),
          )
        else
          ...filtered.map(_invitationCard),
      ],
    );
  }

  Widget _chipItem(String? status, String label, int count) {
    final isSelected = _statusFilter == status;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: const Color(0xFFEC4899),
      backgroundColor: DesignColors.surfaceSoft,
      labelStyle: DesignTypography.labelSmall.copyWith(
        color: isSelected ? Colors.white : DesignColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFFEC4899)
            : DesignColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignRadius.full),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _invitationCard(Map<String, dynamic> inv) {
    final role = inv['role']?.toString() ?? '';
    final email = inv['email']?.toString() ?? '';
    final phone = inv['phone']?.toString() ?? '';
    final status = inv['status']?.toString().toUpperCase() ?? '';
    final villaObj = inv['villa'] as Map<String, dynamic>?;
    final villaNum = villaObj?['villaNumber']?.toString() ?? '';
    final expiresAt = inv['expiresAt']?.toString() ?? '';
    final contact = email.isNotEmpty ? email : phone;

    final statusColor = _statusColor(status);

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      onTap: status == 'PENDING'
          ? () => _showRevokeConfirm(inv['id']?.toString() ?? '')
          : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _statusIcon(status),
              color: statusColor,
              size: 20,
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
                        contact.isNotEmpty ? contact : 'No contact',
                        style: DesignTypography.label
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatStatus(status),
                        style: DesignTypography.captionSmall.copyWith(
                          color: statusColor,
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
                    if (role.isNotEmpty) role,
                    if (villaNum.isNotEmpty) 'Villa $villaNum',
                    if (expiresAt.isNotEmpty)
                      'Expires ${_formatDate(expiresAt)}',
                  ].join(' \u00b7 '),
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRevokeConfirm(String id) {
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
              Text('Revoke Invitation?', style: DesignTypography.headingM),
              const SizedBox(height: 8),
              Text(
                'This invitation link will no longer be valid.',
                style: DesignTypography.bodySmall
                    .copyWith(color: DesignColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleRevoke(id);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignColors.error,
                      ),
                      child: const Text('Revoke'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSheet() {
    String selectedRole = 'RESIDENT';
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: BorderRadius.circular(DesignRadius.xl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
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
                    Text('New Invitation', style: DesignTypography.headingM),
                    const SizedBox(height: 16),
                    Text('Role',
                        style: DesignTypography.labelSmall
                            .copyWith(color: DesignColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['RESIDENT', 'GUARD', 'ADMIN'].map((r) {
                        final sel = selectedRole == r;
                        return ChoiceChip(
                          label: Text(r),
                          selected: sel,
                          onSelected: (_) =>
                              setSheetState(() => selectedRole = r),
                          selectedColor: const Color(0xFFEC4899),
                          backgroundColor: DesignColors.surfaceSoft,
                          labelStyle: TextStyle(
                            color: sel
                                ? Colors.white
                                : DesignColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                        isDense: true,
                      ),
                      validator: (v) {
                        // At least email or phone is required; validated in cross-field check below
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone (optional)',
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (emailCtrl.text.trim().isEmpty && phoneCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please provide email or phone')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          _handleCreate(
                            selectedRole,
                            emailCtrl.text.trim(),
                            phoneCtrl.text.trim(),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEC4899),
                        ),
                        child: const Text('Send Invitation'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreate(
      String role, String email, String phone) async {
    try {
      await ref.read(adminInvitationRepositoryProvider).createInvitation(
            role: role,
            email: email.isNotEmpty ? email : null,
            phone: phone.isNotEmpty ? phone : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully')),
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

  Future<void> _handleRevoke(String id) async {
    try {
      await ref.read(adminInvitationRepositoryProvider).revokeInvitation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation revoked')),
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

  static String _formatStatus(String s) {
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'ACCEPTED':
        return const Color(0xFF10B981);
      case 'REVOKED':
        return const Color(0xFFEF4444);
      case 'EXPIRED':
        return DesignColors.textTertiary;
      default:
        return DesignColors.textSecondary;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule;
      case 'ACCEPTED':
        return Icons.check_circle_outline;
      case 'REVOKED':
        return Icons.cancel_outlined;
      case 'EXPIRED':
        return Icons.timer_off_outlined;
      default:
        return Icons.mail_outlined;
    }
  }
}
