import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
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
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Vehicle Number
            TextFormField(
              controller: _numberController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Vehicle Number',
                hintText: 'e.g., MH 12 AB 1234',
                prefixIcon: Icon(Icons.numbers),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: Validators.vehicleNumber,
            ),

            const SizedBox(height: AppSpacing.md),

            // Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: _vehicleTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Brand
            TextFormField(
              controller: _brandController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brand (Optional)',
                hintText: 'e.g., Honda, Hero',
                prefixIcon: Icon(Icons.branding_watermark),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Model
            TextFormField(
              controller: _modelController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Model (Optional)',
                hintText: 'e.g., City, Splendor',
                prefixIcon: Icon(Icons.category),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Color
            TextFormField(
              controller: _colorController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Color (Optional)',
                hintText: 'e.g., White, Black',
                prefixIcon: Icon(Icons.palette),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle',
                    ),
            ),
          ],
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
        Navigator.pop(context, true);
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
