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
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
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
                        child: Icon(Icons.cancel_outlined, color: DesignColors.error, size: 28),
                      ),
                      SizedBox(height: 16),
                      Text('Cancel SOS?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        'Only cancel if the emergency is over or was triggered by mistake.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonCtrl,
                        decoration: DesignComponents.inputDecoration(label: 'Reason', hint: 'Briefly describe why you are cancelling'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetCtx, false),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(sheetCtx, true),
                              style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                              child: const Text('Cancel SOS', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
        title: Text('Active SOS'),
        backgroundColor: DesignColors.error,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(async),
    );
  }

  Widget _buildBody(AsyncValue<dynamic> async) {
    final stale = async.valueOrNull;
    final isInitialLoad = async.isLoading && stale == null;

    if (isInitialLoad) return const DetailSkeleton(heroHeight: 140);
    if (async.hasError && stale == null) {
      return Center(child: Text(userFacingMessage(async.error!)));
    }

    final alert = stale ?? async.valueOrNull;
    return Builder(builder: (context) {
          if (alert == null || alert.status.isTerminal) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
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
