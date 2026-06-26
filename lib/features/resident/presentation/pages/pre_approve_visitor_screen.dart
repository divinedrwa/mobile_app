import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../../../core/widgets/flow_layout_widgets.dart';
import '../../data/models/pre_approved_visitor_model.dart';
import '../providers/visitor_provider.dart';
import 'visitor_success_screen.dart';

/// Pre-approve visitor — multi-step flow with shared design system.
class PreApproveVisitorScreen extends ConsumerStatefulWidget {
  const PreApproveVisitorScreen({super.key});

  @override
  ConsumerState<PreApproveVisitorScreen> createState() =>
      _PreApproveVisitorScreenState();
}

class _PreApproveVisitorScreenState
    extends ConsumerState<PreApproveVisitorScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  late final PageController _pageController;

  VisitorType _selectedType = VisitorType.guest;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isFrequent = false;
  bool _isSubmitting = false;

  static const int _stepCount = 4;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _animateToStep(int step) async {
    if (!mounted) return;
    setState(() => _currentStep = step);
    await _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onPrimaryPressed() async {
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep < _stepCount - 1) {
      final next = _currentStep + 1;
      await _animateToStep(next);
    } else {
      await _submitForm();
    }
  }

  Future<void> _onLeadingPressed() async {
    if (_isSubmitting) return;
    if (_currentStep > 0) {
      await _animateToStep(_currentStep - 1);
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  IconData _typeIcon(VisitorType type) {
    switch (type) {
      case VisitorType.guest:
        return Icons.groups_2_outlined;
      case VisitorType.delivery:
        return Icons.local_shipping_outlined;
      case VisitorType.service:
        return Icons.home_repair_service_outlined;
      case VisitorType.vendor:
        return Icons.storefront_outlined;
    }
  }

  (String title, String? subtitle) _headerForStep(int step) {
    switch (step) {
      case 0:
        return (
          'Who is visiting?',
          'Pick a category so security can process the visit faster.',
        );
      case 1:
        return (
          'Visitor details',
          'We’ll share this with the gate — keep phone number accurate.',
        );
      case 2:
        return (
          'Schedule & preferences',
          'When should access apply, and any notes for security.',
        );
      case 3:
      default:
        return (
          'Review & submit',
          'Double-check everything before sending to your gate.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _headerForStep(_currentStep);
    final primaryLabel =
        _currentStep < _stepCount - 1 ? 'Continue' : 'Submit request';
    final leadingLabel = _currentStep > 0 ? 'Back' : 'Cancel';

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
              'Add visitor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.text.primary),
            ),
            Text(
              'Create a pre-approved pass',
              style: TextStyle(fontSize: 12, color: context.text.secondary, height: 1.2),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DivineFlowStepHeader(
              currentStep: _currentStep,
              stepCount: _stepCount,
              title: header.$1,
              subtitle: header.$2,
            ),
            Expanded(
              child: PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pageController,
                children: [
                  _buildTypePage(),
                  _buildDetailsPage(),
                  _buildSchedulePage(),
                  _buildReviewPage(),
                ],
              ),
            ),
            DivineFlowBottomBar(
              primaryLabel: primaryLabel,
              onPrimary: _isSubmitting ? null : _onPrimaryPressed,
              primaryLoading: _isSubmitting,
              showLeadingAction: true,
              leadingLabel: leadingLabel,
              onLeading: _onLeadingPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignSpacing.screenPaddingH,
        0,
        DesignSpacing.screenPaddingH,
        DesignSpacing.xl,
      ),
      children: [
        const DivineFlowSectionLabel('Visitor category'),
        ...VisitorType.values.map((type) {
          return Padding(
            padding: const EdgeInsets.only(bottom: DesignSpacing.md),
            child: DivineChoiceCard(
              selected: _selectedType == type,
              icon: _typeIcon(type),
              title: _getVisitorTypeLabel(type),
              subtitle: _getVisitorTypeDescription(type),
              onTap: () => setState(() => _selectedType = type),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignSpacing.screenPaddingH,
        0,
        DesignSpacing.screenPaddingH,
        DesignSpacing.xl,
      ),
      children: [
        const DivineFlowSectionLabel('Contact'),
        TextFormField(
          controller: _nameController,
          autofocus: false,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: DesignComponents.inputDecoration(
            label: 'Full name',
            hint: 'As it should appear at the gate',
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: DesignColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          validator: (value) {
            final t = value?.trim() ?? '';
            if (t.isEmpty) return 'Please enter the visitor’s name';
            if (t.length < 2) return 'Name must be at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: DesignSpacing.md),
        TextFormField(
          controller: _phoneController,
          textInputAction: TextInputAction.next,
          decoration: DesignComponents.inputDecoration(
            label: 'Mobile number',
            hint: '10-digit number',
            prefixIcon: Icon(
              Icons.phone_android_rounded,
              color: DesignColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            if (!RegExp(r'^\d{10}$').hasMatch(value)) {
              return 'Enter exactly 10 digits';
            }
            return null;
          },
        ),
        const SizedBox(height: DesignSpacing.lg),
        const DivineFlowSectionLabel('Visit'),
        TextFormField(
          controller: _purposeController,
          textInputAction: TextInputAction.done,
          decoration: DesignComponents.inputDecoration(
            label: 'Purpose',
            hint: 'e.g. Dinner, parcel pickup, AC service',
            prefixIcon: Icon(
              Icons.subject_rounded,
              color: DesignColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          minLines: 2,
          maxLines: 4,
          validator: (value) {
            final t = value?.trim() ?? '';
            if (t.isEmpty) return 'Please describe the purpose of visit';
            if (t.length < 2) return 'Add a bit more detail (at least 2 characters)';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSchedulePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignSpacing.screenPaddingH,
        0,
        DesignSpacing.screenPaddingH,
        DesignSpacing.xl,
      ),
      children: [
        DivinePickerRow(
          icon: Icons.calendar_today_rounded,
          label: 'Visit date',
          value: DateFormat('EEE, d MMM yyyy').format(_selectedDate),
          helper: 'Pass validity is based on this date',
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (date != null) setState(() => _selectedDate = date);
          },
        ),
        const SizedBox(height: DesignSpacing.md),
        DivinePickerRow(
          icon: Icons.schedule_rounded,
          label: 'Expected time (optional)',
          value: _selectedTime.format(context),
          helper: 'Helps guards anticipate arrival',
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _selectedTime,
            );
            if (time != null) setState(() => _selectedTime = time);
          },
        ),
        const SizedBox(height: DesignSpacing.lg),
        Material(
          color: DesignColors.surface,
          borderRadius: DesignRadius.borderLG,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DesignSpacing.md,
              vertical: DesignSpacing.xs,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: DesignRadius.borderLG,
              side: BorderSide(color: DesignColors.borderLight),
            ),
            title: Text(
              'Frequent visitor',
              style: DesignTypography.label.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Enable for household help or regular vendors',
              style: DesignTypography.caption,
            ),
            value: _isFrequent,
            activeThumbColor: DesignColors.primary,
            onChanged: (v) => setState(() => _isFrequent = v),
          ),
        ),
        const SizedBox(height: DesignSpacing.lg),
        const DivineFlowSectionLabel('Notes for security (optional)'),
        TextFormField(
          controller: _notesController,
          textInputAction: TextInputAction.done,
          decoration: DesignComponents.inputDecoration(
            label: 'Additional notes',
            hint: 'Vehicle number, escort name, special instructions…',
            prefixIcon: Icon(
              Icons.notes_rounded,
              color: DesignColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildReviewPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignSpacing.screenPaddingH,
        0,
        DesignSpacing.screenPaddingH,
        DesignSpacing.xl,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(DesignSpacing.lg),
          decoration: DesignComponents.cardDecoration(
            boxShadow: DesignElevation.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_rounded, color: DesignColors.primary, size: 22),
                  const SizedBox(width: DesignSpacing.sm),
                  Text(
                    'Summary',
                    style: DesignTypography.headingM.copyWith(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: DesignSpacing.md),
              DivineSummaryRow(
                label: 'Type',
                value: _getVisitorTypeLabel(_selectedType),
              ),
              DivineSummaryRow(label: 'Name', value: _nameController.text.trim()),
              DivineSummaryRow(label: 'Phone', value: _phoneController.text.trim()),
              if (_purposeController.text.trim().isNotEmpty)
                DivineSummaryRow(
                  label: 'Purpose',
                  value: _purposeController.text.trim(),
                ),
              DivineSummaryRow(
                label: 'Date',
                value: DateFormat('EEE, d MMM yyyy').format(_selectedDate),
              ),
              DivineSummaryRow(
                label: 'Time',
                value: _selectedTime.format(context),
              ),
              DivineSummaryRow(
                label: 'Frequent',
                value: _isFrequent ? 'Yes' : 'No',
              ),
              if (_notesController.text.trim().isNotEmpty)
                DivineSummaryRow(
                  label: 'Notes',
                  value: _notesController.text.trim(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final visitor = PreApprovedVisitorModel(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        type: _selectedType,
        purpose: _purposeController.text.trim().isNotEmpty
            ? _purposeController.text.trim()
            : null,
        visitDate: _selectedDate,
        visitTime: _selectedTime.format(context),
        visitTimeHour: _selectedTime.hour,
        visitTimeMinute: _selectedTime.minute,
        isFrequent: _isFrequent,
        notes: _notesController.text.isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      final result = await ref.read(visitorRepositoryProvider).preApproveVisitor(visitor);

      if (mounted) {
        ref.invalidate(preApprovedVisitorsProvider);
        unawaited(
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VisitorSuccessScreen(visitor: result),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingMessage(e, 'Could not pre-approve visitor'),
            ),
            backgroundColor: DesignColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _getVisitorTypeLabel(VisitorType type) => type.label;

  String _getVisitorTypeDescription(VisitorType type) => type.description;
}
