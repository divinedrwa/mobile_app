import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/widgets/flow_layout_widgets.dart';
import '../../../../core/constants/form_options.dart';
import '../../data/models/family_member_model.dart';
import '../../data/providers/family_member_provider.dart';

/// Add/Edit Family Member Screen
class AddFamilyMemberScreen extends ConsumerStatefulWidget {
  final FamilyMemberModel? member;

  const AddFamilyMemberScreen({super.key, this.member});

  @override
  ConsumerState<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends ConsumerState<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedRelationship = 'Spouse';
  DateTime? _dateOfBirth;
  bool _isSubmitting = false;

  final List<String> _relationships = FormOptions.familyRelationships;

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      _nameController.text = widget.member!.name;
      _selectedRelationship = widget.member!.relationship;
      _phoneController.text = widget.member!.phone ?? '';
      _emailController.text = widget.member!.email ?? '';
      _dateOfBirth = widget.member!.dateOfBirth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
          widget.member == null ? 'Add Family Member' : 'Edit Family Member',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: context.text.primary),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DesignSpacing.lg, DesignSpacing.md, DesignSpacing.lg, DesignSpacing.xxxl),
          children: [
            const DivineFlowSectionLabel('Member details'),
            TextFormField(
              controller: _nameController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Full Name', hint: 'Enter full name', prefixIcon: const Icon(Icons.person_outline_rounded)),
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: DesignSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedRelationship,
              decoration: DesignComponents.inputDecoration(label: 'Relationship', prefixIcon: const Icon(Icons.family_restroom_outlined)),
              items: _relationships.map((rel) => DropdownMenuItem(value: rel, child: Text(rel))).toList(),
              onChanged: (value) => setState(() => _selectedRelationship = value!),
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Contact info (optional)'),
            TextFormField(
              controller: _phoneController,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Phone', hint: 'Enter phone number', prefixIcon: const Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              validator: Validators.phoneOptional,
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _emailController,
              textInputAction: TextInputAction.done,
              decoration: DesignComponents.inputDecoration(label: 'Email', hint: 'Enter email address', prefixIcon: const Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Date of birth (optional)'),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(2000),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _dateOfBirth = date);
              },
              borderRadius: DesignRadius.borderMD,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: DesignColors.surfaceSoft,
                  borderRadius: DesignRadius.borderMD,
                  border: Border.all(color: DesignColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: DesignColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dateOfBirth != null ? DateFormat('dd MMM yyyy').format(_dateOfBirth!) : 'Select date of birth',
                        style: TextStyle(
                          fontSize: 14,
                          color: _dateOfBirth != null ? DesignColors.textPrimary : DesignColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today_outlined, color: DesignColors.textTertiary, size: 18),
                  ],
                ),
              ),
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
                  : Text(widget.member == null ? 'Add Member' : 'Update Member',
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

    final notifier = ref.read(familyMemberProvider.notifier);
    if (widget.member != null &&
        (widget.member!.id == null || widget.member!.id!.isEmpty)) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update this family member'),
          backgroundColor: DesignColors.error,
        ),
      );
      return;
    }
    final error = widget.member == null
        ? await notifier.addFamilyMember(
            name: _nameController.text.trim(),
            relationship: _selectedRelationship,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            dateOfBirth: _dateOfBirth,
          )
        : await notifier.updateFamilyMember(
            id: widget.member!.id!,
            name: _nameController.text.trim(),
            relationship: _selectedRelationship,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            dateOfBirth: _dateOfBirth,
          );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.member == null
                  ? 'Family member added successfully!'
                  : 'Family member updated successfully!',
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
