import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/design_animations.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../data/models/parcel_model.dart';
import '../../../data/providers/maintenance_provider.dart';
import '../../../data/providers/parcel_provider.dart';
import '../../../data/providers/utilities_provider.dart';
import '../../providers/visitor_provider.dart';
import 'home_shared.dart';

/// MyGate-style priority feed — additive layer only; does not replace other home sections.
class HomeUpdatesStrip extends ConsumerWidget {
  const HomeUpdatesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <_HomeUpdateCardData>[];

    final pendingVisitors =
        ref.watch(visitorApprovalRequestsProvider('pending')).valueOrNull;
    if (pendingVisitors != null && pendingVisitors.isNotEmpty) {
      final first = pendingVisitors.first;
      final name = (first['name'] as String?)?.trim();
      cards.add(
        _HomeUpdateCardData(
          badge: 'ACTION',
          title: 'Visitor at gate',
          subtitle: name != null && name.isNotEmpty
              ? '$name · Approve or deny'
              : '${pendingVisitors.length} waiting for approval',
          icon: Icons.how_to_reg_rounded,
          color: DesignColors.primary,
          onTap: () => context.push('/resident/visitor-requests'),
        ),
      );
    }

    final parcels = ref.watch(parcelProvider).valueOrNull ?? const <ParcelModel>[];
    final atGate = parcels
        .where((p) => p.leftAtGate && p.status == ParcelStatus.pending)
        .toList();
    if (atGate.isNotEmpty) {
      final p = atGate.first;
      cards.add(
        _HomeUpdateCardData(
          badge: 'COLLECT',
          title: 'Parcel at gate',
          subtitle: '${p.courier} · Waiting for pickup',
          icon: Icons.inventory_2_outlined,
          color: DesignColors.warning,
          onTap: () => context.push('/resident/parcels'),
        ),
      );
    }

    final waterGates = ref.watch(waterSupplyStatusProvider).valueOrNull ?? [];
    final onGate = waterGates.where((g) => g.isOn).toList();
    if (onGate.isNotEmpty) {
      final gateName =
          onGate.first.gateName.isNotEmpty ? onGate.first.gateName : 'Main Gate';
      cards.add(
        _HomeUpdateCardData(
          badge: 'LIVE',
          title: 'Water supply ON',
          subtitle: 'at $gateName',
          icon: Icons.water_drop_rounded,
          color: DesignColors.success,
          onTap: () => context.push('/resident/utilities'),
        ),
      );
    }

    if (ref.watch(garbageCollectionActiveProvider).valueOrNull?.isInside == true) {
      cards.add(
        _HomeUpdateCardData(
          badge: 'ACTIVE',
          title: 'Garbage collection',
          subtitle: 'Collector inside society',
          icon: Icons.delete_outline_rounded,
          color: DesignColors.warning,
          onTap: () => context.push('/resident/utilities'),
        ),
      );
    }

    final pendingDues =
        ref.watch(pendingMaintenanceProvider).valueOrNull ??
            ref.watch(pendingMaintenanceSeedProvider);
    if (pendingDues != null && pendingDues.isNotEmpty) {
      final total =
          pendingDues.fold<double>(0, (sum, m) => sum + m.remainingDue);
      if (total > 0) {
        final earliest = pendingDues
            .map((m) => m.dueDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final dueLabel = earliest.isBefore(DateTime.now())
            ? 'Overdue'
            : 'Due ${DateFormat('d MMM').format(earliest.toLocal())}';
        cards.add(
          _HomeUpdateCardData(
            badge: 'DUE',
            title: 'Maintenance ${NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0).format(total)}',
            subtitle: dueLabel,
            icon: Icons.receipt_long_outlined,
            color: DesignColors.error,
            onTap: () => context.push('/resident/maintenance/dues'),
          ),
        );
      }
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(bottom: kHomeSectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: HomeSectionHeader(title: 'Updates')),
                TextButton(
                  onPressed: () => context.push('/resident/notifications'),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DesignColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _HomeUpdateCard(data: card);
                },
              ),
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

class _HomeUpdateCardData {
  const _HomeUpdateCardData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _HomeUpdateCard extends StatelessWidget {
  const _HomeUpdateCard({required this.data});

  final _HomeUpdateCardData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        width: 248,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(kHomeRadiusLg),
          border: Border.all(color: data.color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(data.icon, size: 19, color: data.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: data.color,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: data.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data.badge,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: data.color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: DesignColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
