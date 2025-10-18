import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sub_item.dart';
import '../widgets/app_theme.dart';

class SubItemsList extends StatefulWidget {
  final List<SubItem> subItems;
  final Function(SubItem) onEdit;
  final Function(SubItem) onDelete;
  final Function(SubItem) onToggleCompleted;
  final double totalAmount;
  final String monthKey;
  final String? parentStartDate;
  final bool hasSubItems;

  const SubItemsList({
    super.key,
    required this.subItems,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleCompleted,
    required this.totalAmount,
    required this.monthKey,
    this.parentStartDate,
    this.hasSubItems = true,
  });

  @override
  State<SubItemsList> createState() => _SubItemsListState();
}

class _SubItemsListState extends State<SubItemsList> {
  bool _isExpanded = true;

  // Check if a sub-item applies to the current month based on frequency
  bool _subItemAppliesInMonth(SubItem subItem, String monthKey) {
    try {
      final parts = monthKey.split('-');
      final firstDay = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      final lastDay = DateTime(
        firstDay.year,
        firstDay.month + 1,
        1,
      ).subtract(const Duration(days: 1));

      // Get the effective start date for this sub-item (use parent start date as fallback)
      String? effectiveStartDate = subItem.startDate ?? widget.parentStartDate;

      if (subItem.frequency == 'monthly') {
        if (effectiveStartDate == null) return true;
        final sd = DateTime.parse(effectiveStartDate);
        return !sd.isAfter(lastDay);
      } else if (subItem.frequency == 'weekly') {
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        if (sd.isAfter(lastDay)) return false;
        // find first occurrence >= firstDay
        int offsetDays = firstDay.difference(sd).inDays;
        int weeksOffset = 0;
        if (offsetDays > 0) weeksOffset = (offsetDays + 6) ~/ 7;
        DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
        if (firstOcc.isAfter(lastDay)) return false;
        return true;
      } else {
        // once
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        return sd.year == firstDay.year && sd.month == firstDay.month;
      }
    } catch (_) {
      return false;
    }
  }

  // Helper method to get filtered sub-items
  List<SubItem> _getFilteredSubItems() {
    print(
      widget.subItems.where(
        (subItem) => _subItemAppliesInMonth(subItem, widget.monthKey),
      ),
    );
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

    final totalSubItemsAmount = widget.subItems.fold(
      0.0,
      (sum, subItem) => sum + subItem.amount,
    );
    final completedSubItemsAmount = widget.subItems
        .where((subItem) => subItem.isCompleted)
        .fold(0.0, (sum, subItem) => sum + subItem.amount);
    final progressPercentage = widget.totalAmount > 0
        ? (completedSubItemsAmount / widget.totalAmount) * 100
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
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        title: Row(
          children: [
            const Icon(Icons.subdirectory_arrow_right, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Sub-items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getProgressBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${progressPercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              color: getProgressColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress bar showing how much of the main item's amount is used
                if (widget.subItems.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Usage:'),
                          Text(
                            '${NumberFormat('#,###').format(completedSubItemsAmount)} / ${NumberFormat('#,###').format(widget.totalAmount)} Rwf',
                            style: TextStyle(
                              color: getProgressColor(),
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
                            'Total: ${NumberFormat('#,###').format(totalSubItemsAmount)} Rwf',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Completed: ${NumberFormat('#,###').format(completedSubItemsAmount)} Rwf',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Sub-items list
                if (widget.subItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No sub-items added yet',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  _buildSubItemsList(),
              ],
            ),
          ),
        ],
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
              '${subItem.amount.toStringAsFixed(0)} Rwf${subItem.description != null ? '\\n' + subItem.description! : ''}',
              style: TextStyle(color: AppColors.lightGrey),
            ),
            value: subItem.isCompleted,
            onChanged: (value) {
              widget.onToggleCompleted(
                subItem.copyWith(isCompleted: value ?? false),
              );
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
