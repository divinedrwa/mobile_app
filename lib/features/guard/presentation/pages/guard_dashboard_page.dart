import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/business_analytics.dart';
import '../../../../core/utils/foreground_polling_mixin.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_dashboard_error.dart';
import '../widgets/guard_dashboard_skeleton.dart';
import '../widgets/guard_home_hero.dart';
import '../widgets/guard_gate_utilities_card.dart';
import '../widgets/guard_premium_quick_actions.dart';
import '../widgets/guard_admit_by_otp_sheet.dart';
import '../widgets/guard_sos_strip.dart';
import '../widgets/guard_summary_strip.dart';
import '../widgets/guard_view_visitors_cta.dart';

/// Premium guard dashboard — summary, visitors entry point, quick actions (Flutter).
class GuardDashboardPage extends ConsumerStatefulWidget {
  const GuardDashboardPage({super.key});

  @override
  ConsumerState<GuardDashboardPage> createState() => _GuardDashboardPageState();
}

class _GuardDashboardPageState extends ConsumerState<GuardDashboardPage>
    with ForegroundPollingMixin {
  final ScrollController _scroll = ScrollController();

  // Refresh the visitor-facing sections on an interval so a guard learns of a
  // resident's approve/reject decision (and new pre-approvals) even when the
  // FCM push is delayed or dropped — the back-channel push is best-effort.
  // Foreground-only: no ticks while the app is backgrounded/locked.
  @override
  Duration get pollInterval => const Duration(seconds: 15);

  @override
  void onPollTick() {
    ref.invalidate(guardDashboardProvider);
    ref.invalidate(guardPendingVisitorsProvider);
    ref.invalidate(guardActiveVisitorsTabProvider);
    ref.invalidate(guardPreApprovedEntriesProvider);
  }

  @override
  void initState() {
    super.initState();
    startForegroundPolling();
  }

  @override
  void dispose() {
    stopForegroundPolling();
    _scroll.dispose();
    super.dispose();
  }

  /// Reloads dashboard + satellite sections; awaits network so pull-to-refresh works.
  Future<void> _refreshAll() async {
    ref.invalidate(guardDashboardProvider);
    ref.invalidate(guardMyGateProvider);
    ref.invalidate(guardActiveAlertsProvider);
    ref.invalidate(guardTodayVisitorsProvider);
    ref.invalidate(guardPendingVisitorsProvider);
    ref.invalidate(guardPreApprovedEntriesProvider);
    ref.invalidate(guardActiveVisitorsTabProvider);
    ref.invalidate(guardPendingParcelsProvider);
    ref.invalidate(guardPatrolsTodayProvider);
    ref.invalidate(guardMyPatrolsProvider);

    await ref.read(guardDashboardProvider.future);

    Future<void> silent(Future<dynamic> f) async {
      try {
        await f;
      } catch (_) {}
    }

    await Future.wait<void>([
      silent(ref.read(guardMyGateProvider.future)),
      silent(ref.read(guardActiveAlertsProvider.future)),
      silent(ref.read(guardTodayVisitorsProvider.future)),
      silent(ref.read(guardPendingVisitorsProvider.future)),
      silent(ref.read(guardPreApprovedEntriesProvider.future)),
      silent(ref.read(guardActiveVisitorsTabProvider.future)),
      silent(ref.read(guardPendingParcelsProvider.future)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(guardDashboardProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? GuardTokens.darkSurface
          : GuardTokens.surfaceCard,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? GuardTokens.darkCard
                : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Icon(
              Icons.security_rounded,
              size: 22,
              color: Theme.of(context).brightness == Brightness.dark
                  ? GuardTokens.guardAccent
                  : GuardTokens.guardAccentDeep,
            ),
            const SizedBox(width: 10),
            Text(
              'Security · Gate',
              style: GuardTokens.headingStyle(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _buildBody(dashAsync),
    );
  }

  Widget _buildBody(AsyncValue<dynamic> dashAsync) {
    final data = dashAsync.valueOrNull;
    final isInitialLoad = dashAsync.isLoading && data == null;
    final hasError = dashAsync.hasError && data == null;

    if (isInitialLoad) { return const GuardDashboardSkeleton(); }
    if (hasError) {
      return GuardDashboardError(
        message: userFacingMessage(dashAsync.error!, 'Could not load dashboard.'),
        onRetry: _refreshAll,
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: _refreshAll,
      child: _DashboardContent(
        dash: data!,
        onRefreshInvalidate: _refreshAll,
        scrollController: _scroll,
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.dash,
    required this.onRefreshInvalidate,
    required this.scrollController,
  });

  final GuardDashboardData dash;
  final Future<void> Function() onRefreshInvalidate;
  final ScrollController scrollController;

  /// Keys the visitor-approval page actually consumes from a scanned payload.
  /// Anything else in the QR (e.g. schema tag `source: 'resident_preapproved_v1'`
  /// from [VisitorSuccessScreen]) is dropped so it doesn't pollute the URL or
  /// trigger surprising side-effects later.
  static const _qrPayloadKeys = {
    'otp',
    'name',
    'phone',
    'villaId',
    'residentPhone',
  };

  Map<String, String>? _scanPayload(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final out = <String, String>{};
        for (final entry in decoded.entries) {
          final key = entry.key.toString();
          if (!_qrPayloadKeys.contains(key)) continue;
          final value = entry.value?.toString().trim() ?? '';
          if (value.isNotEmpty) out[key] = value;
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {
      // Fall through to plain OTP payload.
    }

    if (RegExp(r'^\d{4,8}$').hasMatch(trimmed)) {
      return {'otp': trimmed};
    }
    // Unrecognized payload — open the approval form anyway so the guard can
    // fill details manually. We deliberately do not forward the raw string as
    // a query param: it isn't read anywhere and could collide with future keys.
    return const <String, String>{};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myGate = ref.watch(guardMyGateProvider);
    final activeSos = ref.watch(guardActiveAlertsProvider);

    final effectiveGateId = dash.gateId ?? myGate.asData?.value?.gateId;
    final effectiveGateName = dash.gateName ?? myGate.asData?.value?.name;
    final gateLocation = myGate.asData?.value?.location;

    final sosForStrip = activeSos.when(
      data: (list) => list.isNotEmpty ? list : dash.activeSos,
      loading: () => dash.activeSos,
      error: (_, _) => dash.activeSos,
    );

    return ListView(
      controller: scrollController,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        left: GuardTokens.padScreen,
        right: GuardTokens.padScreen,
        top: GuardTokens.g2,
        bottom: GuardTokens.g3,
      ),
      children: [
        GuardHomeHero(
          guardName: dash.guardName ?? 'Officer',
          gateName: effectiveGateName,
          gateLocation: gateLocation,
          onNotificationsTap: () {
            context.push(GuardRoutes.notifications);
          },
        ),
        const SizedBox(height: GuardTokens.g2),
        GuardSummaryStrip(
          stats: dash.todayStats,
          onOpenDetail: () => context.push(GuardRoutes.todaySummary),
        ),
        const SizedBox(height: GuardTokens.sectionGap),
        GuardViewVisitorsCta(
          onTap: () => context.go(GuardRoutes.entries),
        ),
        const SizedBox(height: GuardTokens.sectionGap),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: GuardTokens.guardAccentDeep,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final admitted = await showAdmitByOtpSheet(context);
              if (admitted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Visitor admitted.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                onRefreshInvalidate();
              }
            },
            icon: const Icon(Icons.password_rounded, size: 18),
            label: const Text('Admit by OTP'),
          ),
        ),
        const SizedBox(height: GuardTokens.sectionGap),
        GuardPremiumQuickActions(
          onAddVisitor: () => context.push(GuardRoutes.addVisitor),
          onScanQr: () async {
            final raw = await context.push<String>(GuardRoutes.qrScan);
            if (!context.mounted || raw == null || raw.trim().isEmpty) {
              return;
            }
            final extra = _scanPayload(raw);
            if (extra == null) return;
            unawaited(BusinessAnalytics.track(BusinessAnalytics.guardQrScan));
            await context.push(
              GuardRoutes.visitorApprovalWithQuery('qr-scan', extra),
            );
            await onRefreshInvalidate();
          },
          onDelivery: () => context.push(GuardRoutes.delivery),
          onEmergency: () => context.push(GuardRoutes.emergency),
          onPreApprovedVisitors: () =>
              context.push(GuardRoutes.preApprovedList),
          onPatrol: () => context.push(GuardRoutes.patrol),
          onApprovedVehicles: () =>
              context.push(GuardRoutes.approvedVehicles),
        ),
        const SizedBox(height: GuardTokens.sectionGap + 6),
        GuardGateUtilitiesCard(
          gateId: effectiveGateId,
          gateLabel: effectiveGateName,
          onSuccess: () {
            onRefreshInvalidate();
          },
        ),
        const SizedBox(height: GuardTokens.sectionGap),
        GuardSosStrip(alerts: sosForStrip),
      ],
    );
  }
}
