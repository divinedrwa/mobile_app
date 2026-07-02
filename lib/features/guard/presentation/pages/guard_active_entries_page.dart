import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../resident/data/models/parcel_model.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../widgets/guard_keep_alive_tab.dart';
import '../widgets/guard_pre_approved_entries_list.dart';
import '../widgets/guard_empty_placeholder.dart';
import '../widgets/guard_skeletons.dart';
import '../widgets/guard_admit_by_otp_sheet.dart';

/// Prominent entry to the OTP-only admit flow (type OTP → resolve → admit),
/// so a guard never has to hunt a visitor in a long pre-approved list.
class _AdmitByOtpButton extends StatelessWidget {
  const _AdmitByOtpButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () async {
          final admitted = await showAdmitByOtpSheet(context);
          if (admitted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Visitor admitted.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        icon: const Icon(Icons.password_rounded, size: 18),
        label: const Text('Admit by OTP'),
      ),
    );
  }
}

List<BoxShadow> _visitorsListCardShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.035),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Tabs: Visitors / Pre-approved / Deliveries / Vehicles — mark exit / collect where applicable.
class GuardActiveEntriesPage extends ConsumerStatefulWidget {
  const GuardActiveEntriesPage({super.key});

  @override
  ConsumerState<GuardActiveEntriesPage> createState() =>
      _GuardActiveEntriesPageState();
}

class _GuardActiveEntriesPageState extends ConsumerState<GuardActiveEntriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Timer? _poll;
  final _visitorsScroll = ScrollController();
  final _preApprovedScroll = ScrollController();
  final _deliveriesScroll = ScrollController();
  final _vehiclesScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    // Keep body (IndexedStack) in sync — TabController notifies listeners on index changes.
    _tab.addListener(_onTabCtl);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardDashboardProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
    });
  }

  void _onTabCtl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tab.removeListener(_onTabCtl);
    _tab.dispose();
    _visitorsScroll.dispose();
    _preApprovedScroll.dispose();
    _deliveriesScroll.dispose();
    _vehiclesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Active entries',
            style: GuardTokens.headingStyle(context).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              letterSpacing: -0.2,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding:
                    const EdgeInsets.only(left: 4, right: GuardTokens.padScreen),
                labelColor: GuardTokens.guardAccentDeep,
                unselectedLabelColor: GuardTokens.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                indicatorColor: GuardTokens.guardAccentDeep,
                indicatorWeight: 3,
                dividerColor: GuardTokens.borderSubtle,
                tabs: const [
                  Tab(text: 'Visitors'),
                  Tab(text: 'Pre-approved'),
                  Tab(text: 'Deliveries'),
                  Tab(text: 'Vehicles'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tab,
          physics: const BouncingScrollPhysics(),
          children: [
            GuardKeepAliveTab(child: _VisitorsTab(scrollController: _visitorsScroll)),
            GuardKeepAliveTab(
              child: _PreApprovedTab(scrollController: _preApprovedScroll),
            ),
            GuardKeepAliveTab(
              child: _DeliveriesTab(scrollController: _deliveriesScroll),
            ),
            GuardKeepAliveTab(child: _VehicleTab(scrollController: _vehiclesScroll)),
          ],
        ),
      ),
    );
  }
}

class _VisitorsTab extends ConsumerStatefulWidget {
  const _VisitorsTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  ConsumerState<_VisitorsTab> createState() => _VisitorsTabState();
}

class _VisitorsTabState extends ConsumerState<_VisitorsTab> {
  // Per-row busy guard so a rapid double-tap on Admit/Mark exit can't fire
  // two concurrent network calls for the same visitor.
  final Set<String> _busyVisitorIds = <String>{};

  String _statusLabel(GuardVisitorRow v) =>
      guardVisitorStatusLabel(v, compact: true);

  Color _statusTone(BuildContext context, GuardVisitorRow v) {
    if (v.entryDenied) return GuardTokens.dangerBrand;
    if (v.needsResidentApproval) return GuardTokens.warning;
    if (v.awaitingGuardAdmission) return GuardTokens.guardAccentDeep;
    if (v.awaitingCheckout) return GuardTokens.success;
    return GuardTokens.textSecondary;
  }

  Future<void> _confirmAdmission(
    BuildContext context,
    GuardVisitorRow v,
  ) async {
    if (_busyVisitorIds.contains(v.id)) return;
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _busyVisitorIds.add(v.id));
    try {
      await ref.read(guardRepositoryProvider).confirmVisitorEntryAfterApproval(v.id);
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
      ref.invalidate(guardTodayVisitorsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${v.name} checked in')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busyVisitorIds.remove(v.id));
    }
  }

