import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for managing bank accounts.
class AdminBankAccountsScreen extends ConsumerStatefulWidget {
  const AdminBankAccountsScreen({super.key});

  @override
  ConsumerState<AdminBankAccountsScreen> createState() =>
      _AdminBankAccountsScreenState();
}

class _AdminBankAccountsScreenState
    extends ConsumerState<AdminBankAccountsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminBankAccountsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(adminBankAccountsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Bank Accounts',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: DesignColors.info,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Account', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: accountsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
                  ),
                ),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load bank accounts',
              subtitle: 'Something went wrong. Please try again.',
              iconColor: DesignColors.error,
              actionLabel: 'Retry',
              onAction: _refresh,
            ),
          ),
          data: (accounts) {
            if (accounts.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.account_balance_outlined,
                      title: 'No bank accounts',
                      subtitle: 'Tap + to add your first bank account.',
                      iconColor: DesignColors.info,
                    ),
                  ),
                ],
              );
            }
            return _buildList(accounts);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> accounts) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: accounts.asMap().entries.map((entry) {
        final idx = entry.key;
        final a = entry.value;
        final accountName = a['accountHolderName']?.toString() ?? '';
        final bankName = a['bankName']?.toString() ?? '';
        final accountNumber = a['accountNumber']?.toString() ?? '';
        final ifsc = a['ifscCode']?.toString() ?? '';
        final accountType = a['accountType']?.toString() ?? '';
        final isActive = a['isActive'] as bool? ?? true;

        // Mask account number
        final masked = accountNumber.length > 4
            ? '${'*' * (accountNumber.length - 4)}${accountNumber.substring(accountNumber.length - 4)}'
            : accountNumber;

        return EnterprisePanel(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          onTap: () => _showForm(existing: a),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DesignColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_outlined,
                    color: DesignColors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            accountName.isNotEmpty ? accountName : bankName,
                            style: DesignTypography.label
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DesignColors.textSecondary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Inactive',
                              style: DesignTypography.captionSmall.copyWith(
                                color: DesignColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (bankName.isNotEmpty) bankName,
                        masked,
                        if (ifsc.isNotEmpty) ifsc,
                        if (accountType.isNotEmpty) accountType,
                      ].join(' \u00b7 '),
                      style: DesignTypography.captionSmall
                          .copyWith(color: DesignColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: DesignAnimations.staggerFor(idx)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
      }).toList(),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(
        text: existing?['accountHolderName']?.toString() ?? '');
    final bankCtrl = TextEditingController(
        text: existing?['bankName']?.toString() ?? '');
    final numberCtrl = TextEditingController(
        text: existing?['accountNumber']?.toString() ?? '');
    final ifscCtrl = TextEditingController(
        text: existing?['ifscCode']?.toString() ?? '');
    final typeCtrl = TextEditingController(
        text: existing?['accountType']?.toString() ?? '');
    // Active state — the graceful alternative to Delete, which the backend
    // refuses for accounts that already have payment records.
    final isActive = ValueNotifier<bool>(existing?['isActive'] as bool? ?? true);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: BorderRadius.circular(DesignRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
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
                  const SizedBox(height: 16),
                  Text(isEdit ? 'Edit Account' : 'Add Account',
                      style: DesignTypography.headingM),
                  const SizedBox(height: 16),
                  _field('Account Holder Name *', nameCtrl, required: true),
                  _field('Bank Name *', bankCtrl, required: true),
                  _field(
                    isEdit ? 'Account Number' : 'Account Number *',
                    numberCtrl,
                    keyboardType: TextInputType.number,
                    required: !isEdit,
                    // The account number can't be changed after creation.
                    enabled: !isEdit,
                  ),
                  _field('IFSC Code *', ifscCtrl, required: true),
                  _field('Account Type *', typeCtrl, required: true),
                  if (isEdit)
                    ValueListenableBuilder<bool>(
                      valueListenable: isActive,
                      builder: (_, active, __) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: DesignColors.info,
                        title: const Text('Active'),
                        subtitle: Text(
                          active
                              ? 'Shown to residents for payments'
                              : 'Deactivated — hidden from residents',
                          style: DesignTypography.captionSmall
                              .copyWith(color: DesignColors.textSecondary),
                        ),
                        value: active,
                        onChanged: (v) => isActive.value = v,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (isEdit) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleDelete(existing['id']?.toString() ?? '');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: DesignColors.error,
                              side: BorderSide(color: DesignColors.error),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            Navigator.pop(ctx);
                            if (isEdit) {
                              _handleUpdate(
                                existing['id']?.toString() ?? '',
                                nameCtrl.text,
                                bankCtrl.text,
                                numberCtrl.text,
                                ifscCtrl.text,
                                typeCtrl.text,
                                isActive.value,
                              );
                            } else {
                              _handleCreate(nameCtrl.text, bankCtrl.text,
                                  numberCtrl.text, ifscCtrl.text, typeCtrl.text);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: DesignColors.info,
                          ),
                          child: Text(isEdit ? 'Update' : 'Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, bool required = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _handleCreate(String name, String bank, String number,
      String ifsc, String type) async {
    try {
      await ref.read(adminBankAccountRepositoryProvider).createBankAccount(
            accountHolderName: name.trim(),
            bankName: bank.trim(),
            accountNumber: number.trim(),
            ifscCode: ifsc.trim(),
            accountType: type.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account created')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _handleUpdate(String id, String name, String bank,
      String number, String ifsc, String type, bool isActive) async {
    try {
      await ref.read(adminBankAccountRepositoryProvider).updateBankAccount(
            id,
            accountHolderName: name.trim().isNotEmpty ? name.trim() : null,
            bankName: bank.trim().isNotEmpty ? bank.trim() : null,
            ifscCode: ifsc.trim().isNotEmpty ? ifsc.trim() : null,
            accountType: type.trim().isNotEmpty ? type.trim() : null,
            isActive: isActive,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account updated')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }

  Future<void> _handleDelete(String id) async {
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
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: DesignColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_outlined, color: DesignColors.error, size: 28)),
              SizedBox(height: 16),
              Text('Delete Bank Account?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Are you sure you want to delete this bank account?',
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
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.error, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminBankAccountRepositoryProvider).deleteBankAccount(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account deleted')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingMessage(e))),
        );
      }
    }
  }
}
