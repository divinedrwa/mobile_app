import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/telemetry/business_analytics.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for billing cycle v1 — view, publish, unpublish, reopen.
class AdminBillingCyclesScreen extends ConsumerStatefulWidget {
  const AdminBillingCyclesScreen({super.key});

  @override
  ConsumerState<AdminBillingCyclesScreen> createState() =>
      _AdminBillingCyclesScreenState();
}

class _AdminBillingCyclesScreenState
    extends ConsumerState<AdminBillingCyclesScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminBillingCyclesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cyclesAsync = ref.watch(adminBillingCyclesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Billing Cycles',
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
        child: cyclesAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 120, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (_, __) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load billing cycles',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (data) {
            final cycles = (data['cycles'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                [];
            final residentCount = data['residentCount'] as int? ?? 0;

            if (cycles.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.calendar_month_outlined,
                      title: 'No billing cycles',
                      subtitle:
                          'Create cycles on the web admin, then publish them here.',
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                EnterprisePanel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          color: DesignColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '$residentCount active residents',
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...cycles.map((c) => _cycleCard(c)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cycleCard(Map<String, dynamic> c) {
    final id = c['id']?.toString() ?? '';
    final title = c['title']?.toString() ?? c['cycleKey']?.toString() ?? 'Cycle';
    final amount = (c['amount'] as num?)?.toDouble() ?? 0;
    final status = c['status']?.toString() ?? '';
    final storedStatus = c['storedStatus']?.toString() ?? '';
    final published = c['publishedAt'] != null;
    final paid = c['paidUsersCount'] as int? ?? 0;
    final pending = c['pendingUsersCount'] as int? ?? 0;
    final fyLabel = c['financialYearLabel']?.toString();

    String startStr = '';
    String endStr = '';
    try {
      final start = DateTime.parse(c['paymentStartDate']?.toString() ?? '');
      final end = DateTime.parse(c['paymentEndDate']?.toString() ?? '');
      startStr = DateFormat('d MMM').format(start);
      endStr = DateFormat('d MMM yyyy').format(end);
    } catch (_) {}

    return EnterprisePanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: DesignTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
              ),
              _statusChip(published, status, storedStatus),
            ],
          ),
          if (fyLabel != null) ...[
            const SizedBox(height: 4),
            Text(fyLabel,
                style: DesignTypography.captionSmall.copyWith(
                  color: DesignColors.textSecondary,
                )),
          ],
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(0)} · $startStr – $endStr',
            style: DesignTypography.captionSmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniStat('Paid', paid, DesignColors.success),
              const SizedBox(width: 12),
              _miniStat('Pending', pending, DesignColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!published)
                _actionBtn('Publish', DesignColors.success, () => _publish(id)),
              if (published)
                _actionBtn('Unpublish', DesignColors.warning,
                    () => _unpublish(id)),
              if (published)
                _actionBtn('Reopen', DesignColors.info, () => _reopen(id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool published, String status, String stored) {
    final label = published ? 'Published' : (stored.isNotEmpty ? stored : status);
    final color = published ? DesignColors.success : DesignColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          )),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $count',
            style: DesignTypography.captionSmall.copyWith(
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _publish(String id) async {
    final ok = await _confirm('Publish cycle?',
        'Residents will see this cycle and can pay maintenance.');
    if (!ok) return;
    final success = await _runAction(() => ref
        .read(adminBillingCycleRepositoryProvider)
        .publishCycle(id), 'Cycle published');
    if (success) {
      unawaited(BusinessAnalytics.track(BusinessAnalytics.billingCyclePublish));
    }
  }

  Future<void> _unpublish(String id) async {
    final ok = await _confirm('Unpublish cycle?',
        'Residents will no longer see this cycle.');
    if (!ok) return;
    await _runAction(() => ref
        .read(adminBillingCycleRepositoryProvider)
        .unpublishCycle(id), 'Cycle unpublished');
  }

  Future<void> _reopen(String id) async {
    final ok = await _confirm('Reopen cycle?',
        'Extends the payment window for pending residents.');
    if (!ok) return;
    await _runAction(() => ref
        .read(adminBillingCycleRepositoryProvider)
        .reopenCycle(id), 'Cycle reopened');
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _runAction(
      Future<Map<String, dynamic>> Function() action, String success) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
      _refresh();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    }
  }
}
