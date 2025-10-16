import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_item.dart';

Future<void> showEditItemDialog(
  BuildContext context,
  BudgetItem item,
  Function(BudgetItem) onSave,
) async {
  final nameCtrl = TextEditingController(text: item.name);
  final amountCtrl = TextEditingController(
    text: NumberFormat('#,###').format(item.amount ?? 0),
  );
  String mode = item.frequency; // 'once', 'weekly', 'monthly'
  DateTime? startDate;
  if (item.startDate != null) {
    try {
      startDate = DateTime.parse(item.startDate!);
    } catch (_) {
      startDate = null;
    }
  }
  final numberFormat = NumberFormat('#,###');

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, dialogSetState) => AlertDialog(
        title: const Text('Edit item'),
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
                value = value.replaceAll(RegExp(r'[^\d]'), '');
                if (value.isEmpty) return;
                final number = int.tryParse(value) ?? 0;
                final formatted = numberFormat.format(number);
                amountCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
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
                  if (mode == 'once') startDate ??= DateTime.now();
                });
              },
            ),
            if (mode == 'weekly' || mode == 'monthly' || mode == 'once')
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
            child: const Text('CANCEL'),
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

              final updatedItem = BudgetItem(
                id: item.id,
                name: name,
                frequency: mode,
                amount: amount,
                startDate: startDate == null
                    ? null
                    : DateFormat('yyyy-MM-dd').format(startDate!),
              );
              onSave(updatedItem);
              Navigator.of(ctx).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}
