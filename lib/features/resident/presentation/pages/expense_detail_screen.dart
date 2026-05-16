import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/expense_attachment_model.dart';
import '../../data/models/expense_model.dart';
import '../../data/providers/expense_provider.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expenseDetailProvider(expenseId));
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20b9',
      decimalDigits: 2,
    );
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Expense Details',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Failed to load expense details.',
              textAlign: TextAlign.center,
              style: DesignTypography.bodyMedium.copyWith(
                color: DesignColors.error,
              ),
            ),
          ),
        ),
        data: (expense) => _Body(
          expense: expense,
          inr: inr,
          dateFmt: dateFmt,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.expense,
    required this.inr,
    required this.dateFmt,
  });

  final ExpenseModel expense;
  final NumberFormat inr;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final catColor = _parseColor(expense.category?.color) ??
        DesignColors.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        // Header: category badge + amount
        _HeaderCard(
          expense: expense,
          catColor: catColor,
          inr: inr,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Payment details
        _DetailsCard(expense: expense, inr: inr, dateFmt: dateFmt),

        // Description / notes
        if ((expense.description ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(label: 'Description'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            expense.description!,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],

        if ((expense.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(label: 'Notes'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            expense.notes!,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],

        // Tags
        if (expense.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(label: 'Tags'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: expense.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: DesignColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                ),
                child: Text(
                  tag,
                  style: DesignTypography.caption.copyWith(
                    color: DesignColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // Attachments
        if (expense.attachments.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(
            label: 'Attachments (${expense.attachments.length})',
          ),
          const SizedBox(height: AppSpacing.sm),
          _AttachmentGrid(attachments: expense.attachments),
        ],
      ],
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
  }
}

// ---- Header card ----

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.expense,
    required this.catColor,
    required this.inr,
  });

  final ExpenseModel expense;
  final Color catColor;
  final NumberFormat inr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          // Category badge
          if (expense.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                expense.category!.name,
                style: DesignTypography.caption.copyWith(
                  color: catColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            expense.title,
            textAlign: TextAlign.center,
            style: DesignTypography.headingM.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            inr.format(expense.amount),
            style: DesignTypography.headingM.copyWith(
              color: DesignColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          if (expense.gstAmount != null &&
              expense.gstAmount! > 0 ||
              expense.tdsAmount != null &&
              expense.tdsAmount! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Net: ${inr.format(expense.netAmount)}',
              style: DesignTypography.caption.copyWith(
                color: DesignColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Details card ----

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.expense,
    required this.inr,
    required this.dateFmt,
  });

  final ExpenseModel expense;
  final NumberFormat inr;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.circular(DesignRadius.xl),
        border: Border.all(color: DesignColors.borderLight),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Paid to', value: expense.paidTo),
          if ((expense.paidToContact ?? '').isNotEmpty)
            _DetailRow(label: 'Contact', value: expense.paidToContact!),
          _DetailRow(
            label: 'Payment date',
            value: dateFmt.format(expense.paymentDate),
          ),
          _DetailRow(label: 'Payment mode', value: expense.paymentModeLabel),
          if ((expense.paymentRef ?? '').isNotEmpty)
            _DetailRow(label: 'Reference', value: expense.paymentRef!),
          if (expense.gstAmount != null && expense.gstAmount! > 0)
            _DetailRow(label: 'GST', value: inr.format(expense.gstAmount!)),
          if (expense.tdsAmount != null && expense.tdsAmount! > 0)
            _DetailRow(label: 'TDS', value: inr.format(expense.tdsAmount!)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: DesignTypography.caption.copyWith(
                color: DesignColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: DesignTypography.bodySmall.copyWith(
                color: DesignColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Section label ----

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: DesignTypography.bodyMedium.copyWith(
        color: DesignColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ---- Attachment grid ----

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({required this.attachments});
  final List<ExpenseAttachmentModel> attachments;

  Future<void> _openFile(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.3,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final att = attachments[index];
        return _AttachmentTile(
          attachment: att,
          onTap: () => _openFile(context, att.fileUrl),
        );
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onTap});

  final ExpenseAttachmentModel attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: DesignColors.borderLight),
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
          child: attachment.isImage
              ? _imageContent()
              : _fileContent(),
        ),
      ),
    );
  }

  Widget _imageContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignRadius.lg - 1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            attachment.fileUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fileFallback(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileContent() {
    final isPdf = attachment.isPdf;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
          size: 32,
          color: isPdf ? Colors.red : DesignColors.textTertiary,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            attachment.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: DesignTypography.caption.copyWith(
              color: DesignColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          attachment.fileSizeFormatted,
          style: DesignTypography.caption.copyWith(
            color: DesignColors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _fileFallback() {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 32,
        color: DesignColors.textTertiary,
      ),
    );
  }
}
