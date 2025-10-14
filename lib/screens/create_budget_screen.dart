import 'package:flutter/material.dart';
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
  final _amountCtrl = TextEditingController(text: '1000');
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
      amount: double.parse(_amountCtrl.text.trim()),
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
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? 'Enter amount'
                    : null,
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
