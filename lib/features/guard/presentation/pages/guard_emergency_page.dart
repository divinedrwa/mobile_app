import 'dart:async';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_screen_section_header.dart';

String _kindToApi(String ui) {
  switch (ui) {
    case 'Fire':
      return 'FIRE';
    case 'Medical':
      return 'MEDICAL';
    case 'Security':
    default:
      return 'SECURITY';
  }
}

/// SOC emergency — oversized long-press target, guarded against accidental taps.
class GuardEmergencyPage extends ConsumerStatefulWidget {
  const GuardEmergencyPage({super.key});

  @override
  ConsumerState<GuardEmergencyPage> createState() => _GuardEmergencyPageState();
}

class _GuardEmergencyPageState extends ConsumerState<GuardEmergencyPage> {
  String _kind = 'Security';
  bool _sending = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Single source of truth for the note that will be POSTed — mirrors the
  /// fallback default when the textfield is empty so the preview banner and
  /// the actual broadcast can never disagree.
  String _broadcastNote() {
    final trimmed = _note.text.trim();
    return trimmed.isEmpty
        ? 'Long-press escalation from guard app'
        : trimmed;
  }

  Color _kindAccent(String kind) {
    switch (kind) {
      case 'Fire':
        return GuardTokens.dangerBrand;
      case 'Medical':
        return GuardTokens.warning;
      case 'Security':
      default:
        return GuardTokens.guardAccentDeep;
    }
  }

