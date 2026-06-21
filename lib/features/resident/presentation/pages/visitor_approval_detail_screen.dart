import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../providers/visitor_provider.dart';
import '../widgets/visitor_management_ui.dart';

class VisitorApprovalDetailScreen extends ConsumerStatefulWidget {
  const VisitorApprovalDetailScreen({super.key, required this.visitorId});

  final String visitorId;

  @override
  ConsumerState<VisitorApprovalDetailScreen> createState() =>
      _VisitorApprovalDetailScreenState();
}

class _VisitorApprovalDetailScreenState
    extends ConsumerState<VisitorApprovalDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(visitorApprovalDetailProvider(widget.visitorId));

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: Text(
          'Visitor request',
          style: DesignTypography.headingM.copyWith(fontSize: 17),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: DesignColors.surface,
        foregroundColor: DesignColors.textPrimary,
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const DetailSkeleton(heroHeight: 200),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DesignSpacing.xl),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
            const Icon(
              Icons.wifi_tethering_error_rounded,
              size: 56,
              color: DesignColors.warning,
            ),
            const SizedBox(height: DesignSpacing.lg),
            Text(
              'Could not load visitor',
              textAlign: TextAlign.center,
              style: DesignTypography.headingM.copyWith(fontSize: 18),
            ),
            const SizedBox(height: DesignSpacing.sm),
            Text(
              userFacingMessage(e, 'Check your connection and try again.'),
              textAlign: TextAlign.center,
              style: DesignTypography.body.copyWith(
                color: DesignColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DesignSpacing.xl),
            Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(
                  visitorApprovalDetailProvider(widget.visitorId),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignSpacing.xl,
                    vertical: DesignSpacing.md + 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderMD,
                  ),
                ),
              ),
            ),
          ],
        ),
        data: (bundle) {
          final visitor = bundle['visitor'] as Map<String, dynamic>? ?? {};
          final guardName = bundle['guardName'] as String?;
          final mode = bundle['visitorMultiVillaApprovalMode'] as String?;
          final vv = (visitor['villaVisits'] as List?) ?? const [];
          final myVisit = vv.isNotEmpty ? vv.first as Map : <String, dynamic>{};
          final myDecision = myVisit['approvalStatus'] as String? ?? 'PENDING';
          final agg = visitor['status'] as String? ?? '';

          final purpose = visitor['purpose'] as String? ?? '';
          final phone = visitor['phone'] as String? ?? '';
          final name = visitor['name'] as String? ?? 'Visitor';
          final flat = (myVisit['villa'] as Map?)?['villaNumber']?.toString();
          final block = (myVisit['villa'] as Map?)?['block']?.toString();
          final visitorType = visitor['visitorType'] as String?;
          final vehicle = visitor['vehicleNumber'] as String?;
          final photo = visitor['photo'] as String?;
          final gateName = (visitor['gate'] as Map?)?['name'] as String?;
          final checkIn = visitor['checkInTime'] ?? visitor['checkInAt'];

          final canAct =
              agg == 'PENDING_APPROVAL' && myDecision == 'PENDING' && !_busy;

          final flatLabel = [
            if (block != null && block.isNotEmpty) block,
            if (flat != null && flat.isNotEmpty) flat,
          ].join(' · ');

          final mySt = VisitorMgmtStatus.styleForVillaDecision(myDecision);
          final ovSt = VisitorMgmtStatus.style(agg.trim().isEmpty ? '' : agg);

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: DesignColors.primary,
                  onRefresh: () async {
                    ref.invalidate(visitorApprovalDetailProvider(widget.visitorId));
                    await ref.read(
                      visitorApprovalDetailProvider(widget.visitorId).future,
                    );
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignSpacing.screenPaddingH,
                        DesignSpacing.sm,
                        DesignSpacing.screenPaddingH,
                        DesignSpacing.xl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _HeroHeader(
                            name: name,
                            visitorTypeLabel: _visitorTypeLabel(visitorType),
                            visitorTypeRaw: visitorType,
                            photo: photo,
                            initials: _initials(name),
                          ),
                          const SizedBox(height: DesignSpacing.lg),
                          Text(
                            'Visitor details',
                            style: DesignTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: DesignColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: DesignSpacing.md),
                          DecoratedBox(
                            decoration: DesignComponents.cardDecoration(
                              boxShadow: DesignElevation.sm,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              child: Column(
                                children: [
                                  _DetailTile(
                                    icon: Icons.phone_rounded,
                                    label: 'Phone',
                                    value: phone.isEmpty ? '—' : phone,
                                  ),
                                  if (flatLabel.isNotEmpty)
                                    _DetailTile(
                                      icon: Icons.home_work_outlined,
                                      label: 'Your flat',
                                      value: flatLabel,
                                    ),
                                  if (purpose.isNotEmpty)
                                    _DetailTile(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      label: 'Purpose',
                                      value: purpose,
                                    ),
                                  if (vehicle != null &&
                                      vehicle.trim().isNotEmpty)
                                    _DetailTile(
                                      icon: Icons.directions_car_outlined,
                                      label: 'Vehicle',
                                      value: vehicle.trim(),
                                    ),
                                  if (gateName != null &&
                                      gateName.trim().isNotEmpty)
                                    _DetailTile(
                                      icon: Icons.shield_outlined,
                                      label: 'Gate',
                                      value: gateName.trim(),
                                    ),
                                  if (guardName != null &&
                                      guardName.trim().isNotEmpty)
                                    _DetailTile(
                                      icon: Icons.badge_outlined,
                                      label: 'Logged by',
                                      value: guardName.trim(),
                                    ),
                                  _DetailTile(
                                    icon: Icons.schedule_rounded,
                                    label: 'Requested',
                                    value: _formatRequestedAt(checkIn),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (mode != null) ...[
                            const SizedBox(height: DesignSpacing.md),
                            _RuleCallout(
                              mode: mode,
                              textTheme: theme.textTheme,
                            ),
                          ],
                          const SizedBox(height: DesignSpacing.lg),
                          Text(
                            'Status',
                            style: DesignTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: DesignColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: DesignSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _StatusChip(
                                  title: 'Your response',
                                  subtitle: VisitorMgmtStatus.labelForVillaDecision(
                                    myDecision,
                                  ),
                                  foreground: mySt.foreground,
                                  container: mySt.background,
                                  borderColor: mySt.border,
                                  icon: mySt.icon,
                                ),
                              ),
                              const SizedBox(width: DesignSpacing.md),
                              Expanded(
                                child: _StatusChip(
                                  title: 'Overall',
                                  subtitle: VisitorMgmtStatus.label(agg),
                                  foreground: ovSt.foreground,
                                  container: ovSt.background,
                                  borderColor: ovSt.border,
                                  icon: ovSt.icon,
                                ),
                              ),
                            ],
                          ),
                          if (!canAct &&
                              agg == 'PENDING_APPROVAL' &&
                              myDecision != 'PENDING') ...[
                            const SizedBox(height: 20),
                            _AlreadyRespondedNotice(
                              approved: myDecision == 'APPROVED',
                              textTheme: theme.textTheme,
                            ),
                          ],
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              if (canAct)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    border: Border(
                      top: BorderSide(
                        color: DesignColors.borderLight.withValues(alpha: 0.9),
                      ),
                    ),
                    boxShadow: DesignElevation.sm,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DesignSpacing.screenPaddingH,
                        DesignSpacing.md,
                        DesignSpacing.screenPaddingH,
                        DesignSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Allow this visitor to enter the premises?',
                            style: DesignTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DesignSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(context, approve: true),
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, size: 20),
                                  label: const Text('Approve entry'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: DesignColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: DesignColors.primary
                                        .withValues(alpha: 0.55),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: DesignSpacing.md + 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: DesignRadius.borderMD,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: DesignSpacing.md),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _decide(context, approve: false),
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: DesignColors.textPrimary,
                                    side: const BorderSide(
                                      color: DesignColors.border,
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: DesignSpacing.md + 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: DesignRadius.borderMD,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _decide(BuildContext context, {required bool approve}) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(visitorRepositoryProvider);
      if (approve) {
        await repo.approveVisitorRequest(widget.visitorId);
      } else {
        await repo.rejectVisitorRequest(widget.visitorId);
      }
      ref.invalidate(visitorApprovalDetailProvider(widget.visitorId));
      ref.invalidate(visitorApprovalRequestsProvider('pending'));
      ref.invalidate(visitorApprovalRequestsProvider('all'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: DesignRadius.borderMD,
            ),
            content: Text(approve ? 'Entry approved.' : 'Entry declined.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.name,
    required this.visitorTypeLabel,
    required this.visitorTypeRaw,
    required this.photo,
    required this.initials,
  });

  final String name;
  final String visitorTypeLabel;
  final String? visitorTypeRaw;
  final String? photo;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final trimmed = photo?.trim();
    final isNetwork =
        trimmed != null &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: DesignColors.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: DesignColors.borderLight),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                initials: initials,
                photoUrl: isNetwork ? trimmed : null,
                fg: DesignColors.primary,
                bg: DesignColors.primary.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: DesignColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _DetailMetaChip(
                          icon: _visitorTypeDetailIcon(visitorTypeRaw),
                          label: visitorTypeLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailMetaChip extends StatelessWidget {
  const _DetailMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignColors.textSecondary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: DesignColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _visitorTypeDetailIcon(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'DELIVERY':
      return Icons.local_shipping_outlined;
    case 'SERVICE':
    case 'SERVICE_PROVIDER':
      return Icons.build_outlined;
    case 'VENDOR':
      return Icons.storefront_outlined;
    case 'CONTRACTOR':
      return Icons.engineering_outlined;
    case 'OTHER':
      return Icons.category_outlined;
    case 'GUEST':
    default:
      return Icons.person_outline_rounded;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.photoUrl,
    required this.fg,
    required this.bg,
  });

  final String initials;
  final String? photoUrl;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    if (photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: size,
            height: size,
            color: bg,
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: fg,
              ),
            ),
          ),
          errorWidget: (_, _, _) => _InitialsCircle(
            initials: initials,
            fg: fg,
            bg: bg,
            size: size,
          ),
        ),
      );
    }
    return _InitialsCircle(
      initials: initials,
      fg: fg,
      bg: bg,
      size: size,
    );
  }
}

