import 'package:flutter/material.dart';
import '../widgets/app_theme.dart';
import 'forecast_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugo'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppTheme.mainGradient()),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.mainGradient(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Budget forecast made simple',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForecastScreen()),
                );
              },
              icon: const Icon(Icons.show_chart),
              label: const Text('Create forecast'),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: Center(
                child: Text(
                  'No forecasts yet 14 tap "Create forecast" to begin.',
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ForecastScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
