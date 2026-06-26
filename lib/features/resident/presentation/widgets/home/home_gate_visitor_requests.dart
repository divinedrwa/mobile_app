import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../providers/visitor_provider.dart';
import 'home_shared.dart';
import 'home_skeletons.dart';

/// Shows pending gate visitor approval requests.
/// Hidden entirely when empty (data == []) or on error.
/// Shows skeleton during loading so the section doesn't jump.
class HomeGateVisitorRequests extends ConsumerWidget {
  const HomeGateVisitorRequests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(visitorApprovalRequestsProvider('pending'));

    // Resolved empty or error → hide entirely with smooth collapse.
    final resolved = gateAsync.valueOrNull;
    final hide = (resolved != null && resolved.isEmpty) || gateAsync.hasError;

    Widget inner;
    if (hide) {
      inner = const SizedBox.shrink();
    } else if (gateAsync.isLoading && resolved == null) {
      // Initial load skeleton
      inner = Padding(
        padding: const EdgeInsets.only(bottom: kHomeSectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeSectionHeader(title: 'Gate Visitor Requests'),
            const SizedBox(height: 10),
            const HomeGateRequestSkeleton(),
          ],
        ),
      );
    } else {
      inner = Padding(
        padding: const EdgeInsets.only(bottom: kHomeSectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HomeSectionHeader(title: 'Gate Visitor Requests'),
            const SizedBox(height: 10),
            _PendingRequestCard(list: resolved ?? []),
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: inner,
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.list});

  final List list;

  @override
  Widget build(BuildContext context) {
    final n = list.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DesignColors.primary.withValues(alpha: 0.07),
            DesignColors.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(kHomeRadiusLg),
        border: Border.all(
          color: DesignColors.primary.withValues(alpha: 0.28),
        ),
        boxShadow: homeCardShadow(0.03),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kHomeRadiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(kHomeRadiusLg),
          onTap: () {
            DesignHaptics.selection();
            context.push('/resident/visitor-requests');
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                // Pulsing dot + icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: DesignColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.how_to_reg_rounded,
                        size: 22,
                        color: DesignColors.primary,
                      ),
                    ),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: DesignColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$n',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$n pending ${n == 1 ? 'request' : 'requests'} awaiting your approval',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: DesignColors.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Security is waiting — tap to approve or decline',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: context.text.secondary,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: DesignColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
