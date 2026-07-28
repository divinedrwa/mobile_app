import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../resident/presentation/widgets/list_skeleton.dart';
import '../../data/providers/admin_providers.dart';

class AdminPaymentDisputesScreen extends ConsumerStatefulWidget {
  const AdminPaymentDisputesScreen({super.key});

  @override
  ConsumerState<AdminPaymentDisputesScreen> createState() =>
      _AdminPaymentDisputesScreenState();
}

class _AdminPaymentDisputesScreenState
    extends ConsumerState<AdminPaymentDisputesScreen> {
  String? _processingId;
  final _noteControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminPaymentDisputesProvider);
  }

  TextEditingController _noteFor(String id) =>
      _noteControllers.putIfAbsent(id, TextEditingController.new);

  Future<void> _update(String id, String status) async {
    setState(() => _processingId = id);
    try {
      await ref.read(adminPaymentDisputesRepositoryProvider).updateDispute(
            id,
            status: status,
            adminNote: _noteFor(id).text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispute marked $status')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : 'Update failed'),
          backgroundColor: DesignColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminPaymentDisputesStatusFilterProvider);
    final disputesAsync = ref.watch(adminPaymentDisputesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        title: Text(
          'Payment Disputes',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                for (final f in const [
                  ('', 'All'),
                  ('OPEN', 'Open'),
                  ('IN_REVIEW', 'In review'),
                  ('RESOLVED', 'Resolved'),
                  ('REJECTED', 'Rejected'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: filter == f.$1,
                      onSelected: (_) => ref
                          .read(adminPaymentDisputesStatusFilterProvider.notifier)
                          .state = f.$1,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: disputesAsync.when(
              loading: () => const ListSkeleton(),
              error: (e, _) => EmptyStateWidget(
                icon: Icons.error_outline,
                title: 'Failed to load disputes',
                subtitle: e is AppException ? e.message : 'Please try again',
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
              data: (data) {
                if (data.disputes.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.check_circle_outline,
                    title: 'No disputes',
                    subtitle: 'Resident payment disputes will appear here.',
                    iconColor: DesignColors.success,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: data.disputes.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EnterpriseInfoBanner(
                            icon: Icons.scale_outlined,
                            title: '${data.openCount} open / in review',
                            message:
                                'Review resident reports of missing or incorrect maintenance payments.',
                            tone: EnterpriseTone.info,
                          ),
                        );
                      }
                      final d = data.disputes[index - 1];
                      return _DisputeCard(
                        dispute: d,
                        noteController: _noteFor(d['id']?.toString() ?? ''),
                        processing: _processingId == d['id']?.toString(),
                        onResolve: () =>
                            _update(d['id']?.toString() ?? '', 'RESOLVED'),
                        onReject: () =>
                            _update(d['id']?.toString() ?? '', 'REJECTED'),
                        onReview: () =>
                            _update(d['id']?.toString() ?? '', 'IN_REVIEW'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.noteController,
    required this.processing,
    required this.onReview,
    required this.onResolve,
    required this.onReject,
  });

  final Map<String, dynamic> dispute;
  final TextEditingController noteController;
  final bool processing;
  final VoidCallback onReview;
  final VoidCallback onResolve;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final user = dispute['user'] as Map<String, dynamic>?;
    final villa = dispute['villa'] as Map<String, dynamic>?;
    final status = dispute['status']?.toString() ?? 'OPEN';
    final created = dispute['createdAt']?.toString();
    final amount = dispute['amount'];
    final fmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EnterprisePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user?['name']?.toString() ?? 'Resident',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: DesignColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Villa ${villa?['villaNumber'] ?? '—'} · ${dispute['cycleKey'] ?? '—'}',
              style: TextStyle(color: DesignColors.textSecondary, fontSize: 13),
            ),
            if (created != null) ...[
              const SizedBox(height: 2),
              Text(
                fmt.format(DateTime.tryParse(created)?.toLocal() ?? DateTime.now()),
                style: TextStyle(color: DesignColors.textSecondary, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(dispute['reason']?.toString() ?? '',
                style: const TextStyle(height: 1.4)),
            if (dispute['residentNote'] != null &&
                dispute['residentNote'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Resident note: ${dispute['residentNote']}',
                  style: TextStyle(color: DesignColors.textSecondary)),
            ],
            if (amount != null) ...[
              const SizedBox(height: 6),
              Text(
                'Amount: ₹${amount is num ? amount.toStringAsFixed(0) : amount}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (status == 'OPEN' || status == 'IN_REVIEW')
              Row(
                children: [
                  if (status == 'OPEN')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: processing ? null : onReview,
                        child: const Text('Mark in review'),
                      ),
                    ),
                  if (status == 'OPEN') const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: processing ? null : onResolve,
                      child: processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Resolve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: processing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignColors.error,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
