import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/tap_scale.dart';
import '../../../data/providers/utilities_provider.dart';

class HomeUtilityStatusStrip extends ConsumerWidget {
  const HomeUtilityStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterAsync = ref.watch(waterSupplyStatusProvider);
    final garbageAsync = ref.watch(garbageCollectionActiveProvider);

    final waterGates = waterAsync.valueOrNull ?? [];
    final collectorInside = garbageAsync.valueOrNull?.isInside ?? false;

    // Show water card only when supply is ON at any gate
    final anyOn = waterGates.any((g) => g.isOn);
    final onGate = anyOn
        ? waterGates.firstWhere((g) => g.isOn)
        : null;

    // Hide entire strip when water is off AND garbage collector is not inside
    if (!anyOn && !collectorInside) return const SizedBox.shrink();

    final cards = <Widget>[];

    // Water card — only when supply is ON
    if (anyOn && onGate != null) {
      final gateName =
          onGate.gateName.isNotEmpty ? onGate.gateName : 'Main Gate';
      cards.add(Expanded(
        child: _StatusCard(
          icon: Icons.water_drop_rounded,
          color: DesignColors.success,
          title: 'Water supply is ON',
          subtitle: 'at $gateName — available now',
          onTap: () => context.push('/resident/utilities'),
        ),
      ));
    }

    // Garbage card — only when collector is inside
    if (collectorInside) {
      if (cards.isNotEmpty) cards.add(const SizedBox(width: 8));
      cards.add(Expanded(
        child: _StatusCard(
          icon: Icons.delete_outline_rounded,
          color: DesignColors.warning,
          title: 'Garbage collector inside',
          subtitle: 'Collection in progress',
          onTap: () => context.push('/resident/utilities'),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: cards),
    )
        .animate()
        .fadeIn(duration: DesignAnimations.durationEntrance);
  }

}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: DesignRadius.borderLG,
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.6),
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

