import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/sub_item.dart';
import '../services/storage.dart';
import '../widgets/sub_items_list.dart';
import '../widgets/sub_item_dialog.dart';

class ItemDetailScreen extends StatefulWidget {
  final Budget budget;
  final BudgetItem item;
  final void Function(Budget updated)? onChanged;

  const ItemDetailScreen({
    super.key,
    required this.budget,
    required this.item,
    this.onChanged,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Budget _budget;
  late BudgetItem _item;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _item = widget.item;
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = _budget.monthKeys();
    // Determine months to show based on frequency/startDate
    List<String> months;
    if (_item.frequency == 'once' && _item.startDate != null) {
      final key = DateFormat(
        'yyyy-MM',
      ).format(DateTime.parse(_item.startDate!));
      months = allMonths.contains(key) ? [key] : [];
    } else {
      months = List.from(allMonths); // Create a copy of the list
      if (months.isNotEmpty) {
        months.removeLast(); // Remove the last month
      }
    }
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: Text(_item.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Month range list
          ...months
              .where((m) {
                // Only include months where the item should be displayed based on its start date
                if (_item.startDate == null) {
                  return true; // If no start date, show all months
                }

                try {
                  final itemStartDate = DateTime.parse(_item.startDate!);

                  // Get the end date of the month range to determine if item's start date is before or within this range
                  final monthParts = m.split('-');
                  final monthStart = DateTime(
                    int.parse(monthParts[0]),
                    int.parse(monthParts[1]),
                    1,
                  );
                  final nextDate = DateTime(
                    monthStart.year,
                    monthStart.month + 1,
                    1,
                  );
                  final nextKey =
                      '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
                  final keys = _budget.monthKeys();
                  final isLast = keys.isNotEmpty && m == keys.last;

                  DateTime endDate;
                  if (isLast) {
                    endDate = _budget.end;
                  } else {
                    final nextSalary = _budget.salaryDateForMonth(nextKey);
                    endDate = nextSalary.subtract(const Duration(days: 1));
                  }

                  // Only include this month if the item's start date is not after the end of the month range
                  return !itemStartDate.isAfter(endDate);
                } catch (e) {
                  // If there's an issue parsing the date, show the month by default
                  return true;
                }
              })
              .map((m) {
                final map = _budget.checklist[m] ?? {};
                final checked = map[_item.id] == true;

                // label: frequency + base amount or overridden amount for month
                final overriddenAmount =
                    _budget.monthItemAmountOverrides[m]?[_item.id];
                String label = '';
                final displayAmount = overriddenAmount ?? _item.amount ?? 0;
                if (_item.frequency == 'monthly') {
                  label = 'Monthly: ${fmt.format(displayAmount)} Rwf';
                } else if (_item.frequency == 'weekly') {
                  label = 'Weekly: ${fmt.format(displayAmount)} Rwf';
                } else if (_item.frequency == 'once') {
                  label = 'One-time: ${fmt.format(displayAmount)} Rwf';
                }

                // show start/override date if present
                final overrideDateStr =
                    _budget.monthItemOverrides[m]?[_item.id];
                final startToShow = overrideDateStr ?? _item.startDate;
                if (startToShow != null) {
                  label = '$label\nDate: $startToShow';
                }

                String rangeLabel = _budget.monthRangeLabel(m);
                // Only show the list tile if the range label is valid (not empty)
                if (rangeLabel.isEmpty) {
                  return const SizedBox.shrink(); // Don't render anything for invalid ranges
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(rangeLabel),
                      subtitle: Text(label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit amount/date for this month',
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () async {
                              final amountCtrl = TextEditingController(
                                text: (overriddenAmount ?? _item.amount ?? 0)
                                    .toStringAsFixed(0),
                              );
                              DateTime? initialDate;
                              try {
                                if (overrideDateStr != null) {
                                  initialDate = DateTime.parse(overrideDateStr);
                                } else if (_item.startDate != null) {
                                  initialDate = DateTime.parse(
                                    _item.startDate!,
                                  );
                                }
                              } catch (_) {
                                initialDate = null;
                              }

                              await showDialog<DateTime?>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Edit month override'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: amountCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount (Rwf)',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ThousandsFormatter()],
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final now = DateTime.now();
                                          final d = await showDatePicker(
                                            context: context,
                                            initialDate: initialDate ?? now,
                                            firstDate: DateTime(
                                              _budget.start.year - 1,
                                            ),
                                            lastDate: DateTime(
                                              _budget.end.year + 1,
                                            ),
                                          );
                                          if (d != null) {
                                            initialDate = d;
                                          }
                                        },
                                        icon: const Icon(Icons.calendar_today),
                                        label: Text(
                                          initialDate == null
                                              ? 'Pick date'
                                              : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(initialDate!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(null),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        // parse amount
                                        final parsed =
                                            double.tryParse(
                                              amountCtrl.text.replaceAll(
                                                RegExp(r'[^\d]'),
                                                '',
                                              ),
                                            ) ??
                                            0.0;
                                        // apply overrides
                                        setState(() {
                                          // amount override
                                          final amounts =
                                              _budget
                                                  .monthItemAmountOverrides[m] ??
                                              {};
                                          amounts[_item.id] = parsed;
                                          _budget.monthItemAmountOverrides[m] =
                                              amounts;
                                          // date override
                                          if (initialDate != null) {
                                            final dates =
                                                _budget.monthItemOverrides[m] ??
                                                {};
                                            dates[_item.id] = DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(initialDate!);
                                            _budget.monthItemOverrides[m] =
                                                dates;
                                          }
                                        });
                                        // persist
                                        Storage.updateBudget(_budget);
                                        widget.onChanged?.call(_budget);
                                        Navigator.of(ctx).pop(initialDate);
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              // no further action needed; state updated in dialog
                            },
                          ),
                          Checkbox(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                final newMap = _budget.checklist[m] ?? {};
                                newMap[_item.id] = v == true;
                                _budget.checklist[m] = newMap;
                              });
                              widget.onChanged?.call(_budget);
                            },
                          ),
                        ],
                      ),
                    ),
                    // Show sub-items section if sub-items are enabled for this item
                    if (_item.hasSubItems)
                      SubItemsList(
                        subItems: _item.subItems,
                        parentItemId: _item.id, // Pass the parent item ID
                        onEdit: (subItem) async {
                          final updatedSubItem = await showSubItemDialog(
                            context,
                            subItem: subItem,
                            maxAmount: displayAmount,
                          );
                          if (updatedSubItem != null) {
                            setState(() {
                              final subItemIndex = _item.subItems.indexWhere(
                                (s) => s.id == subItem.id,
                              );
                              if (subItemIndex != -1) {
                                _item.subItems[subItemIndex] = updatedSubItem;
                              }
                            });
                            await Storage.updateSubItem(updatedSubItem);
                            // Update budget item in the main budget
                            final itemIndex = _budget.items.indexWhere(
                              (item) => item.id == _item.id,
                            );
                            if (itemIndex != -1) {
                              _budget.items[itemIndex] = _item;
                            }
                            widget.onChanged?.call(_budget);
                          }
                        },
                        onDelete: (subItem) async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Sub-item'),
                              content: Text(
                                'Are you sure you want to delete "${subItem.name}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('CANCEL'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('DELETE'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            setState(() {
                              _item.subItems.removeWhere(
                                (s) => s.id == subItem.id,
                              );
                            });
                            await Storage.deleteSubItem(subItem.id);
                            // Update budget item in the main budget
                            final itemIndex = _budget.items.indexWhere(
                              (item) => item.id == _item.id,
                            );
                            if (itemIndex != -1) {
                              _budget.items[itemIndex] = _item;
                            }
                            widget.onChanged?.call(_budget);
                          }
                        },
                        onToggleCompleted: (subItem, monthKey) async {
                          setState(() {
                            // Update the checklist for this month with the sub-item completion status
                            final monthChecklist =
                                _budget.checklist[monthKey] ?? {};
                            final checklistKey =
                                'subitem_${_item.id}_${subItem.id}';
                            monthChecklist[checklistKey] = subItem.isCompleted;
                            _budget.checklist[monthKey] = monthChecklist;
                          });
                          // Only update the sub-item if the global completion status needs to be changed
                          // This is for backward compatibility
                          final subItemIndex = _item.subItems.indexWhere(
                            (s) => s.id == subItem.id,
                          );
                          if (subItemIndex != -1) {
                            _item.subItems[subItemIndex] = subItem;
                          }
                          await Storage.updateSubItem(subItem);
                          // Update budget item in the main budget
                          final itemIndex = _budget.items.indexWhere(
                            (item) => item.id == _item.id,
                          );
                          if (itemIndex != -1) {
                            _budget.items[itemIndex] = _item;
                          }
                          widget.onChanged?.call(_budget);
                        },
                        totalAmount: displayAmount,
                        monthKey: m,
                        checklist: _budget
                            .checklist[m], // Pass the checklist for this month
                        parentStartDate:
                            _item.startDate, // Pass parent item's start date
                        hasSubItems: _item.hasSubItems,
                      ),
                  ],
                );
              }),

          if (_item.hasSubItems)
            Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sub-items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_item.subItems.isEmpty)
                        const Text(
                          'No sub-items added yet',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ..._item.subItems.map(
                          (subItem) => Card(
                            color: Colors.grey[700],
                            child: ListTile(
                              title: Text(
                                subItem.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${NumberFormat('#,###').format(subItem.amount)} Rwf${subItem.description != null ? '\\n${subItem.description}' : ''}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (subItem.isCompleted)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editSubItem(subItem);
                                      } else if (value == 'delete') {
                                        _deleteSubItem(subItem);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: _item.hasSubItems
          ? FloatingActionButton(
              onPressed: _addSubItem,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _addSubItem() async {
    final newItem = await showSubItemDialog(context, maxAmount: _item.amount);
    if (newItem != null) {
      setState(() {
        _item.subItems.add(newItem);
      });
      await Storage.addSubItem(_item.id, newItem);
      // Update budget item in the main budget
      final itemIndex = _budget.items.indexWhere((item) => item.id == _item.id);
      if (itemIndex != -1) {
        _budget.items[itemIndex] = _item;
      }
      widget.onChanged?.call(_budget);
    }
  }

  Future<void> _editSubItem(SubItem subItem) async {
    final updatedItem = await showSubItemDialog(
      context,
      subItem: subItem,
      maxAmount: _item.amount,
    );
    if (updatedItem != null) {
      setState(() {
        final index = _item.subItems.indexWhere((s) => s.id == subItem.id);
        if (index != -1) {
          _item.subItems[index] = updatedItem;
        }
      });
      await Storage.updateSubItem(updatedItem);
      // Update budget item in the main budget
      final itemIndex = _budget.items.indexWhere((item) => item.id == _item.id);
      if (itemIndex != -1) {
        _budget.items[itemIndex] = _item;
      }
      widget.onChanged?.call(_budget);
    }
  }

  Future<void> _deleteSubItem(SubItem subItem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub-item'),
        content: Text('Are you sure you want to delete "${subItem.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _item.subItems.removeWhere((s) => s.id == subItem.id);
      });
      await Storage.deleteSubItem(subItem.id);
      // Update budget item in the main budget
      final itemIndex = _budget.items.indexWhere((item) => item.id == _item.id);
      if (itemIndex != -1) {
        _budget.items[itemIndex] = _item;
      }
      widget.onChanged?.call(_budget);
    }
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any non-digit characters except decimal point for parsing purposes
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');

    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Handle decimal numbers
    List<String> parts = newText.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // Only format the integer part with thousands separators
    if (integerPart.isNotEmpty) {
      int? integerNum = int.tryParse(integerPart);
      if (integerNum != null) {
        String formattedInteger = NumberFormat('#,###').format(integerNum);
        String formattedText = decimalPart.isNotEmpty
            ? '$formattedInteger.$decimalPart'
            : formattedInteger;

        return newValue.copyWith(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
    }

    return oldValue;
  }
}
