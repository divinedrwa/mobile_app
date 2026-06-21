import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/pre_approved_visitor_model.dart';
import '../providers/visitor_provider.dart';
import '../widgets/list_skeleton.dart';
import '../widgets/visitor_management_ui.dart';

/// Lists pre-approved visitors for the logged-in resident's flat (newest first).
class MyPreApprovedVisitorsScreen extends ConsumerStatefulWidget {
  const MyPreApprovedVisitorsScreen({super.key});

  @override
  ConsumerState<MyPreApprovedVisitorsScreen> createState() =>
      _MyPreApprovedVisitorsScreenState();
}

class _MyPreApprovedVisitorsScreenState
    extends ConsumerState<MyPreApprovedVisitorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  static String _typeLabel(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return 'Guest';
      case VisitorType.delivery:
        return 'Delivery';
      case VisitorType.service:
        return 'Service';
      case VisitorType.vendor:
        return 'Vendor';
    }
  }

  static IconData _typeIcon(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return Icons.person_rounded;
      case VisitorType.delivery:
        return Icons.local_shipping_outlined;
      case VisitorType.service:
        return Icons.home_repair_service_outlined;
      case VisitorType.vendor:
        return Icons.storefront_outlined;
    }
  }

  static Color _typeAccent(VisitorType t) {
    switch (t) {
      case VisitorType.guest:
        return DesignColors.primary;
      case VisitorType.delivery:
        return const Color(0xFF0891B2);
      case VisitorType.service:
        return const Color(0xFF7C3AED);
      case VisitorType.vendor:
        return const Color(0xFFCA8A04);
    }
  }

  static bool _isExpired(PreApprovedVisitorModel v) {
    final u = v.passcodeExpiry;
    if (u == null) return false;
    return !u.toLocal().isAfter(DateTime.now());
  }

  String _validityLine(PreApprovedVisitorModel v, DateFormat dtf) {
    final end = v.passcodeExpiry;
    if (end != null) {
      return 'Valid until ${dtf.format(end.toLocal())}';
    }
    return 'Open-ended approval';
  }

  Future<void> _refresh() async {
    ref.invalidate(preApprovedVisitorsProvider);
    await ref.read(preApprovedVisitorsProvider.future);
  }

  String _buildShareMessage(PreApprovedVisitorModel v) {
    final otp = v.passcode?.trim() ?? '';
    final expiry = v.passcodeExpiry != null
        ? '\nValid until: ${DateFormat('dd MMM yyyy, hh:mm a').format(v.passcodeExpiry!.toLocal())}'
        : '';
    return 'Visitor Pass for ${v.name}\n\n'
        'Passcode: $otp\n\n'
        'Date: ${DateFormat('dd MMM yyyy').format(v.visitDate)}'
        '$expiry\n\n'
        'Please show this code at the gate.\n'
        '- ${AppConstants.appName}';
  }

  void _sharePasscode(BuildContext context, PreApprovedVisitorModel v) {
    final pass = v.passcode?.trim();
    if (pass == null || pass.isEmpty) return;
    Share.share(_buildShareMessage(v));
  }

  Future<void> _shareViaWhatsApp(
    BuildContext context,
    PreApprovedVisitorModel v,
  ) async {
    final pass = v.passcode?.trim();
    if (pass == null || pass.isEmpty) return;
    final message = Uri.encodeComponent(_buildShareMessage(v));
    final phone = v.phone.replaceAll(RegExp(r'\D'), '');
    final waUri = phone.length >= 10
        ? Uri.parse('https://wa.me/$phone?text=$message')
        : Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('WhatsApp not installed'),
        ),
      );
    }
  }

  Future<void> _copyPasscode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Passcode copied'),
        margin: const EdgeInsets.all(DesignSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PreApprovedVisitorModel v,
  ) async {
    final id = v.id;
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove pre-approval?'),
        content: Text(
          'Guards will no longer see ${v.name} under expected visitors.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(visitorRepositoryProvider).deletePreApprovedVisitor(id);
      ref.invalidate(preApprovedVisitorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pre-approval removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e, 'Could not remove'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(preApprovedVisitorsProvider);
    final scheme = Theme.of(context).colorScheme;
    final dtf = DateFormat('EEE, d MMM yyyy · h:mm a');

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        centerTitle: true,
        title: Text(
          'Pre-approved visitors',
          style: DesignTypography.headingM.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add visitor',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DesignColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: DesignColors.primary,
                size: 22,
              ),
            ),
            onPressed: () => context.push('/resident/pre-approve-visitor'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: async.maybeWhen(
          data: (list) {
            final active = list.where((v) => !_isExpired(v)).length;
            final expired = list.length - active;
            return PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Material(
                color: DesignColors.surface,
                child: VisitorMgmtTabBar(
                  controller: _tab,
                  tabs: [
                    Tab(text: 'Active · $active'),
                    Tab(text: 'Expired · $expired'),
                  ],
                ),
              ),
            );
          },
          orElse: () => null,
        ),
      ),
      body: async.when(
        loading: () => const ListSkeleton(itemHeight: 100),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: DesignColors.textTertiary,
                ),
                const SizedBox(height: DesignSpacing.md),
                Text(
                  userFacingMessage(e, 'Could not load your list.'),
                  textAlign: TextAlign.center,
                  style: DesignTypography.body,
                ),
                const SizedBox(height: DesignSpacing.lg),
                FilledButton.icon(
                  onPressed: _refresh,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: DesignRadius.borderMD,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              color: DesignColors.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(DesignSpacing.xl),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
                  Container(
                    padding: const EdgeInsets.all(DesignSpacing.lg),
                    decoration: const BoxDecoration(
                      color: DesignColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.event_available_outlined,
                      size: 48,
                      color: DesignColors.primary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: DesignSpacing.lg),
                  Text(
                    'No pre-approved visitors yet',
                    style: DesignTypography.headingM.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignSpacing.sm),
                  Text(
                    "Add someone you're expecting so security can admit them quickly "
                    'with the gate passcode.',
                    style: DesignTypography.body.copyWith(
                      color: DesignColors.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignSpacing.xl),
                  FilledButton.icon(
                    onPressed: () =>
                        context.push('/resident/pre-approve-visitor'),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSpacing.xl,
                        vertical: DesignSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DesignRadius.borderMD,
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Pre-approve a visitor'),
                  ),
                ],
              ),
            );
          }

          final activeList = list.where((v) => !_isExpired(v)).toList();
          final expiredList = list.where((v) => _isExpired(v)).toList();

          Widget tabBody(List<PreApprovedVisitorModel> rows, bool expiredTab) {
            if (rows.isEmpty) {
              return RefreshIndicator(
                color: DesignColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(DesignSpacing.xl),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.18,
                    ),
                    Icon(
                      expiredTab
                          ? Icons.history_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 52,
                      color: DesignColors.textTertiary,
                    ),
                    const SizedBox(height: DesignSpacing.md),
                    Text(
                      expiredTab
                          ? 'No expired entries'
                          : 'No active pre-approvals',
                      style: DesignTypography.headingM.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignSpacing.sm),
                    Text(
                      expiredTab
                          ? 'Expired passes are cleared from this list over time.'
                          : 'Tap + to add an expected guest for your flat.',
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: DesignColors.primary,
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  DesignSpacing.screenPaddingH,
                  DesignSpacing.md,
                  DesignSpacing.screenPaddingH,
                  DesignSpacing.xl + 8,
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DesignSpacing.md),
                itemBuilder: (context, i) {
                  return _PreApprovalVisitorCard(
                    visitor: rows[i],
                    expired: expiredTab,
                    validityLine: _validityLine(rows[i], dtf),
                    typeLabel: _typeLabel(rows[i].type),
                    typeIcon: _typeIcon(rows[i].type),
                    typeAccent: _typeAccent(rows[i].type),
                    onDelete: () => _confirmDelete(context, rows[i]),
                    onCopyPasscode: (code) => _copyPasscode(context, code),
                    onShare: () => _sharePasscode(context, rows[i]),
                    onWhatsApp: () => _shareViaWhatsApp(context, rows[i]),
                  );
                },
              ),
            );
          }

          return TabBarView(
            controller: _tab,
            children: [
              tabBody(activeList, false),
              tabBody(expiredList, true),
            ],
          );
        },
      ),
    );
  }
}

