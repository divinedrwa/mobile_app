import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../data/providers/emergency_contact_provider.dart';

class AddEmergencyContactScreen extends ConsumerStatefulWidget {
  const AddEmergencyContactScreen({super.key});

  @override
  ConsumerState<AddEmergencyContactScreen> createState() =>
      _AddEmergencyContactScreenState();
}

class _AddEmergencyContactScreenState
    extends ConsumerState<AddEmergencyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.error,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text(
          'Add Emergency Contact',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(DesignSpacing.lg, DesignSpacing.md, DesignSpacing.lg, DesignSpacing.xxxl),
          children: [
            const EnterpriseInfoBanner(
              icon: Icons.warning_amber_rounded,
              title: 'SOS notification recipient',
              message: 'This contact will be notified immediately when you trigger an SOS emergency alert.',
              tone: EnterpriseTone.danger,
            ),
            const SizedBox(height: DesignSpacing.lg),
            TextFormField(
              controller: _nameController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Full Name', prefixIcon: const Icon(Icons.person_outline_rounded)),
              validator: (v) => v?.isEmpty ?? true ? 'Please enter name' : null,
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _relationController,
              textInputAction: TextInputAction.next,
              decoration: DesignComponents.inputDecoration(label: 'Relation', hint: 'e.g., Brother, Friend', prefixIcon: const Icon(Icons.people_outline_rounded)),
              validator: (v) => v?.isEmpty ?? true ? 'Please enter relation' : null,
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _phoneController,
              textInputAction: TextInputAction.done,
              decoration: DesignComponents.inputDecoration(label: 'Phone Number', prefixIcon: const Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
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
                backgroundColor: DesignColors.error,
                padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md + 2),
                shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Add Contact', style: DesignTypography.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final error = await ref
        .read(emergencyContactProvider.notifier)
        .addContact(
          name: _nameController.text.trim(),
          relationship: _relationController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency contact added!'),
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
