import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sub_item.dart';
import '../models/budget.dart';
import '../widgets/app_theme.dart';

class SubItemsList extends StatefulWidget {
  final List<SubItem> subItems;
  final String parentItemId; // Added parent item ID
  final Function(SubItem) onEdit;
  final Function(SubItem) onDelete;
  final Function(SubItem, String) onToggleCompleted; // Added monthKey parameter
  final double totalAmount;
  final String monthKey;
  final Map<String, bool>? checklist; // Added checklist parameter
  final String? parentStartDate;
  final bool hasSubItems;
  final Budget budget; // Added budget to access salary date calculation

  const SubItemsList({
    super.key,
    required this.subItems,
    required this.parentItemId, // Added parent item ID
    required this.onEdit,
    required this.onDelete,
    required this.onToggleCompleted,
    required this.totalAmount,
    required this.monthKey,
    this.checklist,
    this.parentStartDate,
    this.hasSubItems = true,
    required this.budget,
  });

  @override
  State<SubItemsList> createState() => _SubItemsListState();
}

class _SubItemsListState extends State<SubItemsList> {
  bool _isExpanded = true;

  // Check if a sub-item applies to the current month based on frequency
  // Uses salary date range logic to match budget deduction calculation
  bool _subItemAppliesInMonth(SubItem subItem, String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      // Calculate the salary date range for this month using the budget
      final thisMonthSalary = widget.budget.salaryDateForMonth(monthKey);
      DateTime rangeStart = thisMonthSalary;

      final nextDate = DateTime(year, month + 1, 1);
      final nextKey =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
      final keys = widget.budget.monthKeys();
      DateTime rangeEnd;

      final isLast = keys.isNotEmpty && monthKey == keys.last;
      if (isLast) {
        rangeEnd = widget.budget.end;
      } else {
        final nextSalary = widget.budget.salaryDateForMonth(nextKey);
        rangeEnd = nextSalary.subtract(const Duration(days: 1));
      }

      // Get the effective start date for this sub-item (use parent start date as fallback)
      String? effectiveStartDate = subItem.startDate ?? widget.parentStartDate;

      if (subItem.frequency == 'monthly') {
        if (effectiveStartDate == null) return true;
        final sd = DateTime.parse(effectiveStartDate);
        // Monthly items apply if their start date is not after the range end
        return !sd.isAfter(rangeEnd);
      } else if (subItem.frequency == 'weekly') {
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        if (sd.isAfter(rangeEnd)) return false;
        // Find first occurrence >= rangeStart
        int offsetDays = rangeStart.difference(sd).inDays;
        int weeksOffset = 0;
        if (offsetDays > 0) weeksOffset = (offsetDays + 6) ~/ 7;
        DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
        if (firstOcc.isAfter(rangeEnd)) return false;
        return true;
      } else {
        // once - check if the date falls within the salary range
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        return !sd.isBefore(rangeStart) && !sd.isAfter(rangeEnd);
      }
    } catch (_) {
      return false;
    }
  }

  // Helper method to get filtered sub-items
  List<SubItem> _getFilteredSubItems() {
    return widget.subItems
        .where((subItem) => _subItemAppliesInMonth(subItem, widget.monthKey))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Only show if sub-items are enabled for this budget item
    if (!widget.hasSubItems) {
      return const SizedBox.shrink();
    }

    // Get filtered sub-items that apply to this month
    final filteredSubItems = _getFilteredSubItems();

    // Calculate used amount (completed sub-items) using the monthly checklist
    // Only count sub-items that apply to this specific month
    final usedAmount = filteredSubItems
        .where((subItem) {
          // Check if this specific sub-item is marked as completed in this month
          // Use the pattern: subitem_${parentItemId}_${subItem.id}
          final checklistKey = 'subitem_${widget.parentItemId}_${subItem.id}';
          return widget.checklist != null &&
              widget.checklist!.containsKey(checklistKey) &&
              widget.checklist![checklistKey] == true;
        })
        .fold(0.0, (sum, subItem) => sum + subItem.amount);
    final remainingAmount = widget.totalAmount - usedAmount;
    final progressPercentage = widget.totalAmount > 0
        ? (usedAmount / widget.totalAmount) * 100
        : 0;

    Color getProgressColor() {
      if (progressPercentage >= 100) return Colors.red;
      if (progressPercentage >= 80) return Colors.orange;
      return AppColors.teal;
    }

    Color getProgressBackgroundColor() {
      if (progressPercentage >= 100) return Colors.red.shade50;
      if (progressPercentage >= 80) return Colors.orange.shade50;
      return AppColors.slateTint8;
    }

    return Card(
      color: AppColors.cardGrey,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Sub-items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar showing how much of the main item's amount is used
            if (filteredSubItems.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Budget:'),
                      Text(
                        '${NumberFormat('#,###').format(widget.totalAmount)} Rwf',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progressPercentage > 100
                        ? 1.0
                        : progressPercentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      getProgressColor(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Used: ${NumberFormat('#,###').format(usedAmount)} Rwf',
                        style: TextStyle(
                          fontSize: 12,
                          color: getProgressColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Remaining: ${NumberFormat('#,###').format(remainingAmount)} Rwf',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getProgressBackgroundColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.percent,
                          size: 16,
                          color: getProgressColor(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${progressPercentage.toStringAsFixed(1)}% used',
                          style: TextStyle(
                            color: getProgressColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Collapsible sub-items list
            if (filteredSubItems.isNotEmpty)
              ExpansionTile(
                initiallyExpanded: _isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isExpanded = expanded;
                  });
                },
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Items (${filteredSubItems.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  _buildSubItemsList(),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No sub-items added yet',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubItemsList() {
    final filteredSubItems = _getFilteredSubItems();

    if (filteredSubItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No sub-items for this month',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredSubItems.length,
      itemBuilder: (context, index) {
        final subItem = filteredSubItems[index];
        return Card(
          color: AppColors.slate,
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            title: Text(
              subItem.name,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${NumberFormat('#,###').format(subItem.amount)} Rwf${subItem.description != null ? '\\n${subItem.description!}' : ''}',
              style: TextStyle(color: AppColors.lightGrey),
            ),
            value:
                widget.checklist != null &&
                widget.checklist!['subitem_${widget.parentItemId}_${subItem.id}'] ==
                    true,
            onChanged: (value) {
              final updatedSubItem = subItem.copyWith(
                isCompleted: value ?? false,
              );
              widget.onToggleCompleted(updatedSubItem, widget.monthKey);
            },
            secondary: PopupMenuButton(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: const [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: const [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  widget.onEdit(subItem);
                } else if (value == 'delete') {
                  widget.onDelete(subItem);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
