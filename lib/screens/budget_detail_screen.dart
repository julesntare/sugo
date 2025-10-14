import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import 'package:intl/intl.dart';

class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;
  const BudgetDetailScreen({super.key, required this.budget});

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
    String mode = 'monthly';
    String? oneTimeMonth;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: mode,
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'one-time', child: Text('One-time')),
              ],
              onChanged: (v) {
                mode = v ?? 'monthly';
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
                  if (d != null) oneTimeMonth = DateFormat('yyyy-MM').format(d);
                },
                child: const Text('Pick month'),
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
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (name.isEmpty || amount <= 0) return;
              final id = DateTime.now().millisecondsSinceEpoch.toString();
              final item = BudgetItem(
                id: id,
                name: name,
                monthlyAmount: mode == 'monthly' ? amount : null,
                oneTimeAmount: mode == 'one-time' ? amount : null,
                oneTimeMonth: oneTimeMonth,
              );
              setState(() => _budget.items.add(item));
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = _budget.monthKeys();
    final fmt = NumberFormat.currency(symbol: 'Rwf ', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: Text(_budget.title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        itemBuilder: (context, i) {
          final key = months[i];
          final deductions = _budget.deductionsForMonth(key);
          final remaining = _budget.remainingUpTo(key);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(key),
              subtitle: Text(
                'Deductions: ${fmt.format(deductions)} • Remaining: ${fmt.format(remaining)}',
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
