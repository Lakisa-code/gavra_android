import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📱 Za Edge-to-Edge prikaz (Android 15+)
import 'package:google_api_availability/google_api_availability.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'globals.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings_service.dart'; // 🔧 Podešavanja aplikacije (nav bar tip)
import 'services/cache_service.dart';
import 'services/firebase_background_handler.dart';
import 'services/firebase_service.dart';
import 'services/huawei_push_service.dart';
import 'services/putnik_service.dart'; // 🔄 DODATO za nedeljni reset
import 'services/realtime_gps_service.dart'; // 🛰️ DODATO za cleanup
import 'services/realtime_notification_service.dart';
import 'services/sms_service.dart'; // 📱 SMS podsetnici za plaćanje
import 'services/theme_manager.dart'; // 🎨 Novi tema sistem
import 'services/vozac_mapping_service.dart'; // 🗂️ DODATO za inicijalizaciju mapiranja
import 'services/weather_service.dart'; // 🌤️ DODATO za cleanup
import 'supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 📱 EDGE-TO-EDGE PRIKAZ ZA ANDROID 15+ (SDK 35)
  // Omogućava prikaz od ivice do ivice sa pravilnim insets-ima
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 🌍 INICIJALIZACIJA LOCALE ZA FORMATIRANJE DATUMA
  await initializeDateFormatting('sr_RS', null);

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
        FirebaseService.setupFCMListeners();

        // 📲 REGISTRUJ FCM TOKEN NA SERVER (push_tokens tabela)
        // Ovo omogućava slanje push notifikacija na Samsung i druge GMS uređaje
        try {
          final fcmToken = await FirebaseService.initializeAndRegisterToken();
          if (kDebugMode && fcmToken != null) {
            debugPrint('📲 [FCM] Token registered: ${fcmToken.substring(0, 20)}...');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ [FCM] Token registration failed: $e');
        }
      } catch (e) {
        // If Firebase init fails, fall through to Huawei initialization
      }
    } else {
      // No GMS available — initialize Huawei Push if possible
      try {
        await HuaweiPushService().initialize();
        // Try to register any pending tokens from previous sessions
        await HuaweiPushService().tryRegisterPendingToken();
      } catch (e) {
        // HMS initialization attempt failed
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
      try {
        await HuaweiPushService().initialize();
        // Try to register any pending tokens from previous sessions
        await HuaweiPushService().tryRegisterPendingToken();
      } catch (e) {
        // HMS fallback initialization attempt failed
      }
    } catch (_) {}
  }

  // 🌐 SUPABASE INICIJALIZACIJA
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 5));

    // If Huawei Push initialized earlier and a token arrived before
    // Supabase was ready, attempt to register that token now.
    try {
      await HuaweiPushService().tryRegisterPendingToken();
    } catch (e) {
      // Error registering pending Huawei token after Supabase init
    }

    // 📲 Pokušaj registrovati pending FCM token ako postoji
    try {
      await FirebaseService.tryRegisterPendingToken();
    } catch (e) {
      // Error registering pending FCM token after Supabase init
    }

    // 🗂️ INICIJALIZUJ VOZAC MAPPING CACHE
    try {
      await VozacMappingService.initialize();
    } catch (e) {
      // Nastavi bez vozac mapping-a ako ne uspe
    }

    // 🔧 INICIJALIZUJ APP SETTINGS SERVICE (nav bar tip iz baze)
    try {
      await AppSettingsService.initialize();
    } catch (e) {
      // Nastavi bez app settings ako ne uspe - default je 'auto'
    }

    // 🔄 NEDELJNI RESET - Proveri da li treba resetovati polasci_po_danu
    // Izvršava se u subotu ujutru, NE resetuje bolovanje/godišnji
    try {
      await PutnikService().checkAndPerformWeeklyReset();
    } catch (e) {
      // Weekly reset check failed - silent
    }

    // 🔄 REALTIME se inicijalizuje lazy kroz PutnikService
    // Ne treba eksplicitna pretplata ovde - PutnikService.streamKombinovaniPutniciFiltered()
    // će se pretplatiti kad neki ekran zatraži stream

    // GPS Learn će naučiti prave koordinate kada vozač pokupi putnika
  } catch (e) {
    // Continue without Supabase if it fails
  }

  // 🛠️ GPS MANAGER - centralizovani GPS singleton
  // GpsManager.instance se koristi lazy - ne treba inicijalizacija ovde
  // Tracking se pokreće kad je potreban (danas_screen, navigation widget)

  // 🔐 INITIALIZE CACHE SERVICE
  try {
    await CacheService.initialize();
  } catch (e) {
    // Ignoriši greške u cache - optional feature
  }

  // 📱 POKRENI SMS SERVIS - automatski podsetnici za plaćanje
  // Predzadnji dan meseca u 20:00 + prvi dan meseca u 10:00
  try {
    SMSService.startAutomaticSMSService();
  } catch (e) {
    // Ignoriši greške u SMS servisu
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    // Setup realtime notification listeners (FCM) for foreground handling
    try {
      RealtimeNotificationService.listenForForegroundNotifications(context);
    } catch (_) {}

    // 🔔 FORCE SUBSCRIBE to FCM topics on app start (for testing)
    _forceSubscribeToTopics();
  }

  Future<void> _forceSubscribeToTopics() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Wait for Firebase init
      if (!mounted) return; // 🛡️ Zaštita od poziva nakon dispose
      await RealtimeNotificationService.subscribeToDriverTopics('test_driver');
    } catch (e) {
      // FORCE subscribe failed
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel(); // 🧹 Cancel periodic timer
    WidgetsBinding.instance.removeObserver(this);
    // 🧹 CLEANUP: Zatvori stream controllere
    WeatherService.dispose();
    RealtimeGpsService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is resumed, try registering pending tokens (if any)
    if (state == AppLifecycleState.resumed) {
      try {
        HuaweiPushService().tryRegisterPendingToken();
      } catch (e) {
        // Error while trying pending token registration on resume
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      // 🚀 OPTIMIZOVANA INICIJALIZACIJA SA CACHE CLEANUP
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // 🎨 Inicijalizuj ThemeManager
      await ThemeManager().initialize();

      // 🧹 PERIODIČKI CLEANUP - svaki put kada se app pokrene
      CacheService.performAutomaticCleanup();

      // 🔥 Kreiranje timer-a za automatski cleanup svakih 10 minuta
      _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
        CacheService.performAutomaticCleanup();
      });

      // Inicijalizacija završena
    } catch (_) {
      // Init error - silent
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
          navigatorObservers: [],
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    // Uvek idi direktno na WelcomeScreen - bez Loading ekrana
    return const WelcomeScreen();
  }
}
