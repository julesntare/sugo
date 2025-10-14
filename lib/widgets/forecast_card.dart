import 'package:flutter/material.dart';

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Months: $months • Goal: 	\		\$${goal.toString()}'),
                ],
              ),
            ),
            ElevatedButton(onPressed: () {}, child: const Text('Open')),
          ],
        ),
      ),
    );
  }
}
