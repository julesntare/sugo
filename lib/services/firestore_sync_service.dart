import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/sub_item.dart';
import 'storage.dart';

class FirestoreSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sync daily totals from Firestore to the local app
  /// Returns a message indicating the sync result
  static Future<String> syncDailyTotals(Budget budget) async {
    try {
      // Get today's date in YYYY-MM-DD format
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      // Fetch document from Firestore
      final docRef = _firestore.collection('daily_totals').doc(dateKey);
      final docSnapshot = await docRef.get();

      // If document doesn't exist, skip
      if (!docSnapshot.exists) {
        return 'No data found for today';
      }

      // Extract data
      final data = docSnapshot.data();
      if (data == null || !data.containsKey('total')) {
        return 'Invalid data structure';
      }

      // Parse total amount, cleaning any unexpected string values
      double total;
      final totalValue = data['total'];
      if (totalValue is num) {
        total = totalValue.toDouble();
      } else if (totalValue is String) {
        // Clean any newlines, whitespace, or text from string values
        final cleanValue = totalValue.replaceAll(RegExp(r'[\n\r\t\s,]'), '');
        total = double.tryParse(cleanValue) ?? 0.0;
      } else {
        total = 0.0;
      }

      // Find the misc item (item with hasSubItems = true)
      final miscItem = budget.items.firstWhere(
        (item) => item.hasSubItems,
        orElse: () => BudgetItem(id: '', name: ''),
      );

      if (miscItem.id.isEmpty) {
        return 'No misc item found';
      }

      // Format the sub-item name (e.g., "26th Nov 25 misc")
      final subItemName = _formatDateForSubItem(today);

      // Check if a sub-item with today's date already exists
      final existingSubItem = miscItem.subItems.firstWhere(
        (subItem) => subItem.startDate == dateKey,
        orElse: () => SubItem(id: '', name: '', amount: 0),
      );

      // Get current month key for checklist
      final currentMonthKey = budget.currentActiveMonthKey();

      if (existingSubItem.id.isNotEmpty) {
        // Update existing sub-item if amount is different
        if (existingSubItem.amount != total) {
          final updatedSubItem = existingSubItem.copyWith(
            name: subItemName,
            amount: total,
          );

          // Update in the list
          final index = miscItem.subItems.indexWhere(
            (s) => s.id == existingSubItem.id,
          );
          if (index != -1) {
            miscItem.subItems[index] = updatedSubItem;
          }

          // Save to storage
          await Storage.updateSubItem(updatedSubItem);

          // Update budget
          final itemIndex = budget.items.indexWhere(
            (item) => item.id == miscItem.id,
          );
          if (itemIndex != -1) {
            budget.items[itemIndex] = miscItem;
          }

          await Storage.updateBudget(budget);

          return 'Updated: $subItemName - ${total.toStringAsFixed(0)} Rwf';
        } else {
          return 'Already synced for today';
        }
      } else {
        // Create new sub-item
        final newSubItem = SubItem(
          id: '${miscItem.id}_${DateTime.now().millisecondsSinceEpoch}',
          name: subItemName,
          amount: total,
          description: '',
          frequency: 'once',
          startDate: dateKey,
          isCompleted: false,
        );

        // Add to the misc item
        miscItem.subItems.add(newSubItem);

        // Mark as completed in checklist
        final monthChecklist = budget.checklist[currentMonthKey] ?? {};
        final checklistKey = 'subitem_${miscItem.id}_${newSubItem.id}';
        monthChecklist[checklistKey] = true;
        budget.checklist[currentMonthKey] = monthChecklist;

        // Save to storage
        await Storage.addSubItem(miscItem.id, newSubItem);

        // Update budget item in the main budget
        final itemIndex = budget.items.indexWhere(
          (item) => item.id == miscItem.id,
        );
        if (itemIndex != -1) {
          budget.items[itemIndex] = miscItem;
        }

        // Save the budget to persist checklist changes
        await Storage.updateBudget(budget);

        return 'Synced: $subItemName - ${total.toStringAsFixed(0)} Rwf';
      }
    } catch (e) {
      return 'Sync failed: ${e.toString()}';
    }
  }

  /// Format date for sub-item name
  /// Examples: "26th Nov 25 misc", "1st Dec 25 misc"
  static String _formatDateForSubItem(DateTime date) {
    final day = _ordinal(date.day);
    final month = DateFormat('MMM').format(date);
    final year = DateFormat('yy').format(date);
    return '$day $month $year misc';
  }

  /// Helper to get ordinal suffix for day
  static String _ordinal(int n) {
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
}
