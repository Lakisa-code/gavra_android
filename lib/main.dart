import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals.dart';
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/adresa_supabase_service.dart'; // 🧹 Za čišćenje koordinata
import 'services/analytics_service.dart';
import 'services/cache_service.dart';
import 'services/firebase_background_handler.dart';
import 'services/firebase_service.dart';
import 'services/huawei_push_service.dart';
import 'services/offline_map_service.dart';
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

  // 🔥 CLOUD/NOTIFICATION PROVIDER INITIALIZATION
  // Decide which push provider to use depending on device capabilities.
  // bool firebaseAvailable = false; // track if Firebase/FCM inited (kept for future use)
  try {
    final availability = await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
    final gmsOk = availability == GooglePlayServicesAvailability.success;

    if (gmsOk) {
      // Device has Google Play services -> initialize Firebase normally
      try {
        await Firebase.initializeApp();

        // Register FCM background handler and initialize messaging helpers
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        } catch (_) {}

        await FirebaseService.initialize();
        await AnalyticsService.initialize();
        FirebaseService.setupFCMListeners();
        // firebaseAvailable = true; // used to reflect successful Firebase init
        print('Init: Google Play Services available -> Firebase/FCM enabled');

        // Debug helper: dump FCM token to logs so testers can use it for E2E
        if (kDebugMode) {
          try {
            final fcmToken = await FirebaseService.getFCMToken();
            // mask token in logs when printing publicly — but during local testing we show full token
            debugPrint('FCM token (debug): ${fcmToken ?? '[null]'}');
          } catch (e) {
            debugPrint('FCM token retrieval failed: $e');
          }
        }
      } catch (e) {
        // If Firebase init fails, fall through to Huawei initialization
        print('Firebase init failed: $e - will try Huawei Push as fallback');
      }
    } else {
      // No GMS available — initialize Huawei Push if possible
      print('Init: Google Play Services NOT available (status=$availability) -> trying HMS');
      try {
        final token = await HuaweiPushService().initialize();
        debugPrint(
            'HMS init attempt returned token: ${token ?? 'null'} (no immediate token available — stream will register later if a token arrives)');
      } catch (e) {
        debugPrint('HMS initialization attempt failed: $e');
      }
    }
  } catch (e) {
    // Unexpected checks failed — attempt graceful Firebase initialization as a fallback
    try {
      // await Firebase.initializeApp(
      //   options: DefaultFirebaseOptions.currentPlatform,
      // );
      // await FirebaseService.initialize();
      // await AnalyticsService.initialize();
      // FirebaseService.setupFCMListeners();
      // firebaseAvailable = true; // fallback succeeded
      print('Fallback: Huawei Push initialized despite prior error: $e');
      try {
        final token = await HuaweiPushService().initialize();
        debugPrint(
            'HMS fallback init returned token (masked): ${token != null ? '[REDACTED]' : 'null'} (no immediate token — stream may register later)');
      } catch (e) {
        debugPrint('HMS fallback initialization attempt failed: $e');
      }
    } catch (_) {
      print('Fallback failed — continuing without push services: $e');
    }
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

    // 🧹 JEDNOM: Očisti koordinate centra grada iz baze
    // Ovo omogućava GPS Learn da nauči prave koordinate
    try {
      final clearedCount = await AdresaSupabaseService.clearCityCenterCoordinates();
      if (clearedCount > 0) {
        print('🧹 Očišćeno $clearedCount adresa sa koordinatama centra grada');
      }
    } catch (e) {
      print('⚠️ Čišćenje koordinata nije uspelo: $e');
    }
  } catch (e) {
    // Continue without Supabase if it fails
  }

  // 🛰️ GPS MANAGER - centralizovani GPS singleton
  // GpsManager.instance se koristi lazy - ne treba inicijalizacija ovde
  // Tracking se pokreće kad je potreban (danas_screen, navigation widget)

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

  // 🔐 INITIALIZE CACHE SERVICE
  try {
    await CacheService.initialize();
  } catch (e) {
    // Ignoriši greške u cache - optional feature
  }

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
    // Setup realtime notification listeners (FCM) for foreground handling
    try {
      RealtimeNotificationService.listenForForegroundNotifications(context);
    } catch (_) {}
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
