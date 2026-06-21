import 'dart:math' show min;

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
import '../widgets/guard_screen_section_header.dart';

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
  final _villaQuery = TextEditingController();

  static const _maxFlatRowsVisible = 8;
  static const _flatRowHeight = 68.0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    _villaQuery.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm check-in'),
        content: Text(
          'Check in ${_name.text.trim()} (${formState.visitorType.name})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check in'),
          ),
        ],
      ),
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

  List<ResidentPickerItem> _filterResidents(List<ResidentPickerItem> all) {
    final q = _villaQuery.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      final block = (r.block ?? '').toLowerCase();
      final num = r.villaNumber.toLowerCase();
      final name = r.name.toLowerCase();
      return block.contains(q) ||
          num.contains(q) ||
          '$block $num'.contains(q) ||
          name.contains(q);
    }).toList();
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    Widget? prefix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
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
        borderSide: const BorderSide(
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
            icon: const Icon(Icons.close_rounded),
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
                      _IntroBanner(isDark: isDark),
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(GuardTokens.padScreen),
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
                              Wrap(
                                spacing: GuardTokens.g2,
                                runSpacing: GuardTokens.g2,
                                children: GuardCheckInVisitorType.values.map((
                                  t,
                                ) {
                                  final selected = _type == t;
                                  return ChoiceChip(
                                    label: Text(
                                      _labelForType(t),
                                      style: TextStyle(
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        fontSize: GuardTokens.body,
                                      ),
                                    ),
                                    selected: selected,
                                    onSelected: _submitting
                                        ? null
                                        : (_) => formNotifier.setVisitorType(t),
                                    selectedColor: GuardTokens.guardAccent
                                        .withValues(alpha: 0.22),
                                    checkmarkColor: GuardTokens.guardAccentDeep,
                                    side: BorderSide(
                                      color: selected
                                          ? GuardTokens.guardAccent
                                          : (isDark
                                                ? GuardTokens.darkBorder
                                                : GuardTokens.borderSubtle),
                                      width: selected ? 1.5 : 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: GuardTokens.g1,
                                      vertical: 8,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(GuardTokens.padScreen),
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
                                enabled: !_submitting,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(15),
                                ],
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
                                  prefix: const Icon(
                                    Icons.phone_android_rounded,
                                    color: GuardTokens.guardAccent,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 10)
                                    ? 'Enter a valid mobile number'
                                    : null,
                              ),
                              const SizedBox(height: GuardTokens.g2),
                              TextFormField(
                                controller: _name,
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
                                  prefix: const Icon(
                                    Icons.badge_outlined,
                                    color: GuardTokens.guardAccent,
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
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(GuardTokens.padScreen),
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
                                      const Icon(
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
                                      const Icon(
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
                              TextField(
                                controller: _villaQuery,
                                enabled: !_submitting,
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecoration(
                                  context,
                                  label: 'Search residents',
                                  hint: 'Name, flat number, or block…',
                                  prefix: const Icon(
                                    Icons.search_rounded,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: GuardTokens.g2),
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
                                      const Icon(
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
                                  final filtered = _filterResidents(list);
                                  if (_villaQuery.text.trim().isNotEmpty &&
                                      filtered.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'No matches — try another search.',
                                        style: GuardTokens.bodyStyle(context),
                                      ),
                                    );
                                  }
                                  final display = filtered
                                      .take(_maxFlatRowsVisible)
                                      .toList();
                                  final listHeight = min(
                                    filtered.length * _flatRowHeight + 8,
                                    _maxFlatRowsVisible * _flatRowHeight + 8,
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            GuardTokens.radiusCard,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? GuardTokens.darkBorder
                                                : GuardTokens.borderSubtle,
                                          ),
                                          color: isDark
                                              ? GuardTokens.darkSurface
                                                    .withValues(alpha: 0.4)
                                              : GuardTokens.surfaceCard,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            GuardTokens.radiusCard,
                                          ),
                                          child: SizedBox(
                                            height: listHeight,
                                            child: ListView.separated(
                                              physics:
                                                  const ClampingScrollPhysics(),
                                              itemCount: display.length,
                                              separatorBuilder: (_, _) =>
                                                  Divider(
                                                    height: 1,
                                                    indent: GuardTokens.g2,
                                                    endIndent: GuardTokens.g2,
                                                    color: GuardTokens
                                                        .borderSubtle
                                                        .withValues(alpha: 0.7),
                                                  ),
                                              itemBuilder: (_, i) {
                                                final r = display[i];
                                                final selected =
                                                    _selectedUserIds
                                                        .contains(r.userId);
                                                return Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    onTap: _submitting
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              if (selected) {
                                                                _selectedUserIds
                                                                    .remove(
                                                                      r.userId,
                                                                    );
                                                              } else {
                                                                _selectedUserIds
                                                                    .add(
                                                                      r.userId,
                                                                    );
                                                              }
                                                            });
                                                          },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal:
                                                                GuardTokens.g2,
                                                            vertical: 10,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child: Checkbox(
                                                              value: selected,
                                                              activeColor:
                                                                  GuardTokens
                                                                      .success,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                              onChanged:
                                                                  _submitting
                                                                  ? null
                                                                  : (_) {
                                                                      formNotifier.toggleResident(r.userId);
                                                                    },
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width:
                                                                GuardTokens.g2,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  r.name,
                                                                  style:
                                                                      TextStyle(
                                                                    fontWeight:
                                                                        selected
                                                                            ? FontWeight
                                                                                .w700
                                                                            : FontWeight
                                                                                .w500,
                                                                    fontSize:
                                                                        GuardTokens
                                                                            .body,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  r.tag.isNotEmpty
                                                                      ? '${r.flatLabel} · ${r.tag}'
                                                                      : r.flatLabel,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurface
                                                                        .withValues(
                                                                          alpha:
                                                                              0.6,
                                                                        ),
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (selected)
                                                            const Icon(
                                                              Icons
                                                                  .done_rounded,
                                                              size: 20,
                                                              color: GuardTokens
                                                                  .success,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (filtered.length > display.length) ...[
                                        const SizedBox(height: GuardTokens.g2),
                                        Text(
                                          'Showing first $_maxFlatRowsVisible results. Narrow your search to see more.',
                                          style: GuardTokens.captionStyle(
                                            context,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
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
                                  prefix: const Icon(
                                    Icons.directions_car_outlined,
                                    color: GuardTokens.guardAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: GuardTokens.sectionGap),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(GuardTokens.padScreen),
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
                                      icon: const Icon(
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
                                      icon: const Icon(
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
                                      icon: const Icon(
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

  String _labelForType(GuardCheckInVisitorType t) => t.label;
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.how_to_reg_rounded,
            size: 18,
            color: isDark
                ? GuardTokens.guardAccent
                : GuardTokens.guardAccentDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Accurate contact + flat selection keeps residents informed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
            ),
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
          const Icon(Icons.schedule_rounded, color: GuardTokens.warning),
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
