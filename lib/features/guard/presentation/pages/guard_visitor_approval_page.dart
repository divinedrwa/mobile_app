import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../../../core/utils/phone_launch.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../providers/guard_visitor_approval_notifier.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_screen_section_header.dart';

/// Walk-in approval: OTP verify, notify flat, dial resident, allow/deny entry.
class GuardVisitorApprovalPage extends ConsumerStatefulWidget {
  const GuardVisitorApprovalPage({
    super.key,
    required this.visitorId,
    this.initialExtra,
  });

  /// From route path (e.g. queue / visit id) — display only.
  final String visitorId;
  final Map<String, String>? initialExtra;

  @override
  ConsumerState<GuardVisitorApprovalPage> createState() =>
      _GuardVisitorApprovalPageState();
}

class _GuardVisitorApprovalPageState
    extends ConsumerState<GuardVisitorApprovalPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _villaQuery = TextEditingController();

  /// Ensures [initialExtra] `villaId` is applied even when [guardVillasProvider] is already loaded.
  bool _didResolveInitialVilla = false;
  bool _requestedVillasRefresh = false;

  @override
  void initState() {
    super.initState();
    final x = widget.initialExtra;
    if (x != null) {
      if (x['name'] != null) _name.text = x['name']!;
      if (x['phone'] != null) _phone.text = x['phone']!;
      if (x['otp'] != null) _otp.text = x['otp']!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _otp.dispose();
    _villaQuery.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GuardVisitorApprovalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitorId != widget.visitorId ||
        oldWidget.initialExtra?['villaId'] !=
            widget.initialExtra?['villaId']) {
      _didResolveInitialVilla = false;
      _requestedVillasRefresh = false;
    }
  }

  List<ResidentPickerItem> _filter(List<ResidentPickerItem> all) {
    final q = _villaQuery.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      final block = (r.block ?? '').toLowerCase();
      final num = r.villaNumber.toLowerCase();
      final name = r.name.toLowerCase();
      return block.contains(q) ||
          num.contains(q) ||
          '$block $num'.contains(q) ||
          name.contains(q);
    }).toList();
  }

  void _tryApplyInitialVillaExtra(List<ResidentPickerItem> list) {
    if (_didResolveInitialVilla || !mounted) return;
    final vid = widget.initialExtra?['villaId'];
    if (vid == null || vid.isEmpty) {
      _didResolveInitialVilla = true;
      return;
    }
    if (list.isEmpty) {
      _didResolveInitialVilla = true;
      return;
    }
    // Find first resident in that villa.
    ResidentPickerItem? found;
    for (final r in list) {
      if (r.villaId == vid) {
        found = r;
        break;
      }
    }
    _didResolveInitialVilla = true;
    if (found != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(visitorApprovalFormProvider.notifier).selectResident(found);
        }
      });
    }
  }

  String _requestSubtitle() {
    switch (widget.visitorId) {
      case 'walk-in':
        return 'Walk-in / OTP — enter visitor details and flat below';
      case 'qr-scan':
        return 'From QR scan — confirm details and flat';
      case 'dir':
        return 'From Residents directory — confirm visitor details and OTP';
      default:
        return _mask(widget.visitorId);
    }
  }

  /// Header card. When launched from the Residents directory we already know
  /// _which_ resident the guard tapped, so show their name + flat instead of
  /// the generic "Request" copy. Falls back to the original card otherwise.
  Widget _buildRequestCard(BuildContext context) {
    final residentName = widget.initialExtra?['name']?.trim();
    final hasResidentCtx =
        widget.visitorId == 'dir' &&
        residentName != null &&
        residentName.isNotEmpty;
    final selectedFlatLabel = ref.watch(visitorApprovalFormProvider).resident?.flatLabel;

    final title = hasResidentCtx ? 'Approving for $residentName' : 'Request';
    final subtitle = hasResidentCtx
        ? (selectedFlatLabel != null
              ? '$selectedFlatLabel · From Residents directory'
              : 'From Residents directory')
        : _requestSubtitle();
    final leading = hasResidentCtx
        ? Icons.verified_user_rounded
        : Icons.assignment_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GuardTokens.padScreen),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: GuardTokens.guardAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
              ),
              child: Icon(
                leading,
                color: GuardTokens.guardAccentDeep,
                size: 20,
              ),
            ),
            const SizedBox(width: GuardTokens.g2),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GuardTokens.headingStyle(
                      context,
                    ).copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GuardTokens.captionStyle(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(visitorApprovalFormProvider);
    final formNotifier = ref.read(visitorApprovalFormProvider.notifier);
    // Local aliases for minimal diff with old field references.
    final _resident = formState.resident;
    final _submittingOtp = formState.submittingOtp;
    final _submittingNotify = formState.submittingNotify;
    final _submittingAllow = formState.submittingAllow;
    final _otpVerified = formState.otpVerified;

    if (!_requestedVillasRefresh) {
      _requestedVillasRefresh = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(guardVillasProvider);
      });
    }
    ref.listen(guardResidentsPickerProvider, (prev, next) {
      next.whenData(_tryApplyInitialVillaExtra);
    });

    final villas = ref.watch(guardResidentsPickerProvider);
    final dashAsync = ref.watch(guardDashboardProvider);
    final theme = Theme.of(context);

    return GuardThemeScope(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Visitor approval',
            style: GuardTokens.headingStyle(context),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
            padding: const EdgeInsets.fromLTRB(
              GuardTokens.padScreen,
              GuardTokens.g2,
              GuardTokens.padScreen,
              GuardTokens.g3,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              dashAsync.maybeWhen(
                      data: (d) {
                        if (d.gateName != null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                          child: Card(
                            color: GuardTokens.warningMuted,
                            child: Padding(
                              padding: const EdgeInsets.all(GuardTokens.g2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: GuardTokens.warning,
                                  ),
                                  const SizedBox(width: GuardTokens.g2),
                                  Expanded(
                                    child: Text(
                                      'No active gate shift on your account. '
                                      'OTP admission is blocked until an admin schedules a shift for you at this gate.',
                                      style: GuardTokens.bodyStyle(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    _buildRequestCard(context),
                    _buildPreApprovedStrip(context),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.person_rounded,
                      title: 'Visitor details',
                      subtitle: 'Uses resident notifications — keep accurate',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Visitor name',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: GuardTokens.guardAccent,
                        ),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Visitor phone',
                        prefixIcon: Icon(
                          Icons.phone_android_rounded,
                          color: GuardTokens.guardAccent,
                        ),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.apartment_rounded,
                      title: 'Visiting flat',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _villaQuery,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Block, flat, or name…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
              villas.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(GuardTokens.g3),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: GuardTokens.g2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              userFacingMessage(e),
                              style: GuardTokens.bodyStyle(context),
                            ),
                            const SizedBox(height: GuardTokens.g2),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ref.invalidate(guardVillasProvider),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry loading flats'),
                            ),
                          ],
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return Text(
                            'No residents.',
                            style: GuardTokens.bodyStyle(context),
                          );
                        }
                        final filtered = _filter(list);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusCard,
                            ),
                            border: Border.all(
                              color: GuardTokens.borderSubtle,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              GuardTokens.radiusCard,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  indent: GuardTokens.g2,
                                  endIndent: GuardTokens.g2,
                                  color: GuardTokens.borderSubtle
                                      .withValues(alpha: 0.7),
                                ),
                                itemBuilder: (_, i) {
                                  final r = filtered[i];
                                  final sel = _resident?.userId == r.userId;
                                  return Material(
                                    color: sel
                                        ? GuardTokens.guardAccent
                                            .withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        formNotifier.selectResident(r);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: GuardTokens.g2,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              sel
                                                  ? Icons
                                                      .radio_button_checked_rounded
                                                  : Icons
                                                      .radio_button_off_rounded,
                                              size: 22,
                                              color: sel
                                                  ? GuardTokens.guardAccentDeep
                                                  : theme
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.4),
                                            ),
                                            const SizedBox(
                                              width: GuardTokens.g2,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    r.name,
                                                    style: TextStyle(
                                                      fontWeight: sel
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      fontSize:
                                                          GuardTokens.body,
                                                    ),
                                                  ),
                                                  Text(
                                                    r.tag.isNotEmpty
                                                        ? '${r.flatLabel} · ${r.tag}'
                                                        : r.flatLabel,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (sel)
                                              const Icon(
                                                Icons.done_rounded,
                                                size: 20,
                                                color: GuardTokens
                                                    .guardAccentDeep,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: GuardTokens.sectionGap),
              const GuardScreenSectionHeader(
                      icon: Icons.support_agent_rounded,
                      title: 'Reach the resident',
                      subtitle:
                          'Confirm the visitor first — then ask for the OTP',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submittingNotify
                                ? null
                                : _notifyResident,
                            icon: _submittingNotify
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: GuardTokens.guardAccent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.notifications_active_rounded,
                                  ),
                            label: Text(
                              _submittingNotify ? 'Sending…' : 'Notify flat',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: GuardTokens.g2),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _callResident,
                            icon: const Icon(Icons.call_rounded),
                            label: const Text(
                              'Call',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.verified_user_rounded,
                      title: 'Resident OTP',
                      subtitle:
                          'Ask the resident — they share this in the app/SMS',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: const TextStyle(
                        fontSize: 22,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '• • • •',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    SizedBox(
                      width: double.infinity,
                      height: GuardTokens.btnPrimaryH,
                      child: FilledButton(
                        style: GuardTokens.primaryFilled(context),
                        onPressed: _submittingOtp ? null : _verifyOtp,
                        child: _submittingOtp
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Verify OTP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_otpVerified != null) ...[
                      const SizedBox(height: GuardTokens.g2),
                      _OtpStatusBanner(ok: _otpVerified == true),
                    ],
                    const SizedBox(height: GuardTokens.sectionGap),
                  ],
                ),
              ),
              Material(
                elevation: 12,
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GuardTokens.padScreen,
                      GuardTokens.g2,
                      GuardTokens.padScreen,
                      GuardTokens.g2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: GuardTokens.btnPrimaryH + 4,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: GuardTokens.dangerBrand,
                                side: BorderSide(
                                  color: GuardTokens.dangerBrand.withValues(
                                    alpha: 0.65,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                GuardFlowTelemetry.start(
                                  'guard_deny_entry',
                                ).complete();
                                context.pop(false);
                              },
                              child: const Text(
                                'Deny entry',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: GuardTokens.g2),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: GuardTokens.btnPrimaryH + 4,
                            child: FilledButton(
                              style: GuardTokens.primaryFilled(context),
                              onPressed: _submittingAllow ? null : _allowEntry,
                              child: _submittingAllow
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Allow entry',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prominent strip surfacing pre-approved visitors for the currently-known
  /// flat — shown when launched from the Residents directory or after a QR
  /// scan. Walk-in flows have no villa context yet, so the strip stays hidden
  /// there to avoid suggesting unrelated residents. Tapping Admit fires the
  /// same endpoint as the standalone arrival screen, skipping the OTP dance.
  Widget _buildPreApprovedStrip(BuildContext context) {
    if (widget.visitorId != 'dir' && widget.visitorId != 'qr-scan') {
      return const SizedBox.shrink();
    }

    // Prefer the resolved resident's villa (handles manual changes); fall back
    // to the villaId carried in by the directory tap.
    final vid =
        (ref.watch(visitorApprovalFormProvider).resident?.villaId ??
            widget.initialExtra?['villaId'])?.trim();
    if (vid == null || vid.isEmpty) return const SizedBox.shrink();

    final async = ref.watch(guardPreApprovedEntriesProvider);
    final matches = async.maybeWhen(
      data: (rows) =>
          rows.where((e) => e.villaId == vid).toList(growable: false),
      orElse: () => const <GuardPreApprovedEntry>[],
    );
    if (matches.isEmpty) return const SizedBox.shrink();

    const maxShown = 3;
    final shown = matches.length > maxShown
        ? matches.sublist(0, maxShown)
        : matches;
    final more = matches.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: GuardTokens.g2),
      child: Material(
        color: GuardTokens.successMuted,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(GuardTokens.g2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: GuardTokens.success,
                    size: 22,
                  ),
                  const SizedBox(width: GuardTokens.g1),
                  Expanded(
                    child: Text(
                      '${matches.length} pre-approved '
                      '${matches.length == 1 ? 'visitor' : 'visitors'}',
                      style: GuardTokens.bodyStyle(context).copyWith(
                        fontWeight: FontWeight.w800,
                        color: GuardTokens.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Resident already approved these visitors — tap Admit to check '
                'in without an OTP.',
                style: GuardTokens.captionStyle(context),
              ),
              const SizedBox(height: GuardTokens.g2),
              ...() {
                final admId = ref.watch(visitorApprovalFormProvider).admittingPreApprovedId;
                return [
                  for (final e in shown)
                    _PreApprovedAdmitRow(
                      entry: e,
                      admitting: admId == e.id,
                      disabled: admId != null && admId != e.id,
                      onAdmit: () => _admitPreApprovedInline(e),
                    ),
                ];
              }(),
              if (more > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+ $more more — open the Pre-approved list to see all',
                  style: GuardTokens.captionStyle(context).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// One-tap admit for a pre-approval row.
  Future<void> _admitPreApprovedInline(GuardPreApprovedEntry entry) async {
    final result = await ref
        .read(visitorApprovalFormProvider.notifier)
        .admitPreApproved(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.message ?? (result.success ? '${entry.name} checked in' : 'Could not admit visitor'),
        ),
      ),
    );
    if (result.success) {
      context.pop(true);
    }
  }

  Future<void> _callResident() async {
    final span = GuardFlowTelemetry.start('guard_call_resident');
    final residentPhone = widget.initialExtra?['residentPhone']?.trim();
    if (residentPhone != null && residentPhone.isNotEmpty) {
      final ok = await launchDial(residentPhone);
      if (!mounted) return;
      if (!ok) {
        span.complete(success: false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot open dialer — use Residents directory.'),
          ),
        );
      } else {
        span.complete();
      }
      return;
    }
    span.complete(success: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening directory — tap Call next to flat.'),
      ),
    );
    unawaited(context.push(GuardRoutes.directory));
  }

  Future<void> _verifyOtp() async {
    final result = await ref
        .read(visitorApprovalFormProvider.notifier)
        .verifyOtp(otp: _otp.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Done'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _notifyResident() async {
    final result = await ref
        .read(visitorApprovalFormProvider.notifier)
        .notifyResident(
          visitorName: _name.text.trim(),
          visitorPhone: _phone.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Done')),
    );
  }

  Future<void> _allowEntry() async {
    final result = await ref
        .read(visitorApprovalFormProvider.notifier)
        .allowEntry(
          otp: _otp.text,
          visitorName: _name.text.trim(),
          visitorPhone: _phone.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Done')),
    );
    if (result.success) {
      context.pop(true);
    }
  }

  String _mask(String id) => id.length <= 4 ? id : '${id.substring(0, 4)}…';
}

/// Compact one-tap admit row used inside [_GuardVisitorApprovalPageState._buildPreApprovedStrip].
class _PreApprovedAdmitRow extends StatelessWidget {
  const _PreApprovedAdmitRow({
    required this.entry,
    required this.admitting,
    required this.disabled,
    required this.onAdmit,
  });

  final GuardPreApprovedEntry entry;
  final bool admitting;
  final bool disabled;
  final VoidCallback onAdmit;

  static String? _typeLabel(String? api) {
    if (api == null || api.trim().isEmpty) return null;
    switch (api.trim().toUpperCase()) {
      case 'DELIVERY':
        return 'Delivery';
      case 'SERVICE_PROVIDER':
        return 'Service';
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
    final initial = entry.name.isNotEmpty
        ? entry.name.trim()[0].toUpperCase()
        : '?';
    final typeLabel = _typeLabel(entry.visitorType);
    final subtitle = typeLabel != null
        ? '$typeLabel · ${entry.phone}'
        : entry.phone;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
          border: Border.all(
            color: GuardTokens.success.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: GuardTokens.success.withValues(alpha: 0.15),
              foregroundColor: GuardTokens.success,
              child: Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GuardTokens.captionStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GuardTokens.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      GuardTokens.radiusButton,
                    ),
                  ),
                ),
                onPressed: (admitting || disabled) ? null : onAdmit,
                child: admitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Admit',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpStatusBanner extends StatelessWidget {
  const _OtpStatusBanner({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? GuardTokens.successMuted : GuardTokens.dangerMuted;
    final fg = ok ? GuardTokens.success : GuardTokens.dangerBrand;
    final icon = ok ? Icons.check_circle_rounded : Icons.error_outline_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GuardTokens.g2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: GuardTokens.g2),
          Expanded(
            child: Text(
              ok
                  ? 'OTP matches — resident approved.'
                  : 'OTP failed or expired.',
              style: GuardTokens.bodyStyle(
                context,
              ).copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
