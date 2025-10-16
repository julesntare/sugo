import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../widgets/app_theme.dart';
import '../services/storage.dart';
import 'create_budget_screen.dart';
import 'budget_detail_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final List<Budget> _budgets = [];

  void _create() async {
    final b = await Navigator.of(context).push<Budget>(
      MaterialPageRoute(builder: (_) => const CreateBudgetScreen()),
    );
    if (b != null) setState(() => _budgets.add(b));
    // persist after creating
    await Storage.saveBudgets(_budgets);
  }

  @override
  void initState() {
    super.initState();
    // load persisted budgets
    Storage.loadBudgets().then((list) {
      if (!mounted) return;
      setState(() {
        _budgets.clear();
        _budgets.addAll(list);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: _budgets.isEmpty
          ? Center(
              child: TextButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Create budget'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _budgets.length,
              itemBuilder: (context, i) {
                final b = _budgets[i];
                // compute a sensible monthKey for remaining: prefer current month if in range
                final nowKey = DateFormat('yyyy-MM').format(DateTime.now());
                final keys = b.monthKeys();
                String keyForRemaining;
                if (keys.contains(nowKey)) {
                  keyForRemaining = nowKey;
                } else if (DateTime.now().isBefore(b.start)) {
                  // before budget starts - remaining is full amount
                  keyForRemaining = keys.isNotEmpty ? keys.first : nowKey;
                } else {
                  // after end - show remaining after last month
                  keyForRemaining = keys.isNotEmpty ? keys.last : nowKey;
                }
                final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
                return Dismissible(
                  key: Key(b.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Budget'),
                            content: Text(
                              'Are you sure you want to delete "${b.title}"?',
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
                    setState(() => _budgets.removeAt(i));
                    await Storage.deleteBudget(b.id);
                  },
                  child: Card(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BudgetDetailScreen(
                            budget: b,
                            onChanged: (updated) async {
                              // replace in list and persist
                              setState(() {
                                _budgets[i] = updated;
                              });
                              await Storage.saveBudgets(_budgets);
                            },
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppTheme.mainGradient(),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Amount: ${fmt.format(b.amount)} Rwf • Remaining: ${fmt.format(b.remainingUpTo(keyForRemaining))} Rwf',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final updated = await Navigator.of(context)
                                      .push<Budget>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CreateBudgetScreen(budget: b),
                                        ),
                                      );
                                  if (updated != null) {
                                    // Preserve existing items when updating budget
                                    updated.items = b.items;
                                    setState(() => _budgets[i] = updated);
                                    await Storage.updateBudget(updated);
                                  }
                                } else if (value == 'delete') {
                                  final confirmed =
                                      await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Budget'),
                                          content: Text(
                                            'Are you sure you want to delete "${b.title}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text('CANCEL'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text('DELETE'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (confirmed) {
                                    setState(() => _budgets.removeAt(i));
                                    await Storage.deleteBudget(b.id);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}
