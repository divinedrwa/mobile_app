import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: const Color(0xFF0EA5E9),
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
                      iconColor: const Color(0xFF0EA5E9),
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
      children: accounts.map((a) {
        final accountName = a['accountName']?.toString() ?? '';
        final bankName = a['bankName']?.toString() ?? '';
        final accountNumber = a['accountNumber']?.toString() ?? '';
        final ifsc = a['ifscCode']?.toString() ?? '';
        final accountType = a['accountType']?.toString() ?? '';

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
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_outlined,
                    color: Color(0xFF0EA5E9), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName.isNotEmpty ? accountName : bankName,
                      style: DesignTypography.label
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        );
      }).toList(),
    );
  }

  void _showForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(
        text: existing?['accountName']?.toString() ?? '');
    final bankCtrl = TextEditingController(
        text: existing?['bankName']?.toString() ?? '');
    final numberCtrl = TextEditingController(
        text: existing?['accountNumber']?.toString() ?? '');
    final ifscCtrl = TextEditingController(
        text: existing?['ifscCode']?.toString() ?? '');
    final typeCtrl = TextEditingController(
        text: existing?['accountType']?.toString() ?? '');

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
                _field('Account Name *', nameCtrl),
                _field('Bank Name *', bankCtrl),
                _field('Account Number *', numberCtrl,
                    keyboardType: TextInputType.number),
                _field('IFSC Code', ifscCtrl),
                _field('Account Type', typeCtrl),
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
                            side: const BorderSide(color: DesignColors.error),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isEdit) {
                            _handleUpdate(
                              existing['id']?.toString() ?? '',
                              nameCtrl.text,
                              bankCtrl.text,
                              numberCtrl.text,
                              ifscCtrl.text,
                              typeCtrl.text,
                            );
                          } else {
                            _handleCreate(nameCtrl.text, bankCtrl.text,
                                numberCtrl.text, ifscCtrl.text, typeCtrl.text);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
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
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _handleCreate(String name, String bank, String number,
      String ifsc, String type) async {
    if (name.trim().isEmpty || bank.trim().isEmpty || number.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(adminBankAccountRepositoryProvider).createBankAccount(
            accountName: name.trim(),
            bankName: bank.trim(),
            accountNumber: number.trim(),
            ifscCode: ifsc.trim().isNotEmpty ? ifsc.trim() : null,
            accountType: type.trim().isNotEmpty ? type.trim() : null,
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
      String number, String ifsc, String type) async {
    try {
      await ref.read(adminBankAccountRepositoryProvider).updateBankAccount(
            id,
            accountName: name.trim().isNotEmpty ? name.trim() : null,
            bankName: bank.trim().isNotEmpty ? bank.trim() : null,
            accountNumber: number.trim().isNotEmpty ? number.trim() : null,
            ifscCode: ifsc.trim(),
            accountType: type.trim(),
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
