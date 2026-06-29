import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/sos_alert_model.dart';
import '../providers/sos_provider.dart';

/// SOS — select type, press & hold 2s, optional 3s countdown, then create alert.
class SOSScreen extends ConsumerStatefulWidget {
  const SOSScreen({super.key});

  @override
  ConsumerState<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends ConsumerState<SOSScreen>
    with WidgetsBindingObserver {
  SOSType? _selectedType;
  bool _arming = false;
  bool _isSubmitting = false;
  double _holdProgress = 0;
  Timer? _holdTicker;
  DateTime? _holdStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cancel hold if user switches away — prevent accidental SOS in background.
    if (state != AppLifecycleState.resumed && _arming) {
      _cancelHold();
    }
  }

  void _beginHold() {
    if (_arming || _isSubmitting) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an emergency type first')),
      );
      return;
    }
    setState(() {
      _arming = true;
      _holdProgress = 0;
      _holdStart = DateTime.now();
    });
    HapticFeedback.lightImpact();
    _holdTicker?.cancel();
    _holdTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final start = _holdStart;
      if (start == null) return;
      final elapsed = DateTime.now().difference(start).inMilliseconds / 2000;
      setState(() => _holdProgress = elapsed.clamp(0.0, 1.0));
      if (elapsed >= 1) {
        _holdTicker?.cancel();
        setState(() {
          _arming = false;
          _holdProgress = 0;
        });
        HapticFeedback.heavyImpact();
        unawaited(_confirmAndSend());
      }
    });
  }

  void _cancelHold() {
    _holdTicker?.cancel();
    setState(() {
      _arming = false;
      _holdProgress = 0;
      _holdStart = null;
    });
  }

  /// Check HTTP 409 by status code instead of fragile string matching.
  bool _isConflict(Object e) {
    if (e is AppException) return e.statusCode == 409;
    if (e is DioException) {
      if (e.response?.statusCode == 409) return true;
      final inner = e.error;
      if (inner is AppException && inner.statusCode == 409) return true;
    }
    return false;
  }

  Future<void> _confirmAndSend() async {
    final type = _selectedType;
    if (type == null || _isSubmitting) return;

    final send = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(
        seconds: 3,
        onFinished: () => Navigator.pop(ctx, true),
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );

    if (send != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final alert = SOSAlertModel(
        type: type,
        description: '${type.value} emergency',
        location: 'On premises',
      );

      await ref.read(sosRepositoryProvider).sendSOSAlert(alert);
      ref.invalidate(activeSosProvider);
      ref.invalidate(sosAlertsProvider);

      if (!mounted) return;
      DesignHaptics.success();
      context.go('/resident/sos/active');
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingMessage(e, 'Could not send SOS');
      if (_isConflict(e)) {
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetCtx) {
            return Container(
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
                    Container(
                      width: 40, height: 4,
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2)),
                    ),
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(Icons.warning_amber_rounded, color: DesignColors.error, size: 28),
                    ),
                    SizedBox(height: 16),
                    Text('Active SOS exists', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'You already have an open emergency.\nOpen your active SOS screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                            child: const Text('Dismiss'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              context.go('/resident/sos/active');
                            },
                            style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                            child: const Text('View SOS', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: DesignColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(sosAlertsProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Emergency SOS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Alert guards & admins immediately',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async => ref.invalidate(sosAlertsProvider),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        children: [
          // Warning banner
          EnterpriseInfoBanner(
            icon: Icons.warning_amber_rounded,
            title: 'For real emergencies only',
            message: 'Guards and admins are notified immediately. Misuse may affect your account.',
            tone: EnterpriseTone.warning,
          ),
          SizedBox(height: 24),
          Icon(Icons.emergency_rounded, size: 72, color: DesignColors.error)
              .animate()
              .shake(duration: 600.ms),
          const SizedBox(height: 12),
          Text(
            'Select type, then press & hold for 2 seconds',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.text.primary,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _typeChip(SOSType.medical, 'Medical', Icons.local_hospital),
              _typeChip(SOSType.fire, 'Fire', Icons.local_fire_department),
              _typeChip(SOSType.security, 'Security', Icons.security),
              _typeChip(SOSType.accident, 'Accident', Icons.car_crash),
              _typeChip(SOSType.other, 'Other', Icons.warning_amber_rounded),
            ],
          ),
          const SizedBox(height: 24),
          Semantics(
            label: 'Hold to trigger SOS alert',
            button: true,
            child: IgnorePointer(
            ignoring: _isSubmitting,
            child: Listener(
            onPointerDown: (_) => _beginHold(),
            onPointerUp: (_) => _cancelHold(),
            onPointerCancel: (_) => _cancelHold(),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: DesignRadius.borderXL,
                  gradient: LinearGradient(
                    colors: [
                      DesignColors.error,
                      DesignColors.error.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.error.withValues(alpha: 0.35),
                      blurRadius: _arming ? 18 : 8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _holdProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: DesignRadius.borderXL,
                        ),
                      ),
                    ),
                    Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _arming
                                  ? 'Hold… ${(_holdProgress * 100).toInt()}%'
                                  : 'Press & hold to trigger SOS (2 sec)',
                              style: DesignTypography.button.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ),
          ),
          ),
          const SizedBox(height: 28),
          EnterpriseSectionHeader(
            title: 'SOS history',
            subtitle: 'Past emergency alerts from your account',
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final stale = historyAsync.valueOrNull;
            final isInitialLoad = historyAsync.isLoading && stale == null;
            if (isInitialLoad) return const TimelineSkeleton(itemCount: 4);
            if (historyAsync.hasError && stale == null) return Text(
              userFacingMessage(historyAsync.error!),
              style: DesignTypography.bodySmall.copyWith(color: DesignColors.textSecondary),
            );
            final list = stale ?? [];
            return Builder(builder: (context) {
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DesignColors.surfaceSoft,
                    borderRadius: DesignRadius.borderLG,
                    border: Border.all(color: DesignColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: DesignColors.textTertiary),
                      const SizedBox(width: 10),
                      Text(
                        'No past alerts',
                        style: DesignTypography.bodySmall.copyWith(
                          color: DesignColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final sorted = [...list]
                ..sort((a, b) => (b.createdAt ?? DateTime(0))
                    .compareTo(a.createdAt ?? DateTime(0)));
              return Column(
                children: sorted.take(15).map((a) {
                  final statusColor = a.status.value.toUpperCase() == 'RESOLVED'
                      ? DesignColors.success
                      : a.status.value.toUpperCase() == 'ACTIVE'
                          ? DesignColors.error
                          : DesignColors.warning;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignColors.surface,
                        borderRadius: DesignRadius.borderLG,
                        border: Border.all(color: DesignColors.borderLight),
                        boxShadow: DesignElevation.sm,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: DesignColors.error.withValues(alpha: 0.10),
                                borderRadius: DesignRadius.borderMD,
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.emergency_rounded, size: 18, color: DesignColors.error),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.type.value,
                                    style: DesignTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: DesignColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a.createdAt != null
                                        ? DateFormat('MMM d · HH:mm').format(a.createdAt!.toLocal())
                                        : '—',
                                    style: DesignTypography.caption.copyWith(
                                      color: DesignColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: DesignRadius.borderMD,
                              ),
                              child: Text(
                                a.status.value.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            });
          }),
          const SizedBox(height: 48),
        ],
        ),
      ),
    );
  }

  Widget _typeChip(SOSType type, String label, IconData icon) {
    final sel = _selectedType == type;
    return FilterChip(
      selected: sel,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => setState(() => _selectedType = type),
      selectedColor: DesignColors.error.withValues(alpha: 0.2),
      checkmarkColor: DesignColors.error,
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({
    required this.seconds,
    required this.onFinished,
    required this.onCancel,
  });

  final int seconds;
  final VoidCallback onFinished;
  final VoidCallback onCancel;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _left;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
    _t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _left -= 1);
      if (_left <= 0) {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DesignRadius.borderXL,
          boxShadow: DesignElevation.md,
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$_left',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: DesignColors.error),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Confirm SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Sending emergency alert…\nTap cancel if this was a mistake.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: DesignColors.error),
                  foregroundColor: DesignColors.error,
                  shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
