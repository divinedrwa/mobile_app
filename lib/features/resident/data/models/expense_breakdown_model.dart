/// Society expense split for a single billing cycle, plus the number of
/// paying members it's shared across — used by the "Where your money goes"
/// card to show each resident's per-member share of every expense category.
///
/// Per-member share = category amount ÷ [memberCount] (the count of billed,
/// non-excluded villas for the cycle). Sourced from the resident
/// maintenance-dashboard response (`monthlyExpenseBreakdown` / `yearlyBreakdown`
/// for amounts, `residentsSummary.totalResidents` for the member count).
class ExpenseBreakdown {
  const ExpenseBreakdown({
    required this.month,
    required this.year,
    required this.total,
    required this.categories,
    this.memberCount = 0,
    this.totalExpected = 0,
    this.billingCycleId,
  });

  final int month;
  final int year;

  /// Total society expenses for the month (`totalExpenses`).
  final double total;

  /// Category → amount (society totals), filtered positive, sorted desc.
  final List<ExpenseCategory> categories;

  /// Number of billed members the cost is divided across (0 = unknown).
  final int memberCount;

  /// Total maintenance the society expects to collect for the cycle
  /// (`residentsSummary.totalExpectedCollection`) = per-home amount × members.
  final double totalExpected;

  /// Billing cycle id this breakdown belongs to, when known.
  final String? billingCycleId;

  bool get hasData => categories.isNotEmpty && total > 0;

  /// True when we can compute a per-member share.
  bool get hasMemberSplit => memberCount > 0;

  /// Sum of the individual category amounts (society totals).
  double get categoriesTotal =>
      categories.fold<double>(0, (acc, c) => acc + c.amount);

  /// The resident's total expense share across all categories.
  double get perMemberTotal =>
      memberCount > 0 ? categoriesTotal / memberCount : categoriesTotal;

  /// The per-home maintenance amount the resident pays for the cycle.
  double get perHomeExpected =>
      memberCount > 0 ? totalExpected / memberCount : 0;

  /// What's left of the resident's maintenance after expenses — saved toward
  /// common society reserves. Never negative.
  double get perHomeSavings {
    final s = perHomeExpected - perMemberTotal;
    return s > 0 ? s : 0;
  }

  ExpenseBreakdown copyWith(
          {int? memberCount, double? totalExpected, String? billingCycleId}) =>
      ExpenseBreakdown(
        month: month,
        year: year,
        total: total,
        categories: categories,
        memberCount: memberCount ?? this.memberCount,
        totalExpected: totalExpected ?? this.totalExpected,
        billingCycleId: billingCycleId ?? this.billingCycleId,
      );

  factory ExpenseBreakdown.empty() =>
      const ExpenseBreakdown(month: 0, year: 0, total: 0, categories: []);

  /// Parses a maintenance-dashboard response into a breakdown.
  ///
  /// [allowFallback] (default true): when the selected month has no expenses
  /// recorded yet, fall back to the most recent month in `yearlyBreakdown`
  /// that does. Pass false when the caller picked a specific cycle and wants
  /// that cycle's data verbatim (even if empty).
  factory ExpenseBreakdown.fromDashboard(
    Map<String, dynamic> dashboard, {
    bool allowFallback = true,
  }) {
    double dv(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    List<ExpenseCategory> parseCategories(dynamic raw) {
      final out = <ExpenseCategory>[];
      if (raw is Map) {
        for (final entry in raw.entries) {
          final amount = dv(entry.value);
          if (amount > 0) {
            out.add(ExpenseCategory(name: entry.key.toString(), amount: amount));
          }
        }
      }
      out.sort((a, b) => b.amount.compareTo(a.amount));
      return out;
    }

    // Member count + expected collection are society-level (the cycle's billed
    // villas) and apply regardless of which month's expenses we end up showing.
    final summary = dashboard['residentsSummary'];
    final memberCount = summary is Map
        ? (summary['totalResidents'] as num?)?.toInt() ?? 0
        : 0;
    final totalExpected = summary is Map
        ? dv(summary['totalExpectedCollection'])
        : 0.0;

    // 1) Preferred: the selected month's breakdown.
    final block = dashboard['monthlyExpenseBreakdown'];
    if (block is Map) {
      final categories = parseCategories(block['categoryBreakdown']);
      if (categories.isNotEmpty) {
        return ExpenseBreakdown(
          month: (block['month'] as num?)?.toInt() ?? 0,
          year: (block['year'] as num?)?.toInt() ?? 0,
          total: dv(block['totalExpenses']),
          categories: categories,
          memberCount: memberCount,
          totalExpected: totalExpected,
        );
      }
    }

    // 2) Fallback: latest month in yearlyBreakdown that has a breakdown.
    if (allowFallback) {
      final yearly = dashboard['yearlyBreakdown'];
      if (yearly is List) {
        ExpenseBreakdown? best;
        for (final item in yearly) {
          if (item is! Map) continue;
          final categories = parseCategories(item['expenseBreakdown']);
          if (categories.isEmpty) continue;
          final month = (item['month'] as num?)?.toInt() ?? 0;
          final year = (item['year'] as num?)?.toInt() ?? 0;
          final candidate = ExpenseBreakdown(
            month: month,
            year: year,
            total: dv(item['totalExpense']),
            categories: categories,
            memberCount: memberCount,
            totalExpected: totalExpected,
          );
          if (best == null ||
              year > best.year ||
              (year == best.year && month > best.month)) {
            best = candidate;
          }
        }
        if (best != null) return best;
      }
    }

    return ExpenseBreakdown.empty()
        .copyWith(memberCount: memberCount, totalExpected: totalExpected);
  }
}

class ExpenseCategory {
  const ExpenseCategory({required this.name, required this.amount});

  final String name;

  /// Society total spent on this category for the cycle.
  final double amount;

  /// Share of [parentTotal] as a 0–100 percentage.
  double percentOf(double parentTotal) =>
      parentTotal <= 0 ? 0 : (amount / parentTotal) * 100;

  /// This resident's share of the category (society amount ÷ members).
  double perMember(int memberCount) =>
      memberCount > 0 ? amount / memberCount : amount;
}
