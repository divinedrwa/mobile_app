import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../data/providers/admin_providers.dart';
import '../widgets/admin_villa_picker_field.dart';

/// Admin form — register approved vehicles (resident / visitor / other).
class AdminAddVehicleScreen extends ConsumerStatefulWidget {
  const AdminAddVehicleScreen({super.key});

  @override
  ConsumerState<AdminAddVehicleScreen> createState() =>
      _AdminAddVehicleScreenState();
}

class _AdminAddVehicleScreenState extends ConsumerState<AdminAddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtl = TextEditingController();
  final _modelCtl = TextEditingController();
  final _colorCtl = TextEditingController();
  final _slotCtl = TextEditingController();
  final _ownerCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  String _category = 'RESIDENT';
  String _vehicleType = 'FOUR_WHEELER';
  String? _villaId;
  bool _submitting = false;
  bool _showOptional = false;
  String? _villaError;

  static const _categories = [
    ('RESIDENT', 'Resident', Icons.home_outlined),
    ('VISITOR', 'Visitor', Icons.person_outline),
    ('OTHER', 'Other', Icons.badge_outlined),
  ];

  static const _vehicleTypes = [
    ('TWO_WHEELER', 'Two wheeler', Icons.two_wheeler),
    ('FOUR_WHEELER', 'Four wheeler', Icons.directions_car_outlined),
    ('BICYCLE', 'Bicycle', Icons.pedal_bike),
    ('OTHER', 'Other', Icons.local_shipping_outlined),
  ];

  @override
  void dispose() {
    _numberCtl.dispose();
    _modelCtl.dispose();
    _colorCtl.dispose();
    _slotCtl.dispose();
    _ownerCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  bool get _needsOwnerLabel => _category == 'VISITOR' || _category == 'OTHER';

  void _resetForAnother() {
    _numberCtl.clear();
    _modelCtl.clear();
    _colorCtl.clear();
    _slotCtl.clear();
    _ownerCtl.clear();
    _notesCtl.clear();
    if (_category != 'RESIDENT') _villaId = null;
    _formKey.currentState?.reset();
  }

  Future<void> _submit({bool registerAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == 'RESIDENT' && (_villaId == null || _villaId!.isEmpty)) {
      setState(() => _villaError = 'Select a villa');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a villa for resident vehicles')),
      );
      return;
    }
    setState(() => _villaError = null);

    setState(() => _submitting = true);
    try {
      await ref.read(adminParkingRepositoryProvider).registerVehicle(
            registrationCategory: _category,
            vehicleNumber: _numberCtl.text,
            vehicleType: _vehicleType,
            villaId: _villaId,
            model: _modelCtl.text,
            color: _colorCtl.text,
            parkingSlot: _slotCtl.text,
            ownerLabel: _needsOwnerLabel ? _ownerCtl.text : null,
            notes: _notesCtl.text,
          );
      ref.invalidate(adminParkingVehiclesProvider);
      ref.invalidate(adminParkingOverviewProvider);
      if (!mounted) return;

      if (registerAnother) {
        _resetForAnother();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vehicle registered — add another'),
            action: SnackBarAction(
              label: 'Done',
              onPressed: () {
                if (mounted) context.pop(true);
              },
            ),
          ),
        );
      } else {
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final villasAsync = ref.watch(adminVillasProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        title: Text(
          'Register vehicle',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
          children: [
            EnterpriseInfoBanner(
              icon: Icons.verified_user_outlined,
              title: 'Approved vehicle registry',
              message:
                  'Registered plates appear on the guard app for gate verification. Search works on full plate or last digits (e.g. 5670).',
              tone: EnterpriseTone.info,
            ),
            const SizedBox(height: 16),
            const EnterpriseSectionHeader(
              title: 'Who is this for?',
              subtitle: 'Pick the registration type first',
            ),
            const SizedBox(height: 8),
            Row(
              children: _categories.map((c) {
                final selected = _category == c.$1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: c.$1 != 'OTHER' ? 8 : 0,
                    ),
                    child: _CategoryTile(
                      label: c.$2,
                      icon: c.$3,
                      selected: selected,
                      enabled: !_submitting,
                      onTap: () => setState(() {
                        _category = c.$1;
                        if (_category == 'RESIDENT') {
                          _ownerCtl.clear();
                        } else {
                          _villaId = null;
                        }
                      }),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const EnterpriseSectionHeader(title: 'Plate number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _numberCtl,
              enabled: !_submitting,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(
                labelText: 'Registration number *',
                hintText: 'KA01 AB 5670',
                helperText: 'Guards can search by full plate or digits only',
                filled: true,
                fillColor: DesignColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignRadius.lg),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().length < 3 ? 'Enter plate number' : null,
            ),
            const SizedBox(height: 16),
            const EnterpriseSectionHeader(title: 'Vehicle type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vehicleTypes.map((t) {
                final selected = _vehicleType == t.$1;
                return ChoiceChip(
                  avatar: Icon(
                    t.$3,
                    size: 18,
                    color: selected ? DesignColors.primary : DesignColors.textSecondary,
                  ),
                  label: Text(t.$2),
                  selected: selected,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _vehicleType = t.$1),
                  selectedColor: DesignColors.primary.withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (_category == 'RESIDENT') ...[
              const EnterpriseSectionHeader(title: 'Linked villa'),
              const SizedBox(height: 8),
              villasAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  'Could not load villas',
                  style: DesignTypography.captionSmall
                      .copyWith(color: DesignColors.error),
                ),
                data: (villas) => AdminVillaPickerField(
                  villas: villas,
                  selectedVillaId: _villaId,
                  required: true,
                  enabled: !_submitting,
                  errorText: _villaError,
                  onSelected: (id) => setState(() {
                    _villaId = id;
                    _villaError = null;
                  }),
                ),
              ),
            ] else ...[
              const EnterpriseSectionHeader(
                title: 'Owner / description',
                subtitle: 'Required for visitor and other vehicles',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ownerCtl,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: 'Owner / description *',
                  hintText: 'e.g. Milk vendor, Chairman guest',
                  filled: true,
                  fillColor: DesignColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                ),
                validator: (v) => _needsOwnerLabel &&
                        (v == null || v.trim().length < 2)
                    ? 'Required for visitor/other vehicles'
                    : null,
              ),
              const SizedBox(height: 16),
              const EnterpriseSectionHeader(title: 'Optional villa link'),
              const SizedBox(height: 8),
              villasAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (villas) => AdminVillaPickerField(
                  villas: villas,
                  selectedVillaId: _villaId,
                  allowClear: true,
                  enabled: !_submitting,
                  label: 'Villa (optional)',
                  onSelected: (id) => setState(() => _villaId = id),
                ),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _submitting
                  ? null
                  : () => setState(() => _showOptional = !_showOptional),
              borderRadius: BorderRadius.circular(DesignRadius.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _showOptional
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: DesignColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Optional details (model, color, slot, notes)',
                      style: DesignTypography.label.copyWith(
                        color: DesignColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showOptional) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtl,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: 'Model',
                  filled: true,
                  fillColor: DesignColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorCtl,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: 'Color',
                  filled: true,
                  fillColor: DesignColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slotCtl,
                enabled: !_submitting,
                decoration: InputDecoration(
                  labelText: 'Parking slot',
                  filled: true,
                  fillColor: DesignColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtl,
                enabled: !_submitting,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes for guards',
                  hintText: 'e.g. Allowed only until 6 PM',
                  filled: true,
                  fillColor: DesignColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Register vehicle'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => _submit(registerAnother: true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Register & add another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? DesignColors.secondary.withValues(alpha: 0.12)
          : DesignColors.surface,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DesignRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            border: Border.all(
              color: selected
                  ? DesignColors.secondary
                  : DesignColors.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? DesignColors.secondary
                    : DesignColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: DesignTypography.labelSmall.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? DesignColors.secondary
                      : DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
