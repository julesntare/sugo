import 'package:flutter/material.dart';
import '../widgets/forecast_card.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final List<int> _dummy = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create forecast')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _dummy.length,
        itemBuilder: (context, index) => ForecastCard(
          title: 'Forecast ${_dummy[index]}',
          months: 6 + index * 3,
          goal: 1000 * (index + 1),
        ),
      ),
    );
  }
}
