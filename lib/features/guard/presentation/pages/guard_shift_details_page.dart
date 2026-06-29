import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
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
            icon: Icon(Icons.close_rounded),
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

                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final shiftIndex = i - 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: GuardTokens.g2),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GuardTokens.radiusCard),
                              side: BorderSide(
                                color: active
                                    ? GuardTokens.success.withValues(alpha: 0.35)
                                    : (isDark
                                        ? GuardTokens.darkBorder.withValues(alpha: 0.85)
                                        : GuardTokens.borderSubtle.withValues(alpha: 0.9)),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(GuardTokens.g2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? GuardTokens.success.withValues(alpha: 0.12)
                                          : (isDark
                                              ? GuardTokens.darkCard
                                              : GuardTokens.borderSubtle.withValues(alpha: 0.5)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: active
                                            ? GuardTokens.success.withValues(alpha: 0.3)
                                            : GuardTokens.borderSubtle.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      active
                                          ? Icons.brightness_high_rounded
                                          : Icons.nights_stay_rounded,
                                      semanticLabel: active ? 'Active shift' : 'Inactive shift',
                                      color: active
                                          ? GuardTokens.success
                                          : GuardTokens.textSecondary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: GuardTokens.g2),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: GuardTokens.headingStyle(context).copyWith(
                                            fontSize: GuardTokens.body,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          line,
                                          style: GuardTokens.captionStyle(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (active)
                                    Semantics(
                                      label: 'Shift is currently active',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: GuardTokens.success.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: GuardTokens.success.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          'Active',
                                          style: TextStyle(
                                            color: GuardTokens.success,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ).animate(delay: DesignAnimations.staggerFor(shiftIndex)).fadeIn(duration: 200.ms).slideY(begin: 0.04);
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

