import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/utils/phone_launch.dart' show launchDial, maskPhone;
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// Detail view for a visitor row (from active entries or related flows).
class GuardVisitorDetailPage extends ConsumerStatefulWidget {
  const GuardVisitorDetailPage({super.key, required this.visitor});

  final GuardVisitorRow visitor;

  @override
  ConsumerState<GuardVisitorDetailPage> createState() =>
      _GuardVisitorDetailPageState();
}

class _GuardVisitorDetailPageState
    extends ConsumerState<GuardVisitorDetailPage> {
  // Local busy flags so the underlying button stays disabled (and shows a
  // spinner) while a network mutation is in flight. Without these, the guard
  // could double-tap "Confirm guest entered" / "Mark exit" the moment the
  // confirmation dialog dismisses and trigger duplicate POSTs.
  bool _admitting = false;
  bool _exiting = false;

  GuardVisitorRow get visitor => widget.visitor;

  static String _fmtCheckInTimeOnly(BuildContext context, DateTime t) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.Hm(locale).format(t.toLocal());
  }

  static String _fmtCheckInSubline(BuildContext context, DateTime t) {
    final locale = Localizations.localeOf(context).toString();
    final local = t.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return 'Today';
    return DateFormat('EEE, MMM d', locale).format(local);
  }

  static String _statusLabel(GuardVisitorRow v) =>
      guardVisitorStatusLabel(v);

  static IconData _statusIcon(GuardVisitorRow v) {
    if (v.entryDenied) return Icons.block_rounded;
    if (v.needsResidentApproval) return Icons.hourglass_top_rounded;
    if (v.awaitingGuardAdmission) return Icons.login_rounded;
    if (v.awaitingCheckout && v.status == 'CHECKED_IN') {
      return Icons.verified_rounded;
    }
    if (v.checkOutTime != null) return Icons.logout_rounded;
    return Icons.person_outline_rounded;
  }

  static Color _statusAccent(GuardVisitorRow v) {
    if (v.entryDenied) return GuardTokens.dangerBrand;
    if (v.needsResidentApproval) return GuardTokens.warning;
    if (v.awaitingGuardAdmission) return GuardTokens.guardAccentDeep;
    if (v.awaitingCheckout && v.status == 'CHECKED_IN') {
      return GuardTokens.success;
    }
    if (v.checkOutTime != null) return GuardTokens.textSecondary;
    return GuardTokens.guardAccentDeep;
  }

  static String? _visitorTypeLabel(String? api) {
    if (api == null || api.trim().isEmpty) return null;
    switch (api.trim().toUpperCase()) {
      case 'DELIVERY':
        return 'Delivery';
      case 'SERVICE_PROVIDER':
        return 'Service / repair';
      case 'VENDOR':
        return 'Vendor';
      case 'GUEST':
        return 'Guest';
      default:
        return api.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusAccent(v);
    final initial = v.name.trim().isNotEmpty
        ? v.name.trim()[0].toUpperCase()
        : '?';
    final typeLabel = _visitorTypeLabel(v.visitorType);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            v.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GuardTokens.headingStyle(context).copyWith(fontSize: 17),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  GuardTokens.padScreen,
                  GuardTokens.g1,
                  GuardTokens.padScreen,
                  GuardTokens.g2,
                ),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                GuardTokens.guardAccentDeep
                                    .withValues(alpha: 0.35),
                                GuardTokens.darkCard,
                              ]
                            : [
                                GuardTokens.guardAccent.withValues(alpha: 0.14),
                                GuardTokens.guardAccentDeep
                                    .withValues(alpha: 0.06),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(GuardTokens.radiusCard + 4),
                      border: Border.all(
                        color: isDark
                            ? GuardTokens.darkBorder
                            : GuardTokens.borderSubtle,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  GuardTokens.guardAccent,
                                  GuardTokens.guardAccentDeep,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: GuardTokens.guardAccent.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GuardTokens.headingStyle(context)
                                      .copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _StatusChip(
                                  icon: _statusIcon(v),
                                  label: _statusLabel(v),
                                  color: statusColor,
                                ),
                                if (typeLabel != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    typeLabel,
                                    style:
                                        GuardTokens.captionStyle(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: GuardTokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (v.needsResidentApproval) ...[
                    const SizedBox(height: GuardTokens.g2),
                    Material(
                      color: GuardTokens.warningMuted.withValues(
                        alpha: isDark ? 0.22 : 1,
                      ),
                      borderRadius: BorderRadius.circular(
                        GuardTokens.radiusCard,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: GuardTokens.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Residents were notified. Refresh active entries after they approve or reject.',
                                style: GuardTokens.captionStyle(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: GuardTokens.g2),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Visitor details',
                            style: GuardTokens.captionStyle(context).copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: GuardTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (v.villaLabel != null)
                            _VisitorDetailRowCompact(
                              icon: Icons.apartment_rounded,
                              label: 'Flat',
                              value: v.villaLabel!,
                              emphasized: true,
                            ),
                          if (v.purpose != null && v.purpose!.isNotEmpty) ...[
                            if (v.villaLabel != null)
                              const Divider(height: 18),
                            _VisitorDetailRowCompact(
                              icon: Icons.topic_outlined,
                              label: 'Purpose',
                              value: v.purpose!,
                            ),
                          ],
                          if (v.checkInTime != null) ...[
                            if (v.villaLabel != null ||
                                (v.purpose != null && v.purpose!.isNotEmpty))
                              const Divider(height: 18),
                            _VisitorDetailRowCompact(
                              icon: Icons.schedule_rounded,
                              label: 'Check-in',
                              value: _fmtCheckInTimeOnly(
                                context,
                                v.checkInTime!,
                              ),
                              valueSub: _fmtCheckInSubline(
                                context,
                                v.checkInTime!,
                              ),
                            ),
                          ],
                          if (v.checkOutTime != null) ...[
                            const Divider(height: 18),
                            _VisitorDetailRowCompact(
                              icon: Icons.logout_rounded,
                              label: 'Check-out',
                              value: _fmtCheckInTimeOnly(
                                context,
                                v.checkOutTime!,
                              ),
                              valueSub: _fmtCheckInSubline(
                                context,
                                v.checkOutTime!,
                              ),
                            ),
                          ],
                          if (v.villaLabel == null &&
                              (v.purpose == null || v.purpose!.isEmpty) &&
                              v.checkInTime == null &&
                              v.checkOutTime == null)
                            Text(
                              'No visit details yet.',
                              style: GuardTokens.captionStyle(context),
                            ),
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.phone_android_rounded,
                                size: 20,
                                color: GuardTokens.guardAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Phone',
                                      style: GuardTokens.captionStyle(context)
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      maskPhone(v.phone),
                                      style: GuardTokens.bodyStyle(context)
                                          .copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: 0.2,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen,
                    10,
                    GuardTokens.padScreen,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (v.awaitingCheckout &&
                          v.status.trim().toUpperCase() ==
                              'CHECKED_IN') ...[
                        FilledButton.icon(
                          style: GuardTokens.primaryFilled(context).copyWith(
                            minimumSize: WidgetStateProperty.all(
                              const Size(double.infinity, GuardTokens.btnPrimaryH),
                            ),
                          ),
                          onPressed: _exiting
                              ? null
                              : () => _confirmCheckout(context, v),
                          icon: _exiting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded),
                          label: Text(
                            _exiting ? 'Marking exit…' : 'Mark exit',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              double.infinity,
                              GuardTokens.btnPrimaryH,
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? GuardTokens.darkBorder
                                  : GuardTokens.borderSubtle,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                GuardTokens.radiusButton,
                              ),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await launchDial(v.phone);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot open dialer for this number',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.phone_outlined,
                            color: GuardTokens.guardAccentDeep,
                          ),
                          label: const Text(
                            'Call visitor',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: GuardTokens.guardAccentDeep,
                            ),
                          ),
                        ),
                      ] else ...[
                        FilledButton.icon(
                          style: GuardTokens.primaryFilled(context).copyWith(
                            minimumSize: WidgetStateProperty.all(
                              const Size(double.infinity, GuardTokens.btnPrimaryH),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await launchDial(v.phone);
                            if (!context.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot open dialer for this number',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text(
                            'Call visitor',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                      if (v.awaitingGuardAdmission) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: GuardTokens.primaryFilled(context).copyWith(
                            minimumSize: WidgetStateProperty.all(
                              const Size(double.infinity, GuardTokens.btnPrimaryH),
                            ),
                          ),
                          onPressed: _admitting
                              ? null
                              : () => _confirmAdmission(context, v),
                          icon: _admitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(
                            _admitting ? 'Admitting…' : 'Confirm guest entered',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAdmission(
    BuildContext context,
    GuardVisitorRow v,
  ) async {
    if (_admitting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm entry'),
        content: Text(
          'Residents approved ${v.name}. Mark them as on premises?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: GuardTokens.primaryFilled(context),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _admitting = true);
    try {
      await ref
          .read(guardRepositoryProvider)
          .confirmVisitorEntryAfterApproval(v.id);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
      ref.invalidate(guardTodayVisitorsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${v.name} checked in')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _admitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmCheckout(
    BuildContext context,
    GuardVisitorRow v,
  ) async {
    if (_exiting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check out'),
        content: Text('Mark ${v.name} as checked out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: GuardTokens.primaryFilled(context),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _exiting = true);
    try {
      await ref.read(guardRepositoryProvider).checkOutVisitor(v.id);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
      ref.invalidate(guardTodayVisitorsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${v.name} marked as exited'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _exiting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GuardTokens.captionStyle(context).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorDetailRowCompact extends StatelessWidget {
  const _VisitorDetailRowCompact({
    required this.icon,
    required this.label,
    required this.value,
    this.valueSub,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? valueSub;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 20,
            color: GuardTokens.guardAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Text(
                  label,
                  style: GuardTokens.captionStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: GuardTokens.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 19,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GuardTokens.bodyStyle(context).copyWith(
                        fontWeight:
                            emphasized ? FontWeight.w800 : FontWeight.w700,
                        fontSize: emphasized ? 16 : GuardTokens.body,
                        height: 1.25,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (valueSub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        valueSub!,
                        style: GuardTokens.captionStyle(context).copyWith(
                          color: GuardTokens.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
