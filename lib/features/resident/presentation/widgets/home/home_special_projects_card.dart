import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/screen_skeletons.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/providers/special_project_provider.dart';
import 'home_shared.dart';

class HomeSpecialProjectsCard extends ConsumerWidget {
  const HomeSpecialProjectsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(residentSpecialProjectsProvider);

    return projectsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(
            title: 'Special projects',
            onViewAll: () => context.push('/resident/special-projects'),
          ),
          const SizedBox(height: kHomeSectionGap / 2),
          const CardCarouselSkeleton(),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final active =
            projects.where((p) => p.status == 'ACTIVE').toList();
        if (active.isEmpty) return const SizedBox.shrink();

        final inr = NumberFormat.currency(
            locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);
        final myOutstanding = active.fold(
            0.0,
            (sum, p) =>
                sum + (p.myContribution?.outstanding ?? 0));
        final totalCollected =
            active.fold(0.0, (sum, p) => sum + p.totalCollected);
        final totalTarget =
            active.fold(0.0, (sum, p) => sum + p.targetAmount);
        final progress = totalTarget > 0
            ? (totalCollected / totalTarget).clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: kHomeSectionGap),
          child: Container(
          decoration: BoxDecoration(
            color: context.surface.defaultSurface,
            borderRadius: BorderRadius.circular(kHomeRadiusLg),
            border: Border.all(color: context.surface.border),
            boxShadow: homeCardShadow(),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(kHomeRadiusLg),
              onTap: () =>
                  context.push('/resident/special-projects'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED)
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.construction_rounded,
                              color: Color(0xFF7C3AED),
                              size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${active.length} Active Project${active.length != 1 ? 's' : ''}',
                                style: DesignTypography
                                    .bodySmall
                                    .copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.text.primary,
                                ),
                              ),
                              if (myOutstanding > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'My Outstanding: ${inr.format(myOutstanding)}',
                                  style: DesignTypography
                                      .caption
                                      .copyWith(
                                    color: DesignColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14,
                            color: context.text.tertiary),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                          DesignRadius.full),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: context.surface.border,
                        valueColor:
                            const AlwaysStoppedAnimation(
                          Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${inr.format(totalCollected)} / ${inr.format(totalTarget)} collected',
                        style: DesignTypography.captionSmall
                            .copyWith(
                          color: context.text.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        )
            .animate()
            .fadeIn(
                duration: DesignAnimations.durationEntrance)
            .slideY(begin: 0.05, end: 0);
      },
    );
  }
}