  Widget _visitorCard(BuildContext context, GuardVisitorRow v) {
    final trailing = _visitorTrailing(context, v);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initial = v.name.trim().isNotEmpty
        ? v.name.trim()[0].toUpperCase()
        : '?';
    final tone = _statusTone(context, v);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
          boxShadow: _visitorsListCardShadow(context),
        ),
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
            side: BorderSide(
              color: isDark
                  ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                  : GuardTokens.borderSubtle.withValues(alpha: 0.9),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: trailing == null
                  ? BorderRadius.circular(GuardTokens.radiusCard)
                  : const BorderRadius.only(
                      topLeft: Radius.circular(GuardTokens.radiusCard),
                      topRight: Radius.circular(GuardTokens.radiusCard),
                    ),
              onTap: () => context.push(GuardRoutes.visitorDetail, extra: v),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tone.withValues(alpha: 0.12),
                            border: Border.all(
                              color: tone.withValues(alpha: 0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: tone,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GuardTokens.headingStyle(context)
                                          .copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _StatePill(
                                    label: _statusLabel(v),
                                    tone: tone,
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: GuardTokens.textSecondary
                                        .withValues(alpha: 0.55),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              _VisitorMetaLine(
                                icon: Icons.layers_outlined,
                                text: [
                                  if (v.villaLabel != null)
                                    'Flat ${v.villaLabel}',
                                  v.phone,
                                ].join(' · '),
                              ),
                              const SizedBox(height: 2),
                              _VisitorMetaLine(
                                icon: Icons.schedule_rounded,
                                text:
                                    'In ${_fmtTime(v.checkInTime)}'
                                    '${v.purpose != null && v.purpose!.trim().isNotEmpty ? ' · ${v.purpose!.trim()}' : ''}',
                                muted: true,
                              ),
                              if (v.isMultiVilla) ...[
                                const SizedBox(height: 8),
                                _FlatApprovalBreakdown(
                                  approvals: v.villaApprovals,
                                  showHint: v.hasSplitFlatDecision,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? GuardTokens.darkBorder.withValues(alpha: 0.65)
                    : GuardTokens.borderSubtle.withValues(alpha: 0.75),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guardActiveVisitorsTabProvider);
    final staleData = async.valueOrNull;
    final isInitialLoad = async.isLoading && staleData == null;
    final hasError = async.hasError && staleData == null;

    if (isInitialLoad) { return const SizedBox.expand(child: GuardListSkeleton()); }
    if (hasError) {
      return SizedBox.expand(
      child: guardRefreshableMinHeight(
        context: context,
        scrollController: widget.scrollController,
        onRefresh: () async {
          ref.invalidate(guardActiveVisitorsTabProvider);
          await ref.read(guardActiveVisitorsTabProvider.future);
        },
        children: [
          GuardEmptyPlaceholder(
            icon: Icons.cloud_off_rounded,
            iconColor: GuardTokens.warning,
            title: 'Could not load visitors',
            message: userFacingMessage(async.error!, 'Check your connection and try again.'),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(guardActiveVisitorsTabProvider),
          ),
        ],
      ),
    );
    }

    // Use stale data during background refresh to avoid list flicker
    final liveOrStale = staleData ?? async.valueOrNull;
    if (liveOrStale == null) return const SizedBox.expand(child: GuardListSkeleton());

    // original data branch — replace local `data` with `liveOrStale`
    return _buildVisitorsList(context, liveOrStale);
  }

  Widget _buildVisitorsList(BuildContext context, dynamic data) {
        final rows = data.pendingVisitors;
        final ve = data.pendingVisitorsError;

        Future<void> onRefresh() async {
          ref.invalidate(guardActiveVisitorsTabProvider);
          ref.invalidate(guardPreApprovedEntriesProvider);
          ref.invalidate(guardTodayVisitorsProvider);
          await ref.read(guardActiveVisitorsTabProvider.future);
        }

        if (rows.isEmpty) {
          return SizedBox.expand(
            child: guardRefreshableMinHeight(
              context: context,
              scrollController: widget.scrollController,
              onRefresh: onRefresh,
              children: [
                if (ve != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                    child: _FetchWarningBanner(
                      message: userFacingMessage(
                        ve,
                        'Gate visitor list could not be loaded.',
                      ),
                      onRetry: () =>
                          ref.invalidate(guardActiveVisitorsTabProvider),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _AdmitByOtpButton(),
                ),
                GuardEmptyPlaceholder(
                  icon: Icons.groups_outlined,
                  title: ve != null ? 'Nothing to show yet' : 'No visitors',
                  message: ve != null
                      ? 'Pull to refresh or retry. Expected guests are listed under Pre-approved.'
                      : 'Walk-ins and approvals show here. '
                          'Resident expected guests stay under the Pre-approved tab until they arrive.',
                  actionLabel: 'Add visitor',
                  onAction: () => context.push(GuardRoutes.addVisitor),
                ),
              ],
            ),
          );
        }

        // Fixed header widgets, then one lazily-built card per on-site visitor
        // (ListView.builder so a large gate doesn't build every row up-front).
        final headers = <Widget>[
          if (ve != null)
            Padding(
              padding: const EdgeInsets.only(bottom: GuardTokens.g2),
              child: _FetchWarningBanner(
                message: userFacingMessage(
                  ve,
                  'Gate visitor list could not be loaded.',
                ),
                onRetry: () => ref.invalidate(guardActiveVisitorsTabProvider),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _AdmitByOtpButton(),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SummaryBanner(
              icon: Icons.people_alt_rounded,
              label:
                  '${rows.length} visitor${rows.length == 1 ? '' : 's'} on-site',
              tone: GuardTokens.success,
            ),
          ),
        ];

        return SizedBox.expand(
          child: RefreshIndicator(
            color: GuardTokens.guardAccentDeep,
            onRefresh: onRefresh,
            child: ListView.builder(
              controller: widget.scrollController,
              primary: false,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(GuardTokens.padScreen),
              itemCount: headers.length + (rows.length as int),
              itemBuilder: (context, i) => i < headers.length
                  ? headers[i]
                  : _visitorCard(context, rows[i - headers.length]),
            ),
          ),
        );
  }

  Widget? _visitorTrailing(
    BuildContext context,
    GuardVisitorRow v,
  ) {
    final busy = _busyVisitorIds.contains(v.id);
    if (v.awaitingGuardAdmission) {
      return FilledButton.icon(
        style: GuardTokens.primaryFilled(context).copyWith(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: WidgetStateProperty.all(const Size(0, 36)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        onPressed: busy ? null : () => _confirmAdmission(context, v),
        icon: busy
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.verified_user_outlined, size: 18),
        label: Text(
          busy ? 'Admitting…' : 'Admit at gate',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      );
    }
    final status = v.status.trim().toUpperCase();
    if (v.awaitingCheckout && status == 'CHECKED_IN') {
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: GuardTokens.guardAccentDeep,
          backgroundColor: GuardTokens.guardAccent.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: GuardTokens.guardAccent.withValues(alpha: 0.35),
            ),
          ),
        ),
        onPressed: busy ? null : () => _checkout(context, v),
        icon: busy
            ? SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: GuardTokens.guardAccentDeep,))
            : Icon(Icons.logout_rounded, size: 18),
        label: Text(
          busy ? 'Marking…' : 'Mark exit',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      );
    }
    return null;
  }

  Future<void> _checkout(
    BuildContext context,
    GuardVisitorRow v,
  ) async {
    if (_busyVisitorIds.contains(v.id)) return;
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
    setState(() => _busyVisitorIds.add(v.id));
    try {
      await ref.read(guardRepositoryProvider).checkOutVisitor(v.id);
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
      ref.invalidate(guardTodayVisitorsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busyVisitorIds.remove(v.id));
    }
  }
}

class _PreApprovedTab extends ConsumerWidget {
  const _PreApprovedTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardPreApprovedEntriesProvider);
    final stale = async.valueOrNull;
    final isInitialLoad = async.isLoading && stale == null;
    final hasError = async.hasError && stale == null;

    if (isInitialLoad) { return const SizedBox.expand(child: GuardListSkeleton()); }
    if (hasError) {
      return SizedBox.expand(
        child: guardRefreshableMinHeight(
          context: context,
          scrollController: scrollController,
          onRefresh: () async {
            ref.invalidate(guardPreApprovedEntriesProvider);
            await ref.read(guardPreApprovedEntriesProvider.future);
          },
          children: [
            GuardEmptyPlaceholder(
              icon: Icons.cloud_off_rounded,
              iconColor: GuardTokens.warning,
              title: 'Could not load pre-approved',
              message: userFacingMessage(async.error!, 'Check your connection and try again.'),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(guardPreApprovedEntriesProvider),
            ),
          ],
        ),
      );
    }

    final rows = stale ?? [];
    return SizedBox.expand(
      child: RefreshIndicator(
        color: GuardTokens.guardAccentDeep,
        onRefresh: () async {
          ref.invalidate(guardPreApprovedEntriesProvider);
          await ref.read(guardPreApprovedEntriesProvider.future);
        },
        child: GuardPreApprovedEntriesListContent(
          rows: rows,
          scrollController: scrollController,
          showVisitorArrivedButton: true,
          onEntryTap: (e) => context.push(GuardRoutes.preApprovedArrival, extra: e),
        ),
      ),
    );
  }
}

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(guardPendingParcelsProvider);
    final stale = parcelsAsync.valueOrNull;
    final isInitialLoad = parcelsAsync.isLoading && stale == null;

