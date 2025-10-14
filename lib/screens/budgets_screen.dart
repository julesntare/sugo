import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
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
                final fmt = NumberFormat.currency(
                  symbol: 'Rwf ',
                  decimalDigits: 0,
                );
                return ListTile(
                  title: Text(b.title),
                  subtitle: Text(
                    'Amount: ${fmt.format(b.amount)} • Remaining: ${fmt.format(b.remainingUpTo(keyForRemaining))}',
                  ),
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
