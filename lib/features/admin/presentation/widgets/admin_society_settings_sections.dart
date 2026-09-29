import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../data/providers/admin_providers.dart';

double _num(dynamic v, [double fallback = 0]) =>
    v == null ? fallback : (double.tryParse(v.toString()) ?? fallback);

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

void _toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? DesignColors.error : null,
  ));
}

// ── Late fees ────────────────────────────────────────────────────────

class SocietyLateFeePanel extends ConsumerStatefulWidget {
  const SocietyLateFeePanel({
    super.key,
    required this.settings,
    required this.onSaved,
  });

  final Map<String, dynamic> settings;
  final VoidCallback onSaved;

  @override
  ConsumerState<SocietyLateFeePanel> createState() =>
      _SocietyLateFeePanelState();
}

class _SocietyLateFeePanelState extends ConsumerState<SocietyLateFeePanel> {
  late final _percent = TextEditingController(
      text: _fmt(_num(widget.settings['lateFeePercentage'])));
  late final _fixed = TextEditingController(
      text: _fmt(_num(widget.settings['lateFeeFixedAmount'])));
  late final _grace = TextEditingController(
      text: _fmt(_num(widget.settings['maintenanceGracePeriodDays'], 15)));
  bool _saving = false;

  @override
  void dispose() {
    _percent.dispose();
    _fixed.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final percent = double.tryParse(_percent.text.trim());
    final fixed = double.tryParse(_fixed.text.trim());
    final grace = int.tryParse(_grace.text.trim());
    if (percent == null || percent < 0 || percent > 100) {
      _toast(context, 'Late fee % must be between 0 and 100', error: true);
      return;
    }
    if (fixed == null || fixed < 0) {
      _toast(context, 'Fixed late fee must be 0 or more', error: true);
      return;
    }
    if (grace == null || grace < 0 || grace > 90) {
      _toast(context, 'Grace period must be 0–90 days', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminSocietySettingsRepositoryProvider).updateLateFee(
            lateFeePercentage: percent,
            lateFeeFixedAmount: fixed,
            gracePeriodDays: grace,
          );
      if (mounted) _toast(context, 'Late fee settings saved');
      widget.onSaved();
    } catch (e) {
      if (mounted) _toast(context, userFacingMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Applied to unpaid maintenance after the grace period.',
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _percent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Late fee %'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fixed,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Fixed late fee (₹)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _grace,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Grace period (days)'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save late fee settings'),
          ),
        ],
      ),
    );
  }
}

// ── Maintenance billing + charge heads ───────────────────────────────

class SocietyBillingPanel extends ConsumerStatefulWidget {
  const SocietyBillingPanel({
    super.key,
    required this.settings,
    required this.onSaved,
  });

  final Map<String, dynamic> settings;
  final VoidCallback onSaved;

  @override
  ConsumerState<SocietyBillingPanel> createState() =>
      _SocietyBillingPanelState();
}

class _SocietyBillingPanelState extends ConsumerState<SocietyBillingPanel> {
  late String _mode =
      widget.settings['maintenanceBillingMode']?.toString() == 'SQFT'
          ? 'SQFT'
          : 'FIXED';
  late final _fixed = TextEditingController(
      text: _fmt(_num(widget.settings['maintenanceFixedAmount'], 1100)));
  late final _rate = TextEditingController(
      text: _fmt(_num(widget.settings['maintenanceSqftRate'], 1.1)));
  late bool _useChargeHeads = widget.settings['useChargeHeads'] == true;
  bool _saving = false;
  List<Map<String, dynamic>>? _heads;

  @override
  void initState() {
    super.initState();
    _loadHeads();
  }

