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
  // Optional flat association — multi-select (same block-grid picker as Add
  // Visitor); one gate entry logged per flat, or a single entry with no flat
  // when none is chosen.
  final Map<String, GuardFlatSelection> _selectedFlats = {}; // villaId -> flat
  bool _submitting = false;

  Set<String> get _selectedUserIds =>
      {for (final f in _selectedFlats.values) ...f.userIds};

  void _onFlatTapped(GuardFlatSelection flat) {
    if (_submitting) return;
    setState(() {
      if (_selectedFlats.containsKey(flat.villaId)) {
        _selectedFlats.remove(flat.villaId);
      } else {
        _selectedFlats[flat.villaId] = flat;
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
    final flats = _selectedFlats.values.toList();
    final flatSuffix = flats.isEmpty
        ? ''
        : ' for ${flats.length} flat${flats.length == 1 ? '' : 's'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log vehicle entry'),
        content: Text(
          'Record $reg (${_isResident ? "Resident" : "Visitor"})$flatSuffix?',
        ),
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
    final kind = _isResident ? 'RESIDENT' : 'VISITOR';
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    try {
      // One gate entry per selected flat; a single unassociated entry if none.
      final villaIds = flats.isEmpty
          ? <String?>[null]
          : flats.map((f) => f.villaId).toList();
      for (final villaId in villaIds) {
        await ref.read(guardRepositoryProvider).logGateVehicleEntry(
              registrationNumber: reg,
              kind: kind,
              villaId: villaId,
              notes: notes,
            );
      }
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
                      title: 'Visiting flats (optional)',
                      subtitle:
                          'Tap any flats this vehicle is visiting — helps dispute lookups',
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
                    if (_selectedFlats.isNotEmpty) ...[
                      const SizedBox(height: GuardTokens.g2),
                      GuardSelectedFlatsBanner(
                        verb: 'Vehicle for',
                        labels: _selectedFlats.values
                            .map((f) => f.label)
                            .toList(),
                      ),
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
