import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../data/models/sos_alert_model.dart';
import '../providers/sos_provider.dart';

/// Live view of an ongoing SOS — polls until terminal state.
class ActiveSOSScreen extends ConsumerStatefulWidget {
  const ActiveSOSScreen({super.key});

  @override
  ConsumerState<ActiveSOSScreen> createState() => _ActiveSOSScreenState();
}

class _ActiveSOSScreenState extends ConsumerState<ActiveSOSScreen>
    with SingleTickerProviderStateMixin {
  Timer? _poll;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(activeSosProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _statusLabel(SOSStatus s) {
    switch (s) {
      case SOSStatus.created:
      case SOSStatus.active:
      case SOSStatus.pending:
        return 'Waiting for response';
      case SOSStatus.acknowledged:
        return 'Acknowledged';
      case SOSStatus.inProgress:
        return 'In progress';
      case SOSStatus.resolved:
        return 'Resolved';
      case SOSStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _typeLabel(SOSType t) {
    switch (t) {
      case SOSType.medical:
        return 'Medical';
      case SOSType.fire:
        return 'Fire';
      case SOSType.security:
        return 'Security';
      case SOSType.accident:
        return 'Accident';
      case SOSType.other:
        return 'Other';
    }
  }

  Future<void> _callGuard(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _cancelSos(SOSAlertModel alert) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel SOS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Only cancel if the emergency is over or was triggered by mistake.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: DesignColors.error),
            child: const Text('Cancel SOS'),
          ),
        ],
      ),
    );
    if (ok != true) {
      reasonCtrl.dispose();
      return;
    }
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (reason.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a short reason (3+ chars).')),
        );
      }
      return;
    }


    try {
      await ref.read(sosRepositoryProvider).cancelSos(alert.id!, reason);
      if (!mounted) return;
      // Refresh history only — avoid invalidating active SOS here (async refetch + rebuild
      // races with navigation and can trigger a red error screen).
      ref.invalidate(sosAlertsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/resident/sos');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingMessage(e, 'Could not cancel'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeSosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        title: const Text('Active SOS'),
        backgroundColor: DesignColors.error,
        foregroundColor: Colors.white,
      ),
      body: async.when(
        loading: () => const DetailSkeleton(heroHeight: 140),
        error: (e, _) => Center(child: Text(userFacingMessage(e))),
        data: (alert) {
          if (alert == null || alert.status.isTerminal) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 64, color: DesignColors.success),
                    const SizedBox(height: 16),
                    Text(
                      alert?.status == SOSStatus.cancelled
                          ? 'SOS cancelled'
                          : 'No active SOS',
                      style: DesignTypography.headingM,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/resident/sos'),
                      child: const Text('Back to SOS'),
                    ),
                  ],
                ),
              ),
            );
          }

          final elapsed = alert.createdAt != null
              ? DateTime.now().difference(alert.createdAt!)
              : Duration.zero;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.02).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      DesignColors.error,
                      DesignColors.error.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: DesignColors.error.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency, color: Colors.white, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _typeLabel(alert.type).toUpperCase(),
                            style: DesignTypography.headingL.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusLabel(alert.status),
                      style: DesignTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elapsed: ${_formatDuration(elapsed)}',
                      style: DesignTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    if (alert.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Started: ${DateFormat('MMM d, HH:mm').format(alert.createdAt!.toLocal())}',
                        style: DesignTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (alert.assignedGuardName != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Assigned: ${alert.assignedGuardName}',
                        style: DesignTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _callGuard(alert.assignedGuardPhone),
                            icon: const Icon(Icons.phone_in_talk_rounded),
                            label: const Text('Call guard'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelSos(alert),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel SOS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
