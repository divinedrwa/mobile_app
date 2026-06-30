/// Per-resident view of society expenses for a billing cycle.
///
/// - [residentExpectedAmount] = your fixed maintenance (admin snapshot / cycle).
/// - Each category share = society total ÷ [expenseDivisor] (billed homes).
/// - Reserve = your maintenance − your expense shares.
class ExpenseBreakdown {
  const ExpenseBreakdown({
    required this.month,
    required this.year,
    required this.total,
    required this.categories,
    this.memberCount = 0,
    this.expenseDivisor = 0,
    this.totalExpected = 0,
    this.residentExpectedAmount = 0,
    this.billingCycleId,
  });

  final int month;
  final int year;
  final double total;
  final List<ExpenseCategory> categories;
  final int memberCount;
  final int expenseDivisor;
  final double totalExpected;
  final double residentExpectedAmount;
  final String? billingCycleId;

  bool get hasData => categories.isNotEmpty && total > 0;
  bool get hasMemberSplit => _splitDivisor > 0;

  int get _splitDivisor =>
      expenseDivisor > 0 ? expenseDivisor : (memberCount > 0 ? memberCount : 0);

  double get categoriesTotal =>
      categories.fold<double>(0, (acc, c) => acc + c.amount);

  double get perMemberTotal {
    final d = _splitDivisor;
    return d > 0 ? categoriesTotal / d : categoriesTotal;
  }

  double get perHomeExpected {
    if (residentExpectedAmount > 0) return residentExpectedAmount;
    final d = _splitDivisor;
    return d > 0 && totalExpected > 0 ? totalExpected / d : 0;
  }

  double shareOfCategory(ExpenseCategory category) {
    final d = _splitDivisor;
    return d > 0 ? category.amount / d : category.amount;
  }

  double get perHomeSavings {
    final s = perHomeExpected - perMemberTotal;
    return s > 0 ? s : 0;
  }

  double get perHomeDeficit {
    final s = perMemberTotal - perHomeExpected;
    return s > 0 ? s : 0;
  }

  ExpenseBreakdown copyWith({
    int? memberCount,
    int? expenseDivisor,
    double? totalExpected,
    double? residentExpectedAmount,
    String? billingCycleId,
  }) =>
      ExpenseBreakdown(
        month: month,
        year: year,
        total: total,
        categories: categories,
        memberCount: memberCount ?? this.memberCount,
        expenseDivisor: expenseDivisor ?? this.expenseDivisor,
        totalExpected: totalExpected ?? this.totalExpected,
        residentExpectedAmount:
            residentExpectedAmount ?? this.residentExpectedAmount,
        billingCycleId: billingCycleId ?? this.billingCycleId,
      );

  factory ExpenseBreakdown.empty() =>
      const ExpenseBreakdown(month: 0, year: 0, total: 0, categories: []);

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

    final summary = dashboard['residentsSummary'];
    final memberCount = summary is Map
        ? (summary['totalResidents'] as num?)?.toInt() ?? 0
        : 0;
    final totalExpected = summary is Map
        ? dv(summary['totalExpectedCollection'])
        : 0.0;

    int expenseDivisor = summary is Map
        ? (summary['billedHomesCount'] as num?)?.toInt() ?? 0
        : 0;
    if (expenseDivisor <= 0 && dashboard['residents'] is List) {
      expenseDivisor = (dashboard['residents'] as List)
          .whereType<Map>()
          .where((r) => dv(r['amount']) > 0)
          .length;
    }
    if (expenseDivisor <= 0) expenseDivisor = memberCount;

    final userSummary = dashboard['userSummary'];
    double residentExpected = userSummary is Map
        ? dv(userSummary['expectedAmount'])
        : 0.0;
    if (residentExpected <= 0 && dashboard['residents'] is List) {
      final villaId = userSummary is Map ? userSummary['villaId']?.toString() : null;
      if (villaId != null && villaId.isNotEmpty) {
        for (final raw in dashboard['residents'] as List) {
          if (raw is! Map) continue;
          if (raw['residentId']?.toString() == villaId ||
              raw['villaId']?.toString() == villaId) {
            residentExpected = dv(raw['amount']);
            break;
          }
        }
      }
    }

    ExpenseBreakdown build({
      required int month,
      required int year,
      required double total,
      required List<ExpenseCategory> categories,
    }) =>
        ExpenseBreakdown(
          month: month,
          year: year,
          total: total,
          categories: categories,
          memberCount: memberCount,
          expenseDivisor: expenseDivisor,
          totalExpected: totalExpected,
          residentExpectedAmount: residentExpected,
        );

    final block = dashboard['monthlyExpenseBreakdown'];
    if (block is Map) {
      final categories = parseCategories(block['categoryBreakdown']);
      if (categories.isNotEmpty) {
        return build(
          month: (block['month'] as num?)?.toInt() ?? 0,
          year: (block['year'] as num?)?.toInt() ?? 0,
          total: dv(block['totalExpenses']),
          categories: categories,
        );
      }
    }

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
          final candidate = build(
            month: month,
            year: year,
            total: dv(item['totalExpense']),
            categories: categories,
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

    return ExpenseBreakdown.empty().copyWith(
      memberCount: memberCount,
      expenseDivisor: expenseDivisor,
      totalExpected: totalExpected,
      residentExpectedAmount: residentExpected,
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({required this.name, required this.amount});

  final String name;
  final double amount;

  double percentOf(double parentTotal) =>
      parentTotal <= 0 ? 0 : (amount / parentTotal) * 100;

  double perMember(int memberCount) =>
      memberCount > 0 ? amount / memberCount : amount;
}
