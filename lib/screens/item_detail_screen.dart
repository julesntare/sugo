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
      months = List.from(allMonths);
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
                        budget:
                            _budget, // Pass the budget for salary date calculations
                        onEdit: (subItem) async {
                          final result = await showSubItemDialog(
                            context,
                            subItem: subItem,
                            maxAmount: displayAmount,
                          );
                          if (result != null) {
                            setState(() {
                              final subItemIndex = _item.subItems.indexWhere(
                                (s) => s.id == subItem.id,
                              );
                              if (subItemIndex != -1) {
                                _item.subItems[subItemIndex] = result.subItem;
                              }
                            });
                            await Storage.updateSubItem(result.subItem);
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
                          // Save the budget to persist checklist changes
                          await Storage.updateBudget(_budget);
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
    final result = await showSubItemDialog(context, maxAmount: _item.amount);
    if (result != null) {
      // If user marked as completed and it's a "once" item without a start date,
      // set the start date to today so it only applies to the current active month
      SubItem subItemToAdd = result.subItem;
      String? monthKey;

      if (result.markAsCompleted &&
          result.subItem.frequency == 'once' &&
          result.subItem.startDate == null) {
        // Get the current active month (based on salary date ranges)
        monthKey = _budget.currentActiveMonthKey();

        // Set the start date to today
        subItemToAdd = result.subItem.copyWith(
          startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
      }

      setState(() {
        _item.subItems.add(subItemToAdd);

        // If user marked as completed, update the checklist for the relevant month
        if (result.markAsCompleted) {
          // Determine which month to mark as completed
          if (monthKey == null) {
            // If monthKey wasn't set above, calculate it based on the start date
            if (subItemToAdd.startDate != null) {
              // Find which month range contains this start date
              final startDate = DateTime.parse(subItemToAdd.startDate!);
              final keys = _budget.monthKeys();

              for (final key in keys) {
                final parts = key.split('-');
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);

                // Calculate the salary date range for this month
                final thisMonthSalary = _budget.salaryDateForMonth(key);
                DateTime rangeStart = thisMonthSalary;

                final nextDate = DateTime(year, month + 1, 1);
                final nextKey =
                    '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
                DateTime rangeEnd;

                final isLast = keys.isNotEmpty && key == keys.last;
                if (isLast) {
                  rangeEnd = _budget.end;
                } else {
                  final nextSalary = _budget.salaryDateForMonth(nextKey);
                  rangeEnd = nextSalary.subtract(const Duration(days: 1));
                }

                // Check if the start date falls within this month's range
                if (!startDate.isBefore(rangeStart) && !startDate.isAfter(rangeEnd)) {
                  monthKey = key;
                  break;
                }
              }
            }
          }

          // Update checklist if we have a month
          if (monthKey != null) {
            final monthChecklist = _budget.checklist[monthKey!] ?? {};
            final checklistKey = 'subitem_${_item.id}_${subItemToAdd.id}';
            monthChecklist[checklistKey] = true;
            _budget.checklist[monthKey!] = monthChecklist;
          }
        }
      });
      await Storage.addSubItem(_item.id, subItemToAdd);
      // Save the budget to persist checklist changes
      await Storage.updateBudget(_budget);
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
