// import 'services/permission_service.dart'; // Moved to WelcomeScreen
import 'dart:async';

import 'package:app_links/app_links.dart';
// Firebase imports - enabled for multi-channel notifications
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'screens/email_login_screen.dart';
// 🤖 GitHub Actions Android workflow for unlimited free APK delivery
import 'screens/loading_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/connection_resilience_service.dart';
import 'services/firebase_service.dart';
import 'services/gps_service.dart';
import 'services/local_notification_service.dart';
import 'services/realtime_notification_counter_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/realtime_priority_service.dart';
import 'services/realtime_service.dart';
import 'services/sms_service.dart';
import 'services/theme_service.dart';
import 'services/timer_manager.dart';
import 'services/vozilo_service.dart';
import 'supabase_client.dart';
import 'utils/xiaomi_optimizer.dart'; // 🚀 XIAOMI OPTIMIZACIJE

// Dummy navigatorKey for services compatibility
class NavigatorKeyCompat {
  BuildContext? get currentContext => null;
}

final navigatorKey = NavigatorKeyCompat();

// Globalna funkcija za menjanje teme
void Function()? globalThemeToggler;
// Globalna funkcija za osvežavanje teme kada se vozač promeni
void Function()? globalThemeRefresher;

/// � GLOBALNI BACKGROUND MESSAGE HANDLER
/// Firebase background handler for multi-channel notifications
/// Ovo mora biti top-level funkcija da bi radila kad je app zatvoren
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize only if not already initialized in this isolate
    final alreadyInitialized = Firebase.apps.isNotEmpty;
    if (!alreadyInitialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Ignore duplicate-init or platform-specific errors in background isolate
  }
  // Pozovi background-safe helper da prika6e lokalnu notifikaciju iz background isolate
  try {
    await LocalNotificationService.showNotificationFromBackground(
      title: message.notification?.title ?? 'Gavra Notification',
      body: message.notification?.body ?? 'Nova poruka',
      payload: (message.data['type'] as String?) ?? 'firebase_background',
    );
  } catch (e) {
    // Logger removed
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // � XIAOMI OPTIMIZACIJE
  XiaomiOptimizer.optimizeForXiaomi();
  XiaomiOptimizer.configureMIUI();

  // 🚀 CACHE UKLONJEN - koristi direktne Supabase pozive

  // OneSignal initialization (legacy API)
  try {
    OneSignal.initialize(AppConfig.oneSignalAppId);
    OneSignal.User.pushSubscription.addObserver((state) {
      try {
        // OneSignal player ID logged
      } catch (_) {}
    });
  } catch (e) {
    // Logger removed
  }

  // Firebase initialization
  try {
    const timeout = Duration(seconds: 20);

    // Check if Firebase is already initialized
    final alreadyInitialized = Firebase.apps.isNotEmpty;
    if (!alreadyInitialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(timeout);
    }

    // Registruj background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      await RealtimeNotificationService.handleInitialMessage(initialMessage);
    } catch (e) {
      // Logger removed
    }

    // Initialize notification counter service and FCM listeners
    try {
      RealtimeNotificationCounterService.initialize();
    } catch (e) {
      // Logger removed
    }

    try {
      FirebaseService.setupFCMListeners();
    } catch (e) {
      // Logger removed
    }
  } catch (e) {
    // Logger removed
    // Nastavi bez Firebase ako ne može - aplikacija neće da krahira
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));

    // 🌐 INICIJALIZUJ CONNECTION RESILIENCE SERVICE
    await ConnectionResilienceService.initialize();
    // Logger removed
  } catch (e) {
    // Logger removed
    // Continue without Supabase if it fails
  }

  // Initialize GraphQL client
  final HttpLink httpLink = HttpLink(
    'https://gjtabtwudbrmfeyjiicu.supabase.co/graphql/v1',
    defaultHeaders: {'apiKey': supabaseAnonKey},
  );
  final Link link = httpLink;
  ValueNotifier<GraphQLClient> client = ValueNotifier(GraphQLClient(link: link, cache: GraphQLCache()));

  runApp(GraphQLProvider(client: client, child: const MyApp()));
}

