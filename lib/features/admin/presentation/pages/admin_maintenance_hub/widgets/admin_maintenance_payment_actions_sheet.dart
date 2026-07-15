import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/design_tokens.dart';
import '../../../../../../core/widgets/enterprise_ui.dart';
import '../../../../data/providers/admin_providers.dart';
import '../../../../../resident/data/resident_data_refresh.dart';
import '../../../../../resident/presentation/widgets/maintenance/payment_list_tile.dart';

class AdminMaintenancePaymentActionsSheet extends ConsumerStatefulWidget {
  const AdminMaintenancePaymentActionsSheet({required this.resident});

  final Map<String, dynamic> resident;

  @override
  ConsumerState<AdminMaintenancePaymentActionsSheet> createState() =>
      AdminMaintenancePaymentActionsSheetState();
}

const _paymentModes = <String, String>{
  'CASH': 'Cash',
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CHEQUE': 'Cheque',
};

class AdminMaintenancePaymentActionsSheetState extends ConsumerState<AdminMaintenancePaymentActionsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtl;
  final _amountCtl = TextEditingController();
  final _remarksCtl = TextEditingController();
  final _creditAmountCtl = TextEditingController();
  final _creditRemarksCtl = TextEditingController();
  String _paymentMode = 'CASH';
  bool _busy = false;
  String? _error;

  double get _advanceCredit =>
      (widget.resident['advanceCredit'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _tabCtl = TabController(length: 3, vsync: this);
    _tabCtl.addListener(() {
      if (!_tabCtl.indexIsChanging) {
        setState(() => _error = null);
      }
    });
    final amount = (widget.resident['amount'] as num?)?.toDouble() ?? 0;
    final paidToward =
        (widget.resident['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    final remaining = (amount - paidToward).clamp(0, double.infinity);
    if (remaining > 0) {
      _amountCtl.text = remaining.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    _amountCtl.dispose();
    _remarksCtl.dispose();
    _creditAmountCtl.dispose();
    _creditRemarksCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inr =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villa = widget.resident['villaNumber']?.toString() ?? '—';
    final owner = widget.resident['ownerName']?.toString() ?? 'Unknown';
    final amount = (widget.resident['amount'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DesignRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Villa $villa',
                    style: DesignTypography.headingM.copyWith(
                      color: DesignColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$owner · expected ${inr.format(amount)}'
                    '${_advanceCredit > 0 ? ' · credit ${inr.format(_advanceCredit)}' : ''}',
                    style: DesignTypography.bodySmall.copyWith(
                      color: DesignColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Tabs
            TabBar(
              controller: _tabCtl,
              labelColor: DesignColors.primary,
              unselectedLabelColor: DesignColors.textSecondary,
              indicatorColor: DesignColors.primary,
              labelStyle: DesignTypography.bodySmall
                  .copyWith(fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Payment'),
                Tab(text: 'Add credit'),
                Tab(text: 'Deduct credit'),
              ],
            ),
            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabCtl,
                children: [
                  _recordPaymentTab(inr),
                  _creditTab(isAdd: true),
                  _creditTab(isAdd: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordPaymentTab(NumberFormat inr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_advanceCredit > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                borderRadius: BorderRadius.circular(DesignRadius.sm),
              ),
              child: Text(
                'Advance credit available: ${inr.format(_advanceCredit)}',
                style: DesignTypography.bodySmall.copyWith(
                  color: const Color(0xFF166534),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _amountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _paymentMode,
            decoration: const InputDecoration(
              labelText: 'Payment mode',
              border: OutlineInputBorder(),
            ),
            items: _paymentModes.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _paymentMode = v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _remarksCtl,
            decoration: const InputDecoration(
              labelText: 'Remarks (optional)',
              hintText: 'e.g. cash handed over at gate',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_error != null && _tabCtl.index == 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          if (_advanceCredit > 0) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _submitApplyCredit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF166534),
                  side: const BorderSide(color: Color(0xFF86EFAC)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.md),
                  ),
                ),
                child: Text(
                  'Apply credit only (no cash)',
                  style: DesignTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _submitPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: _busy && _tabCtl.index == 0
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Confirm payment',
                          style: DesignTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditTab({required bool isAdd}) {
    final tabIndex = isAdd ? 1 : 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAdd
                ? 'Add advance credit to this villa\'s account.'
                : 'Deduct credit from this villa\'s balance.',
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
            ),
          ),
          if (!isAdd && _advanceCredit > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Available credit: ${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(_advanceCredit)}',
              style: DesignTypography.bodySmall.copyWith(
                color: const Color(0xFF166534),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _creditAmountCtl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              helperText:
                  !isAdd ? 'Cannot exceed available credit' : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _creditRemarksCtl,
            decoration: InputDecoration(
              labelText: 'Reason / remarks',
              hintText: isAdd
                  ? 'e.g. overpayment correction'
                  : 'e.g. penalty deduction',
              border: const OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          if (_error != null && _tabCtl.index == tabIndex) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: DesignTypography.bodySmall
                  .copyWith(color: DesignColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed:
                      _busy ? null : () => _submitCreditAdjustment(isAdd),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isAdd ? DesignColors.primary : DesignColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                  ),
                  child: _busy && _tabCtl.index == tabIndex
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isAdd ? 'Add credit' : 'Deduct credit',
                          style: DesignTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(adminMaintenanceFilterProvider);
      final idempotencyKey = 'payment-${const Uuid().v4()}';

      await ref.read(adminMaintenanceRepositoryProvider).markPaidCash(
            villaId: villaId,
            month: filter.month,
            year: filter.year,
            amount: amount,
            paymentMode: _paymentMode,
            remarks: _remarksCtl.text.trim().isEmpty
                ? null
                : _remarksCtl.text.trim(),
            idempotencyKey: idempotencyKey,
          );
      requestResidentDataRefresh();
      ref.invalidate(adminMaintenanceDashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            'Recorded ₹${amount.toStringAsFixed(0)} for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t record payment. Please try again.';
      });
    }
  }

  Future<void> _submitApplyCredit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(adminMaintenanceFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      final result =
          await ref.read(adminMaintenanceRepositoryProvider).applyCredit(
                villaId: villaId,
                maintenanceCollectionCycleId: cycleId,
              );
      if (!mounted) return;
      Navigator.of(context).pop();
      final applied = result['creditApplied'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            '₹${(applied as num).toStringAsFixed(0)} credit applied for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t apply credit. Please try again.';
      });
    }
  }

  Future<void> _submitCreditAdjustment(bool isAdd) async {
    final amount = double.tryParse(_creditAmountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (!isAdd && amount > _advanceCredit) {
      setState(
          () => _error = 'Amount exceeds available credit of ₹${_advanceCredit.toStringAsFixed(0)}.');
      return;
    }
    final remarks = _creditRemarksCtl.text.trim();
    if (remarks.isEmpty) {
      setState(() => _error = 'Please provide a reason.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final villaId = widget.resident['villaId']?.toString() ?? '';
      if (villaId.isEmpty) throw 'Missing villa id on this row.';

      final filter = ref.read(adminMaintenanceFilterProvider);
      final cycleId = filter.maintenanceCollectionCycleId;
      if (cycleId == null || cycleId.isEmpty) {
        throw 'No billing cycle selected.';
      }

      await ref
          .read(adminMaintenanceRepositoryProvider)
          .manualCreditAdjustment(
            villaId: villaId,
            maintenanceCollectionCycleId: cycleId,
            amount: amount,
            type: isAdd ? 'ADD' : 'DEDUCT',
            remarks: remarks,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            '${isAdd ? "Added" : "Deducted"} ₹${amount.toStringAsFixed(0)} credit for villa '
            '${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t adjust credit. Please try again.';
      });
    }
  }
}

/// Bottom sheet for editing villa grid row amounts.
