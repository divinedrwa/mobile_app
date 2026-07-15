part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOutstandingPart on _MaintenancePaymentScreenState {
  Widget _buildOutstandingTab(BuildContext context) {
    final outstanding = ref.watch(outstandingDuesProvider);
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return outstanding.when(
      loading: () => const ListSkeleton(itemHeight: 100),
      error: (e, _) => _wrapTabWithRefresh(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: DesignColors.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load outstanding dues',
                  style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: DesignTypography.bodySmall.copyWith(color: context.text.secondary),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => ref.invalidate(outstandingDuesProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (data) {
        final villas = (data['villas'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        final totalOutstanding = (data['totalOutstanding'] as num?)?.toDouble() ?? 0;
        final villasWithDuesCount = (data['villasWithDuesCount'] as num?)?.toInt() ?? 0;
        final totalPendingCycles = (data['totalPendingCycles'] as num?)?.toInt() ?? 0;

        if (villas.isEmpty) {
          return _wrapTabWithRefresh(
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DesignColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_outline_rounded, size: 52, color: DesignColors.success),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All dues cleared!',
                      style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every villa is up to date on maintenance payments.',
                      textAlign: TextAlign.center,
                      style: DesignTypography.bodySmall.copyWith(
                        color: context.text.secondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _wrapTabWithRefresh(
          ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            itemCount: villas.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _outstandingSummaryBanner(
                  totalOutstanding, villasWithDuesCount, totalPendingCycles, inr,
                );
              }
              return _outstandingVillaCard(villas[i - 1], inr);
            },
          ),
        );
      },
    );
  }

  Widget _outstandingSummaryBanner(
    double totalOutstanding,
    int villasWithDuesCount,
    int totalPendingCycles,
    NumberFormat inr,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.surface.border),
          boxShadow: [
            BoxShadow(
              color: context.text.primary.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded,
                      size: 20, color: DesignColors.error),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total outstanding',
                        style: DesignTypography.labelSmall.copyWith(
                          color: context.text.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inr.format(totalOutstanding),
                        style: DesignTypography.headingL.copyWith(
                          color: DesignColors.error,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _outstandingChip(
                  Icons.home_outlined,
                  '$villasWithDuesCount ${villasWithDuesCount == 1 ? 'villa' : 'villas'}',
                ),
                const SizedBox(width: 8),
                _outstandingChip(
                  Icons.calendar_month_outlined,
                  '$totalPendingCycles ${totalPendingCycles == 1 ? 'month' : 'months'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outstandingChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DesignColors.error.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: DesignTypography.labelSmall.copyWith(
              color: DesignColors.error.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _outstandingVillaCard(Map<String, dynamic> villa, NumberFormat inr) {
    final villaId = villa['villaId']?.toString() ?? '';
    final villaNumber = villa['villaNumber']?.toString() ?? '-';
    final ownerName = (villa['ownerName']?.toString() ?? '').trim();
    final totalOutstanding = (villa['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final pendingCycles = (villa['pendingCycles'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final isExpanded = _expandedOutstandingVillas.contains(villaId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DesignColors.error.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: DesignColors.error.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () {
                mutateDashboardUi(() {
                  if (isExpanded) {
                    _expandedOutstandingVillas.remove(villaId);
                  } else {
                    _expandedOutstandingVillas.add(villaId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DesignColors.error,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ownerName.isEmpty ? villaNumber : ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesignTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ownerName.isEmpty ? '' : villaNumber,
                            style: DesignTypography.labelSmall.copyWith(
                              color: context.text.secondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 10.5,
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
                          style: DesignTypography.bodySmall.copyWith(
                            color: DesignColors.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: DesignColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${pendingCycles.length} ${pendingCycles.length == 1 ? 'month' : 'months'}',
                            style: DesignTypography.labelSmall.copyWith(
                              color: DesignColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: context.text.secondary,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded cycle rows
            if (isExpanded) ...[
              Divider(height: 1, thickness: 1, color: context.surface.border.withValues(alpha: 0.5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Column(
                  children: pendingCycles
                      .map((cycle) => _outstandingCycleRow(cycle, inr))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _outstandingCycleRow(Map<String, dynamic> cycle, NumberFormat inr) {
    final cycleTitle = cycle['cycleTitle']?.toString() ?? '';
    final remainingDue = (cycle['remainingDue'] as num?)?.toDouble() ?? 0;
    final isOverdue = cycle['isOverdue'] == true;
    final status = cycle['status']?.toString() ?? '';
    final accent = PaymentStatusColors.forOverdueAccent(isOverdue: isOverdue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.error_outline_rounded : Icons.schedule_rounded,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cycleTitle,
                style: DesignTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            if (isOverdue || status == 'OVERDUE')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OVERDUE',
                    style: DesignTypography.labelSmall.copyWith(
                      color: DesignColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 8.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            Text(
              inr.format(remainingDue),
              style: DesignTypography.bodySmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