  @override
  void dispose() {
    _fixed.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _loadHeads() async {
    try {
      final heads =
          await ref.read(adminSocietySettingsRepositoryProvider).getChargeHeads();
      if (mounted) setState(() => _heads = heads);
    } catch (e) {
      if (mounted) {
        setState(() => _heads = const []);
        _toast(context, userFacingMessage(e), error: true);
      }
    }
  }

  Future<void> _save() async {
    final fixed = double.tryParse(_fixed.text.trim());
    final rate = double.tryParse(_rate.text.trim());
    if (fixed == null || fixed <= 0 || rate == null || rate <= 0) {
      _toast(context, 'Fixed amount and sq ft rate must be more than 0',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminSocietySettingsRepositoryProvider).updateMaintenanceBilling(
            mode: _mode,
            fixedAmount: fixed,
            sqftRate: rate,
            useChargeHeads: _useChargeHeads,
          );
      if (mounted) _toast(context, 'Maintenance billing saved');
      widget.onSaved();
      await _loadHeads();
    } catch (e) {
      if (mounted) _toast(context, userFacingMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeHead(Map<String, dynamic> head) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove charge head?'),
        content: Text(
            '"${head['label']}" will no longer be added to new maintenance bills.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: DesignColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(adminSocietySettingsRepositoryProvider)
          .removeChargeHead(head['id']?.toString() ?? '');
      if (mounted) _toast(context, 'Charge head removed');
      await _loadHeads();
    } catch (e) {
      if (mounted) _toast(context, userFacingMessage(e), error: true);
    }
  }

  Future<void> _addHead() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddChargeHeadSheet(),
    );
    if (added == true) {
      if (mounted) _toast(context, 'Charge head added');
      await _loadHeads();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeHeads =
        (_heads ?? const []).where((h) => h['isActive'] != false).toList();
    return EnterprisePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How each villa\'s monthly maintenance is calculated.',
            style: DesignTypography.captionSmall
                .copyWith(color: DesignColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'FIXED', label: Text('Fixed per villa')),
              ButtonSegment(value: 'SQFT', label: Text('Per sq ft')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          if (_mode == 'FIXED')
            TextField(
              controller: _fixed,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Amount per villa (₹)'),
            )
          else ...[
            TextField(
              controller: _rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate per sq ft (₹)'),
            ),
            const SizedBox(height: 4),
            Text(
              'Villas without an area use their saved monthly amount.',
              style: DesignTypography.captionSmall
                  .copyWith(color: DesignColors.textSecondary),
            ),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Itemised bills (charge heads)'),
            subtitle:
                const Text('Split each bill into line items listed below'),
            value: _useChargeHeads,
            onChanged: (v) => setState(() => _useChargeHeads = v),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save billing mode'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Charge heads',
                    style: DesignTypography.label
                        .copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: _addHead,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_heads == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (activeHeads.isEmpty)
            Text('No charge heads yet.',
                style: DesignTypography.captionSmall
                    .copyWith(color: DesignColors.textSecondary))
          else
            ...activeHeads.map((h) {
              final perSqft = h['amountType'] == 'PER_SQFT';
              final amount = perSqft
                  ? '₹${_fmt(_num(h['perSqftRate']))} / sq ft'
                  : '₹${_fmt(_num(h['fixedAmount']))}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(h['label']?.toString() ?? ''),
                subtitle: Text('${h['code']} · $amount'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(Icons.delete_outline, color: DesignColors.error),
                  onPressed: () => _removeHead(h),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AddChargeHeadSheet extends ConsumerStatefulWidget {
  const _AddChargeHeadSheet();

  @override
  ConsumerState<_AddChargeHeadSheet> createState() =>
      _AddChargeHeadSheetState();
}

class _AddChargeHeadSheetState extends ConsumerState<_AddChargeHeadSheet> {
  final _label = TextEditingController();
  final _code = TextEditingController();
  final _amount = TextEditingController();
  String _type = 'FIXED';
  bool _codeEdited = false;
  bool _busy = false;
  String? _error;

  static final _codePattern = RegExp(r'^[a-z][a-z0-9_]*$');

  @override
  void dispose() {
    _label.dispose();
    _code.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onLabelChanged(String v) {
    if (_codeEdited) return;
    _code.text = v
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _save() async {
    final code = _code.text.trim().toLowerCase();
    final amount = double.tryParse(_amount.text.trim());
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Enter a label');
      return;
    }
    if (code.length < 2 || code.length > 32 || !_codePattern.hasMatch(code)) {
      setState(() => _error =
          'Code must start with a letter and use lowercase letters, numbers or _');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Amount must be more than 0');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminSocietySettingsRepositoryProvider).addChargeHead(
            code: code,
            label: _label.text.trim(),
            amountType: _type,
            fixedAmount: _type == 'FIXED' ? amount : null,
            perSqftRate: _type == 'PER_SQFT' ? amount : null,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userFacingMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.circular(DesignRadius.xl),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Add charge head', style: DesignTypography.headingM),
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              onChanged: _onLabelChanged,
              decoration: const InputDecoration(
                labelText: 'Label *',
                hintText: 'e.g. Sinking fund',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              onChanged: (_) => _codeEdited = true,
              decoration: const InputDecoration(
                labelText: 'Code *',
                helperText: 'Lowercase, e.g. sinking_fund',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'FIXED', label: Text('Fixed')),
                ButtonSegment(value: 'PER_SQFT', label: Text('Per sq ft')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    _type == 'FIXED' ? 'Amount per villa (₹) *' : 'Rate per sq ft (₹) *',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: DesignColors.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Add charge head'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Branding images ──────────────────────────────────────────────────

class SocietyBrandingPanel extends ConsumerStatefulWidget {
  const SocietyBrandingPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final Map<String, dynamic> settings;
  final VoidCallback onChanged;

  @override
  ConsumerState<SocietyBrandingPanel> createState() =>
      _SocietyBrandingPanelState();
}

class _SocietyBrandingPanelState extends ConsumerState<SocietyBrandingPanel> {
  static const _items = <(String, String, String)>[
    ('qr', 'upiQrCodeUrl', 'UPI QR code'),
    ('letterhead', 'letterheadUrl', 'Letterhead'),
    ('signature', 'signatureUrl', 'Signature'),
    ('stamp', 'stampUrl', 'Society stamp'),
    ('splash', 'splashUrl', 'App splash image'),
  ];

  String? _busyKind;

  Future<void> _upload(String kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null) return;
    setState(() => _busyKind = kind);
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(adminSocietySettingsRepositoryProvider)
          .uploadBrandingImage(kind, bytes, picked.name);
      if (mounted) _toast(context, 'Image uploaded');
      widget.onChanged();
    } catch (e) {
      if (mounted) _toast(context, userFacingMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<void> _remove(String kind, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: DesignColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyKind = kind);
    try {
      await ref
          .read(adminSocietySettingsRepositoryProvider)
          .removeBrandingImage(kind);
      if (mounted) _toast(context, '$title removed');
      widget.onChanged();
    } catch (e) {
      if (mounted) _toast(context, userFacingMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EnterprisePanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: _items.map((item) {
          final (kind, key, title) = item;
          final url = widget.settings[key]?.toString() ?? '';
          final busy = _busyKind == kind;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: url.startsWith('http')
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : ColoredBox(
                        color: DesignColors.surfaceSoft,
                        child: Icon(Icons.image_outlined,
                            color: DesignColors.textTertiary),
                      ),
              ),
            ),
            title: Text(title),
            subtitle: Text(url.isEmpty ? 'Not uploaded' : 'Uploaded'),
            trailing: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: url.isEmpty ? 'Upload' : 'Replace',
                        icon: const Icon(Icons.upload_rounded),
                        onPressed: _busyKind == null ? () => _upload(kind) : null,
                      ),
                      if (url.isNotEmpty)
                        IconButton(
                          tooltip: 'Remove',
                          icon: Icon(Icons.delete_outline,
                              color: DesignColors.error),
                          onPressed: _busyKind == null
                              ? () => _remove(kind, title)
                              : null,
                        ),
                    ],
                  ),
          );
        }).toList(),
      ),
    );
  }
}
