part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOverviewTabPart on _MaintenancePaymentScreenState {
  Widget _buildOverviewTab(
    BuildContext context,
    Map<String, dynamic> userSummary,
    Map<String, dynamic> residentsSummary,
    Map<String, dynamic> expenses,
    List<Map<String, dynamic>> residents,
    String periodLabel,
    int periodMonth,
    int periodYear,
  ) {
    final inr = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    double dn(String key) =>
        (userSummary[key] as num?)?.toDouble() ?? 0;

    // Only the current personal balance is surfaced here now — the full ledger
    // lives on the My payments tab + the dues screen (see slim strip below).
    final remaining = dn('remainingDue');

    // Society-level summary numbers
    final totalResidents =
        (residentsSummary['totalResidents'] as num?)?.toInt() ?? residents.length;
    final paidCount = (residentsSummary['paidCount'] as num?)?.toInt() ??
        residents.where((r) => (r['status']?.toString() ?? '').toUpperCase() == 'PAID').length;
    final unpaidCount = (residentsSummary['unpaidCount'] as num?)?.toInt() ??
        (totalResidents - paidCount);
    final partialCount = (residentsSummary['partialCount'] as num?)?.toInt() ?? 0;
    final overdueCount = (residentsSummary['overdueCount'] as num?)?.toInt() ?? 0;
    final totalCollected =
        (residentsSummary['totalCollected'] as num?)?.toDouble() ?? 0;
    final totalExpected =
        (residentsSummary['totalExpectedCollection'] as num?)?.toDouble() ?? 0;
    final totalPending =
        (residentsSummary['totalPending'] as num?)?.toDouble() ?? 0;
    final totalExpense =
        (expenses['totalExpenses'] as num?)?.toDouble() ?? 0;
    final net = totalCollected - totalExpense;

    // Sort residents: unpaid/overdue first, then paid
    final sortedResidents = [...residents]..sort((a, b) {
      const order = {'OVERDUE': 0, 'PARTIAL': 1, 'UNPAID': 2, 'PENDING': 3, 'PAID': 4};
      final sa = order[(a['status']?.toString() ?? 'UNPAID').toUpperCase()] ?? 2;
      final sb = order[(b['status']?.toString() ?? 'UNPAID').toUpperCase()] ?? 2;
      if (sa != sb) return sa.compareTo(sb);
      final aa = (a['paidTowardCycle'] as num?)?.toDouble() ?? 0;
      final ab = (b['paidTowardCycle'] as num?)?.toDouble() ?? 0;
      return ab.compareTo(aa);
    });

    // Apply the All-residents search + status filter for the list below.
    final q = _residentQuery.trim().toLowerCase();
    final visibleResidents = sortedResidents.where((r) {
      final st = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
      final matchStatus = _residentStatusFilter == 'ALL' ||
          (_residentStatusFilter == 'UNPAID' &&
              (st == 'UNPAID' || st == 'PENDING')) ||
          st == _residentStatusFilter;
      if (!matchStatus) return false;
      if (q.isEmpty) return true;
      final name =
          '${r['name'] ?? r['ownerName'] ?? ''}'.toLowerCase();
      final unit =
          '${r['flatNumber'] ?? r['villaNumber'] ?? ''}'.toLowerCase();
      return name.contains(q) || unit.contains(q);
    }).toList();

    // Pin the logged-in user's own villa to the top of the list.
    final myVilla = ref
        .watch(authProvider.select((s) => s.user?.villaNumber))
        ?.trim()
        .toLowerCase();
    if (myVilla != null && myVilla.isNotEmpty) {
      final meIdx = visibleResidents.indexWhere((r) =>
          '${r['villaNumber'] ?? r['flatNumber'] ?? ''}'
              .trim()
              .toLowerCase() ==
          myVilla);
      if (meIdx > 0) {
        visibleResidents.insert(0, visibleResidents.removeAt(meIdx));
      }
    }

    return _wrapTabWithRefresh(
      CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              _buildOverviewDuesStrip(remaining, inr),
          _collectionsHeroCard(
            periodLabel: periodLabel,
            totalExpected: totalExpected,
            totalCollected: totalCollected,
            totalPending: totalPending,
            totalExpense: totalExpense,
            net: net,
            paidCount: paidCount,
            partialCount: partialCount,
            unpaidCount: unpaidCount,
            overdueCount: overdueCount,
            inr: inr,
            onExpensesTap: () =>
                _openSocietyExpenses(month: periodMonth, year: periodYear),
          ),
          _buildOverviewAdvanceSection(residents, inr),
          _buildOverviewExpenseSection(
            expenses,
            totalExpense,
            totalResidents,
            periodLabel,
            periodMonth,
            periodYear,
            inr,
          ),
            ]),
          ),
          ..._buildOverviewResidentsSlivers(
            sortedResidents: sortedResidents,
            visibleResidents: visibleResidents,
            myVilla: myVilla,
            paidCount: paidCount,
            totalResidents: totalResidents,
            inr: inr,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
