import 'package:flutter/material.dart';
import '../widgets/forecast_card.dart';
import '../models/forecast.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final List<Forecast> _forecasts = [];

  void _openCreate() async {
    final result = await Navigator.of(context).push<Forecast>(
      MaterialPageRoute(builder: (_) => const CreateForecastScreen()),
    );
    if (result != null) {
      setState(() => _forecasts.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create forecast')),
      body: _forecasts.isEmpty
          ? Center(
              child: TextButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create your first forecast'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _forecasts.length,
              itemBuilder: (context, index) {
                final f = _forecasts[index];
                return ForecastCard(
                  title: f.title,
                  months: f.months,
                  goal: f.goal,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreateForecastScreen extends StatefulWidget {
  const CreateForecastScreen({super.key});

  @override
  State<CreateForecastScreen> createState() => _CreateForecastScreenState();
}

class _CreateForecastScreenState extends State<CreateForecastScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  int _months = 6;
  int _goal = 1000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New forecast')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                onSaved: (v) => _title = v ?? '',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter a title' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Months'),
                keyboardType: TextInputType.number,
                initialValue: '6',
                onSaved: (v) => _months = int.tryParse(v ?? '') ?? 6,
                validator: (v) => (v == null || int.tryParse(v) == null)
                    ? 'Enter months as number'
                    : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Goal (amount)'),
                keyboardType: TextInputType.number,
                initialValue: '1000',
                onSaved: (v) => _goal = int.tryParse(v ?? '') ?? 1000,
                validator: (v) => (v == null || int.tryParse(v) == null)
                    ? 'Enter goal as number'
                    : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _formKey.currentState?.save();
                    final f = Forecast(
                      title: _title,
                      months: _months,
                      goal: _goal,
                    );
                    Navigator.of(context).pop(f);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
