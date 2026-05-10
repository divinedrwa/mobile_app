import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// SOS strip — compact but clear; actions reuse existing APIs.
class GuardSosStrip extends ConsumerWidget {
  const GuardSosStrip({super.key, required this.alerts});

  final List<GuardSosRow> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.crisis_alert_rounded, color: GuardTokens.dangerBrand, size: 22),
            const SizedBox(width: 8),
            Text(
              'Emergency (SOS)',
              style: GuardTokens.headingStyle(context).copyWith(fontSize: 17),
            ),
          ],
        ),
        const SizedBox(height: GuardTokens.g2),
        ...alerts.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: GuardTokens.g2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                color: isDark ? const Color(0xFF3F1E1E) : GuardTokens.dangerMuted,
                border: Border.all(color: GuardTokens.dangerBrand.withValues(alpha: 0.35)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                title: Text(
                  s.residentName ?? 'Resident alert',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  [
                    if (s.villaNumber != null) 'Flat ${s.villaNumber}',
                    if (s.emergencyType != null) s.emergencyType!,
                    s.status,
                  ].join(' · '),
                  style: GuardTokens.captionStyle(context),
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (s.status == 'CREATED' ||
                        s.status == 'ACTIVE' ||
                        s.status == 'PENDING')
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(guardRepositoryProvider).respondToSos(
                                  alertId: s.id,
                                  status: 'ACKNOWLEDGED',
                                );
                            ref.invalidate(guardDashboardProvider);
                            ref.invalidate(guardActiveAlertsProvider);
                            ref.invalidate(guardMyGateProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(userFacingMessage(e))),
                              );
                            }
                          }
                        },
                        style: GuardTokens.textLink(context),
                        child: const Text('Ack'),
                      ),
                    if (s.status == 'ACKNOWLEDGED')
                      TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(guardRepositoryProvider).respondToSos(
                                  alertId: s.id,
                                  status: 'IN_PROGRESS',
                                );
                            ref.invalidate(guardDashboardProvider);
                            ref.invalidate(guardActiveAlertsProvider);
                            ref.invalidate(guardMyGateProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(userFacingMessage(e))),
                              );
                            }
                          }
                        },
                        style: GuardTokens.textLink(context),
                        child: const Text('Start'),
                      ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(guardRepositoryProvider).respondToSos(
                                alertId: s.id,
                                status: 'RESOLVED',
                              );
                          ref.invalidate(guardDashboardProvider);
                          ref.invalidate(guardActiveAlertsProvider);
                          ref.invalidate(guardMyGateProvider);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(userFacingMessage(e))),
                            );
                          }
                        }
                      },
                      style: GuardTokens.textLink(context),
                      child: const Text('Resolve'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
