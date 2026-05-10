import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
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
  bool _loadingGarbage = false;

  bool get _anyLoading =>
      _loadingWaterOn || _loadingWaterOff || _loadingGarbage;

  Future<void> _water(bool on) async {
    final id = widget.gateId;
    if (id == null || id.isEmpty || _anyLoading) return;
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
            on ? 'Residents notified: water supply ON' : 'Residents notified: water supply OFF',
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

  Future<void> _garbage() async {
    final id = widget.gateId;
    if (id == null || id.isEmpty || _anyLoading) return;
    setState(() => _loadingGarbage = true);
    try {
      await ref.read(guardRepositoryProvider).logGarbageCollectorEntry(gateId: id);
      widget.onSuccess?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Garbage collector logged — residents notified'),
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
      if (mounted) setState(() => _loadingGarbage = false);
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
            const _UtilitySectionLabel(
              title: 'Garbage pickup',
              hint: 'Use when the collection vehicle reaches the gate.',
            ),
            const SizedBox(height: 10),
            _PremiumGarbageArrivalButton(
              loading: _loadingGarbage,
              disabled: busy,
              isDark: isDark,
              onTap: _garbage,
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

/// Full-width premium CTA for logging garbage arrival.
class _PremiumGarbageArrivalButton extends StatelessWidget {
  const _PremiumGarbageArrivalButton({
    required this.loading,
    required this.disabled,
    required this.isDark,
    required this.onTap,
  });

  final bool loading;
  final bool disabled;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canTap = !loading && !disabled;

    final gradientColors = isDark
        ? [
            const Color(0xFF1E293B),
            GuardTokens.darkCard,
          ]
        : [
            const Color(0xFFF1F5F9),
            const Color(0xFFE8EEF5),
          ];

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              width: 1,
              color: GuardTokens.guardAccent.withValues(alpha: isDark ? 0.4 : 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: GuardTokens.guardAccentDeep.withValues(alpha: isDark ? 0.18 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: GuardTokens.guardAccent,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              GuardTokens.guardAccent.withValues(alpha: 0.2),
                              GuardTokens.guardAccentDeep.withValues(alpha: 0.35),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: GuardTokens.guardAccent.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: isDark ? Colors.white : GuardTokens.guardAccentDeep,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Log arrival',
                              style: GuardTokens.bodyStyle(context).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: -0.15,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Sends an instant notice so residents know pickup is at the gate.',
                              style: GuardTokens.captionStyle(context).copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: GuardTokens.guardAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: canTap
                              ? GuardTokens.guardAccentDeep
                              : scheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
