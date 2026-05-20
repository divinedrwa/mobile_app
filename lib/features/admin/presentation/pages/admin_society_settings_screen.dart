import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for viewing and updating society settings.
class AdminSocietySettingsScreen extends ConsumerStatefulWidget {
  const AdminSocietySettingsScreen({super.key});

  @override
  ConsumerState<AdminSocietySettingsScreen> createState() =>
      _AdminSocietySettingsScreenState();
}

class _AdminSocietySettingsScreenState
    extends ConsumerState<AdminSocietySettingsScreen> {
  bool _saving = false;

  Future<void> _refresh() async {
    ref.invalidate(adminSocietySettingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminSocietySettingsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Society Settings',
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
        child: settingsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load settings',
                  subtitle: 'Something went wrong. Please try again.',
                  iconColor: DesignColors.error,
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (settings) => _buildBody(settings),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> settings) {
    final societyName = settings['name']?.toString() ??
        settings['societyName']?.toString() ??
        '';
    final status = settings['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final approvalMode =
        settings['visitorMultiVillaApprovalMode']?.toString() ??
            'ANY_ONE_APPROVAL';
    final approvalRequired = settings['visitorApprovalRequired'] == true;
    final guardCanApprove = settings['guardCanApproveVisitors'] == true;

    final isActive = status == 'ACTIVE';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Society info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF64748B), Color(0xFF475569)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Row(
            children: [
              const Icon(Icons.apartment_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      societyName.isNotEmpty ? societyName : 'Society',
                      style: DesignTypography.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFB923C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Active' : status,
                          style: DesignTypography.captionSmall.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Visitor Approval Settings
        EnterpriseSectionHeader(title: 'Visitor Approval'),
        const SizedBox(height: 8),

        EnterprisePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Require Resident Approval',
                      style: DesignTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Visitors must be approved by residents before entry',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: approvalRequired,
                  activeColor: DesignColors.primary,
                  onChanged: (v) => _updateSetting(
                    visitorApprovalRequired: v,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        EnterprisePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guard Can Approve Visitors',
                      style: DesignTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Allow guards to approve visitor entry directly',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: guardCanApprove,
                  activeColor: DesignColors.primary,
                  onChanged: (v) => _updateSetting(
                    guardCanApproveVisitors: v,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        EnterprisePanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Villa Approval Mode',
                      style: DesignTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      approvalMode == 'ANY_ONE_APPROVAL'
                          ? 'Any one villa can approve'
                          : 'All villas must approve',
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: approvalMode != 'ANY_ONE_APPROVAL',
                  activeColor: DesignColors.primary,
                  onChanged: (v) => _updateSetting(
                    visitorMultiVillaApprovalMode:
                        v ? 'ALL_MUST_APPROVE' : 'ANY_ONE_APPROVAL',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _updateSetting({
    String? visitorMultiVillaApprovalMode,
    bool? visitorApprovalRequired,
    bool? guardCanApproveVisitors,
  }) async {
    setState(() => _saving = true);
    try {
      await ref.read(adminSocietySettingsRepositoryProvider).updateSettings(
            visitorMultiVillaApprovalMode: visitorMultiVillaApprovalMode,
            visitorApprovalRequired: visitorApprovalRequired,
            guardCanApproveVisitors: guardCanApproveVisitors,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
