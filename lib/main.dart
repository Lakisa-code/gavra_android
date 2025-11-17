import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'globals.dart';
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/analytics_service.dart';
import 'services/cache_service.dart';
import 'services/firebase_background_handler.dart';
import 'services/firebase_service.dart';
import 'services/offline_map_service.dart';
import 'services/push_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/simple_usage_monitor.dart';
import 'services/theme_manager.dart'; // 🎨 Novi tema sistem
import 'services/voice_navigation_service.dart';
import 'services/vozac_mapping_service.dart'; // 🗂️ DODATO za inicijalizaciju mapiranja
import 'supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📊 POKRETANJE MONITORING SERVISA
  try {
    await SimpleUsageMonitor.pokreni();
  } catch (e) {
    // Ignoriši greške u monitoring-u
  }

  // 🔥 FIREBASE INICIJALIZACIJA
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseService.initialize();
    await AnalyticsService.initialize();
    FirebaseService.setupFCMListeners();
  } catch (e) {
    // Continue without Firebase if it fails
  }

  // 🌐 SUPABASE INICIJALIZACIJA
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 5));

    // 🗂️ INICIJALIZUJ VOZAC MAPPING CACHE
    try {
      await VozacMappingService.initialize();
    } catch (e) {
      // Nastavi bez vozac mapping-a ako ne uspe
    }
  } catch (e) {
    // Continue without Supabase if it fails
  }

  // 🛰️ INITIALIZE BACKGROUND GPS SERVICE (OPTIONAL - Disabled for stability)
  // try {
  //   await BackgroundGpsService.initialize();
  // } catch (e) {
  //   // Ignoriši greške u background GPS - optional feature
  // }

  // 🗺️ INITIALIZE OFFLINE MAPS
  try {
    await OfflineMapService.initialize();
  } catch (e) {
    // Ignoriši greške u offline maps - optional feature
  }

  // 🔊 INITIALIZE VOICE NAVIGATION
  try {
    await VoiceNavigationService.initialize();
  } catch (e) {
    // Ignoriši greške u voice navigation - optional feature
  }

  // 🟦 INITIALIZE PUSH SERVICE (FCM + HMS)
  try {
    await PushService.initialize();
  } catch (e) {}

  // Handle cold-start notification
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      RealtimeNotificationService.handleInitialMessage(initialMessage);
    }
  } catch (e) {}

  // Register background handler for FCM - must be top-level function
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // If a driver session exists, tokens should be registered automatically through PushService.initialize()

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupAuthListener();
  }

  // 🔐 SETUP AUTH STATE LISTENER ZA EMAIL VERIFICATION
  void _setupAuthListener() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.signedIn && session != null) {
          // Korisnik je uspešno ulogovan nakon email verification
        }
      });
    } catch (e) {}
  }

  Future<void> _initializeApp() async {
    try {
      // 🚀 OPTIMIZOVANA INICIJALIZACIJA SA CACHE CLEANUP
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // 🎨 Inicijalizuj ThemeManager
      await ThemeManager().initialize();

      // 🔄 Auto-update removed as per request

      // 🧹 PERIODIČKI CLEANUP - svaki put kada se app pokrene
      CacheService.performAutomaticCleanup();

      // 🔥 Kreiranje timer-a za automatski cleanup svakih 10 minuta
      Timer.periodic(const Duration(minutes: 10), (_) {
        CacheService.performAutomaticCleanup();
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeData>(
      valueListenable: ThemeManager().themeNotifier,
      builder: (context, themeData, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Gavra 013',
          debugShowCheckedModeBanner: false,
          theme: themeData, // Light tema
          // Samo jedna tema - nema dark mode
          navigatorObservers: [
            if (AnalyticsService.observer != null) AnalyticsService.observer!,
          ],
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return LoadingScreen(error: _initError);
    }

    if (!_isInitialized) {
      return const LoadingScreen();
    }

    return const WelcomeScreen();
  }
}
