import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/budget.dart';
import '../services/storage.dart';
import '../services/backup_service.dart';
import '../services/firestore_sync_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/budget_card.dart';
import '../widgets/create_budget_dialog.dart';
import 'budget_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Budget> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgets();
    _checkAutoBackup();
    _syncFirestoreData();
  }

  Future<void> _syncFirestoreData() async {
    // Show toast that sync is in progress
    Fluttertoast.showToast(
      msg: "Syncing Firestore data...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.blue,
      textColor: Colors.white,
    );

    // Wait for budgets to load first
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // If no budgets exist, skip sync
    if (_budgets.isEmpty) {
      Fluttertoast.showToast(
        msg: "No budgets found",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    // Sync each budget (or just the first one if you prefer)
    // For now, syncing all budgets
    for (final budget in _budgets) {
      final result = await FirestoreSyncService.syncDailyTotals(budget);

      // Show result toast
      Fluttertoast.showToast(
        msg: result,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: result.startsWith('Sync') || result.startsWith('Updated')
            ? Colors.green
            : Colors.grey,
        textColor: Colors.white,
      );
    }

    // Reload budgets to reflect changes
    await _loadBudgets();
  }

  Future<void> _checkAutoBackup() async {
    final shouldBackup = await BackupService.shouldRunAutoBackup();
    if (shouldBackup) {
      await BackupService.performAutoBackup();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    final list = await Storage.loadBudgets();
    if (!mounted) return;
    setState(() {
      _budgets.clear();
      _budgets.addAll(list);
      _isLoading = false;
    });
  }

  Future<void> _createBudget() async {
    final budget = await showCreateBudgetDialog(context);
    if (budget != null) {
      setState(() => _budgets.add(budget));
      await Storage.saveBudget(budget);
    }
  }

  Future<void> _editBudget(Budget budget, int index) async {
    final updated = await showCreateBudgetDialog(context, budget: budget);
    if (updated != null) {
      // Preserve existing items and checklist when updating budget
      updated.items = budget.items;
      updated.checklist.addAll(budget.checklist);
      setState(() => _budgets[index] = updated);
      await Storage.updateBudget(updated);
    }
  }

  Future<void> _deleteBudget(Budget budget, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete \"${budget.title}\"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _budgets.removeAt(index));
      await Storage.deleteBudget(budget.id);
    }
  }

  void _openBudgetDetail(Budget budget, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetDetailScreen(
          budget: budget,
          onChanged: (updated) async {
            setState(() => _budgets[index] = updated);
            await Storage.updateBudget(updated);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with gradient
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _openSettings,
                tooltip: 'Settings',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Sugo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(gradient: AppTheme.mainGradient()),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Budget Forecast Made Simple',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stats overview (if budgets exist)
          if (_budgets.isNotEmpty && !_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildStatsCard(),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Empty state
          if (_budgets.isEmpty && !_isLoading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wallet, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No budgets yet',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first budget to get started',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _createBudget,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Budget'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Budget list
          if (_budgets.isNotEmpty && !_isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final budget = _budgets[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: BudgetCard(
                      budget: budget,
                      onTap: () => _openBudgetDetail(budget, index),
                      onEdit: () => _editBudget(budget, index),
                      onDelete: () => _deleteBudget(budget, index),
                    ),
                  );
                }, childCount: _budgets.length),
              ),
            ),
        ],
      ),
      floatingActionButton: _budgets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createBudget,
              icon: const Icon(Icons.add),
              label: const Text('New Budget'),
            )
          : null,
    );
  }

  Widget _buildStatsCard() {
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    double totalBudget = 0;
    double totalRemaining = 0;
    int activeCount = 0;

    final now = DateTime.now();
    final nowKey = DateFormat('yyyy-MM').format(now);

    for (final budget in _budgets) {
      totalBudget += budget.amount;

      // Calculate remaining for current period
      final keys = budget.monthKeys();
      String keyForRemaining;
      if (keys.contains(nowKey)) {
        keyForRemaining = nowKey;
        activeCount++;
      } else if (now.isBefore(budget.start)) {
        keyForRemaining = keys.isNotEmpty ? keys.first : nowKey;
      } else {
        keyForRemaining = keys.isNotEmpty ? keys.last : nowKey;
      }
      totalRemaining += budget.remainingUpTo(keyForRemaining);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Budget',
                    '${fmt.format(totalBudget)} Rwf',
                    AppColors.deepPurple,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: _buildStatItem(
                    'Total Remaining',
                    '${fmt.format(totalRemaining)} Rwf',
                    AppColors.teal,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Budgets',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Text(
                  '$activeCount of ${_budgets.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}