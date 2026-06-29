import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

Color get _kWaterBlue => DesignColors.info;
Color get _kGarbageGreen => DesignColors.success;

/// Admin screen for gate utilities: water supply toggle + garbage pickup.
class AdminGateUtilitiesScreen extends ConsumerStatefulWidget {
  const AdminGateUtilitiesScreen({super.key});

  @override
  ConsumerState<AdminGateUtilitiesScreen> createState() =>
      _AdminGateUtilitiesScreenState();
}

class _AdminGateUtilitiesScreenState
    extends ConsumerState<AdminGateUtilitiesScreen> {
  String? _selectedGateId;
  bool _togglingWater = false;
  bool _loggingGarbage = false;
  bool _markingExit = false;
  String? _resolvingWaterRequestId;

  Future<void> _refresh() async {
    ref.invalidate(adminGatesProvider);
    ref.invalidate(adminWaterSupplyStatusProvider);
    ref.invalidate(adminPendingWaterRequestsProvider);
    if (_selectedGateId != null) {
      ref.invalidate(adminGarbageActiveProvider(_selectedGateId!));
      ref.invalidate(adminWaterSupplyEventsProvider(_selectedGateId));
      ref.invalidate(adminGarbageEventsProvider(_selectedGateId));
    }
  }

  Future<void> _toggleWater(bool turnOn) async {
    if (_selectedGateId == null || _togglingWater) return;

    final confirmed = await _confirm(
      title: turnOn ? 'Turn water supply ON?' : 'Turn water supply OFF?',
      message:
          'This will send a notification to all residents in the society.',
      confirmLabel: turnOn ? 'Yes, turn ON' : 'Yes, turn OFF',
      confirmColor: turnOn ? _kWaterBlue : DesignColors.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _togglingWater = true);
    try {
      await ref
          .read(adminGateUtilitiesRepositoryProvider)
          .toggleWaterSupply(gateId: _selectedGateId!, turnedOn: turnOn);
      ref.invalidate(adminWaterSupplyStatusProvider);
      ref.invalidate(adminWaterSupplyEventsProvider(_selectedGateId));
      if (mounted) {
        _showSnack('Water supply turned ${turnOn ? 'ON' : 'OFF'}', false);
      }
    } catch (e) {
      if (mounted) _showSnack(userFacingMessage(e), true);
    } finally {
      if (mounted) setState(() => _togglingWater = false);
    }
  }

  Future<void> _logGarbageEntry() async {
    if (_selectedGateId == null || _loggingGarbage) return;

    final confirmed = await _confirm(
      title: 'Log garbage pickup arrival?',
      message:
          'This will notify all residents that the garbage collector is at the gate.',
      confirmLabel: 'Yes, notify',
      confirmColor: _kGarbageGreen,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loggingGarbage = true);
    try {
      await ref
          .read(adminGateUtilitiesRepositoryProvider)
          .logGarbageEntry(gateId: _selectedGateId!);
      ref.invalidate(adminGarbageActiveProvider(_selectedGateId!));
      ref.invalidate(adminGarbageEventsProvider(_selectedGateId));
      if (mounted) _showSnack('Garbage collector entry logged', false);
    } catch (e) {
      if (mounted) _showSnack(userFacingMessage(e), true);
    } finally {
      if (mounted) setState(() => _loggingGarbage = false);
    }
  }

  Future<void> _markGarbageExit(String eventId) async {
    if (_markingExit) return;

    final confirmed = await _confirm(
      title: 'Log garbage collector departure?',
      message: 'This marks that the garbage collector has left the gate.',
      confirmLabel: 'Yes, log exit',
      confirmColor: DesignColors.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _markingExit = true);
    try {
      await ref
          .read(adminGateUtilitiesRepositoryProvider)
          .markGarbageExit(eventId);
      ref.invalidate(adminGarbageActiveProvider(_selectedGateId!));
      ref.invalidate(adminGarbageEventsProvider(_selectedGateId));
      if (mounted) _showSnack('Garbage collector exit marked', false);
    } catch (e) {
      if (mounted) _showSnack(userFacingMessage(e), true);
    } finally {
      if (mounted) setState(() => _markingExit = false);
    }
  }

  void _showSnack(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? DesignColors.error : DesignColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignRadius.md)),
    ));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: confirmColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, color: confirmColor, size: 28)),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: confirmColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _resolveWaterRequest(
    String id, {
    required String status,
  }) async {
    if (_resolvingWaterRequestId != null) return;

    final label = status == 'FULFILLED' ? 'fulfill' : 'reject';
    final confirmed = await _confirm(
      title: status == 'FULFILLED' ? 'Fulfill request?' : 'Reject request?',
      message: status == 'FULFILLED'
          ? 'The resident will be notified that their water request was fulfilled.'
          : 'The resident will be notified that their water request was declined.',
      confirmLabel: status == 'FULFILLED' ? 'Fulfill' : 'Reject',
      confirmColor:
          status == 'FULFILLED' ? _kWaterBlue : DesignColors.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _resolvingWaterRequestId = id);
    try {
      await ref
          .read(adminGateUtilitiesRepositoryProvider)
          .resolveWaterRequest(id, status: status);
      ref.invalidate(adminPendingWaterRequestsProvider);
      if (mounted) {
        _showSnack('Water request ${label}ed', false);
      }
    } catch (e) {
      if (mounted) _showSnack(userFacingMessage(e), true);
    } finally {
      if (mounted) setState(() => _resolvingWaterRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gatesAsync = ref.watch(adminGatesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Gate Utilities',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon:
                Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: gatesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: [
                  ShimmerBox(height: 44, borderRadius: DesignRadius.full),
                  const SizedBox(height: 20),
                  ShimmerBox(height: 110, borderRadius: DesignRadius.xl),
                  const SizedBox(height: 16),
                  ShimmerBox(height: 130, borderRadius: DesignRadius.xl),
                ],
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load gates',
              subtitle: 'Pull down to refresh or try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (gates) => _buildBody(gates),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────

  Widget _buildBody(List<Map<String, dynamic>> gates) {
    if (gates.isEmpty) {
      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: EmptyStateWidget(
            icon: Icons.door_front_door_outlined,
            title: 'No gates configured',
            subtitle: 'Gates will appear here once added to your society.',
          ),
        ),
      ]);
    }

    // Auto-select first gate
    if (_selectedGateId == null ||
        !gates.any((g) => g['id']?.toString() == _selectedGateId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(
              () => _selectedGateId = gates.first['id']?.toString() ?? '');
        }
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _buildPendingWaterRequestsSection(),
        const SizedBox(height: 24),
        // Gate selector chips
        _buildGateChips(gates),
        const SizedBox(height: 24),

        if (_selectedGateId != null) ...[
          // ── Water Supply ──
          _buildWaterSupplySection(),
          const SizedBox(height: 28),
          // ── Garbage Pickup ──
          _buildGarbageSection(),
        ],
      ],
    );
  }

  // ── Gate Chips ─────────────────────────────────────────────────────

  Widget _buildGateChips(List<Map<String, dynamic>> gates) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final gate = gates[i];
          final id = gate['id']?.toString() ?? '';
          final name = gate['name']?.toString() ?? 'Gate';
          final selected = _selectedGateId == id;

          return GestureDetector(
            onTap: () => setState(() => _selectedGateId = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? DesignColors.secondary
                    : DesignColors.surface,
                borderRadius: BorderRadius.circular(DesignRadius.full),
                border: Border.all(
                  color: selected
                      ? DesignColors.secondary
                      : DesignColors.borderLight,
                ),
                boxShadow: selected ? DesignElevation.sm : null,
              ),
              child: Text(
                name,
                style: DesignTypography.label.copyWith(
                  color: selected ? Colors.white : DesignColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // PENDING WATER REQUESTS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildPendingWaterRequestsSection() {
    final requestsAsync = ref.watch(adminPendingWaterRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Pending water requests',
          Icons.pending_actions_rounded,
          _kWaterBlue,
        ),
        const SizedBox(height: 14),
        requestsAsync.when(
          loading: () => _shimmerCard(90),
          error: (_, __) => _errorCard('Failed to load pending requests'),
          data: (requests) {
            if (requests.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: BorderRadius.circular(DesignRadius.xl),
                  border: Border.all(color: DesignColors.borderLight),
                ),
                child: Text(
                  'No pending resident requests.',
                  style: DesignTypography.bodySmall
                      .copyWith(color: DesignColors.textSecondary),
                ),
              );
            }

            return Column(
              children: requests.asMap().entries.map((reqEntry) {
                final reqIdx = reqEntry.key;
                final req = reqEntry.value;
                final id = req['id']?.toString() ?? '';
                final user = req['user'] is Map ? req['user'] as Map : {};
                final gate = req['gate'] is Map ? req['gate'] as Map : {};
                final userName = user['name']?.toString() ?? 'Resident';
                final gateName = gate['name']?.toString() ?? 'Gate';
                final requestType =
                    (req['requestType'] ?? '').toString().toUpperCase();
                final turnLabel =
                    requestType == 'TURN_ON' ? 'ON' : 'OFF';
                final isResolving = _resolvingWaterRequestId == id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DesignColors.surface,
                    borderRadius: BorderRadius.circular(DesignRadius.xl),
                    border: Border.all(color: DesignColors.borderLight),
                    boxShadow: DesignElevation.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$userName — Turn water $turnLabel',
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gateName,
                        style: DesignTypography.bodySmall
                            .copyWith(color: DesignColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isResolving
                                  ? null
                                  : () => _resolveWaterRequest(
                                        id,
                                        status: 'REJECTED',
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DesignColors.error,
                                side: BorderSide(
                                  color: DesignColors.error,
                                ),
                              ),
                              child: isResolving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: isResolving
                                  ? null
                                  : () => _resolveWaterRequest(
                                        id,
                                        status: 'FULFILLED',
                                      ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _kWaterBlue,
                              ),
                              child: const Text('Fulfill'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate(delay: DesignAnimations.staggerFor(reqIdx)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // WATER SUPPLY
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildWaterSupplySection() {
    final statusAsync = ref.watch(adminWaterSupplyStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        _sectionTitle('Water Supply', Icons.water_drop_rounded, _kWaterBlue),
        const SizedBox(height: 14),

        // Status + controls card
        statusAsync.when(
          loading: () => _shimmerCard(110),
          error: (_, __) => _errorCard('Failed to load water status'),
          data: (statuses) {
            final gateStatus = statuses
                .cast<Map<String, dynamic>>()
                .where((s) => s['gateId']?.toString() == _selectedGateId);
            final isOn =
                gateStatus.isNotEmpty && gateStatus.first['status'] == 'ON';

            return _waterCard(isOn);
          },
        ),

        // Recent events timeline
        const SizedBox(height: 14),
        _buildWaterTimeline(),
      ],
    );
  }

  Widget _waterCard(bool isOn) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: DesignElevation.sm,
      ),
      child: Column(
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isOn
                  ? _kWaterBlue.withValues(alpha: 0.06)
                  : DesignColors.surfaceSoft,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DesignRadius.xl)),
            ),
            child: Row(
              children: [
                // Animated status indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOn
                        ? _kWaterBlue.withValues(alpha: 0.14)
                        : DesignColors.textTertiary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    isOn ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                    color: isOn ? _kWaterBlue : DesignColors.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status',
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isOn ? _kWaterBlue : DesignColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOn ? 'Supply Running' : 'Supply Stopped',
                            style: DesignTypography.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isOn
                                  ? _kWaterBlue
                                  : DesignColors.textSecondary,
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

          // Action buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _toggleButton(
                    label: 'Turn ON',
                    icon: Icons.power_settings_new_rounded,
                    color: _kWaterBlue,
                    isActive: isOn,
                    isLoading: _togglingWater,
                    onTap: () => _toggleWater(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _toggleButton(
                    label: 'Turn OFF',
                    icon: Icons.power_off_rounded,
                    color: DesignColors.error,
                    isActive: !isOn,
                    isLoading: _togglingWater,
                    onTap: () => _toggleWater(false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null && !isLoading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          border: Border.all(
            color: isActive ? color : DesignColors.borderLight,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading && !isActive)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon,
                  size: 18,
                  color: isActive ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: DesignTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : (enabled ? color : DesignColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTimeline() {
    final eventsAsync =
        ref.watch(adminWaterSupplyEventsProvider(_selectedGateId));

    return eventsAsync.when(
      loading: () => const TimelineSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final recent = events.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: DesignTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textSecondary)),
            const SizedBox(height: 10),
            ...recent.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == recent.length - 1;
              final turnedOn = e['turnedOn'] == true;
              return _timelineRow(
                icon: turnedOn
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: turnedOn ? _kWaterBlue : DesignColors.error,
                title: turnedOn ? 'Turned ON' : 'Turned OFF',
                subtitle: e['reason']?.toString(),
                time: _formatTime(e['createdAt']?.toString()),
                isLast: isLast,
              );
            }),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // GARBAGE PICKUP
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildGarbageSection() {
    if (_selectedGateId == null) return const SizedBox.shrink();
    final activeAsync =
        ref.watch(adminGarbageActiveProvider(_selectedGateId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
            'Garbage Pickup', Icons.local_shipping_rounded, _kGarbageGreen),
        const SizedBox(height: 14),

        activeAsync.when(
          loading: () => _shimmerCard(130),
          error: (_, __) => _errorCard('Failed to load garbage status'),
          data: (data) {
            final isInside = data['isInside'] == true;
            final event = data['event'] as Map<String, dynamic>?;
            final eventId = event?['id']?.toString();
            return _garbageCard(isInside, eventId, event);
          },
        ),

        const SizedBox(height: 14),
        _buildGarbageTimeline(),
      ],
    );
  }

  Widget _garbageCard(
      bool isInside, String? eventId, Map<String, dynamic>? event) {
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
        boxShadow: DesignElevation.sm,
      ),
      child: Column(
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isInside
                  ? _kGarbageGreen.withValues(alpha: 0.06)
                  : DesignColors.surfaceSoft,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DesignRadius.xl)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isInside
                        ? _kGarbageGreen.withValues(alpha: 0.14)
                        : DesignColors.textTertiary.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    isInside
                        ? Icons.local_shipping_rounded
                        : Icons.local_shipping_outlined,
                    color: isInside ? _kGarbageGreen : DesignColors.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Status',
                        style: DesignTypography.captionSmall
                            .copyWith(color: DesignColors.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isInside
                                  ? _kGarbageGreen
                                  : DesignColors.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isInside ? 'Collector Inside' : 'No Active Pickup',
                              style: DesignTypography.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isInside
                                    ? _kGarbageGreen
                                    : DesignColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isInside && event != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Entered ${_formatTime(event['entryTime']?.toString())}',
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Single contextual action (like guard flow)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: isInside && eventId != null
                ? _garbageSingleAction(
                    label: 'Log departure',
                    subtitle:
                        'Collector is inside. Tap when pickup is complete.',
                    icon: Icons.logout_rounded,
                    color: DesignColors.error,
                    isLoading: _markingExit,
                    onTap: () => _markGarbageExit(eventId),
                  )
                : _garbageSingleAction(
                    label: 'Log arrival',
                    subtitle:
                        'Sends an instant notice so residents know pickup is at the gate.',
                    icon: Icons.login_rounded,
                    color: _kGarbageGreen,
                    isLoading: _loggingGarbage,
                    onTap: _logGarbageEntry,
                  ),
          ),
        ],
      ),
    );
  }

  /// Full-width contextual action button (modeled after guard flow).
  Widget _garbageSingleAction({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: color,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.14),
                          border:
                              Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: DesignTypography.label.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: DesignTypography.captionSmall.copyWith(
                                color: DesignColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: color,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGarbageTimeline() {
    final eventsAsync =
        ref.watch(adminGarbageEventsProvider(_selectedGateId));

    return eventsAsync.when(
      loading: () => const TimelineSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();
        final recent = events.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: DesignTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignColors.textSecondary)),
            const SizedBox(height: 10),
            ...recent.asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == recent.length - 1;
              final hasExit = e['exitTime'] != null;
              return _timelineRow(
                icon: hasExit
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded,
                color: hasExit ? _kGarbageGreen : DesignColors.warning,
                title: hasExit ? 'Completed' : 'In Progress',
                subtitle: null,
                time: _formatTime(e['entryTime']?.toString()),
                isLast: isLast,
              );
            }),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: DesignTypography.headingM
                .copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required Color color,
    required String title,
    required String? subtitle,
    required String time,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 2),
                Icon(icon, size: 16, color: color),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: EdgeInsets.symmetric(vertical: 4),
                      color: DesignColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: DesignTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: DesignColors.textPrimary)),
                        if (subtitle != null && subtitle.isNotEmpty)
                          Text(subtitle,
                              style: DesignTypography.captionSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text(time,
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textTertiary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerCard(double height) {
    return ShimmerWrap(
      child: ShimmerBox(height: height, borderRadius: DesignRadius.xl),
    );
  }

  Widget _errorCard(String msg) {
    return EnterpriseInfoBanner(
      icon: Icons.error_outline,
      title: 'Error',
      message: msg,
      tone: EnterpriseTone.danger,
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