// Simple helper instead of FirebaseService.getCurrentDriver()
Future<String?> getCurrentDriver() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('current_driver');
}

// Helper function to get default vehicle ID for GPS tracking
Future<String?> getDefaultVehicleId() async {
  try {
    final voziloService = VoziloService();
    final vozila = await voziloService.getAllVozila();

    // Return the first active vehicle, or create a default one
    if (vozila.isNotEmpty) {
      return vozila.first.id;
    }

    // If no vehicles exist, return a default UUID
    // In a real app, you'd want to create a vehicle here
    return 'a0000000-0000-4000-8000-000000000000';
  } catch (e) {
    // Logger removed
    return 'a0000000-0000-4000-8000-000000000000';
  }
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
    _initializeDeepLinks(); // Dodano za email confirmation

    // Postavi globalnu funkciju za theme toggle
    globalThemeToggler = toggleTheme;
    // Postavi globalnu funkciju za theme refresh
    globalThemeRefresher = refreshThemeForDriver;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Store context to check if widget is still mounted
      if (!mounted) return;

      // INICIJALIZUJ NOTIFIKACIJE SEKVENCIJALNO da izbegneš konflikte
      try {
        // 1. Prvo inicijalizuj lokalne notifikacije (bez permission zahteva)
        await LocalNotificationService.initialize(context);

        // 2. Zatim zatraži permissions jednom kroz Firebase sistem (kratki timeout)
        try {
          await RealtimeNotificationService.requestNotificationPermissions().timeout(const Duration(seconds: 3));
        } catch (e) {
          // Permissions timeout - nastavi bez njih
        }

        // 3. Inicijalizuj realtime notifikacije
        await RealtimeNotificationService.initialize();

        if (mounted) {
          RealtimeNotificationService.listenForForegroundNotifications(context);
        }

        // 🚀 4. INICIJALIZUJ REALTIME PRIORITY SERVICE - NAJBITNIJI!
        // Ovaj servis GARANTUJE da putnik add/cancel stignu ODMAH!
        try {
          await RealtimePriorityService.initialize().timeout(const Duration(seconds: 3));
        } catch (e) {
          // Priority service timeout - nastavi bez njega
        }

        // 5. Pretplati se na topike na osnovu vozača
        final vozacId = await getCurrentDriver();

        // Pokreni centralizovane realtime pretplate
        try {
          RealtimeService.instance.startForDriver(vozacId);

          // Forsiraj početno učitavanje podataka (sa timeout)
          await RealtimeService.instance.refreshNow().timeout(const Duration(seconds: 5));
        } catch (e) {
          // Logger removed
          // Pokušaj da pokreneš bez vozača kao fallback
          try {
            RealtimeService.instance.startForDriver(null);
            await RealtimeService.instance.refreshNow().timeout(const Duration(seconds: 3));
          } catch (fallbackError) {
            // Logger removed
          }
        }

        if (vozacId != null && vozacId.isNotEmpty) {
          await RealtimeNotificationService.subscribeToDriverTopics(vozacId);
        } else {
          // Logger removed
          await RealtimeNotificationService.subscribeToDriverTopics(null);
        }
      } catch (e) {
        // Logger removed
        // Continue without notifications if they fail
      }

      // 📱 6. POKRENI AUTOMATSKI SMS SERVIS
      try {
        SMSService.startAutomaticSMSService();
        // Logger removed
      } catch (e) {
        // Logger removed
        // Continue without SMS service if it fails
      }
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
          final voziloId = await getDefaultVehicleId();
          if (currentVozacId != null && currentVozacId.isNotEmpty && voziloId != null) {
            GpsService.sendCurrentLocation(
              vozacId: currentVozacId,
              voziloId: voziloId,
            );
          }
        },
        isPeriodic: true,
      );

      // Pošalji odmah na startu
      final voziloId = await getDefaultVehicleId();
      if (voziloId != null) {
        GpsService.sendCurrentLocation(
          vozacId: vozacId,
          voziloId: voziloId,
        );
      }
    })();
  }

  @override
  void dispose() {
    // 🧹 CLEANUP SVIH TIMER-A - SPREČAVA MEMORY LEAK
    TimerManager.cancelAllTimers();

    // Stop centralized realtime subscriptions
    try {
      RealtimeService.instance.stopForDriver();
    } catch (e) {
      // Logger removed
    }

    super.dispose();
  }

  // Dodano za deep link handling
  void _initializeDeepLinks() {
    final appLinks = AppLinks();

    // Listen for incoming deep links when app is already running
    appLinks.uriLinkStream.listen(
      (uri) {
        // Logger removed
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        // Logger removed
      },
    );

    // Check for deep link when app is launched
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final initialUri = await appLinks.getInitialAppLink();
        if (initialUri != null) {
          // Logger removed
          _handleDeepLink(initialUri);
        }
      } catch (e) {
        // Logger removed
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    // Logger removed

    // Check if it's a Supabase auth callback
    if (uri.host == 'gjtabtwudbrmfeyjiicu.supabase.co' && uri.path.contains('/auth/v1/callback')) {
      // Handle Supabase auth callback
      Supabase.instance.client.auth.getSessionFromUrl(uri).then((response) {
        // Logger removed
        // Show success message and navigate
        // Logger removed
      }).catchError((Object error) {
        // Logger removed
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Kratka pauza da se UI prikaže
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 🚀 CACHE JE UKLONJEN - koristi direktne Supabase pozive

      // 🔐 INICIJALNI SETUP DOZVOLA se pomerio u didChangeDependencies()
      // da se izvrši kada je MaterialApp potpuno spreman

      // 🔄 RESETUJ KARTICE MESEČNIH PUTNIKA SVAKI PETAK
      try {
        // PutnikStatistike servis je uklonjen - placeholder
        // final putnikStatistike = PutnikStatistike();
        // await putnikStatistike.proveriIResetujKartice();
      } catch (e) {
        // Logger removed
        // Ne prekidaj inicijalizaciju aplikacije zbog greške u resetovanju
      }

      // Schema test removed to prevent startup crashes
      // await _testSchemaStructure();

      if (mounted) {
        if (mounted) setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Logger removed
      if (mounted) {
        if (mounted) setState(() {
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _initializeTheme() async {
    final nocniRezim = await ThemeService.isNocniRezim();
    if (mounted) {
      if (mounted) setState(() {
        _nocniRezim = nocniRezim;
      });
    }
  }

  Future<void> _initializeCurrentDriver() async {
    final driver = await getCurrentDriver();
    if (mounted) {
      if (mounted) setState(() {
        _currentDriver = driver;
      });
      // 💖 Tema se koristi
      if (driver?.toLowerCase() == 'svetlana') {
        // Pink theme activated
      } else {
        // Default blue theme activated
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
      if (mounted) setState(() {
        _nocniRezim = newTheme;
      });
    }
  }

  // 🎨 Javni getter za pristup theme toggle funkcionalnosti iz drugih delova app-a
  void Function() get themeToggler => toggleTheme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gavra 013',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.svetlaTema(
        driverName: _currentDriver,
      ), // 🎨 Svetla tema sa vozačem
      darkTheme: ThemeService.tamnaTema(), // 🎨 Tamna tema za noć
      themeMode: _nocniRezim ? ThemeMode.dark : ThemeMode.light, // 🎨 Dinamičko prebacivanje teme
      routes: {
        '/email-login': (context) => const EmailLoginScreen(),
      },
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

