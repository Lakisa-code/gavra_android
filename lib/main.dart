import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Firebase imports - enabled for multi-channel notifications
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';
import 'supabase_client.dart';
import 'screens/welcome_screen.dart';

// 🤖 GitHub Actions Android workflow for unlimited free APK delivery
import 'screens/loading_screen.dart';
import 'services/realtime_notification_service.dart';
import 'services/local_notification_service.dart';
import 'services/theme_service.dart';
import 'services/gps_service.dart';
import 'services/timer_manager.dart';
import 'services/sms_service.dart';
// import 'services/permission_service.dart'; // Moved to WelcomeScreen
import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';

final _logger = Logger();

// Globalni navigator key za pristup navigation iz bilo kog dela aplikacije
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Globalna funkcija za menjanje teme
void Function()? globalThemeToggler;
// Globalna funkcija za osvežavanje teme kada se vozač promeni
void Function()? globalThemeRefresher;

/// 📬 GLOBALNI BACKGROUND MESSAGE HANDLER
/// Firebase background handler for multi-channel notifications
/// Ovo mora biti top-level funkcija da bi radila kad je app zatvoren
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _logger.i('📬 Background message received: ${message.notification?.title}');
  // Pozovi LocalNotificationService da obradi poruku
  await LocalNotificationService.showRealtimeNotification(
    title: message.notification?.title ?? 'Gavra Notification',
    body: message.notification?.body ?? 'Nova poruka',
    payload: message.data['type'] ?? 'firebase_background',
    playCustomSound: true,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logger.i('🔄 Starting app...');

  // 🚀 CACHE UKLONJEN - koristi direktne Supabase pozive
  _logger.i('🔄 Cache removed - using direct Supabase calls');

  // OneSignal initialization
  OneSignal.initialize('4fd57af1-568a-45e0-a737-3b3918c4e92a');
  OneSignal.User.pushSubscription.addObserver((state) {
    _logger.i('🔔 OneSignal player ID: ${state.current.id}');
  });

  // Firebase initialization - ENABLED for multi-channel notifications
  try {
    _logger.i('🔄 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Registruj background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _logger.i('✅ Firebase initialized with background handler');
  } catch (e) {
    _logger.e('❌ Firebase initialization failed: $e');
  }

  try {
    _logger.i('🔄 Initializing Supabase...');
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _logger.i('✅ Supabase initialized');
  } catch (e) {
    _logger.e('❌ Supabase initialization failed: $e');
  }

  _logger.i('� Starting app with professional CI/CD automation...');
  runApp(const MyApp());
}

// Simple helper instead of FirebaseService.getCurrentDriver()
Future<String?> getCurrentDriver() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('current_driver');
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitialized = false;
  String? _initError;
  bool _nocniRezim = false;
  String? _currentDriver; // Dodano za temu
  // bool _permissionsRequested = false; // Removed - permissions now handled in WelcomeScreen

  @override
  void initState() {
    super.initState();
    _initializeTheme();
    _initializeCurrentDriver(); // Dodano

    // Postavi globalnu funkciju za theme toggle
    globalThemeToggler = toggleTheme;
    // Postavi globalnu funkciju za theme refresh
    globalThemeRefresher = refreshThemeForDriver;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Store context to check if widget is still mounted
      if (!mounted) return;

      // Inicijalizuj lokalne notifikacije
      await LocalNotificationService.initialize(context);

      // UVEK inicijalizuj realtime notifikacije, bez obzira na to da li je app bio zatvoren
      // Dohvati vozača iz SharedPreferences
      final vozacId = await getCurrentDriver();
      _logger.i('🔄 Pronađen vozač iz SharedPreferences: $vozacId');

      if (vozacId != null && vozacId.isNotEmpty) {
        _logger.i('✅ Inicijalizujem notifikacije za vozača: $vozacId');
        // Initialize multi-channel notification system
        try {
          // First request notification permissions
          _logger.i('🔔 Requesting notification permissions...');
          final hasPermissions = await RealtimeNotificationService
              .requestNotificationPermissions();
          _logger.i('🔔 Notification permissions result: $hasPermissions');

          await RealtimeNotificationService.initialize();
          if (mounted) {
            RealtimeNotificationService.listenForForegroundNotifications(
                context);
          }
          // Subscribe to Firebase topics for this driver
          await RealtimeNotificationService.subscribeToDriverTopics(vozacId);
        } catch (e) {
          _logger.w('⚠️ Notification system error: $e');
        }
      } else {
        _logger.w('⚠️ Nema logovanog vozača - notifikacije neće raditi');
        // Ipak zatraži dozvole i pretplati se na osnovne topike za sve vozače
        try {
          _logger.i('🔔 Requesting notification permissions...');
          final hasPermissions = await RealtimeNotificationService
              .requestNotificationPermissions();
          _logger.i('🔔 Notification permissions result: $hasPermissions');

          await RealtimeNotificationService.subscribeToDriverTopics(null);
        } catch (e) {
          _logger.w('⚠️ Notification permissions error: $e');
        }
      }

      // 📱 POKRETANJE SMS SERVISA za automatsko slanje poruka
      _logger.i('📱 Pokretanje SMS servisa...');
      SMSService.startAutomaticSMSService();
      _logger.i(
          '✅ SMS servis pokrenut - šalje poruke predzadnjeg dana u mesecu u 20:00');
    });

    _startPeriodicGpsSending();
    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔐 POZOVI PERMISSION SETUP kada je MaterialApp spreman
    _requestPermissionsWhenReady();
  }

  Future<void> _requestPermissionsWhenReady() async {
    _logger.i('🔄 Permissions will be requested when first screen is ready...');
    // ⚠️ Permissions se sada pozivaju iz WelcomeScreen ili HomeScreen umesto odavde
    // jer ovaj context nije unutar MaterialApp strukture i izaziva MaterialLocalizations grešku
  }

  void _startPeriodicGpsSending() {
    // 🕐 KORISTI TIMER MANAGER za GPS slanje - SPREČAVA MEMORY LEAK
    (() async {
      final vozacId = await getCurrentDriver();
      if (vozacId == null || vozacId.isEmpty) return;

      // Otkaži postojeći GPS timer ako postoji
      TimerManager.cancelTimer('gps_periodic_sender');

      // Kreiraj novi timer sa Timer Manager-om
      TimerManager.createTimer(
        'gps_periodic_sender',
        const Duration(minutes: 1),
        () async {
          final currentVozacId = await getCurrentDriver();
          if (currentVozacId != null && currentVozacId.isNotEmpty) {
            GpsService.sendCurrentLocation(vozacId: currentVozacId);
          }
        },
        isPeriodic: true,
      );

      // Pošalji odmah na startu
      GpsService.sendCurrentLocation(vozacId: vozacId);
    })();
  }

  Future<void> _testSchemaStructure() async {
    try {
      _logger.i('🔍 Testiram strukturu tabela...');

      // Test putovanja_istorija tabele - test postojećih kolona
      try {
        final result = await Supabase.instance.client
            .from('putovanja_istorija')
            .select(
                'vozac, obrisan, status') // ✅ Testiraj samo postojeće kolone
            .limit(1);
        _logger.i('✅ putovanja_istorija tabela dostupna: $result');
      } catch (e) {
        _logger.w('❌ putovanja_istorija greška: $e');
      }

      // Test mesecni_putnici tabele - mesečni putnici NEMAJU vozac kolone
      try {
        final result = await Supabase.instance.client
            .from('mesecni_putnici')
            .select(
                'id, putnik_ime, aktivan') // ✅ ISPRAVKA: proverava osnovne kolone umesto nepostojećih vozac kolona
            .limit(1);
        _logger.i('✅ mesecni_putnici tabela dostupna: $result');
      } catch (e) {
        _logger.w('⚠️ mesecni_putnici tabela ima probleme: $e');
      }
    } catch (e) {
      _logger.e('❌ Greška pri testiranju schema: $e');
    }
  }

  @override
  void dispose() {
    // 🧹 CLEANUP SVIH TIMER-A - SPREČAVA MEMORY LEAK
    TimerManager.cancelAllTimers();

    // 📱 ZAUSTAVITI SMS SERVIS
    SMSService.stopAutomaticSMSService();
    _logger.i('🛑 SMS servis zaustavljen');

    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      _logger.i('🔄 Initializing app...');

      // Kratka pauza da se UI prikaže
      await Future.delayed(const Duration(milliseconds: 500));

      // 🚀 CACHE JE UKLONJEN - koristi direktne Supabase pozive
      _logger.i('🔄 Cache removed - using direct Supabase calls');

      // 🔐 INICIJALNI SETUP DOZVOLA se pomerio u didChangeDependencies()
      // da se izvrši kada je MaterialApp potpuno spreman
      _logger.i(
          '🔄 Permissions setup will be handled when MaterialApp is ready...');

      // 🔄 RESETUJ KARTICE MESEČNIH PUTNIKA SVAKI PETAK
      try {
        _logger.i('🔄 Checking weekly card reset...');
        // PutnikStatistike servis je uklonjen - placeholder
        // final putnikStatistike = PutnikStatistike();
        // await putnikStatistike.proveriIResetujKartice();
        _logger.i('✅ Weekly card reset check completed (placeholder)');
      } catch (e) {
        _logger.w('⚠️ Weekly card reset failed: $e');
        // Ne prekidaj inicijalizaciju aplikacije zbog greške u resetovanju
      }

      _logger.i('✅ App initialized successfully');

      // Test schema strukture - jednokratno testiranje
      await _testSchemaStructure();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _logger.e('❌ App initialization failed: $e');
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _initializeTheme() async {
    final nocniRezim = await ThemeService.isNocniRezim();
    if (mounted) {
      setState(() {
        _nocniRezim = nocniRezim;
      });
    }
  }

  Future<void> _initializeCurrentDriver() async {
    final driver = await getCurrentDriver();
    if (mounted) {
      setState(() {
        _currentDriver = driver;
      });
      // 💖 Log koja tema se koristi za debug
      if (driver?.toLowerCase() == 'svetlana') {
        _logger.d('💖 SVETLANA PINK THEME aktivirana!');
      } else {
        _logger
            .d('🎨 Default blue theme aktivirana za: ${driver ?? "unknown"}');
      }
    }
  }

  // 🎨 Javna funkcija za osvežavanje teme kada se vozač promeni
  void refreshThemeForDriver() async {
    await _initializeCurrentDriver();
  }

  void toggleTheme() async {
    final newTheme = await ThemeService.toggleNocniRezim();
    if (mounted) {
      setState(() {
        _nocniRezim = newTheme;
      });
      _logger.d('🎨 Theme toggled to: ${newTheme ? "dark" : "light"}');
    }
  }

  // 🎨 Javni getter za pristup theme toggle funkcionalnosti iz drugih delova app-a
  void Function() get themeToggler => toggleTheme;

  @override
  Widget build(BuildContext context) {
    _logger.d(
        '🎨 Building MyApp... initialized: $_isInitialized, error: $_initError, nocniRezim: $_nocniRezim');

    return MaterialApp(
      title: 'Rezervacije',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Dodaj globalni navigator key
      theme: ThemeService.svetlaTema(
          driverName: _currentDriver), // 🎨 Svetla tema sa vozačem
      darkTheme: ThemeService.tamnaTema(), // 🎨 Tamna tema za noć
      themeMode: _nocniRezim
          ? ThemeMode.dark
          : ThemeMode.light, // 🎨 Dinamičko prebacivanje teme
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return LoadingScreen(error: _initError);
    }

    if (!_isInitialized) {
      return const LoadingScreen();
    }

    // Za testiranje GPS ekrana, zameni WelcomeScreen sa GpsDemoScreen
    // Kada završiš test, vrati WelcomeScreen
    return const WelcomeScreen(); // <- zameni sa GpsDemoScreen() za demo
    // return GpsDemoScreen();
  }
}
