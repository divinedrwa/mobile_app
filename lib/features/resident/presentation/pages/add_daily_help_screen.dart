import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/constants/form_options.dart';
import '../../data/models/daily_help_model.dart';
import '../../data/providers/daily_help_provider.dart';
import 'dart:io';

class AddDailyHelpScreen extends ConsumerStatefulWidget {
  final DailyHelpModel? helper;
  const AddDailyHelpScreen({super.key, this.helper});

  @override
  ConsumerState<AddDailyHelpScreen> createState() => _AddDailyHelpScreenState();
}

class _AddDailyHelpScreenState extends ConsumerState<AddDailyHelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _timingsController = TextEditingController();
  String _selectedType = 'Maid';
  XFile? _selectedImage;
  bool _isSubmitting = false;

  final List<String> _helpTypes = FormOptions.dailyHelpTypes;

  @override
  void initState() {
    super.initState();
    if (widget.helper != null) {
      _nameController.text = widget.helper!.name;
      _selectedType = widget.helper!.type;
      _phoneController.text = widget.helper!.phone;
      _timingsController.text = widget.helper!.timings ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _timingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.helper == null ? 'Add Vendor' : 'Edit Vendor',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: DesignColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path))
                        : null,
                    child: _selectedImage == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: DesignColors.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: DesignColors.primary,
                      child: IconButton(
                        tooltip: 'Change photo',
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Please enter name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.work),
              ),
              items: _helpTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _timingsController,
              decoration: const InputDecoration(
                labelText: 'Timings (Optional)',
                hintText: 'e.g., 8:00 AM - 10:00 AM',
                prefixIcon: Icon(Icons.access_time),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
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
                  : Text(widget.helper == null ? 'Add Vendor' : 'Update Vendor'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _selectedImage = image);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo selected! Will upload on save.')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final success = await ref
        .read(dailyHelpProvider.notifier)
        .addDailyHelp(
          name: _nameController.text.trim(),
          type: _selectedType,
          phone: _phoneController.text.trim(),
          address: _timingsController.text.trim().isEmpty
              ? null
              : _timingsController.text.trim(),
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.helper == null ? 'Vendor added!' : 'Vendor updated!',
            ),
            backgroundColor: DesignColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save vendor'),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    }
  }
}
