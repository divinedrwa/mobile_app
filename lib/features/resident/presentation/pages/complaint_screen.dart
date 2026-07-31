import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/design_haptics.dart';
import '../../../../core/telemetry/business_analytics.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/flow_layout_widgets.dart';
import '../../../../core/constants/form_options.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/utils/xfile_image_provider.dart';
import '../../data/providers/complaint_provider.dart' show
    complaintSubmitProvider, myComplaintsProvider;

/// File a complaint — aligned with resident form design system.
class ComplaintScreen extends ConsumerStatefulWidget {
  const ComplaintScreen({super.key});

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String _selectedPriority = 'MEDIUM';
  bool _isSubmitting = false;
  XFile? _photo;

  final _imagePicker = ImagePicker();

  final categories = FormOptions.complaintCategories;

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (picked != null && mounted) {
      setState(() => _photo = picked);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: context.surface.defaultSurface,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'File complaint',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
            ),
            Text(
              'Report an issue in your society',
              style: TextStyle(fontSize: 12, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My complaints',
            onPressed: () => context.push('/resident/my-complaints'),
            icon: Icon(Icons.format_list_bulleted_rounded, color: context.text.secondary),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DesignSpacing.screenPaddingH,
            DesignSpacing.md,
            DesignSpacing.screenPaddingH,
            DesignSpacing.xxxl,
          ),
          children: [
            const DivineFlowSectionLabel('Category'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: DesignComponents.inputDecoration(
                label: 'What is the issue about?',
                hint: 'Select one',
                prefixIcon: Icon(
                  Icons.category_outlined,
                  color: DesignColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Summary'),
            TextFormField(
              controller: _titleController,
              autofocus: false,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: DesignComponents.inputDecoration(
                label: 'Title',
                hint: 'Short summary of the issue',
                prefixIcon: Icon(
                  Icons.title_rounded,
                  color: DesignColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                if (value.trim().length < 5) {
                  return 'Title must be at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignSpacing.md),
            TextFormField(
              controller: _descriptionController,
              textInputAction: TextInputAction.done,
              decoration: DesignComponents.inputDecoration(
                label: 'Description',
                hint: 'What happened, where, and when?',
                prefixIcon: Icon(
                  Icons.subject_rounded,
                  color: DesignColors.textSecondary.withValues(alpha: 0.9),
                ),
              ).copyWith(alignLabelWithHint: true),
              minLines: 4,
              maxLines: 8,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                if (value.trim().length < 10) {
                  return 'Description must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Photo (optional)'),
            Row(
              children: [
                if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(
                      image: xfileImageProvider(_photo!),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: DesignColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DesignColors.borderLight),
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: DesignColors.textTertiary,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_photo == null ? 'Add photo' : 'Change photo'),
                  ),
                ),
                if (_photo != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: () => setState(() => _photo = null),
                    icon: Icon(Icons.close_rounded, color: DesignColors.error),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DesignSpacing.lg),
            const DivineFlowSectionLabel('Priority'),
            DivineChoiceCard(
              selected: _selectedPriority == 'HIGH',
              icon: Icons.priority_high_rounded,
              title: 'High',
              subtitle: 'Urgent — needs immediate attention',
              onTap: () => setState(() => _selectedPriority = 'HIGH'),
            ),
            const SizedBox(height: DesignSpacing.sm + 2),
            DivineChoiceCard(
              selected: _selectedPriority == 'MEDIUM',
              icon: Icons.remove_rounded,
              title: 'Medium',
              subtitle: 'Normal — can wait a few days',
              onTap: () => setState(() => _selectedPriority = 'MEDIUM'),
            ),
            const SizedBox(height: DesignSpacing.sm + 2),
            DivineChoiceCard(
              selected: _selectedPriority == 'LOW',
              icon: Icons.low_priority_rounded,
              title: 'Low',
              subtitle: 'Non-urgent — schedule when convenient',
              onTap: () => setState(() => _selectedPriority = 'LOW'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          border: Border(
            top: BorderSide(
              color: DesignColors.borderLight.withValues(alpha: 0.9),
            ),
          ),
          boxShadow: DesignElevation.sm,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(
            left: DesignSpacing.screenPaddingH,
            right: DesignSpacing.screenPaddingH,
            bottom: DesignSpacing.sm,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DesignSpacing.md),
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitComplaint,
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: DesignColors.tertiary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: DesignSpacing.md + 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: DesignRadius.borderMD,
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      'Submit complaint',
                      style: DesignTypography.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final error = await ref.read(complaintSubmitProvider.notifier).submit(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory!,
          priority: _selectedPriority,
          photo: _photo,
        );

    if (mounted) {
      if (error == null) {
        DesignHaptics.success();
        unawaited(BusinessAnalytics.track(BusinessAnalytics.complaintSubmit));
        ref.invalidate(myComplaintsProvider);
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Complaint submitted successfully'),
            backgroundColor: DesignColors.success,
          ),
        );
        context.pop();
      } else {
        final message = error;
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(message),
            backgroundColor: DesignColors.error,
          ),
        );
      }
    }
  }
}
