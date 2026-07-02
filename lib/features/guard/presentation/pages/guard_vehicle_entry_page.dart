import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../../../core/widgets/screen_skeletons.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_command_providers.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_flat_picker.dart';
import '../widgets/guard_screen_section_header.dart';

/// Gate vehicle ledger — large targets, searchable flat optional.
class GuardVehicleEntryPage extends ConsumerStatefulWidget {
  const GuardVehicleEntryPage({super.key});

  @override
  ConsumerState<GuardVehicleEntryPage> createState() =>
      _GuardVehicleEntryPageState();
}

class _GuardVehicleEntryPageState extends ConsumerState<GuardVehicleEntryPage> {
  final _vehicle = TextEditingController();
  final _notes = TextEditingController();

  bool _isResident = false;
  // Optional single flat association — grid single-select (same picker as
  // "Add visitor", one flat at a time).
  String? _villaId;
  String? _flatLabel;
  Set<String> _selectedUserIds = {};
  bool _submitting = false;

  void _onFlatTapped(GuardFlatSelection flat) {
    if (_submitting) return;
    setState(() {
      if (_villaId == flat.villaId) {
        _villaId = null;
        _flatLabel = null;
        _selectedUserIds = {};
      } else {
        _villaId = flat.villaId;
        _flatLabel = flat.label;
        _selectedUserIds = flat.userIds.toSet();
      }
    });
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reg = _vehicle.text.trim();
    if (reg.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Enter a recognizable vehicle number'),
          backgroundColor: GuardTokens.warning,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log vehicle entry'),
        content: Text('Record $reg (${_isResident ? "Resident" : "Visitor"})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    final span = GuardFlowTelemetry.start('guard_vehicle_entry');
    try {
      await ref
          .read(guardRepositoryProvider)
          .logGateVehicleEntry(
            registrationNumber: reg,
            kind: _isResident ? 'RESIDENT' : 'VISITOR',
            villaId: _villaId,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      span.complete();
      if (!mounted) return;
      ref.invalidate(guardGateVehicleTodayProvider);
      ref.invalidate(guardDashboardProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Vehicle logged at gate'),
        ),
      );
    } catch (e) {
      span.complete(success: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(guardCommandErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded),
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Vehicle entry',
            style: GuardTokens.headingStyle(context),
          ),
          centerTitle: false,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  GuardTokens.padScreen,
                  GuardTokens.g2,
                  GuardTokens.padScreen,
                  GuardTokens.g3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GuardScreenSectionHeader(
                      icon: Icons.directions_car_filled_rounded,
                      title: 'Registration number',
                      subtitle:
                          'Parking / traffic disputes — spell as on the plate',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _vehicle,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. KA01 AB 1234',
                        prefixIcon: Icon(
                          Icons.pin_rounded,
                          color: GuardTokens.guardAccent,
                        ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(20)],
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.badge_rounded,
                      title: 'Driver type',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(
                            'Visitor',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          icon: Icon(Icons.local_taxi_rounded),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(
                            'Resident',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          icon: Icon(Icons.home_work_rounded),
                        ),
                      ],
                      selected: {_isResident},
                      emptySelectionAllowed: false,
                      onSelectionChanged: _submitting
                          ? (_) {}
                          : (s) => setState(() => _isResident = s.first),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.apartment_rounded,
                      title: 'Visiting flat (optional)',
                      subtitle:
                          'Helps lookups if tenant or visitor disputes arise',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    ref
                        .watch(guardResidentsPickerProvider)
                        .when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(GuardTokens.g2),
                            child: PickerSkeleton(),
                          ),
                          error: (e, _) => Text(
                            userFacingMessage(e, 'Residents unavailable'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          data: (residents) {
                            if (residents.isEmpty) {
                              return Text(
                                'No residents.',
                                style: GuardTokens.bodyStyle(context),
                              );
                            }
                            return GuardFlatPicker(
                              residents: residents,
                              selectedUserIds: _selectedUserIds,
                              onToggleFlat: _onFlatTapped,
                            );
                          },
                        ),
                    if (_flatLabel != null) ...[
                      const SizedBox(height: GuardTokens.g2),
                      _SelectedFlatBanner(label: _flatLabel!),
                    ],
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.notes_rounded,
                      title: 'Gate note',
                      subtitle: 'Optional context for disputes or follow-up',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _notes,
                      enabled: !_submitting,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'Driver waiting, loaded goods, resident requested hold…',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 10,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  child: SizedBox(
                    width: double.infinity,
                    height: GuardTokens.btnPrimaryH + 4,
                    child: FilledButton.icon(
                      style: GuardTokens.primaryFilled(context),
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.shrink()
                          : Icon(Icons.save_alt_rounded),
                      label: _submitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Log at gate',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation of the flat chosen in the grid — the tapped tile can scroll out
/// of view once the list is long or filtered, so restate it near the actions.
class _SelectedFlatBanner extends StatelessWidget {
  const _SelectedFlatBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GuardTokens.g2,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
        color: GuardTokens.guardAccent.withValues(alpha: 0.10),
        border: Border.all(color: GuardTokens.guardAccent),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 18, color: GuardTokens.guardAccentDeep),
          const SizedBox(width: GuardTokens.g2),
          Text('Flat ', style: GuardTokens.bodyStyle(context)),
          Text(
            label,
            style: GuardTokens.bodyStyle(context)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
