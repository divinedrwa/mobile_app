import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../resident/data/models/upi_payment_model.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen to verify / reject UPI payment submissions.
class AdminUpiVerificationsScreen extends ConsumerStatefulWidget {
  const AdminUpiVerificationsScreen({super.key});

  @override
  ConsumerState<AdminUpiVerificationsScreen> createState() =>
      _AdminUpiVerificationsScreenState();
}

class _AdminUpiVerificationsScreenState
    extends ConsumerState<AdminUpiVerificationsScreen> {
  bool _processing = false;

  Future<void> _refresh() async {
    ref.invalidate(adminPendingUpiPaymentsProvider);
    ref.invalidate(adminUpiStatsProvider);
  }

  Future<void> _verify(UpiPaymentModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Payment?'),
        content: Text(
          'Approve \u20B9${s.amount.toStringAsFixed(0)} from '
          '${s.userName ?? 'Resident'} (Villa ${s.villaNumber ?? ''}) '
          'for ${s.month}/${s.year}?\n\n'
          'This will record the payment in the ledger.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verify')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await ref.read(adminUpiPaymentRepositoryProvider).verifySubmission(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified and recorded')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject(UpiPaymentModel s) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject \u20B9${s.amount.toStringAsFixed(0)} from '
                '${s.userName ?? 'Resident'}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. UTR not found, wrong amount',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DesignColors.error),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Reason must be at least 3 characters')),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _processing = true);
    try {
      await ref
          .read(adminUpiPaymentRepositoryProvider)
          .rejectSubmission(s.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment rejected')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedStatus = ref.watch(adminUpiStatusFilterProvider);
    final listAsync = ref.watch(adminPendingUpiPaymentsProvider);
    final statsAsync = ref.watch(adminUpiStatsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'UPI Verifications',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: Column(
          children: [
            // Stats strip
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ChipRowSkeleton(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) {
                final pending = stats['pending'] ?? 0;
                final verified = stats['verified'] ?? 0;
                final rejected = stats['rejected'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _StatChip('Pending', pending, const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _StatChip('Verified', verified, const Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      _StatChip('Rejected', rejected, DesignColors.error),
                    ],
                  ),
                );
              },
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final s in ['PENDING', 'VERIFIED', 'REJECTED']) ...[
                    if (s != 'PENDING') const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(s[0] + s.substring(1).toLowerCase()),
                      selected: selectedStatus == s,
                      onSelected: (_) {
                        ref.read(adminUpiStatusFilterProvider.notifier).state =
                            s;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: listAsync.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(16),
                  child: ShimmerWrap(
                    child: Column(
                      children: List.generate(
                        4,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ShimmerBox(
                              height: 100, borderRadius: DesignRadius.lg),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: EmptyStateWidget(
                        icon: Icons.error_outline_rounded,
                        title: 'Failed to load',
                        subtitle: userFacingMessage(e),
                        iconColor: DesignColors.error,
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      ),
                    ),
                  ],
                ),
                data: (submissions) {
                  if (submissions.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: EmptyStateWidget(
                            icon: Icons.verified_rounded,
                            title: 'No ${selectedStatus.toLowerCase()} submissions',
                            subtitle: selectedStatus == 'PENDING'
                                ? 'All UPI submissions have been processed.'
                                : 'No submissions with this status.',
                            iconColor: DesignColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    itemCount: submissions.length,
                    itemBuilder: (ctx, i) => _SubmissionCard(
                      submission: submissions[i],
                      processing: _processing,
                      onVerify: () => _verify(submissions[i]),
                      onReject: () => _reject(submissions[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Column(
          children: [
            Text('$count',
                style: DesignTypography.label.copyWith(
                    fontWeight: FontWeight.w800, color: color, fontSize: 18)),
            Text(label,
                style: DesignTypography.captionSmall
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.processing,
    required this.onVerify,
    required this.onReject,
  });
  final UpiPaymentModel submission;
  final bool processing;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        border: Border.all(color: DesignColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.userName ?? 'Resident',
                  style: DesignTypography.label
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '\u20B9${submission.amount.toStringAsFixed(0)}',
                style: DesignTypography.label.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DesignColors.primary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Villa ${submission.villaNumber ?? ''} | '
            '${submission.month}/${submission.year}',
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          if (submission.upiTransactionRef != null &&
              submission.upiTransactionRef!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'UTR: ${submission.upiTransactionRef}',
              style: DesignTypography.captionSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            dateFmt.format(submission.submittedAt.toLocal()),
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textSecondary, fontSize: 11),
          ),
          if (submission.isRejected && submission.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Rejected: ${submission.rejectionReason}',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.error),
            ),
          ],
          if (submission.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: processing ? null : onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignColors.error,
                      side: const BorderSide(color: DesignColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: processing ? null : onVerify,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Verify'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                    ),
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
