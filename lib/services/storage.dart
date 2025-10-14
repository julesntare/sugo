import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';

class Storage {
  static const _budgetsKey = 'sugo_budgets_v1';
  static const _hiveBox = 'budgets';

  /// Save budgets. Prefers Hive box when available; otherwise falls back to SharedPreferences.
  static Future<void> saveBudgets(List<Budget> budgets) async {
    try {
      final box = Hive.isBoxOpen(_hiveBox)
          ? Hive.box(_hiveBox)
          : await Hive.openBox(_hiveBox);
      await box.put('data', budgets.map((b) => b.toJson()).toList());
      return;
    } catch (_) {
      // fallback to SharedPreferences
    }

    final prefs = await SharedPreferences.getInstance();
    final data = budgets.map((b) => b.toJson()).toList();
    await prefs.setString(_budgetsKey, jsonEncode(data));
  }

  /// Load budgets. If Hive is available and contains data, use it. Otherwise try SharedPreferences.
  static Future<List<Budget>> loadBudgets() async {
    try {
      if (Hive.isBoxOpen(_hiveBox)) {
        final box = Hive.box(_hiveBox);
        final raw = box.get('data');
        if (raw is List) {
          return raw
              .map((e) => Budget.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
        }
      } else {
        // attempt to open the box; if it fails, we'll fallback
        try {
          final box = await Hive.openBox(_hiveBox);
          final raw = box.get('data');
          if (raw is List) {
            return raw
                .map((e) => Budget.fromJson((e as Map).cast<String, dynamic>()))
                .toList();
          }
        } catch (_) {}
      }
    } catch (_) {}

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
