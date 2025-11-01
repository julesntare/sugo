import 'package:intl/intl.dart';
import 'budget_item.dart';
import 'sub_item.dart';

class Budget {
  final String id;
  final String title;
  final double amount;
  final DateTime start;
  final DateTime end;
  List<BudgetItem> items; // Changed to non-final for SQLite loading
  /// per-month checklist state: key YYYY-MM -> itemId -> checked
  final Map<String, Map<String, bool>> checklist;

  /// per-month completion dates: key YYYY-MM -> itemId -> ISO date (yyyy-MM-dd) when marked as completed
  final Map<String, Map<String, String>> completionDates;

  /// Optional per-month explicit salary date overrides: key YYYY-MM -> ISO date (yyyy-MM-dd)
  /// If present, this exact date is used as the salary/payment date for that month.
  final Map<String, String> monthSalaryOverrides;

  /// Optional per-month per-item date overrides: key YYYY-MM -> itemId -> ISO date (yyyy-MM-dd)
  final Map<String, Map<String, String>> monthItemOverrides;

  /// Optional per-month per-item amount overrides: key YYYY-MM -> itemId -> amount
  final Map<String, Map<String, double>> monthItemAmountOverrides;

  Budget({
    required this.id,
    required this.title,
    required this.amount,
    required this.start,
    required this.end,
    List<BudgetItem>? items,
    Map<String, Map<String, bool>>? checklist,
    Map<String, Map<String, String>>? completionDates,
    Map<String, String>? monthSalaryOverrides,
    Map<String, Map<String, String>>? monthItemOverridesParam,
    Map<String, Map<String, double>>? monthItemAmountOverridesParam,
  }) : items = List<BudgetItem>.from(items ?? <BudgetItem>[]),
       checklist = checklist ?? {},
       completionDates = completionDates ?? {},
       monthSalaryOverrides = monthSalaryOverrides ?? {},
       monthItemOverrides = monthItemOverridesParam ?? {},
       monthItemAmountOverrides = monthItemAmountOverridesParam ?? {};

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
      monthItemOverridesParam: {},
      monthItemAmountOverridesParam: {},
    );
  }

  /// Returns list of month keys between start and end inclusive, formatted as YYYY-MM
  /// Only includes months where the salary date range is valid
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
      final monthKey = fmt.format(d);
      // Only include this month if the salary date for this month is before or equal to budget end
      final salaryDate = salaryDateForMonth(monthKey);
      if (!salaryDate.isAfter(end)) {
        months.add(monthKey);
      }
      // advance to the first day of next month
      d = DateTime(d.year, d.month + 1, 1);
    }
    return months;
  }

  /// Compute expected deductions for a given month key (YYYY-MM)
  double deductionsForMonth(String monthKey) {
    // Get checklist for the month
    final monthChecks = checklist[monthKey];
    if (monthChecks == null) return 0.0;

    // Sum deductions for all items
    double total = 0.0;
    for (final it in items) {
      // For items with sub-items, calculate deductions based on checked sub-items
      // even if the parent item has no amount or is not checked
      if (it.hasSubItems && it.subItems.isNotEmpty) {
        final subItemsTotal = subItemTotalForMonthInChecklist(it.id, monthKey);
        total += subItemsTotal;
      } else {
        // For items without sub-items, only deduct if checked and has non-zero deduction
        final baseDeduction = _deductionForItemInMonth(it, monthKey);
        if (baseDeduction > 0.0 && monthChecks[it.id] == true) {
          total += baseDeduction;
        }
      }
    }
    return total;
  }

  double _deductionForItemInMonth(BudgetItem it, String monthKey) {
    // Amount to use for this month: per-month override (if any) falls back to item.amount
    final amt = monthItemAmountOverrides[monthKey]?[it.id] ?? it.amount ?? 0.0;
    // Date override (if any) for this item in this month
    final overrideForThisMonth = monthItemOverrides[monthKey]?[it.id];

    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Calculate the salary date range for this month
      final thisMonthSalary = salaryDateForMonth(monthKey);
      DateTime rangeStart = thisMonthSalary;

      final nextDate = DateTime(year, month + 1, 1);
      final nextKey =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
      final keys = monthKeys();
      DateTime rangeEnd;

      final isLast = keys.isNotEmpty && monthKey == keys.last;
      if (isLast) {
        rangeEnd = end;
      } else {
        final nextSalary = salaryDateForMonth(nextKey);
        rangeEnd = nextSalary.subtract(const Duration(days: 1));
      }

      if (it.frequency == 'monthly') {
        // Use override date if available, otherwise use item's start date
        final dateToCheck = overrideForThisMonth ?? it.startDate;
        if (dateToCheck == null) return amt;
        final sd = DateTime.parse(dateToCheck);
        // Monthly items apply if their start date is not after the range end
        return !sd.isAfter(rangeEnd) ? amt : 0.0;
      } else if (it.frequency == 'weekly') {
        // Use override date if available, otherwise use item's start date
        final weeklySdStr = overrideForThisMonth ?? it.startDate;
        if (weeklySdStr == null) return 0.0;
        final sd = DateTime.parse(weeklySdStr);
        if (sd.isAfter(rangeEnd)) return 0.0;
        // Find first occurrence >= rangeStart
        int offsetDays = rangeStart.difference(sd).inDays;
        int weeksOffset = 0;
        if (offsetDays > 0) {
          weeksOffset = (offsetDays + 6) ~/ 7;
        }
        DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
        if (firstOcc.isAfter(rangeEnd)) return 0.0;
        final remainingDays = rangeEnd.difference(firstOcc).inDays;
        final occurrences = 1 + (remainingDays ~/ 7);
        return amt * occurrences;
      } else {
        // once - check if the date falls within the salary range for this month
        final onceSdStr = overrideForThisMonth ?? it.startDate;
        if (onceSdStr == null) return 0.0;
        final sd = DateTime.parse(onceSdStr);
        // Item applies if its date is within the salary date range
        return (!sd.isBefore(rangeStart) && !sd.isAfter(rangeEnd)) ? amt : 0.0;
      }
    } catch (_) {
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

  /// Calculate total amount of sub-items for a specific budget item in a specific month based on frequency
  double subItemTotalForMonth(String itemId, String monthKey) {
    double total = 0.0;
    final budgetItem = items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => BudgetItem(id: '', name: ''),
    );

    // Only include sub-items that are applicable in the given month based on frequency
    for (final subItem in budgetItem.subItems) {
      if (_isSubItemApplicableInMonth(subItem, monthKey)) {
        total += subItem.amount;
      }
    }

    return total;
  }

  /// Determine if a sub-item is applicable in a specific month based on its frequency and start date
  /// Uses salary date range logic to match parent item behavior
  bool _isSubItemApplicableInMonth(SubItem subItem, String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Calculate the salary date range for this month
      final thisMonthSalary = salaryDateForMonth(monthKey);
      DateTime rangeStart = thisMonthSalary;

      final nextDate = DateTime(year, month + 1, 1);
      final nextKey =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
      final keys = monthKeys();
      DateTime rangeEnd;

      final isLast = keys.isNotEmpty && monthKey == keys.last;
      if (isLast) {
        rangeEnd = end;
      } else {
        final nextSalary = salaryDateForMonth(nextKey);
        rangeEnd = nextSalary.subtract(const Duration(days: 1));
      }

      if (subItem.frequency == 'once') {
        if (subItem.startDate != null) {
          final startDate = DateTime.parse(subItem.startDate!);
          // Once items apply if their date falls within the salary range
          return !startDate.isBefore(rangeStart) &&
              !startDate.isAfter(rangeEnd);
        }
        // Sub-items without a start date are treated as flexible/miscellaneous
        // They apply to any month (user decides when to mark them as completed)
        return true;
      } else if (subItem.frequency == 'weekly') {
        if (subItem.startDate != null) {
          final startDate = DateTime.parse(subItem.startDate!);
          if (startDate.isAfter(rangeEnd)) {
            return false; // Start date is after the range
          }

          // Find first occurrence >= rangeStart
          int offsetDays = rangeStart.difference(startDate).inDays;
          int weeksOffset = 0;
          if (offsetDays > 0) {
            weeksOffset = (offsetDays + 6) ~/ 7;
          }
          DateTime firstOcc = startDate.add(Duration(days: weeksOffset * 7));

          // Check if any occurrence falls within the range
          if (firstOcc.isAfter(rangeEnd)) {
            return false;
          }
          return true;
        }
        // Weekly sub-items without start date apply to all months
        return true;
      } else if (subItem.frequency == 'monthly') {
        if (subItem.startDate != null) {
          final startDate = DateTime.parse(subItem.startDate!);
          // Monthly items apply if their start date is not after the range end
          return !startDate.isAfter(rangeEnd);
        }
        // Monthly sub-items without start date apply to all months
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Calculate total amount of sub-items for a specific budget item in a specific month
  /// considering only those that are checked in the checklist
  double subItemTotalForMonthInChecklist(String itemId, String monthKey) {
    double total = 0.0;
    final budgetItem = items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => BudgetItem(id: '', name: ''),
    );

    // Get checklist for this month
    final monthChecklist = checklist[monthKey] ?? {};

    for (final subItem in budgetItem.subItems) {
      // Only include sub-items that are applicable in this month based on frequency
      if (!_isSubItemApplicableInMonth(subItem, monthKey)) {
        continue;
      }

      // Only count sub-items that are marked as completed/checked
      final checklistKey = 'subitem_${itemId}_${subItem.id}';
      if (monthChecklist.containsKey(checklistKey) &&
          monthChecklist[checklistKey] == true) {
        total += subItem.amount;
      }
    }

    return total;
  }

  /// Calculate remaining amount for a budget item after sub-items in a specific month
  double remainingAmountForItemInMonth(String itemId, String monthKey) {
    final budgetItem = items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => BudgetItem(id: '', name: '', amount: 0),
    );
    final itemAmountInMonth = _deductionForItemInMonth(budgetItem, monthKey);
    final subItemTotal = subItemTotalForMonth(itemId, monthKey);

    return itemAmountInMonth - subItemTotal;
  }

  /// Calculate the total amount of sub-items for a budget item in a month that have been 'completed'
  double completedSubItemsAmountForMonth(String itemId, String monthKey) {
    double total = 0.0;
    final budgetItem = items.firstWhere(
      (item) => item.id == itemId,
      orElse: () => BudgetItem(id: '', name: ''),
    );

    // Get checklist for this month
    final monthChecklist = checklist[monthKey] ?? {};

    for (final subItem in budgetItem.subItems) {
      // Only include sub-items that are applicable in this month based on frequency
      if (!_isSubItemApplicableInMonth(subItem, monthKey)) {
        continue;
      }

      // Check if this sub-item is marked as completed in the checklist
      // Use the naming convention: subitem_itemId_subItemId
      final checklistKey = 'subitem_${itemId}_${subItem.id}';
      if (monthChecklist[checklistKey] == true) {
        total += subItem.amount;
      }
    }

    return total;
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
        endDate = end;
      } else {
        final nextSalary = salaryDateForMonth(nextKey, cutoffDay: cutoffDay);
        endDate = nextSalary.subtract(const Duration(days: 1));
      }

      // Validate: if the range is invalid (end before start or same day), return empty string
      if (endDate.isBefore(startDate) || endDate.isAtSameMomentAs(startDate)) {
        return '';
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

  /// Calculate the remaining amount for a specific month
  /// This is the monthly salary allocation minus the deductions for that month
  double remainingForMonth(String monthKey) {
    final keys = monthKeys();
    if (keys.isEmpty) return 0.0;

    // Monthly salary = total budget / number of months
    final monthlySalary = amount / keys.length;

    // Remaining = monthly salary - deductions for this month
    final deductions = deductionsForMonth(monthKey);
    return monthlySalary - deductions;
  }

  /// Find the current active month key based on today's date and salary ranges
  /// Returns the month key whose salary range contains today's date
  /// If today is before the budget starts, returns the first month
  /// If today is after the budget ends, returns the last month
  String currentActiveMonthKey() {
    final now = DateTime.now();
    final keys = monthKeys();

    if (keys.isEmpty) return DateFormat('yyyy-MM').format(now);

    // If we're before the budget starts, return first month
    if (now.isBefore(start)) return keys.first;

    // If we're after the budget ends, return last month
    if (now.isAfter(end)) return keys.last;

    // Find which month range contains today
    for (int i = 0; i < keys.length; i++) {
      final monthKey = keys[i];
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Get the salary date range for this month
      final thisMonthSalary = salaryDateForMonth(monthKey);
      DateTime rangeStart = thisMonthSalary;

      // For the first month, use budget start if it's after salary date
      if (i == 0 && start.isAfter(thisMonthSalary)) {
        rangeStart = start;
      }

      // Calculate range end
      final isLast = i == keys.length - 1;
      DateTime rangeEnd;

      if (isLast) {
        rangeEnd = end;
      } else {
        final nextDate = DateTime(year, month + 1, 1);
        final nextKey = '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
        final nextSalary = salaryDateForMonth(nextKey);
        rangeEnd = nextSalary.subtract(const Duration(days: 1));
      }

      // Check if today falls within this range (inclusive)
      if (!now.isBefore(rangeStart) && !now.isAfter(rangeEnd)) {
        return monthKey;
      }
    }

    // Fallback: return the month key based on calendar month
    return DateFormat('yyyy-MM').format(now);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'checklist': checklist,
    'completionDates': completionDates,
    'monthSalaryOverrides': monthSalaryOverrides,
    'monthItemOverrides': monthItemOverrides,
    'monthItemAmountOverrides': monthItemAmountOverrides,
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
      completionDates:
          (json['completionDates'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as Map<String, dynamic>).map(
                (ik, iv) => MapEntry(ik, iv as String),
              ),
            ),
          ),
      monthSalaryOverrides:
          (json['monthSalaryOverrides'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ),
      monthItemOverridesParam:
          (json['monthItemOverrides'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as Map<String, dynamic>).map(
                (ik, iv) => MapEntry(ik, iv as String),
              ),
            ),
          ),
      monthItemAmountOverridesParam:
          (json['monthItemAmountOverrides'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              (v as Map<String, dynamic>).map(
                (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
              ),
            ),
          ),
    );
  }
}
