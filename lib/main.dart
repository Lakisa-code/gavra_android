import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📱 Za Edge-to-Edge prikaz (Android 15+)
import 'package:google_api_availability/google_api_availability.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'globals.dart';
import 'screens/welcome_screen.dart';
import 'services/app_settings_service.dart'; // 🔧 Podešavanja aplikacije (nav bar tip)
import 'services/battery_optimization_service.dart'; // 🔋 Huawei/Xiaomi battery warning
import 'services/cache_service.dart';
import 'services/firebase_service.dart';
import 'services/huawei_push_service.dart';
import 'services/kapacitet_service.dart'; // 🎫 Realtime kapacitet
import 'services/ml_champion_service.dart';
import 'services/ml_dispatch_autonomous_service.dart';
import 'services/ml_finance_autonomous_service.dart';
import 'services/ml_vehicle_autonomous_service.dart';
import 'services/payment_reminder_service.dart';
import 'services/putnik_service.dart'; // 🔄 DODATO za nedeljni reset
import 'services/realtime_gps_service.dart'; // 🛰️ DODATO za cleanup
import 'services/realtime_notification_service.dart';
import 'services/scheduled_popis_service.dart'; // 📊 Automatski popis u 21:00 (bez notif)
import 'services/theme_manager.dart'; // 🎨 Novi tema sistem
import 'services/vozac_mapping_service.dart'; // 🗂️ DODATO za inicijalizaciju mapiranja
import 'services/vreme_vozac_service.dart'; // 🚐 Per-vreme dodeljivanje vozača
import 'services/weather_alert_service.dart'; // 🌨️ Upozorenja za loše vreme
import 'services/weather_service.dart'; // 🌤️ DODATO za cleanup
import 'supabase_client.dart';
import 'utils/vozac_boja.dart'; // 🎨 Vozač boje i cache

void main() async {
  // 🚀 TRENUTNO POKRETANJE
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) debugPrint('🚀 [Main] App starting...');

  // 1. Pokreni UI odmah
  runApp(const MyApp());

  // 2. Pokreni sve inicijalizacije potpuno asinhrono
  unawaited(_doStartupTasks());
}

/// 🏗️ Pozadinske inicijalizacije koje ne smeju da blokiraju UI
Future<void> _doStartupTasks() async {
  if (kDebugMode) debugPrint('⚙️ [Main] Background tasks started');

  // 🕯️ WAKELOCK & UI
  try {
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  // 🌍 LOCALE
  unawaited(initializeDateFormatting('sr_RS', null));

  // 🌐 SUPABASE - Robustna inicijalizacija sa retry mehanizmom
  bool initialized = false;
  int attempts = 0;
  while (!initialized && attempts < 3) {
    try {
      attempts++;
      // Proveri da li je već inicijalizovan (npr. iz background isolata ili hot restarta)
      if (isSupabaseReady) {
        initialized = true;
        if (kDebugMode) debugPrint('✅ [Main] Supabase already initialized');
        break;
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 10)); // Povećan timeout na 10s

      initialized = true;
      if (kDebugMode) debugPrint('✅ [Main] Supabase initialized (Attempt $attempts)');
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [Main] Supabase init attempt $attempts failed: $e');
      if (attempts < 3) {
        await Future.delayed(Duration(seconds: attempts)); // Exponential backoff ekvivalent
      }
    }
  }

  // 🔥 SVE OSTALO POKRENI ISTOVREMENO (Paralelno)
  unawaited(_initPushSystems());
  unawaited(_initAppServices());
}

/// 📱 Inicijalizacija Notifikacija (GMS vs HMS)
Future<void> _initPushSystems() async {
  try {
    // Provera GMS-a sa kratkim timeoutom
    final availability =
        await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability().timeout(const Duration(seconds: 2));

    if (availability == GooglePlayServicesAvailability.success) {
      if (kDebugMode) debugPrint('📲 [Main] Detected GMS (Google)');
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      await FirebaseService.initialize();
      FirebaseService.setupFCMListeners();
      unawaited(FirebaseService.initializeAndRegisterToken());
    } else {
      if (kDebugMode) debugPrint('📲 [Main] Detected HMS (Huawei)');
      await HuaweiPushService().initialize().timeout(const Duration(seconds: 5));
      await HuaweiPushService().tryRegisterPendingToken();
    }
  } catch (e) {
    // Fallback na HMS ako bilo šta pukne
    try {
      await HuaweiPushService().initialize().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}

/// ⚙️ Inicijalizacija ostalih servisa
Future<void> _initAppServices() async {
  if (!isSupabaseReady) return;

  final services = [
    VozacMappingService.initialize(),
    VozacBoja.initialize(),
    VremeVozacService().loadAllVremeVozac(),
    AppSettingsService.initialize(),
    CacheService.initialize(),
  ];

  for (var service in services) {
    unawaited(service.timeout(const Duration(seconds: 3), onTimeout: () => {}));
  }

  // Realtime & AI (bez čekanja ikoga)
  KapacitetService.startGlobalRealtimeListener();
  unawaited(PutnikService().checkAndPerformWeeklyReset());
  unawaited(PaymentReminderService.checkAndSendReminders());
  unawaited(WeatherAlertService.checkAndSendWeatherAlerts());

  unawaited(MLVehicleAutonomousService().start());
  unawaited(MLDispatchAutonomousService().start());
  unawaited(MLChampionService().start());
  unawaited(MLFinanceAutonomousService().start());
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

    // 🔋 Check for battery optimization warning (Huawei/Xiaomi/etc)
    _checkBatteryOptimization();
  }

  /// 🔋 Show battery optimization warning for Huawei/Xiaomi phones
  Future<void> _checkBatteryOptimization() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 3)); // Wait for app to fully load
      if (!mounted) return;

      final shouldShow = await BatteryOptimizationService.shouldShowWarning();
      if (shouldShow && mounted) {
        await BatteryOptimizationService.showWarningDialog(context);
      }
    } catch (_) {
      // Battery optimization check failed - silent
    }
  }

  Future<void> _forceSubscribeToTopics() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 2)); // Wait for Firebase init
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

      // 📊 Automatski popis u 21:00 (samo čuva u bazu, BEZ notifikacija)
      await ScheduledPopisService.initialize();

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
          navigatorObservers: const [],
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
