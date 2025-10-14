import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'widgets/app_theme.dart';
import 'screens/home_screen.dart';
import 'models/budget_adapter.dart';
import 'models/budget_item_adapter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // register adapters
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BudgetItemAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BudgetAdapter());
  // open budgets box
  await Hive.openBox('budgets');

  runApp(const SugoApp());
}

class SugoApp extends StatelessWidget {
  const SugoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sugo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeScreen(),
    );
  }
}
