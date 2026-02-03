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
import 'services/adresa_supabase_service.dart';
import 'services/app_settings_service.dart'; // 🔧 Podešavanja aplikacije (nav bar tip)
import 'services/battery_optimization_service.dart'; // 🔋 Huawei/Xiaomi battery warning
import 'services/cache_service.dart';
import 'services/daily_checkin_service.dart'; // 📋 Daily check-in kusur tracking
import 'services/firebase_service.dart';
import 'services/huawei_push_service.dart';
import 'services/kapacitet_service.dart'; // 🎫 Realtime kapacitet
import 'services/ml_champion_service.dart';
import 'services/ml_dispatch_autonomous_service.dart';
import 'services/ml_finance_autonomous_service.dart';
import 'services/ml_service.dart'; // 🧠 ML servis za trening modela
import 'services/ml_vehicle_autonomous_service.dart';
import 'services/realtime/realtime_manager.dart'; // 🎯 Centralizovani realtime manager
import 'services/realtime_gps_service.dart'; // 🛰️ DODATO za cleanup
import 'services/realtime_notification_service.dart';
import 'services/registrovani_putnik_service.dart'; // 👥 Registrovani putnici
import 'services/route_service.dart'; // 🚐 Dinamički satni redoslijedi iz baze
import 'services/scheduled_popis_service.dart'; // 📊 Automatski popis u 21:00 (bez notif)
import 'services/seat_request_service.dart';
import 'services/slobodna_mesta_service.dart';
import 'services/theme_manager.dart'; // 🎨 Novi tema sistem
import 'services/vozac_mapping_service.dart'; // 🗂️ DODATO za inicijalizaciju mapiranja
import 'services/vozac_service.dart';
import 'services/vozila_service.dart';
import 'services/voznje_log_service.dart';
import 'services/vreme_vozac_service.dart'; // 🚐 Per-vreme dodeljivanje vozača
import 'services/weather_alert_service.dart'; // 🌤️ Vremenske uzbune
import 'services/weather_service.dart'; // 🌤️ DODATO za cleanup
import 'utils/vozac_boja.dart'; // 🎨 Vozač boje i cache

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) debugPrint('🚀 [Main] App starting...');

  // 🔐 KONFIGURACIJA - Inicijalizuj osnovne kredencijale (bez Supabase)
  try {
    await configService.initializeBasic();
    if (kDebugMode) {
      debugPrint('✅ [Main] Basic config initialized');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('❌ [Main] Basic config init failed: $e');
    // Critical error - cannot continue without credentials
    throw Exception('Ne mogu da inicijalizujem osnovne kredencijale: $e');
  }

  // 🌐 SUPABASE - Inicijalizuj sa osnovnim kredencijalima
  try {
    await Supabase.initialize(
      url: configService.getSupabaseUrl(),
      anonKey: configService.getSupabaseAnonKey(),
    );
    if (kDebugMode) debugPrint('✅ [Main] Supabase initialized');

    // 🧹 TEMP: Clear realtime cache za test putnika
    RegistrovaniPutnikService.clearRealtimeCache();
  } catch (e) {
    if (kDebugMode) debugPrint('❌ [Main] Supabase init failed: $e');
    // Možeš dodati fallback ili crash app ako je kritično
  }

  // 🔐 DOVRŠI KONFIGURACIJU - učitaj preostale kredencijale iz Vault-a
  // try {
  //   await configService.initializeVaultCredentials();
  // } catch (e) {
  //   if (kDebugMode) debugPrint('❌ [Main] Vault credentials failed: $e');
  //   // Non-critical - app can continue with basic credentials
  // }

  // 1. Pokreni UI
  runApp(const MyApp());

  // 2. Pokreni ostale inicijalizacije
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
      if (kDebugMode) debugPrint('📲 [Main] Detected GMS (Google Play Services)');
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 5));
        await FirebaseService.initialize();
        FirebaseService.setupFCMListeners();
        unawaited(FirebaseService.initializeAndRegisterToken());
        if (kDebugMode) debugPrint('✅ [Main] FCM initialized successfully');
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Main] FCM initialization failed: $e');
      }
    } else {
      if (kDebugMode) debugPrint('📲 [Main] GMS not available, trying HMS (Huawei Mobile Services)');
      try {
        final hmsToken = await HuaweiPushService().initialize().timeout(const Duration(seconds: 5));
        if (hmsToken != null) {
          await HuaweiPushService().tryRegisterPendingToken();
          if (kDebugMode) debugPrint('✅ [Main] HMS initialized successfully');
        } else {
          if (kDebugMode) debugPrint('⚠️ [Main] HMS initialization returned null token');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('❌ [Main] HMS initialization failed: $e');
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ [Main] Push services initialization failed: $e');
    // Try HMS as last resort
    try {
      if (kDebugMode) debugPrint('📲 [Main] Last resort: trying HMS');
      await HuaweiPushService().initialize().timeout(const Duration(seconds: 2));
    } catch (e2) {
      if (kDebugMode) debugPrint('❌ [Main] All push services failed: $e2');
    }
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
    RouteService.refreshCache(), // 🚐 Učitaj satne redoslijede iz baze
  ];

  for (var service in services) {
    unawaited(service.timeout(const Duration(seconds: 3), onTimeout: () => {}));
  }

  // 🔔 Initialize centralized realtime manager (monitoring sve tabele)
  unawaited(RealtimeManager.instance.initializeAll());

  // 🚐 Realtime & AI (bez čekanja ikoga)
  // NOTE: RouteService.setupRealtimeListener() je sada dio RealtimeManager.initializeAll()
  // NOTE: KapacitetService.startGlobalRealtimeListener() je sada dio RealtimeManager.initializeAll()
  unawaited(WeatherAlertService.checkAndSendWeatherAlerts());

  unawaited(MLVehicleAutonomousService().start());
  unawaited(MLDispatchAutonomousService().start());
  unawaited(MLChampionService().start());
  unawaited(MLFinanceAutonomousService().start());

  // 🧠 Treniraj ML model za ocenjivanje putnika
  unawaited(MLService.trainPassengerScoringModel());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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

    // Premesti ove pozive u didChangeDependencies ili koristi addPostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Setup realtime notification listeners (FCM) for foreground handling
        try {
          RealtimeNotificationService.listenForForegroundNotifications(context);
        } catch (_) {}

        // 🔔 FORCE SUBSCRIBE to FCM topics on app start (for testing)
        _forceSubscribeToTopics();

        // 🔋 Check for battery optimization warning (Huawei/Xiaomi/etc)
        _checkBatteryOptimization();
      }
    });
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
    AdresaSupabaseService.dispose();
    VozacService.dispose();
    VozilaService.dispose();
    SeatRequestService.dispose();
    VoznjeLogService.dispose();
    MLVehicleAutonomousService.disposeRealtime();
    SlobodnaMestaService.dispose();
    DailyCheckInService.dispose();
    AppSettingsService.dispose();
    KapacitetService.stopGlobalRealtimeListener();
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
