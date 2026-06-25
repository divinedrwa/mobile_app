import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/providers/utilities_provider.dart';
import 'home_shared.dart';
import 'home_skeletons.dart';

class HomeUtilityStatusStrip extends ConsumerWidget {
  const HomeUtilityStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterAsync = ref.watch(waterSupplyStatusProvider);
    final garbageAsync = ref.watch(garbageCollectionActiveProvider);

    final isInitialLoad = (waterAsync.isLoading && waterAsync.valueOrNull == null) ||
        (garbageAsync.isLoading && garbageAsync.valueOrNull == null);
    if (isInitialLoad) return const HomeUtilityStripSkeleton();

    final waterGates = waterAsync.valueOrNull ?? [];
    final collectorInside = garbageAsync.valueOrNull?.isInside ?? false;

    final anyOn = waterGates.any((g) => g.isOn);
    final onGate =
        anyOn ? waterGates.firstWhere((g) => g.isOn) : null;

    // Hide entirely when nothing active — AnimatedSize handles the collapse.
    if (!anyOn && !collectorInside) {
      return const AnimatedSize(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: SizedBox.shrink(),
      );
    }

    final cards = <_LiveStatusCard>[];

    if (anyOn && onGate != null) {
      final gateName =
          onGate.gateName.isNotEmpty ? onGate.gateName : 'Main Gate';
      cards.add(_LiveStatusCard(
        icon: Icons.water_drop_rounded,
        accentColor: DesignColors.success,
        badgeLabel: 'LIVE',
        title: 'Water supply ON',
        subtitle: 'at $gateName — available now',
        onTap: () => context.push('/resident/utilities'),
      ));
    }

    if (collectorInside) {
      cards.add(_LiveStatusCard(
        icon: Icons.delete_outline_rounded,
        accentColor: DesignColors.warning,
        badgeLabel: 'ACTIVE',
        title: 'Garbage collection',
        subtitle: 'Collector is inside the society',
        onTap: () => context.push('/resident/utilities'),
      ));
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(bottom: kHomeSectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeSectionHeader(title: 'Live Updates'),
            const SizedBox(height: 10),
            if (cards.length == 1)
              cards.first
            else
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance)
        .slideY(begin: DesignAnimations.slideSubtle, end: 0);
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard({
    required this.icon,
    required this.accentColor,
    required this.badgeLabel,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String badgeLabel;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(kHomeRadiusLg),
          border: Border.all(color: accentColor.withValues(alpha: 0.22)),
          boxShadow: homeCardShadow(0.025),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            height: 1.15,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: accentColor.withValues(alpha: 0.65),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: accentColor.withValues(alpha: 0.45)),
          ],
        ),
      ),
    );
  }
}
