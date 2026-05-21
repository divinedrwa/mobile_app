import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/models/guard_models.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';
import '../../utils/shift_active_helper.dart';
import '../widgets/guard_error_banner.dart';
import '../widgets/guard_screen_section_header.dart';
import '../widgets/guard_skeletons.dart';

class GuardShiftDetailsPage extends ConsumerWidget {
  const GuardShiftDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(guardMyShiftsProvider);

    return GuardThemeScope(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text('Shift roster', style: GuardTokens.headingStyle(context)),
          centerTitle: false,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: async.when(
                loading: () => const GuardShiftSkeleton(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(GuardTokens.padScreen),
                  child: Center(
                    child: GuardInlineErrorBanner(
                      message: userFacingMessage(e),
                      onRetry: () => ref.invalidate(guardMyShiftsProvider),
                    ),
                  ),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(GuardTokens.padScreen),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 56,
                              color: GuardTokens.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            const SizedBox(height: GuardTokens.g2),
                            Text(
                              'No shifts scheduled',
                              textAlign: TextAlign.center,
                              style: GuardTokens.headingStyle(context),
                            ),
                            const SizedBox(height: GuardTokens.g1),
                            Text(
                              'Assigned slots show here once HR publishes roster.',
                              textAlign: TextAlign.center,
                              style: GuardTokens.bodyStyle(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final now = DateTime.now();
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(guardMyShiftsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        GuardTokens.padScreen,
                        GuardTokens.g2,
                        GuardTokens.padScreen,
                        GuardTokens.g3,
                      ),
                      itemCount: rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(
                              bottom: GuardTokens.sectionGap,
                            ),
                            child: GuardScreenSectionHeader(
                              icon: Icons.schedule_rounded,
                              title: 'Your roster',
                              subtitle: 'Pull down to refresh',
                            ),
                          );
                        }
                        final shift = rows[i - 1];
                        final active =
                            ShiftActiveHelper.isShiftActive(shift.toRawMap(), now);
                        final title =
                            '${_titleCase(shift.shiftType)}${shift.gateName == null ? '' : ' · ${shift.gateName}'}';
                        final line =
                            '${_fmtDate(shift.startTime)} · ${_fmtTime(shift.startTime)}–${_fmtTime(shift.endTime)}';

                        return Card(
                          margin: const EdgeInsets.only(bottom: GuardTokens.g2),
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(GuardTokens.g2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(GuardTokens.g1),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? GuardTokens.successMuted
                                        : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(
                                      GuardTokens.radiusChip,
                                    ),
                                  ),
                                  child: Icon(
                                    active
                                        ? Icons.brightness_high_rounded
                                        : Icons.nights_stay_rounded,
                                    semanticLabel: active ? 'Active shift' : 'Inactive shift',
                                    color: active
                                        ? GuardTokens.success
                                        : GuardTokens.textSecondary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: GuardTokens.g2),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GuardTokens.headingStyle(
                                          context,
                                        ).copyWith(fontSize: GuardTokens.body),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        line,
                                        style: GuardTokens.captionStyle(
                                          context,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (active)
                                  Semantics(
                                    label: 'Shift is currently active',
                                    child: Chip(
                                    label: const Text('Active'),
                                    backgroundColor: GuardTokens.successMuted,
                                    labelStyle: GuardTokens.bodyStyle(context)
                                        .copyWith(
                                          color: GuardTokens.success,
                                          fontWeight: FontWeight.w700,
                                          fontSize: GuardTokens.caption,
                                        ),
                                  ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _titleCase(String input) {
    final low = input.toLowerCase().replaceAll('_', ' ');
    return low
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String _fmtDate(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _fmtTime(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

