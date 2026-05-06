import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
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
  final _villaQuery = TextEditingController();
  final _notes = TextEditingController();

  bool _resident = false;
  VillaPickerItem? _villa;
  bool _submitting = false;

  List<VillaPickerItem> _filter(List<VillaPickerItem> all) {
    final q = _villaQuery.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((v) {
      final block = (v.block ?? '').toLowerCase();
      final num = v.villaNumber.toLowerCase();
      return block.contains(q) || num.contains(q) || '$block $num'.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _vehicle.dispose();
    _villaQuery.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reg = _vehicle.text.trim();
    if (reg.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Enter a recognizable vehicle number'),
          backgroundColor: GuardTokens.warning,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final span = GuardFlowTelemetry.start('guard_vehicle_entry');
    try {
      await ref
          .read(guardRepositoryProvider)
          .logGateVehicleEntry(
            registrationNumber: reg,
            kind: _resident ? 'RESIDENT' : 'VISITOR',
            villaId: _villa?.id,
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
      ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(guardVillasProvider);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
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
                      selected: {_resident},
                      emptySelectionAllowed: false,
                      onSelectionChanged: _submitting
                          ? (_) {}
                          : (s) => setState(() => _resident = s.first),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.apartment_rounded,
                      title: 'Visiting flat (optional)',
                      subtitle:
                          'Helps lookups if tenant or visitor disputes arise',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _villaQuery,
                      enabled: !_submitting,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search block / flat…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            GuardTokens.radiusButton,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    ref
                        .watch(guardVillasProvider)
                        .when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(GuardTokens.g3),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text(
                            userFacingMessage(e, 'Flats unavailable'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          data: (villas) {
                            if (villas.isEmpty) {
                              return Text(
                                'No flats.',
                                style: GuardTokens.bodyStyle(context),
                              );
                            }
                            final filtered = _filter(villas);
                            return Wrap(
                              spacing: GuardTokens.g2,
                              runSpacing: GuardTokens.g2,
                              children: filtered.map((v) {
                                final label =
                                    v.block != null && v.block!.isNotEmpty
                                    ? '${v.block} · ${v.villaNumber}'
                                    : v.villaNumber;
                                final sel = _villa?.id == v.id;
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: sel,
                                  onSelected: _submitting
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _villa = sel ? null : v;
                                          });
                                        },
                                  selectedColor: GuardTokens.guardAccent
                                      .withValues(alpha: 0.2),
                                );
                              }).toList(),
                            );
                          },
                        ),
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
                          : const Icon(Icons.save_alt_rounded),
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
