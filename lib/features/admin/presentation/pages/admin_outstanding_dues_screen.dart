import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../data/providers/admin_providers.dart';

/// Cross-cycle outstanding dues view showing all villas with unpaid amounts.
class AdminOutstandingDuesScreen extends ConsumerWidget {
  const AdminOutstandingDuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duesAsync = ref.watch(adminOutstandingDuesProvider);

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DesignColors.background,
        scrolledUnderElevation: 0,
        title: Text(
          'Outstanding dues',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: DesignColors.textSecondary),
            onPressed: () => ref.invalidate(adminOutstandingDuesProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: DesignColors.primary,
        onRefresh: () async {
          ref.invalidate(adminOutstandingDuesProvider);
          await ref.read(adminOutstandingDuesProvider.future);
        },
        child: duesAsync.when(
          loading: () => _buildSkeleton(),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              EmptyStateWidget(
                icon: Icons.cloud_off_outlined,
                title: 'Something went wrong',
                subtitle: '$e\nPull down to retry.',
              ),
            ],
          ),
          data: (data) => _buildContent(context, data),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final inr =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villas = ((data['villas'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final totalOutstanding =
        (data['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final totalVillas = villas.length;

    if (villas.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: 'All clear!',
            subtitle: 'No outstanding dues across any billing cycle.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignRadius.xl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL OUTSTANDING',
                style: DesignTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                inr.format(totalOutstanding),
                style: DesignTypography.headingXL.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalVillas villa${totalVillas == 1 ? '' : 's'} with pending dues',
                style: DesignTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Villa list
        Text(
          'By villa',
          style: DesignTypography.headingM.copyWith(
            color: DesignColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final villa in villas) ...[
          _VillaOutstandingTile(villa: villa),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildSkeleton() {
    return ShimmerWrap(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          ShimmerBox(height: 120, borderRadius: DesignRadius.xl),
          const SizedBox(height: AppSpacing.xl),
          for (int i = 0; i < 5; i++) ...[
            ShimmerBox(height: 80, borderRadius: DesignRadius.lg),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _VillaOutstandingTile extends StatefulWidget {
  const _VillaOutstandingTile({required this.villa});

  final Map<String, dynamic> villa;

  @override
  State<_VillaOutstandingTile> createState() => _VillaOutstandingTileState();
}

class _VillaOutstandingTileState extends State<_VillaOutstandingTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final inr =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final v = widget.villa;
    final villaNumber = v['villaNumber']?.toString() ?? '—';
    final villaId = v['villaId']?.toString() ?? '';
    final ownerName = v['ownerName']?.toString() ?? 'Unknown';
    final totalOutstanding =
        (v['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final cycles = ((v['cycles'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        border: Border.all(color: DesignColors.borderLight),
        borderRadius: BorderRadius.circular(DesignRadius.lg),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
            onTap: cycles.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            onLongPress: villaId.isNotEmpty
                ? () =>
                    context.go('/resident/admin-villa-history/$villaId')
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DesignColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(DesignRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      villaNumber,
                      style: DesignTypography.bodySmall.copyWith(
                        color: DesignColors.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Villa $villaNumber',
                          style: DesignTypography.bodyMedium.copyWith(
                            color: DesignColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$ownerName · ${cycles.length} cycle${cycles.length == 1 ? '' : 's'}',
                          style: DesignTypography.caption.copyWith(
                            color: DesignColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr.format(totalOutstanding),
                        style: DesignTypography.bodyMedium.copyWith(
                          color: DesignColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: DesignColors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded cycle breakdown
          if (_expanded && cycles.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  for (final cycle in cycles) ...[
                    _cycleLine(cycle, inr),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: villaId.isNotEmpty
                          ? () => context.go(
                              '/resident/admin-villa-history/$villaId')
                          : null,
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('View full history'),
                      style: TextButton.styleFrom(
                        foregroundColor: DesignColors.primary,
                        textStyle: DesignTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cycleLine(Map<String, dynamic> cycle, NumberFormat inr) {
    final month = (cycle['periodMonth'] as num?)?.toInt();
    final year = (cycle['periodYear'] as num?)?.toInt();
    final label = month != null && year != null
        ? DateFormat('MMM y').format(DateTime(year, month))
        : cycle['label']?.toString() ?? '—';
    final expected = (cycle['expectedAmount'] as num?)?.toDouble() ?? 0;
    final paid = (cycle['paidAmount'] as num?)?.toDouble() ?? 0;
    final remaining = (expected - paid).clamp(0, double.infinity);
    final isOverdue =
        (cycle['isOverdue'] as bool?) ?? false;

    return Row(
      children: [
        if (isOverdue)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: DesignColors.error,
              shape: BoxShape.circle,
            ),
          ),
        Expanded(
          child: Text(
            label,
            style: DesignTypography.bodySmall.copyWith(
              color: DesignColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '${inr.format(paid)} / ${inr.format(expected)}',
          style: DesignTypography.caption.copyWith(
            color: DesignColors.textTertiary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          inr.format(remaining),
          style: DesignTypography.bodySmall.copyWith(
            color: DesignColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
