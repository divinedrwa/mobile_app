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
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../../../core/theme/design_tokens.dart';
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
    if (_arming) return;
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
    if (type == null) return;

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

    try {
      final alert = SOSAlertModel(
        type: type,
        description: '${type.value} emergency',
        location: 'On premises',
      );

      await ref.read(sendSOSAlertProvider(alert).future);
      ref.invalidate(activeSosProvider);
      ref.invalidate(sosAlertsProvider);

      if (!mounted) return;
      DesignHaptics.success();
      context.go('/resident/sos/active');
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingMessage(e, 'Could not send SOS');
      if (_isConflict(e)) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Active SOS exists'),
            content: const Text(
              'You already have an open emergency. Open your active SOS screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/resident/sos/active');
                },
                child: const Text('View active SOS'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: DesignColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(sosAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: DesignColors.error,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(Icons.emergency, size: 88, color: DesignColors.error)
              .animate()
              .shake(duration: 600.ms),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Select type, then press & hold the button for 2 seconds',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Guards and admins are notified immediately. Misuse may affect your account.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
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
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            label: 'Hold to trigger SOS alert',
            button: true,
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
                      child: Text(
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
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'SOS history',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          historyAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return const Text(
                  'No past alerts yet.',
                  style: TextStyle(color: DesignColors.textSecondary),
                );
              }
              final sorted = [...list]
                ..sort((a, b) => (b.createdAt ?? DateTime(0))
                    .compareTo(a.createdAt ?? DateTime(0)));
              return Column(
                children: sorted.take(15).map((a) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history, color: DesignColors.error),
                      title: Text(a.type.value),
                      subtitle: Text(
                        '${a.status.value} · ${a.createdAt != null ? DateFormat('MMM d HH:mm').format(a.createdAt!.toLocal()) : '—'}',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(userFacingMessage(e)),
          ),
          const SizedBox(height: 48),
        ],
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
    return AlertDialog(
      title: const Text('Confirm SOS'),
      content: Text(
        'Sending in $_left… Tap cancel if this was a mistake.',
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }
}