    if (isInitialLoad) return const SizedBox.expand(child: GuardListSkeleton());

    return parcelsAsync.when(
      loading: () => const SizedBox.expand(child: GuardListSkeleton()),
      error: (e, _) => SizedBox.expand(
        child: guardRefreshableMinHeight(
        context: context,
        scrollController: scrollController,
        onRefresh: () async {
          ref.invalidate(guardPendingParcelsProvider);
          await ref.read(guardPendingParcelsProvider.future);
        },
        children: [
          GuardEmptyPlaceholder(
            icon: Icons.local_shipping_outlined,
            iconColor: GuardTokens.warning,
            title: 'Could not load deliveries',
            message: userFacingMessage(e, 'Check your connection and try again.'),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(guardPendingParcelsProvider),
          ),
        ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return SizedBox.expand(
            child: guardRefreshableMinHeight(
            context: context,
            scrollController: scrollController,
            onRefresh: () async {
              ref.invalidate(guardPendingParcelsProvider);
              await ref.read(guardPendingParcelsProvider.future);
            },
            children: [
              GuardEmptyPlaceholder(
                icon: Icons.inventory_2_outlined,
                title: 'No pending parcels',
                message:
                    'Incoming parcels logged at your gate appear here until residents collect them.',
                actionLabel: 'Log delivery',
                onAction: () => context.push(GuardRoutes.delivery),
              ),
            ],
            ),
          );
        }
        return SizedBox.expand(
          child: RefreshIndicator(
          color: GuardTokens.guardAccentDeep,
          onRefresh: () async {
            ref.invalidate(guardPendingParcelsProvider);
            await ref.read(guardPendingParcelsProvider.future);
          },
          child: ListView.builder(
            controller: scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(GuardTokens.padScreen),
            itemCount: list.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                  child: _SummaryBanner(
                    icon: Icons.inventory_2_rounded,
                    label:
                        '${list.length} parcel${list.length == 1 ? '' : 's'} awaiting collection',
                    tone: GuardTokens.warning,
                  ),
                );
              }
              final p = list[i - 1];
              final primaryTitle = p.trackingNumber.trim().isNotEmpty
                  ? p.trackingNumber
                  : p.courier.trim().isNotEmpty
                      ? p.courier
                      : 'Delivery';
              final canCollect =
                  p.id != null &&
                  p.status != ParcelStatus.collected &&
                  p.status != ParcelStatus.returned;

              return _DeliveryCard(
                parcel: p,
                primaryTitle: primaryTitle,
                canCollect: canCollect,
                onCollected: () async {
                  try {
                    await ref
                        .read(guardRepositoryProvider)
                        .markParcelCollected(p.id!);
                    ref.invalidate(guardPendingParcelsProvider);
                    ref.invalidate(guardTodayParcelsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(userFacingMessage(e))),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        );
      },
    );
  }
}

class _VehicleTab extends ConsumerWidget {
  const _VehicleTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardGateVehicleTodayProvider);
    final isInitialLoad = async.isLoading && async.valueOrNull == null;

    if (isInitialLoad) return const SizedBox.expand(child: GuardListSkeleton());

    return async.when(
      loading: () => const SizedBox.expand(child: GuardListSkeleton()),
      error: (e, _) => SizedBox.expand(
        child: guardRefreshableMinHeight(
        context: context,
        scrollController: scrollController,
        onRefresh: () async {
          ref.invalidate(guardGateVehicleTodayProvider);
          await ref.read(guardGateVehicleTodayProvider.future);
        },
        children: [
          GuardEmptyPlaceholder(
            icon: Icons.directions_car_outlined,
            iconColor: GuardTokens.warning,
            title: 'Could not load vehicles',
            message: userFacingMessage(e, 'Check your connection and try again.'),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(guardGateVehicleTodayProvider),
          ),
        ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return SizedBox.expand(
            child: guardRefreshableMinHeight(
            context: context,
            scrollController: scrollController,
            onRefresh: () async {
              ref.invalidate(guardGateVehicleTodayProvider);
              await ref.read(guardGateVehicleTodayProvider.future);
            },
            children: [
              GuardEmptyPlaceholder(
                icon: Icons.directions_car_outlined,
                title: 'No vehicles logged today',
                message:
                    'Register arrivals from Vehicle entry on the home screen — '
                    'they will show here until you mark exit.',
                actionLabel: 'Vehicle entry',
                onAction: () => context.push(GuardRoutes.vehicle),
              ),
            ],
            ),
          );
        }
        final insideCount = entries.where((v) => v.isInside).length;
        return SizedBox.expand(
          child: RefreshIndicator(
          color: GuardTokens.guardAccentDeep,
          onRefresh: () async {
            ref.invalidate(guardGateVehicleTodayProvider);
            await ref.read(guardGateVehicleTodayProvider.future);
          },
          child: ListView.builder(
            controller: scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(GuardTokens.padScreen),
            itemCount: entries.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                  child: _SummaryBanner(
                    icon: Icons.directions_car_rounded,
                    label:
                        '$insideCount vehicle${insideCount == 1 ? '' : 's'} currently inside',
                    tone: GuardTokens.guardAccentDeep,
                  ),
                );
              }
              final v = entries[i - 1];
              return _VehicleCard(
                entry: v,
                onMarkExit: (!v.isInside || v.id.isEmpty)
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(guardRepositoryProvider)
                              .markGateVehicleExit(v.id);
                          ref.invalidate(guardGateVehicleTodayProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(userFacingMessage(e)),
                              ),
                            );
                          }
                        }
                      },
              );
            },
          ),
        ),
        );
      },
    );
  }
}

