  import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/history_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load local history
  await HistoryService().init();

  runApp(const BookScannerApp(showSplash: true));
}

class BookScannerApp extends StatelessWidget {
  final bool showSplash;

  const BookScannerApp({super.key, this.showSplash = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perpus Dupat - Scanner Buku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: showSplash ? const SplashScreen() : const HomeScreen(),
    );
  }
}

