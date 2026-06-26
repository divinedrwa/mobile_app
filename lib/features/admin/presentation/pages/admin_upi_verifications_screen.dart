import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
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
  String? _processingId;

  Future<void> _refresh() async {
    ref.invalidate(adminPendingUpiPaymentsProvider);
    ref.invalidate(adminUpiStatsProvider);
  }

  Future<void> _verify(UpiPaymentModel s) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
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
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF16A34A), size: 28)),
              const SizedBox(height: 16),
              Text('Verify Payment?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Approve \u20B9${s.amount.toStringAsFixed(0)} from ${s.userName ?? 'Resident'} (Villa ${s.villaNumber ?? ''}) for ${s.month}/${s.year}? This will record the payment in the ledger.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingId = s.id);
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
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(UpiPaymentModel s) async {
    final reasonController = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2)))),
              Text('Reject Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Reject \u20B9${s.amount.toStringAsFixed(0)} from ${s.userName ?? 'Resident'}?',
                  style: TextStyle(fontSize: 14, color: DesignColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                decoration: DesignComponents.inputDecoration(label: 'Reason', hint: 'e.g. UTR not found, wrong amount'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () {
                    final text = reasonController.text.trim();
                    if (text.length < 3) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(content: Text('Reason must be at least 3 characters')));
                      return;
                    }
                    Navigator.pop(sheetCtx, text);
                  },
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _processingId = s.id);
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
      if (mounted) setState(() => _processingId = null);
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
            icon: Icon(Icons.refresh, color: DesignColors.textSecondary),
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
                      processing: _processingId == submissions[i].id,
                      onVerify: () => _verify(submissions[i]),
                      onReject: () => _reject(submissions[i]),
                    ).animate(delay: DesignAnimations.staggerFor(i)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance),
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
          if (submission.remark != null && submission.remark!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.comment_outlined, size: 12, color: DesignColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    submission.remark!,
                    style: DesignTypography.captionSmall.copyWith(
                      color: DesignColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
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
                      side: BorderSide(color: DesignColors.error),
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
