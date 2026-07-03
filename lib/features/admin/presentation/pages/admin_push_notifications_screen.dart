import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen to broadcast push notifications to residents/guards/admins.
class AdminPushNotificationsScreen extends ConsumerStatefulWidget {
  const AdminPushNotificationsScreen({super.key});

  @override
  ConsumerState<AdminPushNotificationsScreen> createState() =>
      _AdminPushNotificationsScreenState();
}

class _AdminPushNotificationsScreenState
    extends ConsumerState<AdminPushNotificationsScreen> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  final _roles = <String>{'RESIDENT'};
  bool _sending = false;
  bool _testing = false;
  String? _lastResult;

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminNotificationDiagnosticsProvider);
  }

  Future<void> _broadcast() async {
    if (_titleCtl.text.trim().isEmpty || _bodyCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required')),
      );
      return;
    }
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one audience')),
      );
      return;
    }
    // Backend matches roles exactly, so RESIDENT_CUM_ADMIN users must be
    // targeted explicitly when broadcasting to residents.
    final targetRoles = _roles.toList();
    if (_roles.contains('RESIDENT') && !_roles.contains('RESIDENT_CUM_ADMIN')) {
      targetRoles.add('RESIDENT_CUM_ADMIN');
    }
    setState(() => _sending = true);
    try {
      final res = await ref.read(adminNotificationRepositoryProvider).broadcast(
            title: _titleCtl.text.trim(),
            body: _bodyCtl.text.trim(),
            targetRoles: targetRoles,
          );
      if (!mounted) return;
      setState(() {
        _lastResult =
            'Sent. Inbox rows: ${res['rowsCreated'] ?? 0}. Push: ${res['firebaseConfigured'] == true ? 'attempted' : 'skipped'}.';
        _titleCtl.clear();
        _bodyCtl.clear();
      });
      _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastResult = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendTest() async {
    setState(() => _testing = true);
    try {
      final res =
          await ref.read(adminNotificationRepositoryProvider).sendTest();
      if (!mounted) return;
      setState(() {
        _lastResult =
            'Test sent to your account. Push attempted: ${res['pushAttempted'] ?? false}.';
      });
      _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastResult = e.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagAsync = ref.watch(adminNotificationDiagnosticsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Push Notifications',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            diagAsync.when(
              loading: () => EnterprisePanel(
                padding: const EdgeInsets.all(14),
                child: ShimmerWrap(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerBox(
                          height: 16, width: 120, borderRadius: DesignRadius.sm),
                      const SizedBox(height: 12),
                      ...List.generate(
                        4,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: ShimmerBox(
                              height: 12, borderRadius: DesignRadius.sm),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (_, __) => EnterprisePanel(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Could not load diagnostics',
                          style: DesignTypography.captionSmall),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (d) => EnterprisePanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery status',
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    _diagRow('Firebase configured',
                        d['firebaseConfigured'] == true ? 'Yes' : 'No'),
                    _diagRow('Registered devices',
                        '${d['registeredDevices'] ?? 0}'),
                    _diagRow('Users with devices',
                        '${d['usersWithAtLeastOneDevice'] ?? 0}'),
                    _diagRow('Notifications (24h)',
                        '${d['notificationsCreatedLast24h'] ?? 0}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            EnterprisePanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Broadcast',
                      style: DesignTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyCtl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Audience',
                      style: DesignTypography.captionSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _roleChip('Residents', 'RESIDENT'),
                      _roleChip('Guards', 'GUARD'),
                      _roleChip('Admins', 'ADMIN'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sending ? null : _broadcast,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Sending…' : 'Send broadcast'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _sendTest,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(_testing ? 'Sending test…' : 'Send test to me'),
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 12),
                    Text(_lastResult!,
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.textSecondary,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DesignTypography.captionSmall),
          Text(value,
              style: DesignTypography.captionSmall.copyWith(
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String role) {
    final selected = _roles.contains(role);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _roles.add(role);
          } else {
            _roles.remove(role);
          }
        });
      },
      selectedColor: DesignColors.primary.withValues(alpha: 0.15),
      checkmarkColor: DesignColors.primary,
    );
  }
}
