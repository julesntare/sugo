import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';

/// Shows a modal dialog to create or edit a budget
Future<Budget?> showCreateBudgetDialog(
  BuildContext context, {
  Budget? budget,
}) async {
  return showDialog<Budget>(
    context: context,
    builder: (context) => CreateBudgetDialog(budget: budget),
  );
}

class CreateBudgetDialog extends StatefulWidget {
  final Budget? budget;

  const CreateBudgetDialog({super.key, this.budget});

  @override
  State<CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends State<CreateBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  final _numberFormat = NumberFormat('#,###');
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _titleCtrl.text = widget.budget!.title;
      _amountCtrl.text = _numberFormat.format(widget.budget!.amount);
      _start = widget.budget!.start;
      _end = widget.budget!.end;
    }
  }

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
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final initialDate =
        _end ??
        _start?.add(const Duration(days: 30)) ??
        now.add(const Duration(days: 30));
    final d = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _start ?? DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _end = d);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    final id =
        widget.budget?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
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
    final isEditing = widget.budget != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Budget' : 'Create New Budget',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title field
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Budget Title',
                    hintText: 'e.g., Q1 2025 Budget',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: _amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Total Budget Amount',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    suffixText: 'Rwf',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    if (v == null || v.isEmpty) return 'Please enter an amount';
                    final clean = v.replaceAll(RegExp(r'[^\d]'), '');
                    final parsed = int.tryParse(clean);
                    if (parsed == null) return 'Invalid amount';
                    if (parsed <= 0) return 'Amount must be greater than 0';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Date selection
                Text(
                  'Budget Period',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Start date picker
                Material(
                  child: InkWell(
                    onTap: _pickStart,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _start != null
                                      ? DateFormat(
                                          'MMM dd, yyyy',
                                        ).format(_start!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _start != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color
                                              ?.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // End date picker
                Material(
                  child: InkWell(
                    onTap: _pickEnd,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _end != null
                                      ? DateFormat('MMM dd, yyyy').format(_end!)
                                      : 'Select date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _end != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color
                                              ?.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Duration summary
                if (_start != null && _end != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Budget duration: ${_end!.difference(_start!).inDays + 1} days (~${((_end!.difference(_start!).inDays + 1) / 30.44).toStringAsFixed(1)} months)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Budget',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
