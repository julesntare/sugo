import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import 'package:intl/intl.dart';
import '../services/storage.dart';

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
      months = allMonths;
    }
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: Text(_item.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: months.map((m) {
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
          final overrideDateStr = _budget.monthItemOverrides[m]?[_item.id];
          final startToShow = overrideDateStr ?? _item.startDate;
          if (startToShow != null) {
            label = '$label\nDate: $startToShow';
          }

          return ListTile(
            title: Text(_budget.monthRangeLabel(m)),
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
                        initialDate = DateTime.parse(_item.startDate!);
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
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final now = DateTime.now();
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: initialDate ?? now,
                                  firstDate: DateTime(_budget.start.year - 1),
                                  lastDate: DateTime(_budget.end.year + 1),
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
                            onPressed: () => Navigator.of(ctx).pop(null),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              // parse amount
                              final parsed =
                                  double.tryParse(
                                    amountCtrl.text.replaceAll(
                                      RegExp(r'[^\d\.]'),
                                      '',
                                    ),
                                  ) ??
                                  0.0;
                              // apply overrides
                              setState(() {
                                // amount override
                                final amounts =
                                    _budget.monthItemAmountOverrides[m] ?? {};
                                amounts[_item.id] = parsed;
                                _budget.monthItemAmountOverrides[m] = amounts;
                                // date override
                                if (initialDate != null) {
                                  final dates =
                                      _budget.monthItemOverrides[m] ?? {};
                                  dates[_item.id] = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(initialDate!);
                                  _budget.monthItemOverrides[m] = dates;
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
          );
        }).toList(),
      ),
    );
  }
}
