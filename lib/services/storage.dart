import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/sub_item.dart';
import 'database_helper.dart';

class Storage {
  static const _checklistKey = 'sugo_checklists_v1';
  static const _salaryOverridesKey = 'sugo_salary_overrides_v1';
  static final _db = DatabaseHelper.instance;

  /// Save a budget and its items
  static Future<void> saveBudget(Budget budget) async {
    await _db.insertBudget(budget);
    // Save all items for this budget
    for (var item in budget.items) {
      await _db.insertBudgetItem(budget.id, item);
      // Save all sub-items for this budget item
      for (var subItem in item.subItems) {
        await _db.insertSubItem(item.id, subItem);
      }
    }
    // Save checklist state to SharedPreferences
    await _saveChecklist(budget.id, budget.checklist);
  }

  /// Save multiple budgets
  static Future<void> saveBudgets(List<Budget> budgets) async {
    for (var budget in budgets) {
      await saveBudget(budget);
    }
  }

  /// Load a specific budget by ID
  static Future<Budget?> loadBudget(String id) async {
    final budget = await _db.getBudget(id);
    if (budget != null) {
      // Load checklist state from SharedPreferences
      budget.checklist.addAll(await _loadChecklist(id));
      // Load month salary overrides
      budget.monthSalaryOverrides.addAll(await _loadSalaryOverrides(id));
      // Load per-month per-item overrides (dates)
      budget.monthItemOverrides.addAll(await _loadItemOverrides(id));
      // Load per-month per-item amount overrides
      budget.monthItemAmountOverrides.addAll(
        await _loadItemAmountOverrides(id),
      );
      // Load monthly transfers
      budget.monthlyTransfers.addAll(await _loadMonthlyTransfers(id));
      // Load closed misc items
      budget.closedMiscItems.addAll(await _loadClosedMiscItems(id));
      // Load completion dates
      budget.completionDates.addAll(await _loadCompletionDates(id));

      // Load sub-items for each budget item
      for (var item in budget.items) {
        item.subItems = await _db.getSubItems(item.id);
      }
    }
    return budget;
  }

  /// Load all budgets
  static Future<List<Budget>> loadBudgets() async {
    final budgets = await _db.getAllBudgets();
    // Load checklist states for all budgets
    for (var budget in budgets) {
      budget.checklist.addAll(await _loadChecklist(budget.id));
      budget.monthSalaryOverrides.addAll(await _loadSalaryOverrides(budget.id));
      budget.monthItemOverrides.addAll(await _loadItemOverrides(budget.id));
      budget.monthItemAmountOverrides.addAll(
        await _loadItemAmountOverrides(budget.id),
      );
      // Load monthly transfers
      budget.monthlyTransfers.addAll(await _loadMonthlyTransfers(budget.id));
      // Load closed misc items
      budget.closedMiscItems.addAll(await _loadClosedMiscItems(budget.id));
      // Load completion dates
      budget.completionDates.addAll(await _loadCompletionDates(budget.id));

      // Load sub-items for each budget item
      for (var item in budget.items) {
        item.subItems = await _db.getSubItems(item.id);
      }
    }
    return budgets;
  }

