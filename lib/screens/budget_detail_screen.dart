import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/budget_item.dart';
import '../services/storage.dart';
import '../widgets/app_theme.dart';
import 'item_detail_screen.dart';
import 'edit_item_dialog.dart';

class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;
  final void Function(Budget updated)? onChanged;
  const BudgetDetailScreen({super.key, required this.budget, this.onChanged});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late Budget _budget;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
  }

  Future<void> _addItemDialog() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final numberFormat = NumberFormat('#,###');
    String mode = 'once';
    DateTime? startDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, dialogSetState) => AlertDialog(
          title: const Text('Add item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'Rwf',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isEmpty) return;
                  // Remove non-digits
                  value = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (value.isEmpty) return;
                  // Parse and format
                  final number = int.tryParse(value) ?? 0;
                  final formatted = numberFormat.format(number);
                  amountCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                },
              ),
              DropdownButton<String>(
                value: mode,
                items: const [
                  DropdownMenuItem(value: 'once', child: Text('Once')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) {
                  dialogSetState(() {
                    mode = v ?? 'once';
                    startDate ??= DateTime.now();
                  });
                },
              ),
              TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? now,
                    firstDate: now.subtract(const Duration(days: 3650)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (d != null) {
                    dialogSetState(() => startDate = d);
                  }
                },
                child: Text(
                  startDate == null
                      ? 'Pick date'
                      : 'Start: ${DateFormat('yyyy-MM-dd').format(startDate!)}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final amount =
                    double.tryParse(
                      amountCtrl.text.replaceAll(RegExp(r'[^\d]'), ''),
                    ) ??
                    0;
                if (name.isEmpty || amount <= 0) return;
                // ensure startDate is set for items that require it
                if ((mode == 'once' || mode == 'weekly' || mode == 'monthly') &&
                    startDate == null) {
                  startDate = DateTime.now();
                }

                final id = DateTime.now().millisecondsSinceEpoch.toString();
                final item = BudgetItem(
                  id: id,
                  name: name,
                  frequency: mode,
                  amount: amount,
                  startDate: startDate == null
                      ? null
                      : DateFormat('yyyy-MM-dd').format(startDate!),
                );
                setState(() => _budget.items.add(item));
                widget.onChanged?.call(_budget);
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = _budget.monthKeys();
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text(_budget.title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: months.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            // header with budget items list
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget items',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                if (_budget.items.isEmpty)
                  Text(
                    'No items added yet',
                    style: TextStyle(color: AppColors.lightGrey),
                  )
                else
                  ..._budget.items.map((it) {
                    String label = '';
                    if (it.frequency == 'monthly') {
                      label = 'Monthly: ${fmt.format(it.amount ?? 0)} Rwf';
                    } else if (it.frequency == 'weekly') {
                      label = 'Weekly: ${fmt.format(it.amount ?? 0)} Rwf';
                    } else {
                      label = 'One-time: ${fmt.format(it.amount ?? 0)} Rwf';
                    }
                    if (it.startDate != null) {
                      label = '$label\nStart: ${it.startDate}';
                    }
                    return Dismissible(
                      key: Key(it.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Item'),
                                content: Text(
                                  'Are you sure you want to delete "${it.name}"?',
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
                                    child: const Text('DELETE'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      },
                      onDismissed: (direction) async {
                        setState(() {
                          _budget.items.removeWhere((item) => item.id == it.id);
                        });
                        // persist deletion
                        await Storage.deleteBudgetItem(it.id);
                        widget.onChanged?.call(_budget);
                      },
                      child: Card(
                        color: AppColors.cardGrey,
                        child: ListTile(
                          title: Text(
                            it.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            label,
                            style: TextStyle(color: AppColors.lightGrey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await showEditItemDialog(context, it, (
                                    updatedItem,
                                  ) {
                                    setState(() {
                                      final index = _budget.items.indexWhere(
                                        (item) => item.id == it.id,
                                      );
                                      if (index != -1) {
                                        _budget.items[index] = updatedItem;
                                      }
                                    });
                                    Storage.updateBudgetItem(updatedItem);
                                    widget.onChanged?.call(_budget);
                                  });
                                },
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ItemDetailScreen(
                                budget: _budget,
                                item: it,
                                onChanged: (updated) {
                                  setState(() => _budget = updated);
                                  widget.onChanged?.call(_budget);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
            );
          }
          final idx = i - 1;
          final key = months[idx];
          final deductions = _budget.deductionsForMonth(key);
          final remaining = _budget.remainingUpTo(key);
          // render month card with checklist
          // Determine which items apply to this month depending on frequency and startDate
          bool _itemAppliesInMonth(BudgetItem it, String monthKey) {
            try {
              final parts = monthKey.split('-');
              final firstDay = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                1,
              );
              final lastDay = DateTime(
                firstDay.year,
                firstDay.month + 1,
                1,
              ).subtract(const Duration(days: 1));
              if (it.frequency == 'monthly') {
                if (it.startDate == null) return true;
                final sd = DateTime.parse(it.startDate!);
                return !sd.isAfter(lastDay);
              } else if (it.frequency == 'weekly') {
                if (it.startDate == null) return false;
                final sd = DateTime.parse(it.startDate!);
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
                if (it.startDate == null) return false;
                final sd = DateTime.parse(it.startDate!);
                return sd.year == firstDay.year && sd.month == firstDay.month;
              }
            } catch (_) {
              return false;
            }
          }

          final monthItems = _budget.items
              .where((it) => _itemAppliesInMonth(it, key))
              .toList();
          final monthChecks = _budget.checklist[key] ?? {};
          return Card(
            color: AppColors.cardGrey,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppTheme.mainGradient(),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(key, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Deductions: ${fmt.format(deductions)} Rwf • Remaining: ${fmt.format(remaining)} Rwf',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.lightGrey,
                    ),
                  ),
                  const Divider(),
                  if (monthItems.isEmpty)
                    Text(
                      'No items',
                      style: TextStyle(color: AppColors.lightGrey),
                    )
                  else
                    ...monthItems.map((it) {
                      final checked = monthChecks[it.id] == true;
                      return ListTile(
                        title: Text(
                          it.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          it.frequency == 'monthly'
                              ? 'Monthly: ${fmt.format(it.amount ?? 0)} Rwf'
                              : (it.frequency == 'weekly'
                                        ? 'Weekly: ${fmt.format(it.amount ?? 0)} Rwf'
                                        : (it.frequency == 'once'
                                              ? 'One-time: ${fmt.format(it.amount ?? 0)} Rwf'
                                              : '')) +
                                    (it.startDate != null
                                        ? '\nStart: ${it.startDate}'
                                        : ''),
                          style: TextStyle(color: AppColors.lightGrey),
                        ),
                        trailing: Checkbox(
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              final map = _budget.checklist[key] ?? {};
                              map[it.id] = v == true;
                              _budget.checklist[key] = map;
                            });
                            widget.onChanged?.call(_budget);
                          },
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(
                              budget: _budget,
                              item: it,
                              onChanged: (updated) {
                                setState(() => _budget = updated);
                                widget.onChanged?.call(_budget);
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
