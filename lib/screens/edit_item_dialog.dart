import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_item.dart';

Future<void> showEditItemDialog(
  BuildContext context,
  BudgetItem item,
  Function(BudgetItem) onSave, {
  DateTime? preferredDate,
}) async {
  final formKey = GlobalKey<FormState>();
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
  bool enableSubItems = item.hasSubItems; // Track sub-items toggle state
  bool isSaving = item.isSaving; // Track saving toggle state
  final numberFormat = NumberFormat('#,###');

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, dialogSetState) => AlertDialog(
        title: const Text('Edit item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'Rwf',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty ||
                      value.replaceAll(RegExp(r'[,\s]'), '') == '0') {
                    return 'Please enter an amount greater than 0';
                  }
                  final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
                  final amount = double.tryParse(cleanValue) ?? 0;
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
                onChanged: (value) {
                  if (value.isEmpty) return;
                  value = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (value.isEmpty) return;
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
                    if (mode == 'once') startDate ??= DateTime.now();
                  });
                },
              ),
              if (mode == 'weekly' || mode == 'monthly' || mode == 'once')
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    // Prefer a supplied preferredDate (e.g., the month range end) when opening the picker
                    final initial = preferredDate ?? startDate ?? now;
                    final d = await showDatePicker(
                      context: context,
                      initialDate: initial,
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
              const SizedBox(height: 8),
              // Add toggle for savings
              SwitchListTile(
                title: const Text('Mark as Savings'),
                subtitle: Text(
                  isSaving
                      ? 'This amount will be tracked separately, not deducted from budget'
                      : 'This is an expense that will be deducted from your budget',
                  style: TextStyle(
                    color: isSaving ? Colors.teal : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                value: isSaving,
                activeTrackColor: Colors.teal.withValues(alpha: 0.5),
                activeThumbColor: Colors.teal,
                onChanged: (value) {
                  dialogSetState(() {
                    isSaving = value;
                  });
                },
              ),
              // Add toggle for sub-items
              SwitchListTile(
                title: const Text('Enable Sub-items'),
                subtitle: const Text(
                  'Allow adding detailed sub-items to this budget item',
                ),
                value: enableSubItems,
                onChanged: (value) {
                  dialogSetState(() {
                    enableSubItems = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                final name = nameCtrl.text.trim();
                final amount =
                    double.tryParse(
                      amountCtrl.text.replaceAll(RegExp(r'[^\d]'), ''),
                    ) ??
                    0;

                final updatedItem = BudgetItem(
                  id: item.id,
                  name: name,
                  frequency: mode,
                  amount: amount,
                  startDate: startDate == null
                      ? null
                      : DateFormat('yyyy-MM-dd').format(startDate!),
                  hasSubItems: enableSubItems,
                  isSaving: isSaving,
                  subItems: item.subItems, // PRESERVE existing sub-items!
                );

                onSave(updatedItem);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}
