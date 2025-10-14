import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../models/budget_item.dart';
import 'item_detail_screen.dart';

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
    String mode = 'one-time';
    String? oneTimeMonth = DateFormat('yyyy-MM').format(DateTime.now());

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
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'one-time', child: Text('One-time')),
                ],
                onChanged: (v) {
                  dialogSetState(() {
                    mode = v ?? 'one-time';
                    if (mode == 'one-time' &&
                        (oneTimeMonth == null ||
                            (oneTimeMonth?.isEmpty ?? true))) {
                      oneTimeMonth = DateFormat(
                        'yyyy-MM',
                      ).format(DateTime.now());
                    }
                    if (mode == 'monthly') oneTimeMonth = null;
                  });
                },
              ),
              if (mode == 'one-time')
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: now.add(const Duration(days: 3650)),
                    );
                    if (d != null) {
                      dialogSetState(
                        () => oneTimeMonth = DateFormat('yyyy-MM').format(d),
                      );
                    }
                  },
                  child: Text(
                    oneTimeMonth == null
                        ? 'Pick month'
                        : 'Month: $oneTimeMonth',
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
                if (mode == 'one-time' &&
                    (oneTimeMonth == null || (oneTimeMonth?.isEmpty ?? true))) {
                  oneTimeMonth = DateFormat('yyyy-MM').format(DateTime.now());
                }

                final id = DateTime.now().millisecondsSinceEpoch.toString();
                final item = BudgetItem(
                  id: id,
                  name: name,
                  monthlyAmount: mode == 'monthly' ? amount : null,
                  oneTimeAmount: mode == 'one-time' ? amount : null,
                  oneTimeMonth: mode == 'one-time' ? oneTimeMonth : null,
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
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (_budget.items.isEmpty)
                  const Text('No items added yet')
                else
                  ..._budget.items.map((it) {
                    final label = it.monthlyAmount != null
                        ? 'Monthly: ${fmt.format(it.monthlyAmount)} Rwf'
                        : (it.oneTimeAmount != null
                              ? 'One-time: ${fmt.format(it.oneTimeAmount)} Rwf'
                              : '');
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text(label),
                      trailing: const Icon(Icons.chevron_right),
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
                const SizedBox(height: 12),
              ],
            );
          }
          final idx = i - 1;
          final key = months[idx];
          final deductions = _budget.deductionsForMonth(key);
          final remaining = _budget.remainingUpTo(key);
          // render month card with checklist
          // Only include monthly items every month; one-time items only on their month
          final monthItems = _budget.items.where((it) {
            if (it.monthlyAmount != null) return true;
            if (it.oneTimeAmount != null) return it.oneTimeMonth == key;
            return false;
          }).toList();
          final monthChecks = _budget.checklist[key] ?? {};
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Deductions: ${fmt.format(deductions)} Rwf • Remaining: ${fmt.format(remaining)} Rwf',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Divider(),
                  if (monthItems.isEmpty)
                    const Text('No items')
                  else
                    ...monthItems.map((it) {
                      final checked = monthChecks[it.id] == true;
                      return ListTile(
                        title: Text(it.name),
                        subtitle: Text(
                          it.monthlyAmount != null
                              ? 'Monthly: ${fmt.format(it.monthlyAmount)} Rwf'
                              : (it.oneTimeAmount != null
                                    ? 'One-time: ${fmt.format(it.oneTimeAmount)} Rwf'
                                    : ''),
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
