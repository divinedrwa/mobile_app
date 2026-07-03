import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Admin screen for configuring payment gateways (Razorpay, PhonePe, UPI, etc.).
class AdminPaymentMethodsScreen extends ConsumerStatefulWidget {
  const AdminPaymentMethodsScreen({super.key});

  @override
  ConsumerState<AdminPaymentMethodsScreen> createState() =>
      _AdminPaymentMethodsScreenState();
}

class _AdminPaymentMethodsScreenState
    extends ConsumerState<AdminPaymentMethodsScreen> {
  Future<void> _refresh() async {
    ref.invalidate(adminPaymentMethodsProvider);
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'UPI_VPA':
        return 'UPI VPA';
      case 'UPI_QR':
        return 'UPI QR';
      case 'RAZORPAY':
        return 'Razorpay';
      case 'PHONEPE':
        return 'PhonePe';
      default:
        return type;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'BANK_TRANSFER':
        return Icons.account_balance_outlined;
      case 'UPI_VPA':
      case 'UPI_QR':
        return Icons.qr_code_2_outlined;
      case 'RAZORPAY':
        return Icons.credit_card_outlined;
      case 'PHONEPE':
        return Icons.phone_android_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(adminPaymentMethodsProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Payment Methods',
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
        onPressed: _showCreateSheet,
        backgroundColor: DesignColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Method', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: _refresh,
        child: methodsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWrap(
              child: Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerBox(height: 88, borderRadius: DesignRadius.lg),
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
                  title: 'Failed to load payment methods',
                  subtitle: 'Pull down to refresh',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ),
            ],
          ),
          data: (methods) {
            if (methods.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: EmptyStateWidget(
                      icon: Icons.payment_outlined,
                      title: 'No payment methods',
                      subtitle:
                          'Add Razorpay, PhonePe, or UPI to enable online payments.',
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: methods.length,
              itemBuilder: (context, i) {
                final m = methods[i];
                final id = m['id']?.toString() ?? '';
                final type = m['type']?.toString() ?? '';
                final name = m['displayName']?.toString() ?? type;
                final enabled = m['isEnabled'] as bool? ?? false;

                return EnterprisePanel(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  onTap: () => _showEditSheet(m),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DesignColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_typeIcon(type),
                            color: DesignColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: DesignTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                            Text(_typeLabel(type),
                                style: DesignTypography.captionSmall.copyWith(
                                  color: DesignColors.textSecondary,
                                )),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: enabled,
                        activeColor: DesignColors.success,
                        onChanged: (v) => _toggleEnabled(id, v),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleEnabled(String id, bool enabled) async {
    try {
      await ref
          .read(adminPaymentMethodRepositoryProvider)
          .updatePaymentMethod(id, isEnabled: enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enabled ? 'Method enabled' : 'Method disabled')),
        );
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _testConnection(String id) async {
    try {
      final result = await ref
          .read(adminPaymentMethodRepositoryProvider)
          .testConnection(id);
      if (mounted) {
        final msg = result['message']?.toString() ?? 'Connection OK';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showCreateSheet() {
    _showMethodForm();
  }

  void _showEditSheet(Map<String, dynamic> existing) {
    _showMethodForm(existing: existing);
  }

  void _showMethodForm({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final id = existing?['id']?.toString() ?? '';
    final type = existing?['type']?.toString() ?? 'UPI_VPA';
    final config = existing?['config'] is Map
        ? Map<String, dynamic>.from(existing!['config'] as Map)
        : <String, dynamic>{};

    String selectedType = type;
    var submitting = false;
    final nameCtl =
        TextEditingController(text: existing?['displayName']?.toString() ?? '');
    final fields = <String, TextEditingController>{};

    void initFields(String t) {
      // Dispose replaced controllers after the frame so any TextFields still
      // referencing them have been rebuilt first.
      final old = fields.values.toList();
      if (old.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final c in old) {
            c.dispose();
          }
        });
      }
      fields.clear();
      for (final key in _configKeysForType(t)) {
        fields[key] = TextEditingController(
          text: config[key]?.toString() ?? _defaultForKey(t, key),
        );
      }
    }

    initFields(selectedType);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEdit ? 'Edit Payment Method' : 'Add Payment Method',
                        style: DesignTypography.headingM.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isEdit)
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          // UPI_QR is intentionally not offered here: the
                          // backend force-disables new UPI_QR methods until a
                          // QR image is uploaded via the web admin.
                          items: const [
                            DropdownMenuItem(
                                value: 'UPI_VPA', child: Text('UPI VPA')),
                            DropdownMenuItem(
                                value: 'RAZORPAY', child: Text('Razorpay')),
                            DropdownMenuItem(
                                value: 'PHONEPE', child: Text('PhonePe')),
                            DropdownMenuItem(
                                value: 'BANK_TRANSFER',
                                child: Text('Bank Transfer')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() {
                              selectedType = v;
                              initFields(v);
                              if (nameCtl.text.isEmpty) {
                                nameCtl.text = _typeLabel(v);
                              }
                            });
                          },
                        ),
                      if (!isEdit) ...[
                        const SizedBox(height: 6),
                        Text(
                          'UPI QR methods are set up from the web admin.',
                          style: DesignTypography.captionSmall.copyWith(
                            color: DesignColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameCtl,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...fields.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: e.value,
                            obscureText: e.key.contains('Secret') ||
                                e.key.contains('saltKey'),
                            decoration: InputDecoration(
                              labelText: _labelForKey(e.key),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final cfg = <String, dynamic>{};
                                for (final e in fields.entries) {
                                  if (e.value.text.isNotEmpty) {
                                    cfg[e.key] = e.key == 'saltIndex'
                                        ? int.tryParse(e.value.text) ?? 1
                                        : e.value.text;
                                  }
                                }
                                setLocal(() => submitting = true);
                                try {
                                  if (isEdit) {
                                    await ref
                                        .read(
                                            adminPaymentMethodRepositoryProvider)
                                        .updatePaymentMethod(
                                          id,
                                          displayName: nameCtl.text.trim(),
                                          config: cfg,
                                        );
                                  } else {
                                    await ref
                                        .read(
                                            adminPaymentMethodRepositoryProvider)
                                        .createPaymentMethod(
                                          type: selectedType,
                                          displayName:
                                              nameCtl.text.trim().isEmpty
                                                  ? _typeLabel(selectedType)
                                                  : nameCtl.text.trim(),
                                          config: cfg,
                                        );
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _refresh();
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setLocal(() => submitting = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEdit ? 'Save' : 'Create'),
                      ),
                      if (isEdit &&
                          (type == 'RAZORPAY' || type == 'PHONEPE')) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _testConnection(id),
                          icon: const Icon(Icons.link),
                          label: const Text('Test connection'),
                        ),
                      ],
                      if (isEdit) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: const Text('Delete method?'),
                                content: const Text(
                                    'Residents will no longer see this payment option.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              await ref
                                  .read(adminPaymentMethodRepositoryProvider)
                                  .deletePaymentMethod(id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refresh();
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.delete_outline,
                              color: DesignColors.error),
                          label: Text('Delete',
                              style: TextStyle(color: DesignColors.error)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtl.dispose();
      for (final c in fields.values) {
        c.dispose();
      }
    });
  }

  static List<String> _configKeysForType(String type) {
    switch (type) {
      case 'BANK_TRANSFER':
        return [
          'bankName',
          'accountNumber',
          'ifscCode',
          'accountHolderName',
          'accountType',
        ];
      case 'UPI_VPA':
        return ['vpa'];
      case 'UPI_QR':
        return ['qrCodeUrl'];
      case 'RAZORPAY':
        return ['keyId', 'keySecret', 'webhookSecret', 'currency'];
      case 'PHONEPE':
        return ['merchantId', 'saltKey', 'saltIndex', 'environment'];
      default:
        return [];
    }
  }

  static String _defaultForKey(String type, String key) {
    if (type == 'RAZORPAY' && key == 'currency') return 'INR';
    if (type == 'PHONEPE' && key == 'saltIndex') return '1';
    if (type == 'PHONEPE' && key == 'environment') return 'SANDBOX';
    if (type == 'BANK_TRANSFER' && key == 'accountType') return 'SAVINGS';
    return '';
  }

  static String _labelForKey(String key) {
    switch (key) {
      case 'vpa':
        return 'UPI ID (VPA)';
      case 'qrCodeUrl':
        return 'QR image URL';
      case 'keyId':
        return 'Razorpay Key ID';
      case 'keySecret':
        return 'Razorpay Key Secret';
      case 'webhookSecret':
        return 'Webhook Secret';
      case 'merchantId':
        return 'Merchant ID';
      case 'saltKey':
        return 'Salt Key';
      case 'saltIndex':
        return 'Salt Index';
      case 'environment':
        return 'Environment (SANDBOX/PRODUCTION)';
      default:
        return key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(0)}',
        ).trim();
    }
  }
}
