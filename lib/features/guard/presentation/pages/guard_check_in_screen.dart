import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_haptics.dart';
import '../../data/guard_visitor_type.dart';
import '../../data/models/guard_models.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_check_in_notifier.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../../utils/shift_active_helper.dart';
import '../widgets/guard_flat_picker.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_section_card.dart';
import '../widgets/guard_action_sheet.dart';
import '../../voice/guard_plate_scanner.dart';
import '../../voice/guard_voice_input.dart';
import '../../voice/guard_voice_parser.dart';

/// Premium **Add visitor** — card sections, large inputs, searchable flats, optional vehicle & photo.
class GuardCheckInScreen extends ConsumerStatefulWidget {
  const GuardCheckInScreen({super.key});

  @override
  ConsumerState<GuardCheckInScreen> createState() => _GuardCheckInScreenState();
}

class _GuardCheckInScreenState extends ConsumerState<GuardCheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();

  // Returning visitor: looked up once the phone number is complete.
  Timer? _lookupDebounce;
  String? _lookedUpPhone;
  ReturningVisitor? _returning;
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
    // Open keyboard on the first contact field — phone is primary at the gate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _phone.removeListener(_onPhoneChanged);
    _phoneFocus.dispose();
    _nameFocus.dispose();
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final notifier = ref.read(checkInFormProvider.notifier);
    final ok = await notifier.pickPhoto(source);
    if (!ok && mounted) {
      final err = ref.read(checkInFormProvider).errorMessage;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)),
        );
      }
    }
  }

  // ── Returning visitor ────────────────────────────────────────────────

  void _onPhoneChanged() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _lookupDebounce?.cancel();
      if (_returning != null || _lookedUpPhone != null) {
        setState(() {
          _returning = null;
          _lookedUpPhone = null;
        });
      }
      return;
    }
    final key = digits.substring(digits.length - 10);
    if (key == _lookedUpPhone) return;
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 350), () => _lookup(key));
  }

  Future<void> _lookup(String phone) async {
    setState(() {
      _lookedUpPhone = phone;
      _lookingUp = true;
    });
    ReturningVisitor? found;
    try {
      found = await ref.read(guardRepositoryProvider).lookupVisitor(phone);
    } catch (_) {
      found = null; // Offline or unknown: the guard just types the details.
    }
    if (!mounted || _lookedUpPhone != phone) return;
    setState(() {
      _returning = found;
      _lookingUp = false;
    });
    if (found != null) _applyReturning(found, selectFlat: false);
  }

  /// Fills empty fields from the last visit; [selectFlat] also picks that flat.
  void _applyReturning(ReturningVisitor v, {required bool selectFlat}) {
    final notifier = ref.read(checkInFormProvider.notifier);
    // Only fill a fresh form: never overwrite what the guard already entered.
    final fresh = _name.text.trim().isEmpty;
    if (fresh && v.name.trim().isNotEmpty) _name.text = v.name.trim();
    if (_vehicle.text.trim().isEmpty && (v.vehicleNumber ?? '').isNotEmpty) {
      _vehicle.text = v.vehicleNumber!;
    }
    final type = GuardCheckInVisitorType.values
        .where((t) => t.apiValue == v.visitorType)
        .firstOrNull;
    if (fresh && type != null) notifier.setVisitorType(type);
    if (selectFlat) {
      final index = _flatIndex();
      notifier.selectFlats(
        v.lastFlats.map((f) => index.byVillaId[f.villaId] ?? const <String>[]),
      );
    }
  }

  // ── Voice entry ──────────────────────────────────────────────────────

  /// Flats in the picker: label ("A-25") → resident ids, and villaId → ids.
  ({Map<String, List<String>> byLabel, Map<String, List<String>> byVillaId}) _flatIndex() {
    final list = ref.read(guardResidentsPickerProvider).valueOrNull ?? const [];
    final byLabel = <String, List<String>>{};
    final byVillaId = <String, List<String>>{};
    for (final r in list) {
      if (r.villaId.isEmpty) continue;
      final b = r.block?.trim();
      final label = (b != null && b.isNotEmpty) ? '$b-${r.villaNumber}' : r.villaNumber;
      byLabel.putIfAbsent(label, () => []).add(r.userId);
      byVillaId.putIfAbsent(r.villaId, () => []).add(r.userId);
    }
    return (byLabel: byLabel, byVillaId: byVillaId);
  }

  Future<void> _speakEntry() async {
    final index = _flatIndex();
    final flatLabels = index.byLabel.keys.toList();
    final text = await showGuardVoiceSheet(
      context,
      title: 'Say the visitor details',
      example: '"Ramesh, 98765 43210, flat A 25, delivery"',
      checklist: (said) {
        final p = parseVisitorUtterance(said, knownFlatLabels: flatLabels);
        return {
          'Mobile': p.phone != null,
          'Name': p.name != null,
          'Flat': p.flatLabels.isNotEmpty,
          'Type': p.visitorType != null,
        };
      },
    );
    if (text == null || text.isEmpty || !mounted) return;
    final parsed = parseVisitorUtterance(text, knownFlatLabels: index.byLabel.keys.toList());
    if (parsed.isEmpty) {
      _toast("Couldn't pick out details. Try again or type them.", warning: true);
      return;
    }
    final notifier = ref.read(checkInFormProvider.notifier);
    final filled = <String>[];
    if (parsed.phone != null) {
      _phone.text = parsed.phone!;
      filled.add('mobile');
    }
    if (parsed.name != null) {
      _name.text = parsed.name!;
      filled.add('name');
    }
    if (parsed.visitorType != null) {
      notifier.setVisitorType(parsed.visitorType!);
      filled.add(parsed.visitorType!.label.toLowerCase());
    }
    if (parsed.vehicleNumber != null) {
      _vehicle.text = parsed.vehicleNumber!;
      filled.add('vehicle');
    }
    if (parsed.flatLabels.isNotEmpty) {
      notifier.selectFlats(parsed.flatLabels.map((l) => index.byLabel[l] ?? const <String>[]));
      filled.add('flat ${parsed.flatLabels.join(', ')}');
    }
    DesignHaptics.success();
    _toast('Filled ${filled.join(' · ')}. Check and confirm.');
  }

  void _toast(String msg, {bool warning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: warning ? GuardTokens.warning : null,
      content: Text(msg),
    ));
  }

  bool _hasActiveShift(List<GuardShiftRow> rows) =>
      ShiftActiveHelper.hasActiveShift(rows.map((r) => r.toRawMap()).toList());

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final formState = ref.read(checkInFormProvider);
    if (formState.selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one resident'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: GuardTokens.warning,
        ),
      );
      return;
    }
    // Confirmation before API call.
    final confirmed = await showGuardConfirmSheet(
      context,
      title: 'Confirm check-in',
      message:
          'Check in ${_name.text.trim()} (${formState.visitorType.label})?',
      confirmLabel: 'Check in',
      icon: Icons.how_to_reg_rounded,
    );
    if (confirmed != true || !mounted) return;
    final notifier = ref.read(checkInFormProvider.notifier);
    final err = await notifier.submit(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      vehicleNumber:
          _vehicle.text.trim().isEmpty ? null : _vehicle.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      DesignHaptics.success();
      final msg = ref.read(checkInFormProvider).resultMessage ?? 'Done';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)),
      );
    }
  }


  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark
          ? GuardTokens.darkSurface.withValues(alpha: 0.55)
          : GuardTokens.surfaceCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: BorderSide(
          color: isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        borderSide: BorderSide(
          color: GuardTokens.guardAccent,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(checkInFormProvider);
    final formNotifier = ref.read(checkInFormProvider.notifier);
    // Aliases matching previous local fields — minimizes UI churn.
    final _type = formState.visitorType; // ignore: unused_local_variable
    final _selectedUserIds = formState.selectedUserIds;
    final _photoBytes = formState.photoBytes;
    final _submitting = formState.submitting;

    final residentsAsync = ref.watch(guardResidentsPickerProvider);
    final shiftsAsync = ref.watch(guardMyShiftsProvider);
    final residentDirectoryAsync = ref.watch(guardResidentsDirectoryProvider(''));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedCount = _selectedUserIds.length;
    // True when *every* selected resident appears in the directory with a
    // non-null villaId. Falls back to true while the directory is loading or
    // errored — we don't want to flash a scary banner on cold start. The
    // previous implementation used `rows.any((r) => r.villaId != null && _selectedUserIds.isNotEmpty)`
    // which always returned true if any directory row was mapped, so the
    // warning never surfaced when a selected resident was unmapped.
    final selectedHasMappedResident = residentDirectoryAsync.maybeWhen(
      data: (rows) {
        if (_selectedUserIds.isEmpty) return true;
        final mappedSelectedIds = rows
            .where((r) => r.villaId != null && r.villaId!.isNotEmpty)
            .map((r) => r.userId)
            .toSet();
        return _selectedUserIds.every(mappedSelectedIds.contains);
      },
      orElse: () => true,
    );
    final hasActiveShift = shiftsAsync.maybeWhen(
      data: _hasActiveShift,
      orElse: () => true,
    );

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded),
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          ),
          title: Text('Add visitor', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen,
                    GuardTokens.g2,
                    GuardTokens.padScreen,
                    GuardTokens.sectionGap + 96,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _VoiceEntryCard(
                        enabled: !_submitting,
                        onTap: _speakEntry,
                      ),
                      shiftsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: GuardTokens.g2),
                          child: BannerSkeleton(height: 44),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (rows) => _hasActiveShift(rows)
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: GuardTokens.g2),
                                child: _NoActiveShiftBanner(
                                  onViewShift: () => context.push(GuardRoutes.shift),
                                ),
                              ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      GuardSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GuardScreenSectionHeader(
                              icon: Icons.category_rounded,
                              title: 'Visitor category',
                              subtitle:
                                  'Used for notifications and audit trail',
                            ),
                              const SizedBox(height: GuardTokens.g2),
                              Row(
                                children: [
                                  for (final t in GuardCheckInVisitorType.values) ...[
                                    if (t != GuardCheckInVisitorType.values.first)
                                      const SizedBox(width: 6),
                                    Expanded(
                                      child: _VisitorTypeTile(
                                        type: t,
                                        selected: _type == t,
                                        isDark: isDark,
                                        onTap: _submitting
                                            ? null
                                            : () => formNotifier.setVisitorType(t),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      GuardSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GuardScreenSectionHeader(
                              icon: Icons.contact_phone_rounded,
                              title: 'Contact',
                              subtitle:
                                  'Phone first — guards verify quickly outdoors',
                            ),
                              const SizedBox(height: GuardTokens.g2),
                              TextFormField(
                                controller: _phone,
                                focusNode: _phoneFocus,
                                autofocus: true,
                                enabled: !_submitting,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                onFieldSubmitted: (_) =>
                                    _nameFocus.requestFocus(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.35,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: _fieldDecoration(
                                  context,
                                  label: 'Mobile number',
                                  hint: '10+ digits',
                                  prefix: Icon(
                                    Icons.phone_android_rounded,
                                    color: GuardTokens.guardAccent,
                                  ),
                                  suffix: GuardMicButton(
                                    enabled: !_submitting,
                                    title: 'Say the mobile number',
                                    example: '"nine eight seven six five…"',
                                    currentText: () => _phone.text,
                                    onText: (t) {
                                      final d = digitsFromSpeech(t);
                                      if (d.isNotEmpty) {
                                        _phone.text = d.length > 10 ? d.substring(d.length - 10) : d;
                                      }
                                    },
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 10)
                                    ? 'Enter a valid mobile number'
                                    : null,
                              ),
                              if (_lookingUp || _returning != null) ...[
                                const SizedBox(height: GuardTokens.g2),
                                _ReturningVisitorCard(
                                  loading: _lookingUp,
                                  visitor: _returning,
                                  onSelectFlat: _returning == null ||
                                          _returning!.lastFlats.isEmpty
                                      ? null
                                      : () => _applyReturning(_returning!, selectFlat: true),
                                ),
                              ],
                              const SizedBox(height: GuardTokens.g2),
                              TextFormField(
                                controller: _name,
                                focusNode: _nameFocus,
                                enabled: !_submitting,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                textCapitalization: TextCapitalization.words,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                decoration: _fieldDecoration(
                                  context,
                                  label: 'Full name',
                                  prefix: Icon(
                                    Icons.badge_outlined,
                                    color: GuardTokens.guardAccent,
                                  ),
                                  suffix: GuardMicButton(
                                    enabled: !_submitting,
                                    title: "Say the visitor's name",
                                    currentText: () => _name.text,
                                    onText: (t) => _name.text = t
                                        .split(RegExp(r'\s+'))
                                        .where((w) => w.isNotEmpty)
                                        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
                                        .join(' '),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 2)
                                    ? 'Enter name'
                                    : null,
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      GuardSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GuardScreenSectionHeader(
                              icon: Icons.people_rounded,
                              title: 'Visiting resident',
                              subtitle:
                                  'Search by name or flat — tap to select',
                            ),
                              const SizedBox(height: GuardTokens.g2),
                              if (selectedCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: GuardTokens.g2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 20,
                                        color: GuardTokens.success,
                                      ),
                                      const SizedBox(width: GuardTokens.g1),
                                      Text(
                                        '$selectedCount selected',
                                        style: GuardTokens.bodyStyle(context)
                                            .copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: GuardTokens.success,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedCount > 0 &&
                                  !selectedHasMappedResident)
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: GuardTokens.g2,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: GuardTokens.warningMuted,
                                    borderRadius: BorderRadius.circular(
                                      GuardTokens.radiusCard,
                                    ),
                                    border: Border.all(
                                      color: GuardTokens.warning.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: GuardTokens.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No active resident appears mapped to selected flat(s). You can still submit, but approval may not reach anyone.',
                                          style: GuardTokens.captionStyle(
                                            context,
                                          ).copyWith(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              residentsAsync.when(
                                loading: () => const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: GuardTokens.g3,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (e, _) => Container(
                                  padding: const EdgeInsets.all(GuardTokens.g2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? GuardTokens.darkSurface
                                        : GuardTokens.warningMuted,
                                    borderRadius: BorderRadius.circular(
                                      GuardTokens.radiusCard,
                                    ),
                                    border: Border.all(
                                      color: GuardTokens.warning.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.wifi_off_rounded,
                                        color: GuardTokens.warning,
                                      ),
                                      const SizedBox(width: GuardTokens.g2),
                                      Expanded(
                                        child: Text(
                                          userFacingMessage(
                                            e,
                                            'Could not load residents',
                                          ),
                                          style: GuardTokens.bodyStyle(context)
                                              .copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            ref.invalidate(guardVillasProvider),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                                data: (list) {
                                  if (list.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'No residents found.',
                                        style: GuardTokens.bodyStyle(context),
                                      ),
                                    );
                                  }
                                  return GuardFlatPicker(
                                    residents: list,
                                    selectedUserIds: _selectedUserIds,
                                    onToggleFlat: (flat) =>
                                        formNotifier.toggleFlat(flat.userIds),
                                  );
                                },
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      GuardSectionCard(
                        padding: const EdgeInsets.fromLTRB(
                          GuardTokens.padScreen,
                          14,
                          GuardTokens.padScreen,
                          GuardTokens.padScreen,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GuardScreenSectionHeader(
                              icon: Icons.directions_car_rounded,
                              title: 'Vehicle',
                              subtitle:
                                  'Optional — registration for gate records',
                            ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _vehicle,
                                enabled: !_submitting,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _fieldDecoration(
                                  context,
                                  label: 'Vehicle number',
                                  hint: 'e.g. MH01 AB 1234',
                                  prefix: Icon(
                                    Icons.directions_car_outlined,
                                    color: GuardTokens.guardAccent,
                                  ),
                                  suffix: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GuardMicButton(
                                        enabled: !_submitting,
                                        title: 'Say the vehicle number',
                                        example: '"M H one two A B one two three four"',
                                        currentText: () => _vehicle.text,
                                        onText: (t) => _vehicle.text =
                                            vehicleFromText(t) ?? t.toUpperCase(),
                                      ),
                                      GuardPlateScanButton(
                                        enabled: !_submitting,
                                        onPlate: (p) => _vehicle.text = p,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      GuardSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GuardScreenSectionHeader(
                              icon: Icons.photo_camera_outlined,
                              title: 'Photo (optional)',
                              subtitle:
                                  'Helpful if there is ever a dispute at the gate',
                            ),
                              const SizedBox(height: GuardTokens.g2),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () =>
                                                _pickPhoto(ImageSource.camera),
                                      icon: Icon(
                                        Icons.photo_camera_rounded,
                                      ),
                                      label: const Text('Camera'),
                                    ),
                                  ),
                                  const SizedBox(width: GuardTokens.g2),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : () =>
                                                _pickPhoto(ImageSource.gallery),
                                      icon: Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Gallery'),
                                    ),
                                  ),
                                  if (_photoBytes != null)
                                    IconButton(
                                      onPressed: _submitting
                                          ? null
                                          : formNotifier.clearPhoto,
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: GuardTokens.dangerBrand,
                                      ),
                                      tooltip: 'Remove photo',
                                    ),
                                ],
                              ),
                              if (_photoBytes != null) ...[
                                const SizedBox(height: GuardTokens.g2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    GuardTokens.radiusCard,
                                  ),
                                  child: Image.memory(
                                    _photoBytes,
                                    height: 172,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),
                      ),
                      const SizedBox(height: GuardTokens.g3),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Material(
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                GuardTokens.padScreen,
                GuardTokens.g2,
                GuardTokens.padScreen,
                GuardTokens.g2,
              ),
              child: SizedBox(
                width: double.infinity,
                height: GuardTokens.btnPrimaryH + 4,
                child: FilledButton(
                  style: GuardTokens.primaryFilled(context),
                  onPressed: _submitting || !hasActiveShift ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.how_to_reg_rounded, size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Confirm check-in',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of five equal category tiles in a single row: icon over a one-word label.
class _VisitorTypeTile extends StatelessWidget {
  const _VisitorTypeTile({
    required this.type,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final GuardCheckInVisitorType type;
  final bool selected;
  final bool isDark;
  final VoidCallback? onTap;

  static IconData iconFor(GuardCheckInVisitorType t) => switch (t) {
        GuardCheckInVisitorType.delivery => Icons.local_shipping_rounded,
        GuardCheckInVisitorType.guest => Icons.person_rounded,
        GuardCheckInVisitorType.cab => Icons.local_taxi_rounded,
        GuardCheckInVisitorType.serviceProvider => Icons.handyman_rounded,
        GuardCheckInVisitorType.vendor => Icons.storefront_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? GuardTokens.guardAccentDeep
        : (isDark ? Colors.white70 : GuardTokens.textSecondary);
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: Material(
        color: selected
            ? GuardTokens.guardAccent.withValues(alpha: 0.16)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? GuardTokens.guardAccent
                : (isDark ? GuardTokens.darkBorder : GuardTokens.borderSubtle),
            width: selected ? 1.8 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconFor(type), size: 24, color: fg),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    type.shortLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Speak entry": one sentence fills mobile, name, flat and category.
class _VoiceEntryCard extends StatelessWidget {
  const _VoiceEntryCard({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
            gradient: LinearGradient(
              colors: [
                GuardTokens.guardAccentDeep,
                GuardTokens.guardAccentDeep.withValues(alpha: 0.86),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: GuardTokens.guardAccentDeep.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speak entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Say name, mobile and flat — fields fill themselves',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown under the mobile field when this number has visited before.
class _ReturningVisitorCard extends StatelessWidget {
  const _ReturningVisitorCard({
    required this.loading,
    required this.visitor,
    required this.onSelectFlat,
  });

  final bool loading;
  final ReturningVisitor? visitor;
  final VoidCallback? onSelectFlat;

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    if (loading || v == null) {
      return Row(
        children: [
          const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Checking earlier visits…', style: GuardTokens.captionStyle(context)),
        ],
      );
    }
    final last = v.lastVisitAt;
    final when = last == null
        ? null
        : '${last.day}/${last.month} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    final flats = v.lastFlats.map((f) => f.label).join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: GuardTokens.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        border: Border.all(color: GuardTokens.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: GuardTokens.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Returning visitor · ${v.visitCount} ${v.visitCount == 1 ? 'visit' : 'visits'}',
                  style: GuardTokens.bodyStyle(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: GuardTokens.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'Details filled',
                    if (flats.isNotEmpty) 'last to $flats',
                    if (when != null) when,
                  ].join(' · '),
                  style: GuardTokens.captionStyle(context),
                ),
              ],
            ),
          ),
          if (onSelectFlat != null)
            TextButton(
              onPressed: onSelectFlat,
              style: GuardTokens.textLink(context),
              child: Text('Same flat'),
            ),
        ],
      ),
    );
  }
}

class _NoActiveShiftBanner extends StatelessWidget {
  const _NoActiveShiftBanner({required this.onViewShift});

  final VoidCallback onViewShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GuardTokens.g2),
      decoration: BoxDecoration(
        color: GuardTokens.warningMuted,
        borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
        border: Border.all(color: GuardTokens.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: GuardTokens.warning),
          const SizedBox(width: GuardTokens.g2),
          Expanded(
            child: Text(
              'No active shift. Add visitor is disabled until your shift starts.',
              style: GuardTokens.bodyStyle(context).copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onViewShift,
            style: GuardTokens.textLink(context),
            child: const Text('View shift details'),
          ),
        ],
      ),
    );
  }
}
