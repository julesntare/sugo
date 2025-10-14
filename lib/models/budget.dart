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
      if (it.monthlyAmount != null) total += it.monthlyAmount!;
      if (it.oneTimeAmount != null && it.oneTimeMonth == monthKey) {
        total += it.oneTimeAmount!;
      }
    }
    // subtract checked items in checklist for that month
    final monthChecks = checklist[monthKey];
    if (monthChecks != null) {
      for (final it in items) {
        if (monthChecks[it.id] == true) {
          // If item has monthlyAmount, reduce monthlyAmount; else reduce oneTimeAmount if month matches
          if (it.monthlyAmount != null) {
            total -= it.monthlyAmount!;
          } else if (it.oneTimeAmount != null && it.oneTimeMonth == monthKey) {
            total -= it.oneTimeAmount!;
          }
        }
      }
    }
    return total;
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