String _vehicleKindLabel(String kind) {
  switch (kind.trim().toUpperCase()) {
    case 'RESIDENT':
      return 'Resident vehicle';
    case 'VISITOR':
      return 'Visitor vehicle';
    default:
      return kind.trim().isEmpty ? 'Vehicle' : kind.trim();
  }
}

String _fmtTime(DateTime? dt) {
  if (dt == null) return '--:--';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.parcel,
    required this.primaryTitle,
    required this.canCollect,
    required this.onCollected,
  });

  final dynamic parcel;
  final String primaryTitle;
  final bool canCollect;
  final Future<void> Function() onCollected;

  Color _statusTone() {
    if (parcel.status == ParcelStatus.collected) return GuardTokens.success;
    if (parcel.status == ParcelStatus.returned) return GuardTokens.textSecondary;
    return GuardTokens.warning;
  }

  String _statusLabel() => parcel.status.label as String;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = _statusTone();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
          boxShadow: _visitorsListCardShadow(context),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
            side: BorderSide(
              color: isDark
                  ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                  : GuardTokens.borderSubtle.withValues(alpha: 0.9),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: GuardTokens.guardAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: GuardTokens.guardAccent.withValues(alpha: 0.22),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: GuardTokens.guardAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  primaryTitle,
                                  style: GuardTokens.headingStyle(context).copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatePill(label: _statusLabel(), tone: tone),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if ((parcel.trackingNumber as String).trim().isNotEmpty &&
                              primaryTitle.trim() != (parcel.trackingNumber as String).trim())
                            _VisitorMetaLine(
                              icon: Icons.tag_rounded,
                              text: 'Tracking · ${parcel.trackingNumber}',
                            ),
                          if ((parcel.courier as String).trim().isNotEmpty &&
                              primaryTitle.trim() != (parcel.courier as String).trim())
                            _VisitorMetaLine(
                              icon: Icons.local_shipping_outlined,
                              text: 'Carrier · ${parcel.courier}',
                            ),
                          _VisitorMetaLine(
                            icon: Icons.schedule_rounded,
                            text: 'Received ${_fmtTime(parcel.receivedAt as DateTime?)}',
                            muted: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (canCollect) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? GuardTokens.darkBorder.withValues(alpha: 0.65)
                      : GuardTokens.borderSubtle.withValues(alpha: 0.75),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _BusyTextActionButton(
                      style: GuardTokens.textLink(context),
                      label: 'Mark collected',
                      busyLabel: 'Marking…',
                      onPressed: onCollected,
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.entry,
    required this.onMarkExit,
  });

  final dynamic entry;
  final Future<void> Function()? onMarkExit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInside = entry.isInside as bool;
    final tone = isInside ? GuardTokens.success : GuardTokens.textSecondary;
    final reg = (entry.registrationNumber as String).isNotEmpty
        ? entry.registrationNumber as String
        : '(No plate)';
    final subtitleLine = [
      _vehicleKindLabel(entry.kind as String),
      if ((entry.flatLabel as String).isNotEmpty) entry.flatLabel as String,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
          boxShadow: _visitorsListCardShadow(context),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
            side: BorderSide(
              color: isDark
                  ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                  : GuardTokens.borderSubtle.withValues(alpha: 0.9),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: tone.withValues(alpha: 0.22)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.directions_car_outlined,
                        size: 20,
                        color: tone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  reg,
                                  style: GuardTokens.headingStyle(context).copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatePill(
                                label: isInside ? 'Inside' : 'Out',
                                tone: tone,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          _VisitorMetaLine(
                            icon: Icons.layers_outlined,
                            text: subtitleLine,
                          ),
                          _VisitorMetaLine(
                            icon: isInside
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            text: isInside
                                ? 'Awaiting exit mark'
                                : 'Exit recorded',
                            muted: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onMarkExit != null) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? GuardTokens.darkBorder.withValues(alpha: 0.65)
                      : GuardTokens.borderSubtle.withValues(alpha: 0.75),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _BusyTextActionButton(
                      style: GuardTokens.textLink(context),
                      label: 'Mark exit',
                      busyLabel: 'Recording…',
                      onPressed: onMarkExit!,
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

/// A small `TextButton` wrapper that owns its own busy state so per-row
/// actions in the deliveries and vehicles tabs (which are still
/// `ConsumerWidget`s) can show an inline spinner during the network call
/// and reject double-taps without us having to lift state into a parent.
class _BusyTextActionButton extends StatefulWidget {
  const _BusyTextActionButton({
    required this.label,
    required this.busyLabel,
    required this.onPressed,
    this.style,
  });

  final String label;
  final String busyLabel;
  final Future<void> Function() onPressed;
  final ButtonStyle? style;

  @override
  State<_BusyTextActionButton> createState() => _BusyTextActionButtonState();
}

class _BusyTextActionButtonState extends State<_BusyTextActionButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: widget.style,
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onPressed();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: _busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text(widget.busyLabel),
              ],
            )
          : Text(widget.label),
    );
  }
}

