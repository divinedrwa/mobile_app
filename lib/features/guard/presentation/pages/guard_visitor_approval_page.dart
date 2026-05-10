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

  VillaPickerItem? _villa;
  bool _submittingOtp = false;
  bool _submittingNotify = false;
  bool _submittingAllow = false;
  bool? _otpVerified;
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

  List<VillaPickerItem> _filter(List<VillaPickerItem> all) {
    final q = _villaQuery.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((v) {
      final block = (v.block ?? '').toLowerCase();
      final num = v.villaNumber.toLowerCase();
      return block.contains(q) || num.contains(q) || '$block $num'.contains(q);
    }).toList();
  }

  void _tryApplyInitialVillaExtra(List<VillaPickerItem> list) {
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
    VillaPickerItem? found;
    for (final v in list) {
      if (v.id == vid) {
        found = v;
        break;
      }
    }
    _didResolveInitialVilla = true;
    if (found != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _villa = found);
      });
    }
  }

  String _requestSubtitle() {
    switch (widget.visitorId) {
      case 'walk-in':
        return 'Walk-in / OTP — enter visitor details and flat below';
      case 'qr-scan':
        return 'From QR scan — confirm details and flat';
      default:
        return _mask(widget.visitorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_requestedVillasRefresh) {
      _requestedVillasRefresh = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(guardVillasProvider);
      });
    }
    ref.listen(guardVillasProvider, (prev, next) {
      next.whenData(_tryApplyInitialVillaExtra);
    });

    final villas = ref.watch(guardVillasProvider);
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GuardTokens.padScreen),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request',
                              style: GuardTokens.headingStyle(
                                context,
                              ).copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _requestSubtitle(),
                              style: GuardTokens.captionStyle(context),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                        hintText: 'Search block / flat…',
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
                            'No flats.',
                            style: GuardTokens.bodyStyle(context),
                          );
                        }
                        final filtered = _filter(list);
                        return Wrap(
                          spacing: GuardTokens.g2,
                          runSpacing: GuardTokens.g2,
                          children: filtered.map((v) {
                            final label = v.block != null && v.block!.isNotEmpty
                                ? '${v.block} · ${v.villaNumber}'
                                : v.villaNumber;
                            final sel = _villa?.id == v.id;
                            return ChoiceChip(
                              label: Text(label),
                              selected: sel,
                              onSelected: (_) {
                                setState(() {
                                  _villa = v;
                                  _otpVerified = null;
                                });
                              },
                              selectedColor: GuardTokens.guardAccent.withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: GuardTokens.guardAccentDeep,
                              labelStyle: TextStyle(
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        );
                      },
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
                    const GuardScreenSectionHeader(
                      icon: Icons.support_agent_rounded,
                      title: 'Reach the resident',
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
    final villa = _villa ?? await _firstVilla();
    if (!mounted) return;
    if (villa == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a flat first')));
      return;
    }
    if (_otp.text.trim().length < 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter OTP from resident')));
      return;
    }
    setState(() {
      _submittingOtp = true;
      _otpVerified = null;
    });
    try {
      final res = await ref
          .read(guardRepositoryProvider)
          .verifyVisitorOtp(otp: _otp.text.trim(), villaId: villa.id);
      final ok = res['verified'] == true;
      setState(() => _otpVerified = ok);
      if (mounted) {
        final apiMsg = res['message']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'OTP verified' : (apiMsg ?? 'Verification failed'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _otpVerified = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submittingOtp = false);
    }
  }

  Future<void> _notifyResident() async {
    final villa = _villa ?? await _firstVilla();
    if (!mounted) return;
    if (villa == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a flat first')));
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter visitor name and phone')),
      );
      return;
    }
    setState(() => _submittingNotify = true);
    final span = GuardFlowTelemetry.start('guard_notify_visitor_at_gate');
    try {
      await ref
          .read(guardRepositoryProvider)
          .notifyVisitorAtGate(
            villaId: villa.id,
            visitorName: _name.text.trim(),
            visitorPhone: _phone.text.trim(),
          );
      span.complete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flat residents were notified')),
        );
      }
    } catch (e) {
      span.complete(success: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submittingNotify = false);
    }
  }

  Future<void> _allowEntry() async {
    final villa = _villa ?? await _firstVilla();
    if (!mounted) return;
    if (villa == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a flat')));
      return;
    }
    final otp = _otp.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter OTP to allow gate entry')),
      );
      return;
    }

    setState(() => _submittingAllow = true);
    final span = GuardFlowTelemetry.start('guard_allow_entry');
    try {
      final res = await ref
          .read(guardRepositoryProvider)
          .approveVisitorEntry(
            otp: otp,
            villaId: villa.id,
            visitorName: _name.text.trim(),
            visitorPhone: _phone.text.trim(),
          );
      final admitted = res['admitted'] == true || res['verified'] == true;
      if (!mounted) return;
      if (admitted) {
        span.complete();
        ref.invalidate(guardDashboardProvider);
        ref.invalidate(guardTodayVisitorsProvider);
        ref.invalidate(guardPendingVisitorsProvider);
        ref.invalidate(guardActiveVisitorsTabProvider);
        ref.invalidate(guardPreApprovedEntriesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? 'Visitor admitted and checked in',
            ),
          ),
        );
        context.pop(true);
        return;
      }
      span.complete(success: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Entry not allowed'),
        ),
      );
    } catch (e) {
      span.complete(success: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submittingAllow = false);
    }
  }

  Future<VillaPickerItem?> _firstVilla() async {
    try {
      final list = await ref.read(guardVillasProvider.future);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  String _mask(String id) => id.length <= 4 ? id : '${id.substring(0, 4)}…';
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
