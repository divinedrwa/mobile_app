import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../widgets/guard_screen_section_header.dart';

class GuardIncidentReportPage extends ConsumerStatefulWidget {
  const GuardIncidentReportPage({super.key});

  @override
  ConsumerState<GuardIncidentReportPage> createState() =>
      _GuardIncidentReportPageState();
}

class _GuardIncidentReportPageState
    extends ConsumerState<GuardIncidentReportPage> {
  static const _types = [
    ('Suspicious activity', Icons.visibility_outlined),
    ('Property damage', Icons.home_repair_service_outlined),
    ('Noise / dispute', Icons.hearing_outlined),
  ];

  final _note = TextEditingController();
  final _location = TextEditingController();
  String _type = _types.first.$1;
  String _severity = 'MEDIUM';
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final span = GuardFlowTelemetry.start('guard_incident_report');
    try {
      await ref
          .read(guardRepositoryProvider)
          .createGuardIncident(
            title: _type,
            description: _note.text.trim().isEmpty ? _type : _note.text.trim(),
            location: _location.text.trim().isEmpty
                ? null
                : _location.text.trim(),
            severity: _severity,
          );
      span.complete();
      ref.invalidate(guardDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Incident logged'),
        ),
      );
      context.pop();
    } catch (e) {
      span.complete(success: false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Incident report',
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
                      icon: Icons.warning_amber_rounded,
                      title: 'What happened?',
                      subtitle: 'SOC and admin inbox — searchable in audits',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    Wrap(
                      spacing: GuardTokens.g2,
                      runSpacing: GuardTokens.g2,
                      children: _types.map((t) {
                        final sel = _type == t.$1;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                t.$2,
                                size: 18,
                                color: sel
                                    ? GuardTokens.guardAccentDeep
                                    : GuardTokens.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(t.$1),
                            ],
                          ),
                          selected: sel,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() => _type = t.$1),
                          selectedColor: GuardTokens.guardAccent.withValues(
                            alpha: 0.22,
                          ),
                          checkmarkColor: GuardTokens.guardAccentDeep,
                          labelStyle: TextStyle(
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.notes_rounded,
                      title: 'Description',
                      subtitle: 'Facts only — adds to the logged title',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _note,
                      maxLines: 5,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Details (optional)',
                        alignLabelWithHint: true,
                        hintText:
                            'Time, gate, witnesses, registration if relevant…',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.place_outlined,
                      title: 'Location',
                      subtitle: 'Optional gate, block, lane, or landmark',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    TextField(
                      controller: _location,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Location (optional)',
                        hintText: 'Main gate, Block B parking, clubhouse lane…',
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: GuardTokens.sectionGap),
                    const GuardScreenSectionHeader(
                      icon: Icons.priority_high_rounded,
                      title: 'Severity',
                      subtitle: 'Helps admins prioritize the incident',
                    ),
                    const SizedBox(height: GuardTokens.g2),
                    Wrap(
                      spacing: GuardTokens.g2,
                      runSpacing: GuardTokens.g2,
                      children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((
                        level,
                      ) {
                        final selected = _severity == level;
                        return ChoiceChip(
                          label: Text(level),
                          selected: selected,
                          onSelected: _submitting
                              ? null
                              : (_) => setState(() => _severity = level),
                          selectedColor: GuardTokens.guardAccent.withValues(
                            alpha: 0.22,
                          ),
                          checkmarkColor: GuardTokens.guardAccentDeep,
                          labelStyle: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 10,
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
                    height: GuardTokens.btnPrimaryH + 2,
                    child: FilledButton(
                      style: GuardTokens.primaryFilled(context),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded),
                                SizedBox(width: GuardTokens.g1),
                                Text(
                                  'Submit report',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
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
