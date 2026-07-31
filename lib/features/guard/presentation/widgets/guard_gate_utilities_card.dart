import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// Water supply notification (ON/OFF) + garbage collector arrival log (uses [gateId] from shift).
class GuardGateUtilitiesCard extends ConsumerStatefulWidget {
  const GuardGateUtilitiesCard({
    super.key,
    required this.gateId,
    this.gateLabel,
    this.onSuccess,
  });

  final String? gateId;
  final String? gateLabel;
  final VoidCallback? onSuccess;

  @override
  ConsumerState<GuardGateUtilitiesCard> createState() =>
      _GuardGateUtilitiesCardState();
}

class _GuardGateUtilitiesCardState extends ConsumerState<GuardGateUtilitiesCard> {
  bool _loadingWaterOn = false;
  bool _loadingWaterOff = false;
  bool _loadingGarbageArrival = false;
  bool _loadingGarbageDeparture = false;
  bool _loadingGarbageStatus = false;

  /// Non-null when garbage collector is currently inside.
  Map<String, dynamic>? _activeGarbageEvent;

  bool get _anyLoading =>
      _loadingWaterOn ||
      _loadingWaterOff ||
      _loadingGarbageArrival ||
      _loadingGarbageDeparture;

  @override
  void initState() {
    super.initState();
    _fetchGarbageStatus();
  }

