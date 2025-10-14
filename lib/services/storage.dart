import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';

class Storage {
  static const _budgetsKey = 'sugo_budgets_v1';

  static Future<void> saveBudgets(List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final data = budgets.map((b) => b.toJson()).toList();
    await prefs.setString(_budgetsKey, jsonEncode(data));
  }

  static Future<List<Budget>> loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_budgetsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Budget.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
