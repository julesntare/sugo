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
    // If item is one-time, only show that specific month (if within budget range)
    final months = (_item.oneTimeMonth != null)
        ? (allMonths.contains(_item.oneTimeMonth) ? [_item.oneTimeMonth!] : [])
        : allMonths;
    final fmt = NumberFormat.currency(symbol: 'Rwf ', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: Text(_item.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: months.map((m) {
          final map = _budget.checklist[m] ?? {};
          final checked = map[_item.id] == true;
          final label = _item.monthlyAmount != null
              ? 'Monthly: ${fmt.format(_item.monthlyAmount)}'
              : (_item.oneTimeAmount != null
                    ? 'One-time: ${fmt.format(_item.oneTimeAmount)}'
                    : '');
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
