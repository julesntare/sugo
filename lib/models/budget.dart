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

  Budget({
    required this.id,
    required this.title,
    required this.amount,
    required this.start,
    required this.end,
    List<BudgetItem>? items,
    Map<String, Map<String, bool>>? checklist,
  }) : items = List<BudgetItem>.from(items ?? <BudgetItem>[]),
       checklist = checklist ?? {};

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
    double total = 0.0;
    for (final it in items) {
      total += _deductionForItemInMonth(it, monthKey);
    }
    // subtract checked items in checklist for that month
    final monthChecks = checklist[monthKey];
    if (monthChecks != null) {
      for (final it in items) {
        if (monthChecks[it.id] == true) {
          total -= _deductionForItemInMonth(it, monthKey);
        }
      }
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
        if (sd.year == int.parse(parts[0]) && sd.month == int.parse(parts[1]))
          return amt;
      } catch (_) {
        return 0.0;
      }
      return 0.0;
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
