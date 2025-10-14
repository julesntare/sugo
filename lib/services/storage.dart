import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import 'database_helper.dart';

class Storage {
  static const _checklistKey = 'sugo_checklists_v1';
  static final _db = DatabaseHelper.instance;

  /// Save a budget and its items
  static Future<void> saveBudget(Budget budget) async {
    await _db.insertBudget(budget);
    // Save all items for this budget
    for (var item in budget.items) {
      await _db.insertBudgetItem(budget.id, item);
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
    }
    return budget;
  }

  /// Load all budgets
  static Future<List<Budget>> loadBudgets() async {
    final budgets = await _db.getAllBudgets();
    // Load checklist states for all budgets
    for (var budget in budgets) {
      budget.checklist.addAll(await _loadChecklist(budget.id));
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

    // Update or insert each item
    for (var item in budget.items) {
      if (existingIds.contains(item.id)) {
        await _db.updateBudgetItem(item);
      } else {
        await _db.insertBudgetItem(budget.id, item);
      }
    }

    // Update checklist state
    await _saveChecklist(budget.id, budget.checklist);
  }

  /// Add a new item to a budget
  static Future<void> addBudgetItem(String budgetId, BudgetItem item) async {
    await _db.insertBudgetItem(budgetId, item);
  }

  /// Update an existing budget item
  static Future<void> updateBudgetItem(BudgetItem item) async {
    await _db.updateBudgetItem(item);
  }

  /// Delete a budget item
  static Future<void> deleteBudgetItem(String id) async {
    await _db.deleteBudgetItem(id);
  }

  // Helper methods for checklist persistence using SharedPreferences
  static Future<void> _saveChecklist(
    String budgetId,
    Map<String, Map<String, bool>> checklist,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_checklistKey}_$budgetId', jsonEncode(checklist));
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

  static Future<void> _deleteChecklist(String budgetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_checklistKey}_$budgetId');
  }
}