  /// Delete a budget
  static Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    // Clean up checklist state
    await _deleteChecklist(id);
  }

  /// Update an existing budget
  static Future<void> updateBudget(Budget budget) async {
    await _db.updateBudget(budget);

    // First, get existing items to identify ones that need to be removed
    final existingItems = await _db.getBudgetItems(budget.id);
    final existingIds = existingItems.map((e) => e.id).toSet();
    final newIds = budget.items.map((e) => e.id).toSet();

    // Delete items that no longer exist in the budget
    for (var id in existingIds.difference(newIds)) {
      await _db.deleteBudgetItem(id);
    }

    // Update or insert each item and its sub-items
    for (var item in budget.items) {
      if (existingIds.contains(item.id)) {
        await _db.updateBudgetItem(item);
      } else {
        await _db.insertBudgetItem(budget.id, item);
      }

      // Handle sub-items for this budget item
      await _updateSubItemsForItem(item);
    }

    // Update checklist state
    await _saveChecklist(budget.id, budget.checklist);
    await _saveSalaryOverrides(budget.id, budget.monthSalaryOverrides);
    await _saveItemOverrides(budget.id, budget.monthItemOverrides);
    await _saveItemAmountOverrides(budget.id, budget.monthItemAmountOverrides);
    await _saveMonthlyTransfers(budget.id, budget.monthlyTransfers);
    await _saveClosedMiscItems(budget.id, budget.closedMiscItems);
    await _saveCompletionDates(budget.id, budget.completionDates);
  }

  /// Update sub-items for a budget item
  static Future<void> _updateSubItemsForItem(BudgetItem item) async {
    // Get existing sub-items to identify ones that need to be removed
    final existingSubItems = await _db.getSubItems(item.id);
    final existingSubIds = existingSubItems.map((e) => e.id).toSet();
    final newSubIds = item.subItems.map((e) => e.id).toSet();

    // Delete sub-items that no longer exist in the budget item
    final toDelete = existingSubIds.difference(newSubIds);
    for (var id in toDelete) {
      await _db.deleteSubItem(id);
    }

    // Update or insert each sub-item
    for (var subItem in item.subItems) {
      if (existingSubIds.contains(subItem.id)) {
        await _db.updateSubItem(subItem);
      } else {
        await _db.insertSubItem(item.id, subItem);
      }
    }
  }

  /// Add a new item to a budget
  static Future<void> addBudgetItem(String budgetId, BudgetItem item) async {
    await _db.insertBudgetItem(budgetId, item);
  }

  /// Update an existing budget item
  static Future<void> updateBudgetItem(BudgetItem item) async {
    await _db.updateBudgetItem(item);
    // IMPORTANT: Also update sub-items!
    await _updateSubItemsForItem(item);
  }

  /// Delete a budget item
  static Future<void> deleteBudgetItem(String id) async {
    await _db.deleteBudgetItem(id);
  }

  /// Add a new sub-item to a budget item
  static Future<void> addSubItem(String budgetItemId, SubItem subItem) async {
    await _db.insertSubItem(budgetItemId, subItem);
  }

  /// Update an existing sub-item
  static Future<void> updateSubItem(SubItem subItem) async {
    await _db.updateSubItem(subItem);
  }

  /// Delete a sub-item
  static Future<void> deleteSubItem(String id) async {
    await _db.deleteSubItem(id);
  }

  // Helper methods for checklist persistence using SharedPreferences
  static Future<void> _saveChecklist(
    String budgetId,
    Map<String, Map<String, bool>> checklist,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_checklistKey}_$budgetId', jsonEncode(checklist));
  }

  static Future<void> _saveSalaryOverrides(
    String budgetId,
    Map<String, String> overrides,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_$budgetId',
      jsonEncode(overrides),
    );
  }

  static Future<Map<String, Map<String, bool>>> _loadChecklist(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_checklistKey}_$budgetId');
    if (raw == null) return {};

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _loadSalaryOverrides(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_salaryOverridesKey}_$budgetId');
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveItemOverrides(
    String budgetId,
    Map<String, Map<String, String>> overrides,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_items_$budgetId',
      jsonEncode(overrides),
    );
  }

  static Future<Map<String, Map<String, String>>> _loadItemOverrides(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_salaryOverridesKey}_items_$budgetId');
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (ik, iv) => MapEntry(ik, iv as String),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveItemAmountOverrides(
    String budgetId,
    Map<String, Map<String, double>> overrides,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_item_amounts_$budgetId',
      jsonEncode(overrides),
    );
  }

  static Future<Map<String, Map<String, double>>> _loadItemAmountOverrides(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${_salaryOverridesKey}_item_amounts_$budgetId',
    );
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMonthlyTransfers(
    String budgetId,
    Map<String, Map<String, double>> transfers,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_monthly_transfers_$budgetId',
      jsonEncode(transfers),
    );
  }

  static Future<Map<String, Map<String, double>>> _loadMonthlyTransfers(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${_salaryOverridesKey}_monthly_transfers_$budgetId',
    );
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (ik, iv) => MapEntry(ik, (iv as num).toDouble()),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveClosedMiscItems(
    String budgetId,
    Map<String, Map<String, bool>> closedItems,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_closed_misc_items_$budgetId',
      jsonEncode(closedItems),
    );
  }

  static Future<Map<String, Map<String, bool>>> _loadClosedMiscItems(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${_salaryOverridesKey}_closed_misc_items_$budgetId',
    );
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (ik, iv) => MapEntry(ik, iv as bool),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveCompletionDates(
    String budgetId,
    Map<String, Map<String, String>> completionDates,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_salaryOverridesKey}_completion_dates_$budgetId',
      jsonEncode(completionDates),
    );
  }

  static Future<Map<String, Map<String, String>>> _loadCompletionDates(
    String budgetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${_salaryOverridesKey}_completion_dates_$budgetId',
    );
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).map(
            (ik, iv) => MapEntry(ik, iv as String),
          ),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _deleteChecklist(String budgetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_checklistKey}_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_items_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_item_amounts_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_monthly_transfers_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_closed_misc_items_$budgetId');
    await prefs.remove('${_salaryOverridesKey}_completion_dates_$budgetId');
  }
}
