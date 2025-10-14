import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// lightweight id generation (milliseconds since epoch) -- avoids extra dependency
import '../models/budget.dart';

class CreateBudgetScreen extends StatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  final _numberFormat = NumberFormat('#,###');
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _end = d);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_start == null || _end == null) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final b = Budget(
      id: id,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '')),
      start: _start!,
      end: _end!,
    );
    Navigator.of(context).pop(b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create budget')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _amountCtrl,
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
                  final formatted = _numberFormat.format(number);
                  _amountCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                },
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  final clean = v.replaceAll(RegExp(r'[^\d]'), '');
                  return int.tryParse(clean) == null ? 'Invalid amount' : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _start == null
                          ? 'Start date'
                          : 'Start: ${_start!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  TextButton(onPressed: _pickStart, child: const Text('Pick')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _end == null
                          ? 'End date'
                          : 'End: ${_end!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  TextButton(onPressed: _pickEnd, child: const Text('Pick')),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _submit, child: const Text('Create')),
            ],
          ),
        ),
      ),
    );
  }
}
