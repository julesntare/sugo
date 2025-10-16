import 'package:intl/intl.dart';
import 'budget_item.dart';

class Budget {
  final String id;
  final String title;
  final double amount;
  final DateTime start;
  final DateTime end;
  List<BudgetItem> items; // Changed to non-final for SQLite loading
  /// per-month checklist state: key YYYY-MM -> itemId -> checked
  final Map<String, Map<String, bool>> checklist;

  /// Optional per-month explicit salary date overrides: key YYYY-MM -> ISO date (yyyy-MM-dd)
  /// If present, this exact date is used as the salary/payment date for that month.
  final Map<String, String> monthSalaryOverrides;

  Budget({
    required this.id,
    required this.title,
    required this.amount,
    required this.start,
    required this.end,
    List<BudgetItem>? items,
    Map<String, Map<String, bool>>? checklist,
    Map<String, String>? monthSalaryOverrides,
  }) : items = List<BudgetItem>.from(items ?? <BudgetItem>[]),
       checklist = checklist ?? {},
       monthSalaryOverrides = monthSalaryOverrides ?? {};

  // Convert Budget to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    };
  }

  // Create Budget from Map (SQLite row)
  static Budget fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      start: DateTime.parse(map['start']),
      end: DateTime.parse(map['end']),
      items: [], // Items will be loaded separately
      checklist: {}, // Checklist will be loaded from shared preferences
      monthSalaryOverrides: {},
    );
  }

  /// Returns list of month keys between start and end inclusive, formatted as YYYY-MM
  List<String> monthKeys() {
    final months = <String>[];
    final fmt = DateFormat('yyyy-MM');
    // Normalize to the first day of the month to avoid timezone/day differences
    DateTime d = DateTime(start.year, start.month, 1);
    DateTime endMonth = DateTime(end.year, end.month, 1);

    // If both dates are in the same calendar month, return that single month
    if (start.year == end.year && start.month == end.month) {
      return [fmt.format(DateTime(start.year, start.month, 1))];
    }

    // If end is before start, swap to avoid an empty or reversed range
    if (endMonth.isBefore(d)) {
      final tmp = d;
      d = endMonth;
      endMonth = tmp;
    }
    while (!d.isAfter(endMonth)) {
      months.add(fmt.format(d));
      // advance to the first day of next month
      d = DateTime(d.year, d.month + 1, 1);
    }
    return months;
  }

  /// Compute expected deductions for a given month key (YYYY-MM)
  double deductionsForMonth(String monthKey) {
    // Determine which items actually apply to this month (deduction > 0)
    final applicable = items
        .where((it) => _deductionForItemInMonth(it, monthKey) > 0.0)
        .toList();

    // If there are no applicable items, nothing to deduct
    if (applicable.isEmpty) return 0.0;

    // If checklist for the month is missing or any applicable item is not checked,
    // we consider the budget "yet to be checked" and do not reduce the budget.
    final monthChecks = checklist[monthKey];
    if (monthChecks == null) return 0.0;

    for (final it in applicable) {
      if (monthChecks[it.id] != true) {
        // At least one applicable item is unchecked -> skip reductions
        return 0.0;
      }
    }

    // All applicable items are checked: sum their deductions
    double total = 0.0;
    for (final it in applicable) {
      total += _deductionForItemInMonth(it, monthKey);
    }
    return total;
  }

  double _deductionForItemInMonth(BudgetItem it, String monthKey) {
    final amt = it.amount ?? 0.0;
    if (it.frequency == 'monthly') {
      // Applies once per month starting from startDate (if provided)
      if (it.startDate == null) return amt;
      try {
        final sd = DateTime.parse(it.startDate!);
        final keyDate = DateTime(
          int.parse(monthKey.split('-')[0]),
          int.parse(monthKey.split('-')[1]),
          1,
        );
        final lastDay = DateTime(
          keyDate.year,
          keyDate.month + 1,
          1,
        ).subtract(const Duration(days: 1));
        if (!sd.isAfter(lastDay)) return amt;
      } catch (_) {
        return amt;
      }
      return 0.0;
    } else if (it.frequency == 'weekly') {
      // Count number of weekly occurrences within the month for the recurring weekly amount
      if (it.startDate == null) return 0.0;
      try {
        final sd = DateTime.parse(it.startDate!);
        final parts = monthKey.split('-');
        final firstDay = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        final lastDay = DateTime(
          firstDay.year,
          firstDay.month + 1,
          1,
        ).subtract(const Duration(days: 1));
        if (sd.isAfter(lastDay)) return 0.0;
        // Find first occurrence >= firstDay
        int offsetDays = firstDay.difference(sd).inDays;
        int weeksOffset = 0;
        if (offsetDays > 0) {
          weeksOffset = (offsetDays + 6) ~/ 7;
        }
        DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
        if (firstOcc.isAfter(lastDay)) return 0.0;
        final remainingDays = lastDay.difference(firstOcc).inDays;
        final occurrences = 1 + (remainingDays ~/ 7);
        return amt * occurrences;
      } catch (_) {
        return 0.0;
      }
    } else {
      // once
      if (it.startDate == null) return 0.0;
      try {
        final sd = DateTime.parse(it.startDate!);
        final parts = monthKey.split('-');
        if (sd.year == int.parse(parts[0]) && sd.month == int.parse(parts[1])) {
          return amt;
        }
      } catch (_) {
        return 0.0;
      }
      return 0.0;
    }
  }

  /// Compute the salary/payment date for a given monthKey (YYYY-MM).
  /// Behaviour:
  /// - If an explicit override exists in `monthSalaryOverrides`, use that date.
  /// - Otherwise use the budget-level cutoff day (default 25) and adjust: if the day falls on
  ///   Saturday or Sunday, move it back to the previous Friday.
  /// - If the requested day is greater than the number of days in the month, it's clamped to the
  ///   month's last day and then adjusted for weekend accordingly.
  DateTime salaryDateForMonth(String monthKey, {int cutoffDay = 25}) {
    try {
      // If override exists, prefer full date override
      final override = monthSalaryOverrides[monthKey];
      if (override != null) return DateTime.parse(override);

      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // clamp cutoff to last day of month
      final firstOfNext = DateTime(year, month + 1, 1);
      final lastDay = firstOfNext.subtract(const Duration(days: 1)).day;
      final day = cutoffDay.clamp(1, lastDay);
      DateTime dt = DateTime(year, month, day);

      // If falls on weekend, move back to Friday
      if (dt.weekday == DateTime.saturday) {
        dt = dt.subtract(const Duration(days: 1));
      }
      if (dt.weekday == DateTime.sunday) {
        dt = dt.subtract(const Duration(days: 2));
      }
      return dt;
    } catch (_) {
      // fallback to first of month
      final parts = monthKey.split('-');
      final year = int.tryParse(parts[0]) ?? 1970;
      final month = int.tryParse(parts[1]) ?? 1;
      return DateTime(year, month, 1);
    }
  }

  /// Return a human-friendly label for the range between previous month's salary date and this
  /// month's salary date. Example: "24 Oct - 24 Nov".
  String monthRangeLabel(String monthKey, {int cutoffDay = 25}) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Determine start: normally the salary date for this month, but if this is the
      // first budget month and the budget start is after that salary date, use the budget start.
      final keys = monthKeys();
      final thisMonthSalary = salaryDateForMonth(
        monthKey,
        cutoffDay: cutoffDay,
      );
      DateTime startDate = thisMonthSalary;
      if (keys.isNotEmpty &&
          monthKey == keys.first &&
          start.isAfter(thisMonthSalary)) {
        startDate = start;
      }

      // Determine end as one day before the salary date for the next month
      final nextDate = DateTime(year, month + 1, 1);
      final nextKey =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
      DateTime endDate;

      // If this is the last month of the budget, end at budget.end
      final isLast = keys.isNotEmpty && monthKey == keys.last;
      if (isLast) {
        endDate = this.end;
      } else {
        final nextSalary = salaryDateForMonth(nextKey, cutoffDay: cutoffDay);
        endDate = nextSalary.subtract(const Duration(days: 1));
      }

      final startDay = _ordinal(startDate.day);
      final endDay = _ordinal(endDate.day);
      final startMon = DateFormat('MMM').format(startDate);
      final endMon = DateFormat('MMM').format(endDate);
      return '$startDay $startMon - $endDay $endMon';
    } catch (_) {
      return monthKey;
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  /// Remaining forecast after applying deductions up to and including monthKey
  double remainingUpTo(String monthKey) {
    final keys = monthKeys();
    double remaining = amount;
    for (final k in keys) {
      final ded = deductionsForMonth(k);
      remaining -= ded;
      if (k == monthKey) break;
    }
    return remaining;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'checklist': checklist,
  };

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <BudgetItem>[],
      checklist: (json['checklist'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Map<String, bool>.from(v as Map)),
      ),
    );
  }
}