class _InitialsCircle extends StatelessWidget {
  const _InitialsCircle({
    required this.initials,
    required this.fg,
    required this.bg,
    required this.size,
  });

  final String initials;
  final Color fg;
  final Color bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: DesignColors.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: DesignColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: DesignColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCallout extends StatelessWidget {
  const _RuleCallout({
    required this.mode,
    required this.textTheme,
  });

  final String mode;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final text = mode == 'ALL_VILLAS_REQUIRED'
        ? 'Every selected flat must approve before the visitor can enter.'
        : 'Any one flat can approve — the first approval unlocks entry for this visit.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.groups_2_outlined,
            color: DesignColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Multi-flat rule',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DesignColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: DesignColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.container,
    required this.borderColor,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color foreground;
  final Color container;
  final Color borderColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: DesignColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyRespondedNotice extends StatelessWidget {
  const _AlreadyRespondedNotice({
    required this.approved,
    required this.textTheme,
  });

  final bool approved;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              approved ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            approved ? Icons.mark_email_read_outlined : Icons.info_outline,
            color:
                approved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              approved
                  ? 'You’ve approved this request. Other flats may still respond depending on society rules.'
                  : 'You’ve declined this request. The gate will not admit this visitor on behalf of your flat.',
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color:
                    approved ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _visitorTypeLabel(String? raw) {
  switch (raw) {
    case 'GUEST':
      return 'Guest';
    case 'DELIVERY':
      return 'Delivery';
    case 'SERVICE_PROVIDER':
      return 'Service / repair';
    case 'VENDOR':
      return 'Vendor';
    case 'CONTRACTOR':
      return 'Contractor';
    case 'OTHER':
      return 'Other';
    default:
      if (raw == null || raw.isEmpty) return 'Visitor';
      return raw.replaceAll('_', ' ');
  }
}

String _formatRequestedAt(dynamic checkIn) {
  if (checkIn == null) return '—';
  DateTime? dt;
  if (checkIn is String) {
    dt = DateTime.tryParse(checkIn);
  }
  if (dt == null) return '—';
  final local = dt.toLocal();
  final date = DateFormat.yMMMd().format(local);
  final time = DateFormat.jm().format(local);
  return '$date · $time';
}
