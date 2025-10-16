import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import 'package:intl/intl.dart';

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
          String label = '';
          if (_item.frequency == 'monthly') {
            label = 'Monthly: ${fmt.format(_item.amount ?? 0)} Rwf';
          } else if (_item.frequency == 'weekly') {
            label = 'Weekly: ${fmt.format(_item.amount ?? 0)} Rwf';
          } else if (_item.frequency == 'once') {
            label = 'One-time: ${fmt.format(_item.amount ?? 0)} Rwf';
          }
          if (_item.startDate != null) {
            label = '$label\nStart: ${_item.startDate}';
          }
          return CheckboxListTile(
            title: Text(m),
            subtitle: Text(label),
            value: checked,
            onChanged: (v) {
              setState(() {
                final newMap = _budget.checklist[m] ?? {};
                newMap[_item.id] = v == true;
                _budget.checklist[m] = newMap;
              });
              widget.onChanged?.call(_budget);
            },
          );
        }).toList(),
      ),
    );
  }
}
