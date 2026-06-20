import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../theme/context_extensions.dart';
import '../../providers/visitor_provider.dart';

class HomeGateVisitorRequests extends ConsumerWidget {
  const HomeGateVisitorRequests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(visitorApprovalRequestsProvider('pending'));

    final pendingList = gateAsync.valueOrNull;
    if (pendingList != null && pendingList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gate visitor requests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.35,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        gateAsync.when(
          loading: () => const ShimmerWrap(
            child: ShimmerBox(height: 64, borderRadius: DesignRadius.lg),
          ),
          error: (_, _) => Material(
            color: context.surface.defaultSurface,
            borderRadius: DesignRadius.borderLG,
            child: InkWell(
              onTap: () => ref
                  .invalidate(visitorApprovalRequestsProvider('pending')),
              borderRadius: DesignRadius.borderLG,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: DesignRadius.borderLG,
                  border: Border.all(
                    color: DesignColors.error.withValues(alpha: 0.35),
                  ),
                  boxShadow: DesignElevation.sm,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      color: DesignColors.error,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Could not load gate requests. Tap to retry.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DesignColors.error,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.refresh_rounded,
                      color: DesignColors.error,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (list) {
            final n = list.length;
            final hasPending = n > 0;
            return Material(
              color: context.surface.defaultSurface,
              borderRadius: DesignRadius.borderLG,
              elevation: 0,
              child: InkWell(
                borderRadius: DesignRadius.borderLG,
                onTap: () {
                  DesignHaptics.selection();
                  context.push('/resident/visitor-requests');
                },
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(12, 11, 10, 11),
                  decoration: BoxDecoration(
                    borderRadius: DesignRadius.borderLG,
                    border: Border.all(
                      color: hasPending
                          ? DesignColors.primary
                              .withValues(alpha: 0.35)
                          : DesignColors.borderLight,
                    ),
                    boxShadow: DesignElevation.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasPending
                              ? DesignColors.primary
                                  .withValues(alpha: 0.12)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.how_to_reg_rounded,
                          size: 20,
                          color: hasPending
                              ? DesignColors.primary
                              : context.text.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasPending
                                  ? '$n pending ${n == 1 ? 'request' : 'requests'}'
                                  : 'No pending approvals',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: DesignColors.textPrimary,
                                letterSpacing: -0.25,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPending
                                  ? 'Approve or decline — security is waiting'
                                  : 'Visitors registered for your flat appear here',
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
                      if (hasPending)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: DesignColors.primary,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: DesignColors.textSecondary
                            .withValues(alpha: 0.85),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
      ),
    );
  }
}
