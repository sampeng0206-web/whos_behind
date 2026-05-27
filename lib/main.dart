import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/billing_service.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Core initialization failed: $e");
  }

  try {
    await AdService.initialize();
  } catch (e) {
    debugPrint("AdService initialization failed: $e");
  }

  try {
    await BillingService.initialize();
  } catch (e) {
    debugPrint("BillingService initialization failed: $e");
  }

  runApp(const WhosBehindApp());
}

class WhosBehindApp extends StatelessWidget {
  const WhosBehindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '誰在亂搞？Who\'s Behind?',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSwatch(
          brightness: Brightness.dark,
          primarySwatch: Colors.red,
        ).copyWith(
          secondary: Colors.redAccent,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