class _VisitorMetaLine extends StatelessWidget {
  const _VisitorMetaLine({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: muted
              ? GuardTokens.textSecondary.withValues(alpha: 0.9)
              : GuardTokens.guardAccent.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GuardTokens.captionStyle(context).copyWith(
              color: muted ? GuardTokens.textSecondary : GuardTokens.textPrimary,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
              height: 1.3,
              fontSize: muted ? 12 : 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-flat approval chips for a multi-villa visit, so the guard directs the
/// visitor only to flats that approved (and never to one that declined).
class _FlatApprovalBreakdown extends StatelessWidget {
  const _FlatApprovalBreakdown({required this.approvals, this.showHint = false});

  final List<GuardVillaApproval> approvals;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: approvals.map((a) {
            final Color tone;
            final IconData icon;
            if (a.approved) {
              tone = GuardTokens.guardAccentDeep;
              icon = Icons.check_circle_rounded;
            } else if (a.rejected) {
              tone = GuardTokens.dangerBrand;
              icon = Icons.cancel_rounded;
            } else {
              tone = GuardTokens.warning;
              icon = Icons.hourglass_bottom_rounded;
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tone.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: tone),
                  const SizedBox(width: 4),
                  Text(
                    a.villaLabel,
                    style: GuardTokens.captionStyle(context).copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (showHint) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: GuardTokens.warning),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Flats disagree — send the visitor only to approved flats.',
                  style: GuardTokens.captionStyle(context).copyWith(
                    color: GuardTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FetchWarningBanner extends StatelessWidget {
  const _FetchWarningBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GuardTokens.g2),
      decoration: BoxDecoration(
        color: GuardTokens.warningMuted,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(
          color: GuardTokens.warning.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: GuardTokens.warning),
          const SizedBox(width: GuardTokens.g2),
          Expanded(
            child: Text(
              message,
              style: GuardTokens.bodyStyle(context).copyWith(
                height: 1.38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tone, size: 17, semanticLabel: null),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GuardTokens.captionStyle(context).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tone.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
