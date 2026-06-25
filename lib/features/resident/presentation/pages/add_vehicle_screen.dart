import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/flow_layout_widgets.dart';
import '../../../../core/constants/form_options.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/providers/vehicle_provider.dart';

/// Add/Edit Vehicle Screen
class AddVehicleScreen extends ConsumerStatefulWidget {
  final VehicleModel? vehicle;

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();

  String _selectedType = 'Car';
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = FormOptions.vehicleTypes;

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _numberController.text = widget.vehicle!.vehicleNumber;
      _selectedType = widget.vehicle!.type;
      _brandController.text = widget.vehicle!.brand ?? '';
      _modelController.text = widget.vehicle!.model ?? '';
      _colorController.text = widget.vehicle!.color ?? '';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: DesignColors.textPrimary),
        ),
        title: Text(
          widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: DesignColors.textPrimary),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DesignSpacing.lg, DesignSpacing.md, DesignSpacing.lg, DesignSpacing.xxxl),
          children: [
            const DivineFlowSectionLabel('Vehicle details'),
            TextFormField(
              controller: _numberController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(
                label: 'Vehicle Number',
                hint: 'e.g., MH 12 AB 1234',
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: Validators.vehicleNumber,
            ),
            const SizedBox(height: DesignSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: DesignComponents.inputDecoration(
                label: 'Vehicle Type',
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
              items: _vehicleTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Optional details'),
            TextFormField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Brand', hint: 'e.g., Honda, Hero'),
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _modelController,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Model', hint: 'e.g., City, Splendor'),
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _colorController,
              textInputAction: TextInputAction.done,
              decoration: DesignComponents.inputDecoration(label: 'Color', hint: 'e.g., White, Black'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          border: Border(top: BorderSide(color: DesignColors.borderLight.withValues(alpha: 0.9))),
          boxShadow: DesignElevation.sm,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(DesignSpacing.lg, 0, DesignSpacing.lg, DesignSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle',
                      style: DesignTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final notifier = ref.read(vehicleProvider.notifier);
    if (widget.vehicle != null &&
        (widget.vehicle!.id == null || widget.vehicle!.id!.isEmpty)) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update this vehicle'),
          backgroundColor: DesignColors.error,
        ),
      );
      return;
    }
    final error = widget.vehicle == null
        ? await notifier.addVehicle(
            vehicleNumber: _numberController.text.trim(),
            type: _selectedType,
            brand: _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty
                ? null
                : _modelController.text.trim(),
            color: _colorController.text.trim().isEmpty
                ? null
                : _colorController.text.trim(),
          )
        : await notifier.updateVehicle(
            id: widget.vehicle!.id!,
            brand: _brandController.text.trim().isEmpty
                ? null
                : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty
                ? null
                : _modelController.text.trim(),
            color: _colorController.text.trim().isEmpty
                ? null
                : _colorController.text.trim(),
          );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehicle == null
                  ? 'Vehicle added successfully!'
                  : 'Vehicle updated successfully!',
            ),
            backgroundColor: DesignColors.success,
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    }
  }
}
