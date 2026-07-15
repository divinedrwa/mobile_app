import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/design_tokens.dart';
import '../../../../../../core/widgets/enterprise_ui.dart';
import '../../../../data/providers/admin_providers.dart';
import '../../../../../resident/data/resident_data_refresh.dart';

class AdminMaintenanceEditVillaRowSheet extends ConsumerStatefulWidget {
  const AdminMaintenanceEditVillaRowSheet({required this.resident});

  final Map<String, dynamic> resident;

  @override
  ConsumerState<AdminMaintenanceEditVillaRowSheet> createState() =>
      AdminMaintenanceEditVillaRowSheetState();
}

class AdminMaintenanceEditVillaRowSheetState extends ConsumerState<AdminMaintenanceEditVillaRowSheet> {
  final _expectedCtl = TextEditingController();
  final _paidCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final expected = (widget.resident['amount'] as num?)?.toDouble() ?? 0;
    final paid =
        (widget.resident['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    _expectedCtl.text = expected.toStringAsFixed(0);
    _paidCtl.text = paid.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _expectedCtl.dispose();
    _paidCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final villa = widget.resident['villaNumber']?.toString() ?? '—';
    final owner = widget.resident['ownerName']?.toString() ?? 'Unknown';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(DesignRadius.xl)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DesignColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Edit amounts',
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Villa $villa · $owner',
                style: DesignTypography.bodySmall.copyWith(
                  color: DesignColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                ),
                child: Text(
                  'This updates the billing snapshot. Any amount above expected becomes advance credit.',
                  style: DesignTypography.caption.copyWith(
                    color: const Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _expectedCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Expected amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _paidCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paid / collected (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
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
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DesignRadius.md),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save changes',
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
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final expected = double.tryParse(_expectedCtl.text.trim());
    final paid = double.tryParse(_paidCtl.text.trim());
    if (expected == null && paid == null) {
      setState(() => _error = 'Enter at least one amount.');
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

      await ref.read(adminMaintenanceRepositoryProvider).editVillaGridRow(
            cycleId: cycleId,
            villaId: villaId,
            expectedAmount: expected,
            paidAmount: paid,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.success,
          content: Text(
            'Updated amounts for villa ${widget.resident['villaNumber'] ?? ""}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Couldn\'t update. Please try again.';
      });
    }
  }
}
