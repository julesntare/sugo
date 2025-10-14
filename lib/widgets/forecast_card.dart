import 'package:flutter/material.dart';
import 'app_theme.dart';

class ForecastCard extends StatelessWidget {
  final String title;
  final int months;
  final int goal;

  const ForecastCard({
    super.key,
    required this.title,
    required this.months,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.mainGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Months: $months • Goal: \$${goal.toString()}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                elevation: 0,
              ),
              child: const Text('Open', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
