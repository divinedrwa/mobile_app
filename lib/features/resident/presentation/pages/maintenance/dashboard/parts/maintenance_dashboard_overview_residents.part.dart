part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOverviewResidentsPart on _MaintenancePaymentScreenState {
  Widget _statusCountPill(
    String filterValue,
    String count,
    String label,
    Color color,
  ) {
    final active = _residentStatusFilter == filterValue;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => mutateDashboardUi(() {
        _residentStatusFilter = active ? 'ALL' : filterValue;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : color.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              count,
              style: DesignTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: DesignTypography.labelSmall.copyWith(
                color: active ? Colors.white70 : context.text.secondary,
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Residents search + filter ─────────────────────

  Widget _residentsFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _residentSearchCtrl,
        onChanged: (v) => mutateDashboardUi(() => _residentQuery = v),
        textInputAction: TextInputAction.search,
        style: DesignTypography.bodySmall.copyWith(color: context.text.primary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: context.surface.elevated,
          hintText: 'Search resident or unit',
          hintStyle: DesignTypography.bodySmall.copyWith(
            color: context.text.tertiary,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20, color: context.text.tertiary),
          suffixIcon: _residentQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: context.text.tertiary),
                  onPressed: () {
                    _residentSearchCtrl.clear();
                    mutateDashboardUi(() => _residentQuery = '');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.surface.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DesignColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _residentsNoMatch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: context.text.tertiary),
            const SizedBox(height: 10),
            Text(
              'No residents match',
              style: DesignTypography.bodySmall.copyWith(
                color: context.text.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                _residentSearchCtrl.clear();
                mutateDashboardUi(() {
                  _residentQuery = '';
                  _residentStatusFilter = 'ALL';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _residentPaymentTile(Map<String, dynamic> r, NumberFormat inr,
      {bool isMe = false}) {
    final rawStatus = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
    final isPaid = rawStatus == 'PAID';
    final expectedAmount = (r['amount'] as num?)?.toDouble() ?? 0;
    final actualPaid = (r['paidTowardCycle'] as num?)?.toDouble() ?? 0;
    final displayName =
        '${r['name'] ?? r['ownerName'] ?? 'Unknown'}'.trim();
    final unit = '${r['flatNumber'] ?? r['villaNumber'] ?? '-'}';
    final statusText = switch (rawStatus) {
      'PARTIAL' => 'Partial',
      'OVERDUE' => 'Overdue',
      'PAID' => 'Paid',
      _ => 'Unpaid',
    };
    final accent = switch (rawStatus) {
      'PARTIAL' => DesignColors.warning,
      'OVERDUE' => DesignColors.error,
      'PAID' => DesignColors.success,
      _ => DesignColors.error,
    };
    final extra = actualPaid - expectedAmount;
    final hasExtra = extra > 0.005 && isPaid;
    // Lead with what's owed when nothing has been paid yet — a bare ₹0 reads as
    // "no charge" rather than "unpaid".
    final hasNoPayment = actualPaid <= 0.005;
    final displayAmount = hasNoPayment ? expectedAmount : actualPaid;
    final progress = expectedAmount > 0
        ? (actualPaid / expectedAmount).clamp(0.0, 1.0)
        : (isPaid ? 1.0 : 0.0);
    final caption = hasExtra
        ? 'Paid ${inr.format(actualPaid)} · Extra +${inr.format(extra)}'
        : isPaid
            ? 'Paid in full'
            : actualPaid > 0.005
                ? 'Paid ${inr.format(actualPaid)} of ${inr.format(expectedAmount)} · Due ${inr.format(expectedAmount - actualPaid)}'
                : 'Due ${inr.format(expectedAmount)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface.defaultSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? DesignColors.primary.withValues(alpha: 0.5)
                : context.surface.border,
            width: isMe ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                children: [
                  // Unit avatar, tinted by status
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DesignTypography.labelSmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name + unit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DesignTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: DesignColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'You',
                                  style: DesignTypography.labelSmall.copyWith(
                                    color: DesignColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTypography.labelSmall.copyWith(
                            color: context.text.tertiary,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Amount + status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        inr.format(displayAmount),
                        style: DesignTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isPaid
                              ? DesignColors.success
                              : hasNoPayment
                                  ? accent
                                  : context.text.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: DesignTypography.labelSmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Thin paid-vs-expected bar flush to the card's bottom edge.
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: context.surface.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ],
        ),
      ),
    );
  }
}
