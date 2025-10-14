import 'package:flutter/material.dart';
import '../models/budget.dart';
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
                return ListTile(
                  title: Text(b.title),
                  subtitle: Text('Amount: ${b.amount.toStringAsFixed(0)}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BudgetDetailScreen(budget: b),
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
