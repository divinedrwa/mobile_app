import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_command_providers.dart';
import '../providers/guard_providers.dart';
import '../router/guard_routes.dart';
import '../../utils/shift_active_helper.dart';
import '../widgets/guard_screen_section_header.dart';

/// Confirm gate check-in for a resident pre-approval — same visual language as
/// [GuardCheckInScreen], prefilled and editable for verification at the gate.
class GuardPreApprovedArrivalScreen extends ConsumerStatefulWidget {
  const GuardPreApprovedArrivalScreen({super.key, required this.entry});

  final GuardPreApprovedEntry entry;

  @override
  ConsumerState<GuardPreApprovedArrivalScreen> createState() =>
      _GuardPreApprovedArrivalScreenState();
}

class _GuardPreApprovedArrivalScreenState
    extends ConsumerState<GuardPreApprovedArrivalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _purpose;

  bool _submitting = false;

  static bool _hasActiveShift(List<GuardShiftRow> rows) =>
      ShiftActiveHelper.hasActiveShift(rows.map((r) => r.toRawMap()).toList());

  String _visitorTypeLabel(String? api) {
    switch ((api ?? '').trim().toUpperCase()) {
      case 'DELIVERY':
        return 'Delivery';
      case 'SERVICE_PROVIDER':
        return 'Service / repair';
      case 'VENDOR':
        return 'Vendor';
      case 'GUEST':
        return 'Guest';
      default:
        return api?.trim().isNotEmpty == true ? api!.trim() : 'Guest';
    }
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
  void initState() {
    super.initState();
    final e = widget.entry;
    _name = TextEditingController(text: e.name);
    _phone = TextEditingController(text: e.phone);
    _purpose = TextEditingController(text: (e.purpose ?? '').trim());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _confirmCheckIn() async {
    FocusScope.of(context).unfocus();
    final shifts = await ref.read(guardMyShiftsProvider.future);
    if (!_hasActiveShift(shifts)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: GuardTokens.warning,
          content: Text(
            'No active shift found. Ask admin to assign your shift first.',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm entry'),
        content: Text('Admit ${widget.entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Admit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final map = await ref
          .read(guardRepositoryProvider)
          .admitPreApprovedEntry(widget.entry.id);
      final admitted = map['admitted'] == true;
      if (!mounted) return;
      if (admitted) {
        ref.invalidate(guardPreApprovedEntriesProvider);
        ref.invalidate(guardDashboardProvider);
        ref.invalidate(guardTodayVisitorsProvider);
        ref.invalidate(guardPendingVisitorsProvider);
        ref.invalidate(guardActiveVisitorsTabProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              map['message']?.toString() ??
                  '${widget.entry.name} checked in',
            ),
          ),
        );
        context.pop();
      } else {
        final msg = map['message']?.toString() ?? 'Could not check in visitor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(msg),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              guardCommandErrorMessage(e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shiftsAsync = ref.watch(guardMyShiftsProvider);
    final until = widget.entry.validUntil;
    final dateFmt = DateFormat('MMM d, y · h:mm a');
    final hasActiveShift = shiftsAsync.maybeWhen(
      data: _hasActiveShift,
      orElse: () => false,
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
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Expected visitor',
            style: GuardTokens.headingStyle(context),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          GuardTokens.padScreen,
                          GuardTokens.g2,
                          GuardTokens.padScreen,
                          GuardTokens.sectionGap,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            shiftsAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (rows) => _hasActiveShift(rows)
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: GuardTokens.g2,
                                      ),
                                      child: Material(
                                        color: GuardTokens.warning
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          GuardTokens.radiusCard,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.schedule_rounded,
                                                color: GuardTokens.warning,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'No active shift — you can review details, but check-in needs an active shift.',
                                                  style:
                                                      GuardTokens.captionStyle(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _submitting
                                                    ? null
                                                    : () => context.push(
                                                          GuardRoutes.shift,
                                                        ),
                                                child: const Text('Shifts'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            Material(
                              color: GuardTokens.guardAccent.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(
                                GuardTokens.radiusCard,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.verified_outlined,
                                      color: GuardTokens.guardAccentDeep,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Resident pre-approved',
                                            style: GuardTokens.bodyStyle(
                                              context,
                                            ).copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'The saved record on file is used at check-in. '
                                            'You can edit below to match who you see at the gate.',
                                            style: GuardTokens.captionStyle(
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: GuardTokens.sectionGap),
                            Row(
                              children: [
                                const _StatusPill(
                                  label: 'Pending arrival',
                                  color: GuardTokens.warning,
                                ),
                                const Spacer(),
                                Text(
                                  _visitorTypeLabel(widget.entry.visitorType),
                                  style: GuardTokens.captionStyle(context)
                                      .copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: GuardTokens.g2),
                            if (widget.entry.approvedByName != null &&
                                widget.entry.approvedByName!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: GuardTokens.g1,
                                ),
                                child: Text(
                                  'By ${widget.entry.approvedByName}',
                                  style: GuardTokens.captionStyle(context),
                                ),
                              ),
                            if (until != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: GuardTokens.g2,
                                ),
                                child: Text(
                                  'Valid until ${dateFmt.format(until.toLocal())}',
                                  style: GuardTokens.captionStyle(context)
                                      .copyWith(
                                    color: GuardTokens.textSecondary,
                                  ),
                                ),
                              ),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  GuardTokens.padScreen,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const GuardScreenSectionHeader(
                                      icon: Icons.contact_phone_rounded,
                                      title: 'Contact',
                                      subtitle:
                                          'Confirm against ID or resident message',
                                    ),
                                    const SizedBox(height: GuardTokens.g2),
                                    TextFormField(
                                      controller: _phone,
                                      enabled: !_submitting,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter
                                            .digitsOnly,
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
                                      textCapitalization:
                                          TextCapitalization.words,
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
                                padding: const EdgeInsets.all(
                                  GuardTokens.padScreen,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const GuardScreenSectionHeader(
                                      icon: Icons.apartment_rounded,
                                      title: 'Visiting flat',
                                      subtitle:
                                          "From the resident's pre-approval",
                                    ),
                                    const SizedBox(height: GuardTokens.g2),
                                    Text(
                                      'Flat',
                                      style: GuardTokens.captionStyle(context)
                                          .copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: GuardTokens.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? GuardTokens.darkSurface
                                                .withValues(alpha: 0.35)
                                            : GuardTokens.surfaceCard,
                                        borderRadius: BorderRadius.circular(
                                          GuardTokens.radiusButton,
                                        ),
                                        border: Border.all(
                                          color: isDark
                                              ? GuardTokens.darkBorder
                                              : GuardTokens.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.home_work_outlined,
                                            color: GuardTokens.guardAccent,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.entry.flatLabel,
                                              style: GuardTokens.bodyStyle(
                                                context,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: GuardTokens.sectionGap),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  GuardTokens.padScreen,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const GuardScreenSectionHeader(
                                      icon: Icons.edit_note_rounded,
                                      title: 'Purpose',
                                      subtitle: 'Optional — adjust if needed',
                                    ),
                                    const SizedBox(height: GuardTokens.g2),
                                    TextFormField(
                                      controller: _purpose,
                                      enabled: !_submitting,
                                      maxLines: 2,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: _fieldDecoration(
                                        context,
                                        label: 'Reason for visit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: GuardTokens.sectionGap + 88),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GuardTokens.padScreen,
                    8,
                    GuardTokens.padScreen,
                    12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (!hasActiveShift || _submitting)
                          ? null
                          : _confirmCheckIn,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirm check-in',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: GuardTokens.captionStyle(context).copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
