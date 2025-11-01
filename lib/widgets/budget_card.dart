import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../widgets/app_theme.dart';

class BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final now = DateTime.now();
    final nowKey = DateFormat('yyyy-MM').format(now);
    final keys = budget.monthKeys();

    // Determine which month to show for remaining
    String keyForRemaining;
    bool isActive = false;
    bool isPast = false;

    if (keys.contains(nowKey)) {
      keyForRemaining = nowKey;
      isActive = true;
    } else if (now.isBefore(budget.start)) {
      keyForRemaining = keys.isNotEmpty ? keys.first : nowKey;
    } else {
      keyForRemaining = keys.isNotEmpty ? keys.last : nowKey;
      isPast = true;
    }

    final remaining = budget.remainingUpTo(keyForRemaining);
    final used = budget.amount - remaining;
    final percentage = budget.amount > 0
        ? (remaining / budget.amount) * 100
        : 0;
    final isLow = percentage < 20 && percentage >= 0;
    final isNegative = remaining < 0;

    // Calculate total months and months passed
    final totalMonths = keys.length;
    final monthsPassed = keys.indexOf(nowKey) + 1;
    final monthsLeft = isActive ? totalMonths - monthsPassed : 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [AppColors.deepPurple, AppColors.magenta]
                      : isPast
                      ? [Colors.grey[400]!, Colors.grey[600]!]
                      : [AppColors.teal, AppColors.deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat.yMMMd().format(budget.start)} - ${DateFormat.yMMMd().format(budget.end)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isActive, isPast),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Remaining',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isNegative
                                        ? Colors.red
                                        : isLow
                                        ? Colors.orange
                                        : AppColors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation(
                                  isNegative
                                      ? Colors.red
                                      : isLow
                                      ? Colors.orange
                                      : AppColors.teal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatColumn(
                          'Used',
                          '${fmt.format(used)} Rwf',
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: _buildStatColumn(
                          'Remaining',
                          '${fmt.format(remaining)} Rwf',
                          Icons.savings_outlined,
                          isNegative
                              ? Colors.red
                              : isLow
                              ? Colors.orange
                              : AppColors.teal,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Additional info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          Icons.calendar_month,
                          '$totalMonths months',
                        ),
                        if (isActive)
                          _buildInfoItem(Icons.schedule, '$monthsLeft left'),
                        _buildInfoItem(
                          Icons.receipt_long,
                          '${budget.items.length} items',
                        ),
                      ],
                    ),
                  ),

                  // Warning for negative balance
                  if (isNegative) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.red[700],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Budget exceeded!',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, bool isPast) {
    final String label;
    final Color color;

    if (isActive) {
      label = 'ACTIVE';
      color = Colors.greenAccent[400]!;
    } else if (isPast) {
      label = 'PAST';
      color = Colors.grey[300]!;
    } else {
      label = 'UPCOMING';
      color = Colors.blueAccent[100]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPast ? Colors.grey[700] : Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }
}
