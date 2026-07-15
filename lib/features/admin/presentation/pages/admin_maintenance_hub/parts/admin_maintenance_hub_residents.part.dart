part of '../admin_maintenance_hub_screen.dart';

extension _AdminMaintenanceHubResidentsPart on _AdminMaintenanceHubScreenState {
  // ---- reminder button (inline in residents section) ----

  Widget _reminderButton(List<Map<String, dynamic>> pendingList) {
    final count = _selectedVillaIds.length;
    final isBulk = _allSelected(pendingList);

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: DesignColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignRadius.lg),
          ),
        ),
        onPressed: _sendingReminders || count == 0 ? null : _onSendReminders,
        icon: _sendingReminders
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.notifications_active_outlined, size: 18),
        label: Text(
          _sendingReminders
              ? 'Sending...'
              : isBulk
                  ? 'Send reminder to all ($count)'
                  : 'Send reminder to $count selected',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
  Widget _residentsSection(Map<String, dynamic> data) {
    final residents = ((data['residents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['isExcluded'] != true)
        .toList();

    if (residents.isEmpty) {
      return _emptyResidents();
    }

    // Prepare pending residents for selection.
    final pendingList = _pendingResidents(data);
    _initSelection(pendingList);

    final paid = <Map<String, dynamic>>[];
    final partial = <Map<String, dynamic>>[];
    final pending = <Map<String, dynamic>>[];
    final overdue = <Map<String, dynamic>>[];
    for (final r in residents) {
      final s = (r['status']?.toString() ?? 'PENDING').toUpperCase();
      if (s == 'PAID') {
        paid.add(r);
      } else if (s == 'PARTIAL') {
        partial.add(r);
      } else if (s == 'OVERDUE') {
        overdue.add(r);
      } else {
        pending.add(r);
      }
    }

    final hasPending = pendingList.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + select all ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                'Residents',
                style: DesignTypography.headingM.copyWith(
                  color: DesignColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (hasPending)
                GestureDetector(
                  onTap: () => _toggleAll(pendingList),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _allSelected(pendingList),
                          onChanged: (_) => _toggleAll(pendingList),
                          activeColor: DesignColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Select all',
                        style: DesignTypography.captionSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (overdue.isNotEmpty)
          _statusGroup(label: 'Overdue', residents: overdue, status: PaymentTileStatus.overdue, selectable: true),
        if (pending.isNotEmpty)
          _statusGroup(label: 'Pending', residents: pending, status: PaymentTileStatus.pending, selectable: true),
        if (partial.isNotEmpty)
          _statusGroup(label: 'Partial', residents: partial, status: PaymentTileStatus.partial, selectable: true),
        if (paid.isNotEmpty)
          _statusGroup(label: 'Paid', residents: paid, status: PaymentTileStatus.paid, selectable: false),

        // ── Send reminder button ──
        if (hasPending) ...[
          const SizedBox(height: AppSpacing.lg),
          _reminderButton(pendingList),
        ],
      ],
    );
  }

  Widget _statusGroup({
    required String label,
    required List<Map<String, dynamic>> residents,
    required PaymentTileStatus status,
    bool selectable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AdminMaintenanceCollapsibleGroup(
        label: label,
        count: residents.length,
        child: Column(
          children: [
            for (var i = 0; i < residents.length; i++) ...[
              _residentRow(residents[i], status, selectable: selectable, index: i),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  bool get _isAdmin =>
      ref.read(authProvider).user?.role.isAdminLike ?? false;

  Widget _residentRow(
    Map<String, dynamic> r,
    PaymentTileStatus status, {
    bool selectable = false,
    int index = 0,
  }) {
    final inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final villaNumber = r['villaNumber']?.toString() ?? '—';
    final villaId = r['villaId']?.toString() ?? '';
    final ownerName = r['ownerName']?.toString() ?? 'Unknown';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final paidToward = (r['paidTowardCycle'] as num?)?.toDouble();
    final advanceCredit = (r['advanceCredit'] as num?)?.toDouble() ?? 0;
    final dueDate = DateTime.tryParse(r['dueDate']?.toString() ?? '');
    final paidAt = DateTime.tryParse(r['paidAt']?.toString() ?? '');

    final isAdmin = _isAdmin;
    final actionable = isAdmin &&
        (status == PaymentTileStatus.pending ||
            status == PaymentTileStatus.overdue ||
            status == PaymentTileStatus.partial);

    String subtitle;
    if (paidToward != null && paidToward > 0) {
      subtitle = '$ownerName · ${inr.format(paidToward)} of ${inr.format(amount)}';
    } else {
      subtitle = ownerName;
    }
    if (advanceCredit > 0) {
      subtitle += ' · Credit: ${inr.format(advanceCredit)}';
    }

    final isSelected = selectable && villaId.isNotEmpty && _selectedVillaIds.contains(villaId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (selectable && villaId.isNotEmpty) ...[
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleVilla(villaId),
              activeColor: DesignColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: GestureDetector(
            onLongPress: isAdmin ? () => _showRowMenu(r) : null,
            child: PaymentListTile(
              title: 'Villa $villaNumber',
              subtitle: subtitle,
              amount: amount,
              status: status,
              dueDate: status == PaymentTileStatus.paid ? null : dueDate,
              paidDate: status == PaymentTileStatus.paid ? paidAt : null,
              actionLabel: actionable ? 'Actions' : null,
              onAction: actionable ? () => _openMarkCashSheet(r) : null,
            ),
          ),
        ),
      ],
    ).animate(delay: DesignAnimations.staggerFor(index)).fadeIn(duration: 200.ms).slideY(begin: DesignAnimations.slideSubtle, curve: DesignAnimations.curveEntrance);
  }

  void _showRowMenu(Map<String, dynamic> resident) {
    final villaId = resident['villaId']?.toString() ?? '';
    final villaNumber = resident['villaNumber']?.toString() ?? '—';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Villa $villaNumber', style: DesignTypography.headingM.copyWith(fontWeight: FontWeight.w700)),
              ),
              SizedBox(height: 12),
              _sheetAction(ctx, icon: Icons.edit_outlined, color: DesignColors.primary, label: 'Edit amounts',
                  onTap: () { Navigator.pop(ctx); _openEditVillaRowSheet(resident); }),
              Divider(height: 1),
              _sheetAction(ctx, icon: Icons.history_rounded, color: DesignColors.secondary, label: 'Payment history',
                  onTap: () { Navigator.pop(ctx); if (villaId.isNotEmpty) context.go('/resident/admin-villa-history/$villaId'); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetAction(BuildContext ctx, {required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DesignColors.textPrimary)),
            Spacer(),
            Icon(Icons.chevron_right_rounded, color: DesignColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openMarkCashSheet(Map<String, dynamic> resident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminMaintenancePaymentActionsSheet(resident: resident),
    );
    ref.invalidate(adminMaintenanceDashboardProvider);
  }

  Future<void> _openEditVillaRowSheet(Map<String, dynamic> resident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminMaintenanceEditVillaRowSheet(resident: resident),
    );
    ref.invalidate(adminMaintenanceDashboardProvider);
  }

  Widget _emptyResidents() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'No residents in this period',
        subtitle: 'Generate snapshots for the cycle from the detailed finance view to populate this list.',
      ),
    );
  }

  Widget _errorTile(String label) {
    return EnterpriseInfoBanner(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      message: '$label. Pull down to retry.',
      tone: EnterpriseTone.danger,
    );
  }
}
