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
    text: NumberFormat(
      '#,###',
    ).format(item.monthlyAmount ?? item.oneTimeAmount ?? 0),
  );
  String mode = item.monthlyAmount != null ? 'monthly' : 'one-time';
  String? oneTimeMonth =
      item.oneTimeMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
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
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'one-time', child: Text('One-time')),
              ],
              onChanged: (v) {
                dialogSetState(() {
                  mode = v ?? 'one-time';
                  if (mode == 'one-time' &&
                      (oneTimeMonth == null ||
                          (oneTimeMonth?.isEmpty ?? true))) {
                    oneTimeMonth = DateFormat('yyyy-MM').format(DateTime.now());
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
                  oneTimeMonth == null ? 'Pick month' : 'Month: $oneTimeMonth',
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
                monthlyAmount: mode == 'monthly' ? amount : null,
                oneTimeAmount: mode == 'one-time' ? amount : null,
                oneTimeMonth: mode == 'one-time' ? oneTimeMonth : null,
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
