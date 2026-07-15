part of '../maintenance_payment_screen.dart';
extension _MaintenanceDashboardOverviewAdvancePart on _MaintenancePaymentScreenState {
  Widget _buildOverviewAdvanceSection(
    List<Map<String, dynamic>> residents,
    NumberFormat inr,
  ) {
    return Builder(
      builder: (_) {
        final advanceResidents = <Map<String, dynamic>>[];
        for (final r in residents) {
          final paid = (r['paidTowardCycle'] as num?)?.toDouble() ?? 0;
          final exp = (r['amount'] as num?)?.toDouble() ?? 0;
          final adv = paid - exp;
          if (adv > 0.005) {
            advanceResidents.add({...r, '_advance': adv});
          }
        }
        if (advanceResidents.isEmpty) return const SizedBox.shrink();

        advanceResidents.sort((a, b) =>
            ((b['_advance'] as double)).compareTo(a['_advance'] as double));
        final totalAdv = advanceResidents.fold<double>(
            0, (sum, r) => sum + (r['_advance'] as double));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _collapsibleSectionHeader(
              'Advance payments',
              '${advanceResidents.length} members',
              expanded: _advanceExpanded,
              onTap: () => mutateDashboardUi(
                  () => _advanceExpanded = !_advanceExpanded),
            ),
            if (_advanceExpanded)
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface.defaultSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.surface.border),
                  boxShadow: [
                    BoxShadow(
                      color: context.text.primary
                          .withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Total advance header
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      decoration: BoxDecoration(
                        color: DesignColors.info
                            .withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: DesignColors.info
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.trending_up_rounded,
                              color: DesignColors.info,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total advance collected',
                                  style: DesignTypography.labelSmall
                                      .copyWith(
                                    color: context.text.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inr.format(totalAdv),
                                  style: DesignTypography.headingM
                                      .copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: DesignColors.info,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: DesignColors.info
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${advanceResidents.length}',
                              style: DesignTypography.labelSmall
                                  .copyWith(
                                color: DesignColors.info,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Individual advance entries
                    ...advanceResidents.map((r) {
                      final name =
                          '${r['name'] ?? r['ownerName'] ?? 'Unknown'}'
                              .trim();
                      final unit =
                          '${r['flatNumber'] ?? r['villaNumber'] ?? '-'}';
                      final paid =
                          (r['paidTowardCycle'] as num?)?.toDouble() ??
                              0;
                      final exp =
                          (r['amount'] as num?)?.toDouble() ?? 0;
                      final adv = r['_advance'] as double;

                      return Container(
                        padding:
                            const EdgeInsets.fromLTRB(18, 10, 18, 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: context.surface.border
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: DesignColors.info
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unit,
                                style: DesignTypography.labelSmall
                                    .copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DesignColors.info,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DesignTypography.bodySmall
                                        .copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Expected ${inr.format(exp)} · Paid ${inr.format(paid)}',
                                    style: DesignTypography.labelSmall
                                        .copyWith(
                                      color:
                                          context.text.tertiary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: DesignColors.success
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(20),
                                border: Border.all(
                                  color: DesignColors.success
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                '+${inr.format(adv)}',
                                style: DesignTypography.labelSmall
                                    .copyWith(
                                  color: DesignColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

  }
}
