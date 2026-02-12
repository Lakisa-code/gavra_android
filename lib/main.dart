import 'dart:async';
import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📱 Za Edge-to-Edge prikaz (Android 15+)
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'globals.dart';
import 'screens/welcome_screen.dart';
import 'services/adresa_supabase_service.dart';
import 'services/app_settings_service.dart'; // 🔧 Podešavanja aplikacije (nav bar tip)
import 'services/firebase_service.dart';
import 'services/huawei_push_service.dart';
import 'services/kapacitet_service.dart'; // 🎫 Realtime kapacitet
import 'services/ml_service.dart'; // 🧠 ML servis za trening modela
import 'services/ml_vehicle_autonomous_service.dart';
import 'services/realtime/realtime_manager.dart'; // 🎯 Centralizovani realtime manager
import 'services/realtime_gps_service.dart'; // 🛰️ DODATO za cleanup
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
import 'utils/vozac_boja.dart'; // 🎨 VOZAČ BOJE - cache mehanizam

// 🎨 Extension za kompatibilnost sa starijim Flutter verzijama
extension ColorCompat on Color {
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    if (alpha != null) {
      return withOpacity(alpha);
    }
    return this;
  }
}

// 🌍 CUSTOM HTTP CLIENT - za Windows-1252 decoding
class CustomHttpClient implements http.Client {
  final http.Client _client = http.Client();

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    String body = _decodeBody(response.bodyBytes);
    return http.Response(body, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await _client.post(url, headers: headers, body: body, encoding: encoding);
    String decodedBody = _decodeBody(response.bodyBytes);
    return http.Response(decodedBody, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  @override
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await _client.put(url, headers: headers, body: body, encoding: encoding);
    String decodedBody = _decodeBody(response.bodyBytes);
    return http.Response(decodedBody, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  @override
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await _client.patch(url, headers: headers, body: body, encoding: encoding);
    String decodedBody = _decodeBody(response.bodyBytes);
    return http.Response(decodedBody, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  @override
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await _client.delete(url, headers: headers, body: body, encoding: encoding);
    String decodedBody = _decodeBody(response.bodyBytes);
    return http.Response(decodedBody, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.head(url, headers: headers);
    String body = _decodeBody(response.bodyBytes);
    return http.Response(body, response.statusCode, headers: response.headers, request: response.request, isRedirect: response.isRedirect);
  }

  String _decodeBody(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (e) {
      // Try Windows-1252 if UTF-8 fails
      try {
        return windows1252.decode(bytes);
      } catch (e2) {
        // Fallback to UTF-8 with allowMalformed
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async {
    final response = await get(url, headers: headers);
    return response.body;
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.readBytes(url, headers: headers);
    return response;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final streamedResponse = await _client.send(request);
    final bytes = await streamedResponse.stream.toBytes();
    String body = _decodeBody(bytes);
    final newStream = Stream.fromIterable([utf8.encode(body)]);
    return http.StreamedResponse(
      newStream,
      streamedResponse.statusCode,
      contentLength: body.length,
      request: streamedResponse.request,
      headers: streamedResponse.headers,
      isRedirect: streamedResponse.isRedirect,
      persistentConnection: streamedResponse.persistentConnection,
    );
  }

  @override
  void close() => _client.close();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) debugPrint('[Main] App starting...');

  // KONFIGURACIJA - Inicijalizuj osnovne kredencijale (bez Supabase)
  try {
    await configService.initializeBasic();
    if (kDebugMode) {
      debugPrint('[Main] Basic config initialized');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] Basic config init failed: $e');
    // Critical error - cannot continue without credentials
    throw Exception('Ne mogu da inicijalizujem osnovne kredencijale: $e');
  }

  // SUPABASE - Inicijalizuj sa osnovnim kredencijalima
  try {
    await Supabase.initialize(
      url: configService.getSupabaseUrl(),
      anonKey: configService.getSupabaseAnonKey(),
      httpClient: CustomHttpClient(),
    );
    if (kDebugMode) debugPrint('[Main] Supabase initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] Supabase init failed: $e');
    // Možeš dodati fallback ili crash app ako je kritično
  }

  // 🔐 DOVRŠI KONFIGURACIJU - učitaj preostale kredencijale iz Vault-a
  // try {
  //   await configService.initializeVaultCredentials();
  // } catch (e) {
  //   if (kDebugMode) debugPrint('❌ [Main] Vault credentials failed: $e');
  //   // Non-critical - app can continue with basic credentials
  // }

  // 1. Pokreni UI ODMAH (bez čekanja Supabase)
  runApp(const MyApp());

  // 2. Čekaj malo da se UI renderira, pa tek onda inicijalizuj servise
  Future<void>.delayed(const Duration(milliseconds: 500), () {
    unawaited(_doStartupTasks());
  });
}

/// Pozadinske inicijalizacije koje ne smeju da blokiraju UI
Future<void> _doStartupTasks() async {
  if (kDebugMode) debugPrint('[Main] Background tasks started');

  // 🕯️ WAKELOCK & UI
  try {
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}

  // 🌍 LOCALE - UTF-8 podrška za dijakritiku
  unawaited(initializeDateFormatting('sr', null));
  // Intl.defaultLocale = 'sr_RS'; // UKLONJENO - koristi se Flutter locale

  // 🔥 SVE OSTALO POKRENI ISTOVREMENO (Paralelno)
  unawaited(_initPushSystems());
  unawaited(_initAppServices());
}

/// Inicijalizacija Notifikacija (GMS vs HMS)
Future<void> _initPushSystems() async {
  try {
    // Provera GMS-a sa kratkim timeoutom
    final availability =
        await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability().timeout(const Duration(seconds: 2));

    if (availability == GooglePlayServicesAvailability.success) {
      if (kDebugMode) debugPrint('[Main] Detected GMS (Google Play Services)');
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 5));
        await FirebaseService.initialize();
        FirebaseService.setupFCMListeners();
        unawaited(FirebaseService.initializeAndRegisterToken());
        if (kDebugMode) debugPrint('[Main] FCM initialized successfully');
      } catch (e) {
        if (kDebugMode) debugPrint('[Main] FCM initialization failed: $e');
      }
    } else {
      if (kDebugMode) debugPrint('[Main] GMS not available, trying HMS (Huawei Mobile Services)');
      try {
        final hmsToken = await HuaweiPushService().initialize().timeout(const Duration(seconds: 5));
        if (hmsToken != null) {
          await HuaweiPushService().tryRegisterPendingToken();
          if (kDebugMode) debugPrint('[Main] HMS initialized successfully');
        } else {
          if (kDebugMode) debugPrint('[Main] HMS initialization returned null token');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Main] HMS initialization failed: $e');
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] Push services initialization failed: $e');
    // Try HMS as last resort
    try {
      if (kDebugMode) debugPrint('[Main] Last resort: trying HMS');
      await HuaweiPushService().initialize().timeout(const Duration(seconds: 2));
    } catch (e2) {
      if (kDebugMode) debugPrint('[Main] All push services failed: $e2');
    }
  }
}

/// Inicijalizacija ostalih servisa
Future<void> _initAppServices() async {
  // Sada nije potrebna provera - Supabase je već inicijalizovan u main() liniji 69
  if (kDebugMode) debugPrint('[Main] Starting app services...');

  // PRVO - Inicijalizuj vozač mapiranje (MORA biti pre stream-ova!)
  try {
    await VozacMappingService.initialize();
    if (kDebugMode) debugPrint('[Main] VozacMappingService initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('[Main] VozacMappingService init failed: $e');
  }

  // Ostali servisi se mogu pokrenuti paralelno
  final services = [
    VozacBoja.initialize(), // 🎨 Inicijalizuj cache vozača i boja
    AppSettingsService.initialize(),
    KapacitetService.initializeKapacitetCache(), // 🎫 Inicijalizuj cache kapaciteta
  ];

  for (var service in services) {
    unawaited(service);
  }

  // Sync inicijalizacija
  VremeVozacService().loadAllVremeVozac();

  // 🚗 Initialize VozacService stream JEDNOM - pokrenuti stream sa listen() da počne emisija
  VozacService().streamAllVozaci().listen((_) {
    // Samo slušamo, ne radimo ništa - samo da stream počne da emituje podatke
  });

  // 🔔 Initialize centralized realtime manager (monitoring sve tabele)
  unawaited(RealtimeManager.instance.initializeAll());

  // 🚐 Realtime & AI (bez čekanja ikoga)
  // NOTE: RouteService.setupRealtimeListener() je sada dio RealtimeManager.initializeAll()
  // NOTE: KapacitetService.startGlobalRealtimeListener() je sada dio RealtimeManager.initializeAll()
  unawaited(WeatherAlertService.checkAndSendWeatherAlerts());

  // 🧠 Treniraj ML model za ocenjivanje putnika
  unawaited(MLService.trainPassengerScoringModel());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();

    // 🔐 DOZVOLE - Sada se pozivaju iz WelcomeScreen da izbegnu MaterialLocalizations grešku
  }

  @override
  void dispose() {
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
      // 🚀 OPTIMIZOVANA INICIJALIZACIJA
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // 🎨 Inicijalizuj ThemeManager
      await ThemeManager().initialize();

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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('sr'),
            Locale('sr', 'RS'),
            Locale('sr', 'BA'),
            Locale('sr', 'ME'),
          ],
          locale: const Locale('sr'), // Default locale sa dijakritikom
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
