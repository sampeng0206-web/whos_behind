import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/eula_consent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'services/billing_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  // Configure Purchases (RevenueCat) first at startup
  String apiKey = '';
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      apiKey = dotenv.env['REVENUECAT_API_KEY_ANDROID'] ?? '';
    } else if (Platform.isIOS) {
      apiKey = dotenv.env['REVENUECAT_API_KEY'] ?? '';
    }
  }

  if (apiKey.isNotEmpty) {
    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
    } catch (e) {
      debugPrint("Failed to configure Purchases at main.dart top level: $e");
    }
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.setDefaults(const {
      'ad_banner_enabled': true,
      'ad_banner_image_url': '',
      'ad_banner_target_url': 'mailto:sampeng0206@gmail.com',
      'ad_banner_link_type': 'mailto',
    });
    await remoteConfig.fetchAndActivate();
    debugPrint("Firebase Core and Remote Config initialized successfully.");
  } catch (e) {
    debugPrint("Firebase Core/Remote Config initialization failed: $e");
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

  Future<bool> _checkEulaStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasAcceptedEULA') ?? false;
    } catch (e) {
      debugPrint("Failed to read SharedPreferences for EULA: $e");
      return false;
    }
  }

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
      home: FutureBuilder<bool>(
        future: _checkEulaStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const DashboardScreen();
          }
          return const EulaConsentScreen();
        },
      ),
    );
  }
}
