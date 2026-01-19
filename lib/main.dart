import 'package:flutter/material.dart';
import 'widgets/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SugoApp());
}

class SugoApp extends StatelessWidget {
  const SugoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.light();
    return MaterialApp(
      title: 'Sugo',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Container(
        decoration: BoxDecoration(gradient: AppTheme.mainGradient()),
        child: const HomeScreen(),
      ),
    );
  }
}