class _PreApprovalVisitorCard extends StatelessWidget {
  const _PreApprovalVisitorCard({
    required this.visitor,
    required this.expired,
    required this.validityLine,
    required this.typeLabel,
    required this.typeIcon,
    required this.typeAccent,
    required this.onDelete,
    required this.onCopyPasscode,
    required this.onShare,
    required this.onWhatsApp,
  });

  final PreApprovedVisitorModel visitor;
  final bool expired;
  final String validityLine;
  final String typeLabel;
  final IconData typeIcon;
  final Color typeAccent;
  final VoidCallback onDelete;
  final void Function(String code) onCopyPasscode;
  final VoidCallback onShare;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    final pass = v.passcode?.trim();
    final hasPass = pass != null && pass.isNotEmpty;
    final passDisplay = pass ?? '';

    return Material(
      color: DesignColors.surface,
      elevation: 0,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: DesignRadius.borderLG,
        side: BorderSide(
          color: expired
              ? DesignColors.error.withValues(alpha: 0.25)
              : DesignColors.borderLight,
        ),
      ),
      child: InkWell(
        borderRadius: DesignRadius.borderLG,
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignSpacing.md + 2,
            DesignSpacing.md + 2,
            DesignSpacing.sm,
            DesignSpacing.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: typeAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(typeIcon, color: typeAccent, size: 26),
                  ),
                  const SizedBox(width: DesignSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                v.name,
                                style: DesignTypography.headingM.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: expired
                                    ? DesignColors.error.withValues(
                                        alpha: 0.12,
                                      )
                                    : DesignColors.success.withValues(
                                        alpha: 0.14,
                                      ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: expired
                                      ? DesignColors.error.withValues(
                                          alpha: 0.35,
                                        )
                                      : DesignColors.success.withValues(
                                          alpha: 0.35,
                                        ),
                                ),
                              ),
                              child: Text(
                                expired ? 'Expired' : 'Active',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: expired
                                      ? DesignColors.error
                                      : DesignColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MiniChip(
                              icon: Icons.phone_iphone_rounded,
                              label: v.phone,
                            ),
                            _MiniChip(icon: typeIcon, label: typeLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    style: IconButton.styleFrom(
                      foregroundColor: DesignColors.error,
                      backgroundColor:
                          DesignColors.error.withValues(alpha: 0.08),
                    ),
                    onPressed: v.id == null ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                  ),
                ],
              ),
              if (v.flatLabel != null && v.flatLabel!.isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.md),
                _MetaLine(
                  icon: Icons.apartment_rounded,
                  text: 'Flat ${v.flatLabel}',
                  strong: true,
                ),
              ],
              const SizedBox(height: DesignSpacing.sm + 2),
              _MetaLine(
                icon: Icons.schedule_rounded,
                text: validityLine,
                muted: true,
              ),
              if (v.purpose != null && v.purpose!.trim().isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.sm),
                _MetaLine(
                  icon: Icons.topic_outlined,
                  text: v.purpose!.trim(),
                  muted: false,
                  maxLines: 3,
                ),
              ],
              if (v.notes != null && v.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: DesignSpacing.sm),
                _MetaLine(
                  icon: Icons.sticky_note_2_outlined,
                  text: v.notes!.trim(),
                  muted: true,
                  maxLines: 2,
                ),
              ],
              if (hasPass) ...[
                const SizedBox(height: DesignSpacing.md),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DesignColors.primary.withValues(alpha: 0.1),
                        DesignColors.primaryDark.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: DesignRadius.borderMD,
                    border: Border.all(
                      color: DesignColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSpacing.md,
                      vertical: DesignSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.vpn_key_rounded,
                          size: 22,
                          color: DesignColors.primaryDark,
                        ),
                        const SizedBox(width: DesignSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GATE PASSCODE',
                                style: DesignTypography.labelSmall.copyWith(
                                  color: DesignColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                passDisplay,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                  color: DesignColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Copy',
                          onPressed: () => onCopyPasscode(passDisplay),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: DesignColors.surface,
                            foregroundColor: DesignColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'WhatsApp',
                          onPressed: expired ? null : onWhatsApp,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFF25D366),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          tooltip: 'Share',
                          onPressed: expired ? null : onShare,
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          style: IconButton.styleFrom(
                            backgroundColor: DesignColors.surface,
                            foregroundColor: DesignColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: DesignColors.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DesignTypography.labelSmall.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.muted = false,
    this.strong = false,
    this.maxLines = 4,
  });

  final IconData icon;
  final String text;
  final bool muted;
  final bool strong;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color:
              muted ? DesignColors.textTertiary : DesignColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: DesignTypography.bodySmall.copyWith(
              color: muted
                  ? DesignColors.textSecondary
                  : DesignColors.textPrimary,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
