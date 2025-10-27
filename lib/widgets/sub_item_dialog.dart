import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sub_item.dart';

/// Shows a modal dialog to create or edit a sub-item
Future<SubItem?> showSubItemDialog(
  BuildContext context, {
  SubItem? subItem,
  double? maxAmount,
}) async {
  return showDialog<SubItem>(
    context: context,
    builder: (context) => SubItemDialog(subItem: subItem, maxAmount: maxAmount),
  );
}

class SubItemDialog extends StatefulWidget {
  final SubItem? subItem;
  final double? maxAmount;

  const SubItemDialog({super.key, this.subItem, this.maxAmount});

  @override
  State<SubItemDialog> createState() => _SubItemDialogState();
}

class _SubItemDialogState extends State<SubItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  final _descriptionCtrl = TextEditingController();
  String _frequency = 'once';
  DateTime? _startDate;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.subItem != null) {
      _nameCtrl.text = widget.subItem!.name;
      _amountCtrl.text = NumberFormat('#,###').format(widget.subItem!.amount);
      _descriptionCtrl.text = widget.subItem!.description ?? '';
      _frequency = widget.subItem!.frequency;
      if (widget.subItem!.startDate != null) {
        try {
          _startDate = DateTime.parse(widget.subItem!.startDate!);
        } catch (e) {
          _startDate = null;
        }
      }
      _isCompleted = widget.subItem!.isCompleted;
    } else {
      // Set default name for new sub-items
      _nameCtrl.text = _getDefaultSubItemName();
    }
    _amountCtrl.addListener(_formatAmount);
  }

  /// Generates a default sub-item name based on today's date
  /// Format: "25th oct 25 misc" for October 25, 2025
  String _getDefaultSubItemName() {
    final now = DateTime.now();
    final day = now.day;
    final month = DateFormat('MMM').format(now).toLowerCase();
    final year = now.year.toString().substring(2); // Last 2 digits of year

    // Get ordinal suffix (st, nd, rd, th)
    String getOrdinalSuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    final suffix = getOrdinalSuffix(day);
    return '$day$suffix $month $year misc';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.removeListener(_formatAmount);
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _formatAmount() {
    // Get the current input value and remove any formatting
    String value = _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (value.isNotEmpty) {
      // Parse as integer and format with commas
      int numValue = int.tryParse(value) ?? 0;
      String formattedValue = NumberFormat('#,###').format(numValue);

      // Update the text field with the formatted value
      _amountCtrl.value = TextEditingValue(
        text: formattedValue,
        selection: TextSelection.collapsed(offset: formattedValue.length),
      );
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final id =
        widget.subItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    final subItem = SubItem(
      id: id,
      name: _nameCtrl.text.trim(),
      amount: amount,
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      frequency: _frequency,
      startDate: _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null,
      isCompleted: _isCompleted,
    );

    Navigator.of(context).pop(subItem);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subItem != null;

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
                        isEditing ? 'Edit Sub-item' : 'Add Sub-item',
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

                // Name field
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sub-item Name',
                    hintText: 'e.g., Groceries, Fuel',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: _amountCtrl,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.payments),
                    suffixText: 'Rwf',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter an amount';
                    final amount = int.tryParse(
                      v.replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                    if (amount == null) return 'Invalid amount';
                    if (amount <= 0) return 'Amount must be greater than 0';
                    if (widget.maxAmount != null &&
                        amount > widget.maxAmount!) {
                      return 'Amount cannot exceed ${NumberFormat('#,###').format(widget.maxAmount)} Rwf';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Additional details',
                    prefixIcon: const Icon(Icons.note),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Frequency dropdown
                DropdownButtonFormField<String>(
                  value: _frequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'once', child: Text('Once')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _frequency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Start date picker
                if (_frequency != 'once')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final initialDate = _startDate ?? now;
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (selectedDate != null) {
                        setState(() {
                          _startDate = selectedDate;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _startDate == null
                          ? 'Select start date'
                          : DateFormat('yyyy-MM-dd').format(_startDate!),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                const SizedBox(height: 16),

                // Completed checkbox
                CheckboxListTile(
                  title: const Text('Completed'),
                  value: _isCompleted,
                  onChanged: (value) {
                    setState(() {
                      _isCompleted = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
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
                          isEditing ? 'Save Changes' : 'Add Sub-item',
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
