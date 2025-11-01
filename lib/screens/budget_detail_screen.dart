import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/budget_item.dart';
import '../models/sub_item.dart';
import '../services/storage.dart';
import '../widgets/app_theme.dart';
import 'item_detail_screen.dart';
import 'edit_item_dialog.dart';

class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;
  final void Function(Budget updated)? onChanged;

  const BudgetDetailScreen({super.key, required this.budget, this.onChanged});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late Budget _budget = widget.budget;
  late PageController _pageController;
  int _currentPage = 0;
  bool _isBudgetItemsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();

    // Initialize page controller - will be updated in build with correct initial page
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() async {
    final budget = await Storage.loadBudget(widget.budget.id);
    if (budget != null && mounted) {
      setState(() {
        _budget = budget;
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addItemDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '');
    final numberFormat = NumberFormat('#,###');
    String mode = 'once';
    bool enableSubItems = false;
    DateTime? startDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, dialogSetState) => AlertDialog(
          backgroundColor: AppColors.slate,
          title: const Text('Add item'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.label, color: AppColors.lightGrey),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      suffixText: 'Rwf',
                      prefixIcon: Icon(
                        Icons.payments,
                        color: AppColors.lightGrey,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          value.replaceAll(RegExp(r'[,\s]'), '') == '0') {
                        return 'Please enter an amount greater than 0';
                      }
                      final amount =
                          int.tryParse(
                            value.replaceAll(RegExp(r'[^\d]'), ''),
                          ) ??
                          0;
                      if (amount <= 0) {
                        return 'Amount must be greater than 0';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (value.isEmpty) return;
                      String cleanValue = value.replaceAll(
                        RegExp(r'[^\d]'),
                        '',
                      );
                      if (cleanValue.isEmpty) return;
                      int number = int.tryParse(cleanValue) ?? 0;
                      final formatted = numberFormat.format(number);
                      amountCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'once', child: Text('Once')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                    ],
                    onChanged: (v) {
                      dialogSetState(() {
                        mode = v ?? 'once';
                        startDate ??= DateTime.now();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
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
                    icon: const Icon(
                      Icons.calendar_today,
                      color: AppColors.lightGrey,
                    ),
                    label: Text(
                      startDate == null
                          ? 'Pick date'
                          : 'Start: ${DateFormat('yyyy-MM-dd').format(startDate!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      backgroundColor: AppColors.slateTint8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Enable Sub-items'),
                    subtitle: const Text('Allow adding detailed sub-items'),
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
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
                  if ((mode == 'once' ||
                          mode == 'weekly' ||
                          mode == 'monthly') &&
                      startDate == null) {
                    startDate = DateTime.now();
                  }

                  final id = DateTime.now().millisecondsSinceEpoch.toString();
                  final item = BudgetItem(
                    id: id,
                    name: name,
                    frequency: mode,
                    amount: amount,
                    startDate: startDate == null
                        ? null
                        : DateFormat('yyyy-MM-dd').format(startDate!),
                    hasSubItems: enableSubItems,
                  );
                  setState(() => _budget.items.add(item));
                  widget.onChanged?.call(_budget);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  bool _subItemAppliesInMonth(
    SubItem subItem,
    String monthKey,
    BudgetItem parentItem,
  ) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final thisMonthSalary = _budget.salaryDateForMonth(monthKey);
      DateTime rangeStart = thisMonthSalary;

      final nextDate = DateTime(year, month + 1, 1);
      final nextKey =
          '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
      final keys = _budget.monthKeys();
      DateTime rangeEnd;

      final isLast = keys.isNotEmpty && monthKey == keys.last;
      if (isLast) {
        rangeEnd = _budget.end;
      } else {
        final nextSalary = _budget.salaryDateForMonth(nextKey);
        rangeEnd = nextSalary.subtract(const Duration(days: 1));
      }

      // Get the effective start date for this sub-item (use parent start date as fallback)
      String? effectiveStartDate = subItem.startDate ?? parentItem.startDate;

      if (subItem.frequency == 'monthly') {
        if (effectiveStartDate == null) return true;
        final sd = DateTime.parse(effectiveStartDate);
        return !sd.isAfter(rangeEnd);
      } else if (subItem.frequency == 'weekly') {
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        if (sd.isAfter(rangeEnd)) return false;
        int offsetDays = rangeStart.difference(sd).inDays;
        int weeksOffset = 0;
        if (offsetDays > 0) weeksOffset = (offsetDays + 6) ~/ 7;
        DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
        if (firstOcc.isAfter(rangeEnd)) return false;
        return true;
      } else {
        if (effectiveStartDate == null) return false;
        final sd = DateTime.parse(effectiveStartDate);
        return !sd.isBefore(rangeStart) && !sd.isAfter(rangeEnd);
      }
    } catch (_) {
      return false;
    }
  }

  Widget _buildMonthCard(String key, NumberFormat fmt) {
    bool itemAppliesInMonth(BudgetItem it, String monthKey) {
      try {
        final parts = monthKey.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);

        final thisMonthSalary = _budget.salaryDateForMonth(monthKey);
        DateTime rangeStart = thisMonthSalary;

        final nextDate = DateTime(year, month + 1, 1);
        final nextKey =
            '${nextDate.year.toString().padLeft(4, '0')}-${nextDate.month.toString().padLeft(2, '0')}';
        final keys = _budget.monthKeys();
        DateTime rangeEnd;

        final isLast = keys.isNotEmpty && monthKey == keys.last;
        if (isLast) {
          rangeEnd = _budget.end;
        } else {
          final nextSalary = _budget.salaryDateForMonth(nextKey);
          rangeEnd = nextSalary.subtract(const Duration(days: 1));
        }

        if (it.frequency == 'monthly') {
          if (it.startDate == null) return true;
          final sd = DateTime.parse(it.startDate!);
          return !sd.isAfter(rangeEnd);
        } else if (it.frequency == 'weekly') {
          if (it.startDate == null) return false;
          final sd = DateTime.parse(it.startDate!);
          if (sd.isAfter(rangeEnd)) return false;
          int offsetDays = rangeStart.difference(sd).inDays;
          int weeksOffset = 0;
          if (offsetDays > 0) weeksOffset = (offsetDays + 6) ~/ 7;
          DateTime firstOcc = sd.add(Duration(days: weeksOffset * 7));
          if (firstOcc.isAfter(rangeEnd)) return false;
          return true;
        } else {
          if (it.startDate == null) return false;
          final sd = DateTime.parse(it.startDate!);
          return !sd.isBefore(rangeStart) && !sd.isAfter(rangeEnd);
        }
      } catch (_) {
        return false;
      }
    }

    final keys = _budget.monthKeys();
    final monthlySalary = keys.isNotEmpty ? _budget.amount / keys.length : 0.0;
    final deductions = _budget.deductionsForMonth(key);
    final remaining = _budget.remainingForMonth(key);
    final monthLabel = _budget.monthRangeLabel(key);
    final monthItems = _budget.items
        .where((it) => itemAppliesInMonth(it, key))
        .toList();
    final monthChecks = _budget.checklist[key] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: AppColors.cardGrey,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppTheme.mainGradient(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit salary date for this month',
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () async {
                      final current = _budget.monthSalaryOverrides[key] != null
                          ? DateTime.parse(_budget.monthSalaryOverrides[key]!)
                          : _budget.salaryDateForMonth(key);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: current,
                        firstDate: DateTime(_budget.start.year - 1),
                        lastDate: DateTime(_budget.end.year + 1),
                      );
                      if (picked != null) {
                        setState(() {
                          _budget.monthSalaryOverrides[key] = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                        await Storage.updateBudget(_budget);
                        widget.onChanged?.call(_budget);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Salary: ${fmt.format(monthlySalary)} Rwf • Deductions: ${fmt.format(deductions)} Rwf • Remaining: ${fmt.format(remaining)} Rwf',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.lightGrey),
              ),
              const Divider(),
              if (monthItems.isEmpty)
                Text('No items', style: TextStyle(color: AppColors.lightGrey))
              else
                ...monthItems.map((it) {
                  final explicitlyChecked = monthChecks[it.id] == true;
                  // Get the actual amount for this month (considering overrides)
                  final actualAmount =
                      _budget.monthItemAmountOverrides[key]?[it.id] ??
                      it.amount ??
                      0;

                  // Check for sub-items completion status
                  bool isAutoChecked = false;
                  bool isBudgetExceeded = false;
                  double completedSubItemsTotal = 0.0;

                  if (it.hasSubItems) {
                    // Get sub-items that apply to this month
                    final applicableSubItems = it.subItems.where((subItem) {
                      return _subItemAppliesInMonth(subItem, key, it);
                    }).toList();

                    if (applicableSubItems.isNotEmpty) {
                      // Count completed sub-items and their total amount
                      final completedSubItems = applicableSubItems.where((
                        subItem,
                      ) {
                        final checklistKey = 'subitem_${it.id}_${subItem.id}';
                        return monthChecks[checklistKey] == true;
                      }).toList();

                      final completedCount = completedSubItems.length;

                      // Calculate total amount of completed sub-items
                      completedSubItemsTotal = completedSubItems.fold(
                        0.0,
                        (sum, subItem) => sum + subItem.amount,
                      );

                      // Check if budget is exceeded
                      isBudgetExceeded = completedSubItemsTotal > actualAmount;

                      // Check if any sub-items are completed
                      if (completedCount > 0) {
                        // Auto-check if not explicitly checked and has any completed sub-items
                        isAutoChecked = !explicitlyChecked;
                      }
                    }
                  }

                  final checked = explicitlyChecked || isAutoChecked;

                  // Build frequency label
                  String frequencyLabel = '';
                  if (it.frequency == 'monthly') {
                    frequencyLabel = 'Monthly: ${fmt.format(actualAmount)} Rwf';
                  } else if (it.frequency == 'weekly') {
                    frequencyLabel = 'Weekly: ${fmt.format(actualAmount)} Rwf';
                  } else if (it.frequency == 'once') {
                    frequencyLabel =
                        'One-time: ${fmt.format(actualAmount)} Rwf';
                  }

                  // Get the salary range start date for this month
                  final rangeStartDate = _budget.salaryDateForMonth(key);
                  final rangeStartDateStr = DateFormat(
                    'yyyy-MM-dd',
                  ).format(rangeStartDate);

                  // Get completion date if item is checked
                  final completionDate = _budget.completionDates[key]?[it.id];

                  // Add start date if item has not started yet
                  if (!checked) {
                    frequencyLabel += '\nStart: $rangeStartDateStr';
                  }

                  // Add "Started" date if item is marked as completed
                  if (checked && completionDate != null) {
                    frequencyLabel += '\nStarted: $completionDate';
                  }

                  return ListTile(
                    title: Text(
                      it.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      frequencyLabel,
                      style: TextStyle(color: AppColors.lightGrey),
                    ),
                    trailing: Checkbox(
                      value: checked,
                      fillColor: WidgetStateProperty.resolveWith<Color>((
                        states,
                      ) {
                        if (explicitlyChecked) {
                          // Explicitly checked - use primary color
                          return Theme.of(context).colorScheme.primary;
                        }
                        if (isAutoChecked) {
                          // Auto-checked from sub-items
                          if (isBudgetExceeded) {
                            // Budget exceeded - use danger/red color
                            return AppColors.danger;
                          }
                          // Has completed sub-items, budget not exceeded - use warning/orange color
                          // This persists until next monthly range starts
                          return AppColors.warning;
                        }
                        // Unchecked - transparent
                        return Colors.transparent;
                      }),
                      checkColor: Colors.white,
                      onChanged: (v) async {
                        if (v == true) {
                          // If clicking to check (from unchecked or partial state)
                          // Show date picker when marking as completed
                          final now = DateTime.now();
                          // Ensure initialDate is within the valid range
                          final initialDate = now.isBefore(rangeStartDate)
                              ? rangeStartDate
                              : now;

                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: rangeStartDate,
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            helpText: 'Select completion date',
                          );

                          if (selectedDate != null) {
                            setState(() {
                              // Mark as explicitly checked
                              final checkMap = _budget.checklist[key] ?? {};
                              checkMap[it.id] = true;
                              _budget.checklist[key] = checkMap;

                              // Record completion date
                              final dateMap =
                                  _budget.completionDates[key] ?? {};
                              dateMap[it.id] = DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedDate);
                              _budget.completionDates[key] = dateMap;
                            });
                            await Storage.updateBudget(_budget);
                            widget.onChanged?.call(_budget);
                          }
                        } else {
                          // Unchecking - only uncheck if it was explicitly checked
                          // If it's only partially checked (from sub-items), this does nothing
                          if (explicitlyChecked) {
                            setState(() {
                              final checkMap = _budget.checklist[key] ?? {};
                              checkMap[it.id] = false;
                              _budget.checklist[key] = checkMap;

                              // Remove completion date
                              final dateMap =
                                  _budget.completionDates[key] ?? {};
                              dateMap.remove(it.id);
                              if (dateMap.isNotEmpty) {
                                _budget.completionDates[key] = dateMap;
                              } else {
                                _budget.completionDates.remove(key);
                              }
                            });
                            await Storage.updateBudget(_budget);
                            widget.onChanged?.call(_budget);
                          }
                          // If only partially checked, user must go to sub-items to uncheck
                        }
                      },
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          budget: _budget,
                          item: it,
                          onChanged: (updated) {
                            setState(() => _budget = updated);
                            widget.onChanged?.call(_budget);
                          },
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = _budget.monthKeys();
    final months = allMonths
        .where((monthKey) => _budget.monthRangeLabel(monthKey).isNotEmpty)
        .toList();
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);

    if (months.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_budget.title)),
        body: const Center(child: Text('No valid months in this budget')),
      );
    }

    // Find current active month based on salary date ranges
    final activeMonthKey = _budget.currentActiveMonthKey();
    int initialPage = months.indexOf(activeMonthKey);
    if (initialPage == -1) {
      initialPage = 0;
    }

    // Reinitialize page controller if needed
    if (_currentPage != initialPage && !_pageController.hasClients) {
      _pageController = PageController(initialPage: initialPage);
      _currentPage = initialPage;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_budget.title)),
      body: Column(
        children: [
          // Budget items header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isBudgetItemsExpanded = !_isBudgetItemsExpanded;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget items',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      Icon(
                        _isBudgetItemsExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isBudgetItemsExpanded) ...[
                  if (_budget.items.isEmpty)
                    Text(
                      'No items added yet',
                      style: TextStyle(color: AppColors.lightGrey),
                    )
                  else
                    Column(
                      children: _budget.items.map((it) {
                        String label = '';
                        if (it.frequency == 'monthly') {
                          label = 'Monthly: ${fmt.format(it.amount ?? 0)} Rwf';
                        } else if (it.frequency == 'weekly') {
                          label = 'Weekly: ${fmt.format(it.amount ?? 0)} Rwf';
                        } else {
                          label = 'One-time: ${fmt.format(it.amount ?? 0)} Rwf';
                        }
                        return Dismissible(
                          key: Key(it.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Item'),
                                    content: Text(
                                      'Are you sure you want to delete "${it.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('CANCEL'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('DELETE'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                          },
                          onDismissed: (direction) async {
                            setState(() {
                              _budget.items.removeWhere(
                                (item) => item.id == it.id,
                              );
                            });
                            await Storage.deleteBudgetItem(it.id);
                            widget.onChanged?.call(_budget);
                          },
                          child: Card(
                            color: AppColors.cardGrey,
                            child: ListTile(
                              title: Text(
                                it.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                label,
                                style: TextStyle(color: AppColors.lightGrey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      DateTime? preferredDate;
                                      if (it.startDate != null) {
                                        try {
                                          preferredDate = DateTime.parse(
                                            it.startDate!,
                                          );
                                        } catch (_) {
                                          preferredDate = null;
                                        }
                                      }

                                      await showEditItemDialog(context, it, (
                                        updatedItem,
                                      ) {
                                        setState(() {
                                          final index = _budget.items
                                              .indexWhere(
                                                (item) => item.id == it.id,
                                              );
                                          if (index != -1) {
                                            _budget.items[index] = updatedItem;
                                          }
                                        });
                                        Storage.updateBudgetItem(updatedItem);
                                        widget.onChanged?.call(_budget);
                                      }, preferredDate: preferredDate);
                                    },
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(
                                    budget: _budget,
                                    item: it,
                                    onChanged: (updated) {
                                      setState(() => _budget = updated);
                                      widget.onChanged?.call(_budget);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                ],
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly ranges',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${_currentPage + 1} / ${months.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.lightGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Swipeable monthly ranges with navigation arrows
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: months.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final key = months[index];
                    return _buildMonthCard(key, fmt);
                  },
                ),
                // Left arrow
                if (_currentPage > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // Right arrow
                if (_currentPage < months.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
