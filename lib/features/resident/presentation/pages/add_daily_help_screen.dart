import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/widgets/flow_layout_widgets.dart';
import '../../../../core/constants/form_options.dart';
import '../../data/models/daily_help_model.dart';
import '../../data/providers/daily_help_provider.dart';
import '../../../../core/utils/xfile_image_provider.dart';

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
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Text(
          widget.helper == null ? 'Add Staff' : 'Edit Staff',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DesignSpacing.lg, DesignSpacing.md, DesignSpacing.lg, DesignSpacing.xxxl),
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: DesignColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _selectedImage != null
                        ? xfileImageProvider(_selectedImage!)
                        : null,
                    child: _selectedImage == null
                        ? Icon(
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
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Staff details'),
            TextFormField(
              controller: _nameController,
              decoration: DesignComponents.inputDecoration(label: 'Name', prefixIcon: const Icon(Icons.person_outline_rounded)),
              validator: (v) => v?.isEmpty ?? true ? 'Please enter name' : null,
            ),
            const SizedBox(height: DesignSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: DesignComponents.inputDecoration(label: 'Type', prefixIcon: const Icon(Icons.work_outline_rounded)),
              items: _helpTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _phoneController,
              decoration: DesignComponents.inputDecoration(label: 'Phone', prefixIcon: const Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _timingsController,
              decoration: DesignComponents.inputDecoration(label: 'Timings (Optional)', hint: 'e.g., 8:00 AM - 10:00 AM', prefixIcon: const Icon(Icons.access_time_outlined)),
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
                  : Text(widget.helper == null ? 'Add Staff' : 'Update Staff',
                      style: DesignTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (image != null) {
      if (!mounted) return;
      setState(() => _selectedImage = image);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo selected! Will upload on save.')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final error = await ref
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
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.helper == null ? 'Vendor added!' : 'Vendor updated!',
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