  Future<void> _broadcast() async {
    if (_sending) return;
    setState(() => _sending = true);
    unawaited(HapticFeedback.heavyImpact());
    final span = GuardFlowTelemetry.start('guard_soc_broadcast');
    try {
      await ref
          .read(guardRepositoryProvider)
          .postSocBroadcast(
            kind: _kindToApi(_kind),
            note: _broadcastNote(),
          );
      span.complete();
      if (!mounted) return;
      DesignHaptics.success();
      ref.invalidate(guardDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Emergency broadcast sent to admin'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      span.complete(success: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: _sending ? null : () => context.pop(),
          ),
          title: Text('Emergency', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
        ),
        // The body used to be a plain Column inside Padding, which overflowed
        // by ~12px on shorter devices after the broadcast preview banner was
        // added. Wrapping in LayoutBuilder + SingleChildScrollView +
        // ConstrainedBox + IntrinsicHeight gives us the best of both worlds:
        // on tall screens the Spacer() still pushes the red circle to the
        // bottom of the viewport, and on short screens the content becomes
        // scrollable instead of cutting off the disclaimer / overflow stripe.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Adapt the long-press circle to whichever is smaller: the
              // viewport width minus padding, the historical 260px cap, or
              // ~32% of available height so the button still fits cleanly on
              // ~5.5" devices without crowding the preview banner.
              final size = [
                mq.size.width - 48.0,
                260.0,
                constraints.maxHeight * 0.32,
              ].reduce(min);
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(GuardTokens.padScreen),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                const GuardScreenSectionHeader(
                  icon: Icons.crisis_alert_rounded,
                  title: 'What kind of emergency?',
                  subtitle: 'SOC + admin inbox — stays in audit logs',
                ),
                const SizedBox(height: GuardTokens.g2),
                Wrap(
                  spacing: GuardTokens.g2,
                  runSpacing: GuardTokens.g2,
                  children: [
                    _KindChip(
                      label: 'Fire',
                      icon: Icons.local_fire_department_rounded,
                      color: GuardTokens.dangerBrand,
                      selected: _kind == 'Fire',
                      onTap: _sending
                          ? null
                          : () => setState(() => _kind = 'Fire'),
                    ),
                    _KindChip(
                      label: 'Medical',
                      icon: Icons.medical_services_outlined,
                      color: GuardTokens.warning,
                      selected: _kind == 'Medical',
                      onTap: _sending
                          ? null
                          : () => setState(() => _kind = 'Medical'),
                    ),
                    _KindChip(
                      label: 'Security',
                      icon: Icons.shield_moon_rounded,
                      color: GuardTokens.guardAccentDeep,
                      selected: _kind == 'Security',
                      onTap: _sending
                          ? null
                          : () => setState(() => _kind = 'Security'),
                    ),
                  ],
                ),
                const SizedBox(height: GuardTokens.sectionGap),
                const GuardScreenSectionHeader(
                  icon: Icons.notes_rounded,
                  title: 'Situation note',
                  subtitle: 'Optional details sent with the escalation',
                ),
                const SizedBox(height: GuardTokens.g2),
                TextField(
                  controller: _note,
                  enabled: !_sending,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'Smoke at gate 2, resident collapsed, intruder dispute…',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const Spacer(),
                // Live preview of what the long-press will actually send so a
                // guard can sanity-check the situation note (or the fallback
                // default copy) before broadcasting. The banner rebuilds on
                // every keystroke via the TextEditingController listener.
                AnimatedBuilder(
                  animation: _note,
                  builder: (context, _) =>
                      _BroadcastPreviewBanner(
                    kindLabel: _kind,
                    kindColor: _kindAccent(_kind),
                    note: _broadcastNote(),
                    noteIsDefault: _note.text.trim().isEmpty,
                  ),
                ),
                const SizedBox(height: GuardTokens.g2),
                Center(
                  child: Material(
                    elevation: 8,
                    shadowColor: GuardTokens.dangerBrand.withValues(
                      alpha: 0.45,
                    ),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    color: GuardTokens.dangerBrand,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: GuardTokens.darkSurface,
                            content: Text(
                              'Press and HOLD the red circle for ~1 second to send.',
                              style: GuardTokens.bodyStyle(
                                context,
                              ).copyWith(color: Colors.white),
                            ),
                          ),
                        );
                      },
                      onLongPress: _sending ? null : _broadcast,
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: _sending
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    size: 56,
                                    color: Colors.white.withValues(alpha: 0.96),
                                  ),
                                  const SizedBox(height: GuardTokens.g2),
                                  Text(
                                    'EMERGENCY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.98,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hold to send',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      fontSize: GuardTokens.caption,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: GuardTokens.g3),
                Text(
                  'Broadcasts escalate to admins and SOC; residents may receive alerts depending on society settings.',
                  textAlign: TextAlign.center,
                  style: GuardTokens.captionStyle(context),
                ),
                const SizedBox(height: GuardTokens.g2),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Compact summary card shown directly above the red broadcast button so the
/// guard can verify both the selected kind chip and the situation note (or
/// the auto-inserted fallback) before they long-press to send. Styling stays
/// neutral so it doesn't compete with the red action target.
class _BroadcastPreviewBanner extends StatelessWidget {
  const _BroadcastPreviewBanner({
    required this.kindLabel,
    required this.kindColor,
    required this.note,
    required this.noteIsDefault,
  });

  final String kindLabel;
  final Color kindColor;
  final String note;
  final bool noteIsDefault;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuardTokens.g2,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? GuardTokens.darkCard : GuardTokens.surfaceCard,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(
          color: kindColor.withValues(alpha: isDark ? 0.55 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.send_rounded, size: 16, color: kindColor),
              const SizedBox(width: 6),
              Text(
                'Broadcast preview',
                style: GuardTokens.captionStyle(context).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kindColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kindLabel.toUpperCase(),
                  style: TextStyle(
                    color: kindColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GuardTokens.bodyStyle(context).copyWith(
              fontSize: 13.5,
              fontStyle: noteIsDefault ? FontStyle.italic : FontStyle.normal,
              color: noteIsDefault
                  ? GuardTokens.textSecondary
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          if (noteIsDefault) ...[
            const SizedBox(height: 4),
            Text(
              'Add details above to override this default note.',
              style: GuardTokens.captionStyle(context).copyWith(
                color: GuardTokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
      selected: selected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      selectedColor: color.withValues(alpha: isDark ? 0.35 : 0.18),
      checkmarkColor: color,
      backgroundColor: isDark ? GuardTokens.darkCard : GuardTokens.surfaceCard,
      side: BorderSide(
        color: selected
            ? color
            : GuardTokens.borderSubtle.withValues(alpha: 0.9),
      ),
    );
  }
}
