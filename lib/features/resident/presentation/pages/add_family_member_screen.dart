import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
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

  final List<String> _relationships = [
    'Spouse',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Other',
  ];

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
      appBar: AppBar(
        title: Text(
          widget.member == null ? 'Add Family Member' : 'Edit Family Member',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Relationship Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedRelationship,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.family_restroom),
              ),
              items: _relationships.map((rel) {
                return DropdownMenuItem(value: rel, child: Text(rel));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRelationship = value!;
                });
              },
            ),

            const SizedBox(height: AppSpacing.md),

            // Phone
            TextFormField(
              controller: _phoneController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: AppSpacing.md),

            // Email
            TextFormField(
              controller: _emailController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Email (Optional)',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: AppSpacing.md),

            // Date of Birth
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of Birth (Optional)'),
              subtitle: Text(
                _dateOfBirth != null
                    ? DateFormat('dd MMM yyyy').format(_dateOfBirth!)
                    : 'Not set',
              ),
              leading: const Icon(Icons.cake),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(2000),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _dateOfBirth = date;
                  });
                }
              },
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
                      widget.member == null ? 'Add Member' : 'Update Member',
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

    final notifier = ref.read(familyMemberProvider.notifier);
    if (widget.member != null &&
        (widget.member!.id == null || widget.member!.id!.isEmpty)) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update this family member'),
          backgroundColor: DesignColors.error,
        ),
      );
      return;
    }
    final success = widget.member == null
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
      if (success) {
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
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save family member'),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    }
  }
}