  Future<void> _fetchGarbageStatus() async {
    final id = widget.gateId;
    if (id == null || id.isEmpty) return;
    setState(() => _loadingGarbageStatus = true);
    try {
      final event = await ref.read(guardRepositoryProvider).getActiveGarbageCollection();
      if (mounted) setState(() => _activeGarbageEvent = event);
    } catch (_) {
      // Silently ignore — fallback to "Log arrival"
    } finally {
      if (mounted) setState(() => _loadingGarbageStatus = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _water(bool on) async {
    final id = widget.gateId;
    if (id == null || id.isEmpty || _anyLoading) return;

    final confirmed = await _confirm(
      title: on ? 'Turn water supply ON?' : 'Turn water supply OFF?',
      message: on
          ? 'Residents will receive: "Water supply will begin shortly."'
          : 'Only society admins will be notified (residents will not).',
      confirmLabel: on ? 'Yes, turn ON' : 'Yes, turn OFF',
      confirmColor: on
          ? GuardTokens.success
          : Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      if (on) {
        _loadingWaterOn = true;
      } else {
        _loadingWaterOff = true;
      }
    });
    try {
      await ref.read(guardRepositoryProvider).toggleWaterSupply(
            gateId: id,
            turnedOn: on,
          );
      widget.onSuccess?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            on
                ? 'Residents notified: water supply will begin shortly'
                : 'Admins notified: water supply OFF',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(userFacingMessage(e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingWaterOn = false;
          _loadingWaterOff = false;
        });
      }
    }
  }

  Future<void> _garbageArrival() async {
    final id = widget.gateId;
    if (id == null || id.isEmpty || _anyLoading) return;

    final confirmed = await _confirm(
      title: 'Garbage pickup at gate?',
      message: 'Residents will be notified that the garbage collector has arrived.',
      confirmLabel: 'Yes, log pickup',
      confirmColor: GuardTokens.guardAccentDeep,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loadingGarbageArrival = true);
    try {
      await ref.read(guardRepositoryProvider).logGarbageCollectorEntry(gateId: id);
      widget.onSuccess?.call();
      await _fetchGarbageStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Garbage pickup logged — residents notified'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(userFacingMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingGarbageArrival = false);
    }
  }

  Future<void> _garbageDeparture() async {
    final eventId = _activeGarbageEvent?['id'] as String?;
    if (eventId == null || _anyLoading) return;

    final confirmed = await _confirm(
      title: 'Garbage pickup completed?',
      message: 'This marks that the collector has finished and left the gate.',
      confirmLabel: 'Yes, mark completed',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;

    setState(() => _loadingGarbageDeparture = true);
    try {
      await ref.read(guardRepositoryProvider).logGarbageCollectorExit(eventId);
      widget.onSuccess?.call();
      if (mounted) setState(() => _activeGarbageEvent = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Garbage pickup marked completed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(userFacingMessage(e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingGarbageDeparture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gateOk = widget.gateId != null && widget.gateId!.isNotEmpty;
    final busy = _anyLoading;

    final cardBg = isDark ? GuardTokens.darkCard : Colors.white;
    final borderCol = isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard + 2),
        color: cardBg,
        border: Border.all(color: borderCol),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      GuardTokens.guardAccent.withValues(alpha: isDark ? 0.22 : 0.14),
                      GuardTokens.guardAccentDeep.withValues(alpha: isDark ? 0.12 : 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: GuardTokens.guardAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.home_work_rounded,
                  color: isDark ? GuardTokens.guardAccent : GuardTokens.guardAccentDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gate utilities',
                      style: GuardTokens.headingStyle(context).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'One tap tells residents about water and waste pickup at this gate.',
                      style: GuardTokens.captionStyle(context).copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.32,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.gateLabel != null && widget.gateLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: borderCol.withValues(alpha: 0.85),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.gateLabel!.trim(),
                      style: GuardTokens.bodyStyle(context).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (!gateOk)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: GuardTokens.g1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: GuardTokens.guardAccent.withValues(alpha: 0.85),
                    size: 22,
                  ),
                  const SizedBox(width: GuardTokens.g2),
                  Expanded(
                    child: Text(
                      'When your shift is active and a gate is assigned, you can notify residents '
                      'about water supply and log garbage truck arrivals.',
                      style: GuardTokens.bodyStyle(context).copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const _UtilitySectionLabel(
              title: 'Water supply',
              hint: 'Tell residents if supply is running or stopped.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _WaterChoiceTile(
                    label: 'ON',
                    sublabel: 'Running',
                    icon: Icons.waves_rounded,
                    accent: GuardTokens.success,
                    mutedBg: GuardTokens.successMuted.withValues(alpha: isDark ? 0.14 : 1),
                    loading: _loadingWaterOn,
                    disabled: busy,
                    isDark: isDark,
                    onTap: () => _water(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WaterChoiceTile(
                    label: 'OFF',
                    sublabel: 'Stopped',
                    icon: Icons.water_drop_outlined,
                    accent: scheme.error,
                    mutedBg: GuardTokens.dangerMuted.withValues(alpha: isDark ? 0.14 : 1),
                    loading: _loadingWaterOff,
                    disabled: busy,
                    isDark: isDark,
                    onTap: () => _water(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _UtilitySectionLabel(
              title: 'Garbage pickup',
              hint: _activeGarbageEvent != null
                  ? 'Pickup is in progress — tap Completed when the truck leaves.'
                  : 'Log pickup when the truck arrives, then mark completed when done.',
            ),
            const SizedBox(height: 10),
            if (_loadingGarbageStatus)
              const ShimmerWrap(
                child: ShimmerBox(
                  height: 68,
                  borderRadius: 14,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _WaterChoiceTile(
                      label: 'Pickup',
                      sublabel: 'At gate',
                      icon: Icons.delete_sweep_rounded,
                      accent: GuardTokens.guardAccentDeep,
                      mutedBg: GuardTokens.guardAccent
                          .withValues(alpha: isDark ? 0.14 : 0.1),
                      loading: _loadingGarbageArrival,
                      disabled: busy || _activeGarbageEvent != null,
                      isDark: isDark,
                      onTap: _garbageArrival,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WaterChoiceTile(
                      label: 'Completed',
                      sublabel: 'Left gate',
                      icon: Icons.check_circle_outline_rounded,
                      accent: scheme.error,
                      mutedBg: GuardTokens.dangerMuted.withValues(alpha: isDark ? 0.14 : 1),
                      loading: _loadingGarbageDeparture,
                      disabled: busy || _activeGarbageEvent == null,
                      isDark: isDark,
                      onTap: _garbageDeparture,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _UtilitySectionLabel extends StatelessWidget {
  const _UtilitySectionLabel({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GuardTokens.bodyStyle(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: GuardTokens.captionStyle(context).copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            height: 1.28,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _WaterChoiceTile extends StatelessWidget {
  const _WaterChoiceTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.accent,
    required this.mutedBg,
    required this.loading,
    required this.disabled,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color accent;
  final Color mutedBg;
  final bool loading;
  final bool disabled;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveBorder = isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading || disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: mutedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inactiveBorder,
            ),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: accent,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Icon(icon, color: accent, size: 20),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GuardTokens.bodyStyle(context).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            sublabel,
                            style: GuardTokens.captionStyle(context).copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
