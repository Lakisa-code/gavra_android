import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mesecni_putnik.dart';
import '../models/putnik.dart';
import '../services/auth_manager.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import '../services/local_notification_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/printing_service.dart';
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/theme_manager.dart'; // 🎨 Tema sistem
import '../services/timer_manager.dart'; // 🕐 TIMER MANAGEMENT
import '../theme.dart'; // 🎨 Import za prelepe gradijente
import '../utils/animation_utils.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju
import '../utils/page_transitions.dart';
import '../utils/schedule_utils.dart';
import '../utils/text_utils.dart';
import '../utils/vozac_boja.dart'; // Dodato za centralizovane boje vozača
import '../widgets/autocomplete_adresa_field.dart';
import '../widgets/autocomplete_ime_field.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/putnik_card.dart';
import '../widgets/shimmer_widgets.dart';
import 'admin_screen.dart';
import 'danas_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Logging using dlog function from logging.dart
  final PutnikService _putnikService = PutnikService(); // ⏪ VRAĆEN na stari servis zbog grešaka u novom
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  // bool _isAddingPutnik = false; // previously used loading state; now handled local to dialog
  String _selectedDay = 'Ponedeljak'; // Biće postavljeno na današnji dan u initState
  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // Stream kontroleri za reaktivno ažuriranje
  final StreamController<String> _selectedGradSubject = StreamController<String>.broadcast();
  // Key and overlay entry for custom days dropdown
  // (removed overlay support for now) - will use DropdownButton2 built-in overlay

  String? _currentDriver;

  // CACHE UKLONJEN - nepotrebne varijable uklonjene
  // 🕐 TIMER MANAGEMENT - sada koristi TimerManager singleton umesto direktnih Timer-a
  List<Putnik> _allPutnici = [];

  // Real-time subscription variables
  StreamSubscription<dynamic>? _realtimeSubscription;

  // Debug-only cache for last printed count values so we don't spam logs
  int? _lastBc6Count;
  int? _lastBcTotalCount;

  // 🚨 REALTIME MONITORING VARIABLES
  final ValueNotifier<bool> _isRealtimeHealthy = ValueNotifier(true);
  // Note: FailFastStreamManagerNew and NetworkStatus will be integrated later
  StreamSubscription<dynamic>? _networkStatusSubscription;

  final List<String> _dani = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Četvrtak',
    'Petak',
  ];

  // 🕐 VREMENA ZA DROPDOWN
  final List<String> bcVremena = [
    '5:00',
    '6:00',
    '7:00',
    '8:00',
    '9:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00'
  ];

  final List<String> vsVremena = [
    '6:00',
    '7:00',
    '8:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '17:00',
    '19:00'
  ];

// Kompletna lista polazaka za BottomNavBar (bez "Svi polasci") - ZIMSKI RASPORED
  final List<String> _sviPolasci = [
    '5:00 Bela Crkva',
    '6:00 Bela Crkva',
    '7:00 Bela Crkva',
    '8:00 Bela Crkva',
    '9:00 Bela Crkva',
    '11:00 Bela Crkva',
    '12:00 Bela Crkva',
    '13:00 Bela Crkva',
    '14:00 Bela Crkva',
    '15:30 Bela Crkva',
    '18:00 Bela Crkva',
    '6:00 Vršac',
    '7:00 Vršac',
    '8:00 Vršac',
    '10:00 Vršac',
    '11:00 Vršac',
    '13:00 Vršac',
    '14:00 Vršac',
    '15:30 Vršac',
    '16:15 Vršac',
    '19:00 Vršac',
  ];

  // ✅ KORISTI UTILS FUNKCIJU ZA DROPDOWN DAN
  String _getTodayName() {
    return app_date_utils.DateUtils.getTodayFullName();
  }

  // target date calculation handled elsewhere

  // Convert selected full day name (Ponedeljak) into ISO date string for target week
  String _getTargetDateIsoFromSelectedDay(String fullDay) {
    final now = DateTime.now();

    // Map full day names to indices
    final dayNamesMap = {
      'Ponedeljak': 0, 'ponedeljak': 0,
      'Utorak': 1, 'utorak': 1,
      'Sreda': 2, 'sreda': 2,
      'Četvrtak': 3, 'četvrtak': 3,
      'Petak': 4, 'petak': 4,
      'Subota': 5, 'subota': 5,
      'Nedelja': 6, 'nedelja': 6,
      // Short forms too
      'Pon': 0, 'pon': 0,
      'Uto': 1, 'uto': 1,
      'Sre': 2, 'sre': 2,
      'Čet': 3, 'čet': 3,
      'Pet': 4, 'pet': 4,
      'Sub': 5, 'sub': 5,
      'Ned': 6, 'ned': 6,
    };

    int? targetDayIndex = dayNamesMap[fullDay];
    if (targetDayIndex == null) return now.toIso8601String().split('T')[0];

    final currentDayIndex = now.weekday - 1;

    // 🎯 FIX: Ako je odabrani dan isto što i današnji dan, koristi današnji datum
    if (targetDayIndex == currentDayIndex) {
      return now.toIso8601String().split('T')[0];
    }

    // 🔧 POPRAVLJENO: Traži prethodni ili sledeći put kada je bio/će biti taj dan
    // Ali uvek vrati najbliži datum (prethodni ili sledeći)
    int daysToAdd = targetDayIndex - currentDayIndex;
    if (daysToAdd <= -4) {
      // Ako je više od 4 dana unazad, uzmi sledeći put
      daysToAdd += 7;
    } else if (daysToAdd >= 4) {
      // Ako je više od 4 dana unapred, uzmi prethodni put
      daysToAdd -= 7;
    }

    final targetDate = now.add(Duration(days: daysToAdd));
    return targetDate.toIso8601String().split('T')[0];
  }

  // replaced by RealtimeService streamKombinovaniPutnici

  // Konvertuj pun naziv dana u kraticu za poređenje sa bazom
  String _getDayAbbreviation(String fullDayName) {
    switch (fullDayName.toLowerCase()) {
      case 'ponedeljak':
        return 'pon';
      case 'utorak':
        return 'uto';
      case 'sreda':
        return 'sre';
      case 'četvrtak':
        return 'cet';
      case 'petak':
        return 'pet';
      case 'subota':
        return 'sub';
      case 'nedelja':
        return 'ned';
      default:
        return fullDayName.toLowerCase();
    }
  }

  // Normalizuj vreme format - konvertuj "05:00:00" u "5:00"
  String _normalizeTime(String? time) {
    if (time == null || time.isEmpty) return '';

    String normalized = time.trim();

    // Ukloni sekunde ako postoje (05:00:00 -> 05:00)
    if (normalized.contains(':') && normalized.split(':').length == 3) {
      List<String> parts = normalized.split(':');
      normalized = '${parts[0]}:${parts[1]}';
    }

    // Ukloni leading zero (05:00 -> 5:00)
    if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  @override
  void initState() {
    super.initState();

    final todayName = _getTodayName();
    // Home screen only supports weekdays, default to Monday for weekends
    _selectedDay = ['Subota', 'Nedelja'].contains(todayName) ? 'Ponedeljak' : todayName;

    // 🔧 POPRAVLJENO: Inicijalizacija bez blokiranja UI
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      await _initializeCurrentDriver();
      // 🔒 If the current driver is missing or invalid, redirect to welcome/login
      if (_currentDriver == null || !VozacBoja.isValidDriver(_currentDriver)) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
        return;
      }

      // 🚨 POPRAVLJENO: Async inicijalizacija bez blokiranje UI
      _initializeRealtimeService().catchError((e) => <String, dynamic>{});
      _setupRealtimeMonitoring(); // 🚨 NOVO: Setup realtime monitoring
      // StreamBuilder će automatski učitati data - ne treba eksplicitno _loadPutnici()
      _setupRealtimeListener();
      _startSmartNotifikacije();

      // CACHE UKLONJEN - koristimo direktne Supabase pozive

      // Inicijalizuj lokalne notifikacije za heads-up i zvuk
      LocalNotificationService.initialize(context);
      RealtimeNotificationService.listenForForegroundNotifications(context);

      // 🔄 Auto-update removed per request

      // Inicijalizuj realtime notifikacije za aktivnog vozača
      FirebaseService.getCurrentDriver().then((driver) {
        if (driver != null && driver.isNotEmpty) {
          // First request notification permissions
          RealtimeNotificationService.requestNotificationPermissions().then((hasPermissions) {
            RealtimeNotificationService.initialize().then((_) {
              // Subscribe to Firebase topics for this driver
              RealtimeNotificationService.subscribeToDriverTopics(driver);
            });
          });
        }
      });

      // 🔧 KONAČNO UKLONI LOADING STATE
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Ako se dogodi greška, i dalje ukloni loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCurrentDriver() async {
    final driver = await FirebaseService.getCurrentDriver();

    if (mounted)
      setState(() {
        // Inicijalizacija driver-a
        _currentDriver = driver; // Ne postavljaj fallback 'Nepoznat'
      });
  }

  Future<void> _initializeRealtimeService() async {
    try {
      // Start centralized RealtimeService for current driver
      final driver = await FirebaseService.getCurrentDriver();
      RealtimeService.instance.startForDriver(driver);
    } catch (e) {
      // Ignoriši grešku ako realtime ne može da se pokrene
    }
  }

  // 🚨 NOVO: Setup realtime monitoring system
  void _setupRealtimeMonitoring() {
    try {
      // 🕐 KORISTI TIMER MANAGER za heartbeat monitoring - STANDARDIZOVANO
      TimerManager.cancelTimer('home_screen_realtime_health');
      TimerManager.createTimer(
        'home_screen_realtime_health',
        const Duration(seconds: 30),
        _checkRealtimeHealth,
        isPeriodic: true,
      );
    } catch (e) {}
  }

  // 🚨 Check realtime system health
  void _checkRealtimeHealth() {
    try {
      final isHealthy = _realtimeSubscription != null;

      if (_isRealtimeHealthy.value != isHealthy) {
        _isRealtimeHealthy.value = isHealthy;
      }
    } catch (e) {
      _isRealtimeHealthy.value = false;
    }
  }

  void _setupRealtimeListener() {
    // Use centralized RealtimeService to avoid duplicate Supabase subscriptions
    _realtimeSubscription?.cancel();

    // 🔄 STANDARDIZOVANO: koristi putovanja_istorija (glavni naziv tabele)
    _realtimeSubscription = RealtimeService.instance.subscribe('putovanja_istorija', (data) {
      // Stream will update StreamBuilder via service layers
    });
  }

  void _startSmartNotifikacije() {
    // 🕐 KORISTI TIMER MANAGER umesto običnog Timer-a - SPREČAVA MEMORY LEAK
    TimerManager.cancelTimer('home_screen_smart_notifikacije');

    TimerManager.createTimer(
      'home_screen_smart_notifikacije',
      const Duration(minutes: 15),
      () async {
        await _pokretniSmartFunkcionalnosti();
      },
      isPeriodic: true,
    );

    // Pokreni odmah prva analiza
    _pokretniSmartFunkcionalnosti();
  }

  Future<void> _pokretniSmartFunkcionalnosti() async {
    try {
      // Koristi globalno čuvane putike
      if (_allPutnici.isNotEmpty) {
        // Smart notifikacije - ISKLJUČENO
        // await SmartNotifikacijeService.analizirajIposaljiNotifikacije(
        //     _allPutnici);

        // Ruta optimizacija - ISKLJUČENO (servis ne postoji)
        // await RutaOptimizacijaService.analizirajIpredloziRutu(_allPutnici);
      }

      // Weather alerts removed
    } catch (e) {
      // Ignore smart functionality errors in production
    }
  }

  // _loadPutnici metoda uklonjena - StreamBuilder automatski učitava podatke

  // _getPutnikCount je uklonjen jer nije korišćen

  // 🌟 GLASSMORPHISM Helper metoda za stat rows
  Widget _buildGlassStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // Prikaži confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.dangerPrimary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        title: Column(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Da li ste sigurni da se želite odjaviti?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Otkaži',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          HapticElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            hapticType: HapticType.medium,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Koristi centralizovani AuthManager za logout
      await AuthManager.logout(context);
    }
  }

  void _showAddPutnikDialog() async {
    final imeController = TextEditingController();
    final adresaController = TextEditingController();
    bool mesecnaKarta = false;
    bool manuelnoOznaceno = false; // 🔧 NOVO: prati da li je manuelno označeno

    // Povuci dozvoljena imena iz mesecni_putnici tabele
    final serviceInstance = MesecniPutnikService();
    final lista = await serviceInstance.getAllMesecniPutnici();
    final dozvoljenaImena = lista
        .where((MesecniPutnik putnik) => !putnik.obrisan && putnik.aktivan)
        .map((MesecniPutnik putnik) => putnik.putnikIme)
        .toList();

    if (!mounted) return;

    bool isDialogLoading = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              gradient: Theme.of(context).backgroundGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎨 GLASSMORPHISM HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).glassContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).glassBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '✨ Dodaj Putnika',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 📱 SCROLLABLE CONTENT
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🎯 GLASSMORPHISM INFORMACIJE O RUTI
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).glassContainer,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).glassBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📋 Informacije o ruti',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildGlassStatRow('🕐 Vreme:', _selectedVreme),
                              _buildGlassStatRow('🏘️ Grad:', _selectedGrad),
                              _buildGlassStatRow('📅 Dan:', _selectedDay),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 👤 GLASSMORPHISM PODACI O PUTNIKU
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).glassContainer,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).glassBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '👤 Podaci o putniku',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 3,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // IZBOR IMENA - drugačiji UI za mesečne i obične putnike
                              if (mesecnaKarta)
                                // DROPDOWN ZA MESEČNE PUTNIKE
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Izaberite mesečnog putnika:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      initialValue: imeController.text.trim().isEmpty
                                          ? null
                                          : (dozvoljenaImena.contains(
                                              imeController.text.trim(),
                                            )
                                              ? imeController.text.trim()
                                              : null),
                                      decoration: InputDecoration(
                                        labelText: 'Mesečni putnik',
                                        hintText: 'Izaberite putnika...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        filled: true,
                                      ),
                                      items: dozvoljenaImena
                                          .map(
                                            (String ime) => DropdownMenuItem(
                                              value: ime,
                                              child: Text(
                                                ime,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          imeController.text = value ?? '';
                                        });
                                      },
                                    ),
                                  ],
                                )
                              else
                                // AUTOCOMPLETE ZA OBIČNE PUTNIKE
                                AutocompleteImeField(
                                  controller: imeController,
                                  mesecnaKarta: mesecnaKarta,
                                  dozvoljenaImena: dozvoljenaImena,
                                  onChanged: (ime) {
                                    // Automatski označi mesečnu kartu ako je pronađen mesečni putnik
                                    final isMesecniPutnik = dozvoljenaImena.contains(ime.trim());
                                    if (isMesecniPutnik != mesecnaKarta) {
                                      setStateDialog(() {
                                        // 🔧 SAMO ažuriraj checkbox ako NIJE manuelno označeno
                                        if (!manuelnoOznaceno) {
                                          mesecnaKarta = isMesecniPutnik;
                                        }
                                      });
                                    }
                                  },
                                ),
                              const SizedBox(height: 12),

                              // ADRESA FIELD
                              AutocompleteAdresaField(
                                controller: adresaController,
                                grad: _selectedGrad,
                                labelText: 'Adresa',
                                hintText: 'Npr: Glavna 15, Zmaj Jovina 22...',
                              ),

                              // Dodatno obaveštenje o adresi
                              if (adresaController.text.trim().isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.green.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.route,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '✅ Adresa će biti korišćena za optimizaciju rute!',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 🎫 GLASSMORPHISM TIP KARTE
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).glassContainer,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Theme.of(context).glassBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🌟 GLASSMORPHISM SWITCH ZA MESEČNU KARTU
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.2),
                                      Colors.white.withValues(alpha: 0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Mesečna karta',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setStateDialog(() {
                                          mesecnaKarta = !mesecnaKarta;
                                          manuelnoOznaceno = true;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 50,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: mesecnaKarta
                                                ? [
                                                    Colors.green.withValues(alpha: 0.8),
                                                    Colors.green,
                                                  ]
                                                : [
                                                    Colors.white.withValues(alpha: 0.3),
                                                    Colors.white.withValues(alpha: 0.1),
                                                  ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: mesecnaKarta
                                                ? Colors.green.withValues(alpha: 0.6)
                                                : Colors.white.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: AnimatedAlign(
                                          duration: const Duration(milliseconds: 200),
                                          alignment: mesecnaKarta ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            margin: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(11),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // UPOZORENJE ZA MESEČNE PUTNIKE
                              if (mesecnaKarta)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'SAMO POSTOJEĆI MESEČNI PUTNICI',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🌟 GLASSMORPHISM ACTIONS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).glassContainer,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).glassBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Otkaži',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Add button
                      Expanded(
                        flex: 2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: HapticElevatedButton(
                            hapticType: HapticType.success,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: isDialogLoading
                                ? null
                                : () async {
                                    if (imeController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('❌ Ime putnika je obavezno'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // 🚫 VALIDACIJA GRADA
                                    if (GradAdresaValidator.isCityBlocked(
                                      _selectedGrad,
                                    )) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '❌ Grad "$_selectedGrad" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // 🏘️ VALIDACIJA ADRESE
                                    final adresa = adresaController.text.trim();
                                    if (adresa.isNotEmpty &&
                                        !GradAdresaValidator.validateAdresaForCity(
                                          adresa,
                                          _selectedGrad,
                                        )) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '❌ Adresa "$adresa" nije validna za grad "$_selectedGrad". Dozvoljene su samo adrese iz Bele Crkve i Vršca.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // 🚫 VALIDACIJA ZA MESEČNU KARTU - SAMO POSTOJEĆI MESEČNI PUTNICI
                                    if (mesecnaKarta &&
                                        !dozvoljenaImena.contains(
                                          imeController.text.trim(),
                                        )) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '❌ NOVI MESEČNI PUTNICI SE NE MOGU DODATI OVDE!',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Možete dodati samo POSTOJEĆE mesečne putnike.',
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Za NOVE mesečne putnike idite na:',
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 16,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Meni → Mesečni putnici',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                      return;
                                    }

                                    if (_selectedVreme.isEmpty || _selectedGrad.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '❌ Greška: Nije odabrano vreme polaska',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      // STRIKTNA VALIDACIJA VOZAČA - PRVO PROVERI DA NIJE NULL
                                      if (_currentDriver == null || _currentDriver!.isEmpty) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '❌ GREŠKA: Niste ulogovani! Molimo ponovo pokrenite aplikaciju.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      // Uklonjena validacija vozača - dozvoljava sve vozače

                                      // POKAZI LOADING STATE - lokalno za dijalog
                                      setStateDialog(() {
                                        isDialogLoading = true;
                                      });

                                      // 🕐 KORISTI SELEKTOVANO VREME SA HOME SCREEN-A

                                      final putnik = Putnik(
                                        ime: imeController.text.trim(),
                                        polazak: _selectedVreme,
                                        grad: _selectedGrad,
                                        dan: _getDayAbbreviation(_selectedDay),
                                        mesecnaKarta: mesecnaKarta,
                                        vremeDodavanja: DateTime.now(),
                                        dodaoVozac: _currentDriver!, // Safe non-null assertion nakon validacije
                                        adresa:
                                            adresaController.text.trim().isEmpty ? null : adresaController.text.trim(),
                                      );
                                      // Proveri da li već postoji isti dnevni putnik
                                      try {
                                        final exists = await _putnikService.existsDuplicatePutnik(putnik);
                                        if (exists && putnik.mesecnaKarta != true) {
                                          // Ukloni loading state
                                          setStateDialog(() {
                                            isDialogLoading = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '❌ Greška: Sličan putnik za izabrani dan/vreme već postoji',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                      } catch (e) {
                                        // Ignoriši grešku u proveri - nastavi sa dodavanjem
                                      }

                                      await _putnikService.dodajPutnika(putnik);

                                      // 🔄 FORSIRAJ REALTIME REFRESH da se stream ažurira
                                      try {
                                        await RealtimeService.instance.refreshNow();
                                      } catch (e) {
                                        // Ignoriši greške u refresh-u
                                      }

                                      if (!mounted) return;

                                      // Ukloni loading state
                                      setStateDialog(() {
                                        isDialogLoading = false;
                                      });
                                      if (mounted) {
                                        // ignore: use_build_context_synchronously
                                        Navigator.pop(context);
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✅ Putnik je uspešno dodat',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // ensure dialog loading is cleared
                                      setStateDialog(() {
                                        isDialogLoading = false;
                                      });

                                      if (!mounted) return;

                                      if (mounted) {
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '❌ Greška pri dodavanju: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: isDialogLoading
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: const BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black54,
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Dodaje...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Dodaj',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PROVERAVAJ LOADING STANJE ODMAH
    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(74),
          child: Container(
            decoration: BoxDecoration(
              // Keep appbar fully transparent so underlying gradient shows
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
                width: 1.5,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // REZERVACIJE - levo
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 35,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Rezervacije',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onPrimary,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // LOADING - sredina
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 35,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Učitavam...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // PRAZAN PROSTOR - desno
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: ThemeManager().currentGradient, // 🎨 Dinamički gradijent iz tema
          ),
          child: ShimmerWidgets.putnikListShimmer(itemCount: 8),
        ),
        // 🔧 DODAJ BOTTOM NAVIGATION BAR I U LOADING STANJU!
        bottomNavigationBar: isZimski(DateTime.now())
            ? BottomNavBarZimski(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: (grad, vreme) => 0, // Loading state - nema putnika
                onPolazakChanged: (grad, vreme) {
                  if (mounted)
                    setState(() {
                      _selectedGrad = grad;
                      _selectedVreme = vreme;
                      _selectedGradSubject.add(grad);
                    });
                },
              )
            : BottomNavBarLetnji(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: (grad, vreme) => 0, // Loading state - nema putnika
                onPolazakChanged: (grad, vreme) {
                  if (mounted)
                    setState(() {
                      _selectedGrad = grad;
                      _selectedVreme = vreme;
                      _selectedGradSubject.add(grad);
                    });
                },
              ),
      );
    }

    // � PRAVI REALTIME STREAM: streamKombinovaniPutnici() koristi RealtimeService
    // Auto-refresh kada se promeni status putnika (pokupljen/naplaćen/otkazan)
    // Use a parametric stream filtered to the currently selected day
    // so monthly passengers (mesecni_putnici) are created for that day
    // and will appear in the list/counts for arbitrary selected day.
    return StreamBuilder<List<Putnik>>(
      stream: _putnikService.streamKombinovaniPutniciFiltered(
        isoDate: _getTargetDateIsoFromSelectedDay(_selectedDay),
      ),
      builder: (context, snapshot) {
        // 🚨 DEBUG: Log state information
        // 🚨 NOVO: Error handling sa specialized widgets
        if (snapshot.hasError) {
          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(93),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  border: Border.all(
                    color: Theme.of(context).glassBorder,
                    width: 1.5,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Text(
                      'REZERVACIJE - ERROR',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onError,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 🔧 POPRAVLJENO: Prikažemo prazan UI umesto beskonačnog loading-a
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          // Umesto beskonačnog čekanja, nastavi sa praznom listom
          // StreamBuilder će se ažurirati kada podaci stignu
        }

        final allPutnici = snapshot.data ?? [];

        // Get target day abbreviation for additional filtering
        final targetDateIso = _getTargetDateIsoFromSelectedDay(_selectedDay);
        final date = DateTime.parse(targetDateIso);
        const dayAbbrs = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
        final targetDayAbbr = dayAbbrs[date.weekday - 1];

        // Additional client-side filtering like danas_screen
        Iterable<Putnik> filtered = allPutnici.where((p) {
          // Dan u nedelji filter za mesečne putnike
          final dayMatch =
              p.datum != null ? p.datum == targetDateIso : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());

          // Vremski filter - samo poslednja nedelja za dnevne putnike
          bool timeMatch = true;
          if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
            final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
            timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
          }

          return dayMatch && timeMatch;
        });
        // Capture passengers for the selected day (but before applying the
        // selected-time filter). We use this set for counting bottom-bar slots
        // because the bottom counts should reflect the whole day (all times),
        // not just the currently selected time.
        final putniciZaDan = filtered.toList();

        // Additional filters for display (applies time/grad/status and is used
        // to build the visible list). This operates on the putniciZaDan list.
        filtered = putniciZaDan.where((putnik) {
          final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');
          final imaVreme = putnik.polazak.toString().trim().isNotEmpty;
          final imaGrad = putnik.grad.toString().trim().isNotEmpty;
          final imaDan = putnik.dan.toString().trim().isNotEmpty;
          final danBaza = _selectedDay;
          final normalizedPutnikDan = GradAdresaValidator.normalizeString(putnik.dan);
          final normalizedDanBaza = GradAdresaValidator.normalizeString(_getDayAbbreviation(danBaza));
          final odgovarajuciDan = normalizedPutnikDan.contains(normalizedDanBaza);
          final odgovarajuciGrad = GradAdresaValidator.isGradMatch(
            putnik.grad,
            putnik.adresa,
            _selectedGrad,
          );
          final odgovarajuceVreme =
              GradAdresaValidator.normalizeTime(putnik.polazak) == GradAdresaValidator.normalizeTime(_selectedVreme);
          final prikazi = imaVreme &&
              imaGrad &&
              imaDan &&
              odgovarajuciDan &&
              odgovarajuciGrad &&
              odgovarajuceVreme &&
              normalizedStatus != 'obrisan';
          return prikazi;
        });
        final sviPutnici = filtered.toList();

        // DEDUPLIKACIJA PO COMPOSITE KLJUČU: id + polazak + dan
        final Map<String, Putnik> uniquePutnici = {};
        for (final p in sviPutnici) {
          final key = '${p.id}_${p.polazak}_${p.dan}';
          uniquePutnici[key] = p;
        }
        final sviPutniciBezDuplikata = uniquePutnici.values.toList();

        // 🎯 BROJAČ PUTNIKA - koristi SVE putnice za SELEKTOVANI DAN (deduplikovane)
        // Koristimo `putniciZaDan` iznad kao izvor za brojače kako bismo
        // računali broj jedinstvenih putnika po polasku za ceo dan.
        final Map<String, int> brojPutnikaBC = {
          '5:00': 0,
          '6:00': 0,
          '7:00': 0,
          '8:00': 0,
          '9:00': 0,
          '11:00': 0,
          '12:00': 0,
          '13:00': 0,
          '14:00': 0,
          '15:30': 0,
          '18:00': 0,
        };
        final Map<String, int> brojPutnikaVS = {
          '6:00': 0,
          '7:00': 0,
          '8:00': 0,
          '10:00': 0,
          '11:00': 0,
          '12:00': 0,
          '13:00': 0,
          '14:00': 0,
          '15:30': 0,
          '17:00': 0,
          '19:00': 0,
        };

        // Use the filtered, deduplicated list so counts match the displayed list
        // DEDUPLICIRAJ za računanje brojača (id + polazak + dan)
        final Map<String, Putnik> uniqueForCounts = {};
        for (final p in putniciZaDan) {
          final key = '${p.id}_${p.polazak}_${p.dan}';
          uniqueForCounts[key] = p;
        }
        final countCandidates = uniqueForCounts.values.toList();

        for (final p in countCandidates) {
          if (!TextUtils.isStatusActive(p.status)) continue;

          final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
          // Normalize address (strip diacritics, lower-case, etc.) so checks/contains work
          final normAdresa = GradAdresaValidator.normalizeString(p.adresa);

          // Use both heuristics: quick substring checks and membership in the
          // curated naselja lists (which are normalized). This keeps behaviour
          // predictable and allows us to exclude Pavliš / Središte as requested.
          final jeBelaCrkva = normAdresa.contains('bela') ||
              normAdresa.contains('bc') ||
              GradAdresaValidator.naseljaOpstineBelaCrkva.any((n) => normAdresa.contains(n));
          final jeVrsac = normAdresa.contains('vrsac') ||
              normAdresa.contains('vs') ||
              GradAdresaValidator.naseljaOpstineVrsac.any((n) => normAdresa.contains(n));

          if (jeBelaCrkva && brojPutnikaBC.containsKey(normVreme)) {
            brojPutnikaBC[normVreme] = (brojPutnikaBC[normVreme] ?? 0) + 1;
          }
          if (jeVrsac && brojPutnikaVS.containsKey(normVreme)) {
            brojPutnikaVS[normVreme] = (brojPutnikaVS[normVreme] ?? 0) + 1;
          }
        }

        if (kDebugMode) {
          final bc600 = brojPutnikaBC['6:00'] ?? 0;
          final ukupno = brojPutnikaBC.values.fold(0, (a, b) => a + b);
          if (_lastBc6Count != bc600 || _lastBcTotalCount != ukupno) {
            debugPrint('🏠 HOME: BC 6:00 = $bc600');
            debugPrint('🏠 HOME: Ukupno BC putnika = $ukupno');
            _lastBc6Count = bc600;
            _lastBcTotalCount = ukupno;
          }
        }

        // Sortiraj po statusu: bele (nepokupljeni), plave (pokupljeni neplaćeni), zelene (pokupljeni sa mesečnom/plaćeni), žute/narandžaste (bolovanje/godišnji), crvene (otkazani)
        List<Putnik> sortiraniPutnici(List<Putnik> lista) {
          int sortKey(Putnik p) {
            final status = TextUtils.normalizeText(p.status ?? '');
            // Leave/inactive (bolovanje, godišnji, obrisan) always at the bottom
            if (status == 'bolovanje' || status == 'godisnji') {
              return 100;
            }
            if (status == 'otkazano' || status == 'otkazan') {
              return 101;
            }
            if (status == 'obrisan' || p.obrisan) {
              return 102;
            }
            // Mesečni putnici: pokupljeni i plaćeni (zelene), pokupljeni neplaćeni (plave), nepokupljeni (bele)
            if (p.mesecnaKarta == true) {
              if (p.vremePokupljenja == null) {
                return 0; // bela
              }
              if (p.iznosPlacanja != null && p.iznosPlacanja! > 0) {
                return 2; // zelena
              }
              return 1; // plava
            }
            // Dnevni putnici: pokupljeni i plaćeni (zelene), pokupljeni neplaćeni (plave), nepokupljeni (bele)
            if (p.vremePokupljenja == null) return 0; // bela
            if (p.vremePokupljenja != null && (p.iznosPlacanja == null || p.iznosPlacanja == 0)) {
              return 1; // plava
            }
            if (p.vremePokupljenja != null && (p.iznosPlacanja != null && p.iznosPlacanja! > 0)) {
              return 2; // zelena
            }
            return 99;
          }

          final kopija = [...lista];
          kopija.sort((a, b) {
            final cmp = sortKey(a).compareTo(sortKey(b));
            if (cmp != 0) return cmp;
            // Optionally, secondary sort by ime
            return a.ime.compareTo(b.ime);
          });
          return kopija;
        }

        final putniciZaPrikaz = sortiraniPutnici(sviPutniciBezDuplikata);

        // Sortiranje putnika

        // Funkcija za brojanje putnika po gradu, vremenu i danu (samo aktivni)
        // Koristimo prekompjutovane mape `brojPutnikaBC` i `brojPutnikaVS`
        // koje su izračunate iz `allPutnici` iznad. Ovo rešava slučaj kada
        // je prikaz svuda 0.
        int getPutnikCount(String grad, String vreme) {
          try {
            final count = grad == 'Bela Crkva' ? brojPutnikaBC[vreme] ?? 0 : brojPutnikaVS[vreme] ?? 0;
            return count;
          } catch (e) {
            // Log error and continue to fallback
          }

          // Fallback: brzo prebroj ako grad nije standardan
          return allPutnici.where((putnik) {
            final gradMatch = GradAdresaValidator.isGradMatch(
              putnik.grad,
              putnik.adresa,
              grad,
            );
            final vremeMatch = _normalizeTime(putnik.polazak) == _normalizeTime(vreme);
            final normalizedPutnikDan = GradAdresaValidator.normalizeString(putnik.dan);
            final normalizedDanBaza = GradAdresaValidator.normalizeString(
              _getDayAbbreviation(_selectedDay),
            );
            final danMatch = normalizedPutnikDan.contains(normalizedDanBaza);
            final statusOk = TextUtils.isStatusActive(putnik.status);
            return gradMatch && vremeMatch && danMatch && statusOk;
          }).length;
        }

        // (totalFilteredCount removed)

        return Container(
          decoration: BoxDecoration(
            gradient: ThemeManager().currentGradient, // Dinamički gradijent iz tema
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Transparentna pozadina
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(
                93,
              ), // Povećano sa 80 na 95 zbog sezonskog indikatora
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer, // Transparentni glassmorphism
                  border: Border.all(
                    color: Theme.of(context).glassBorder,
                    width: 1.5,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // PRVI RED - Rezervacije
                        Container(
                          // increase height slightly and reduce font so it never drifts under the control row below
                          height: 28,
                          alignment: Alignment.center,
                          child: Text(
                            'R E Z E R V A C I J E',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onPrimary,
                              // slightly reduced letter spacing to keep the text compact on narrow screens
                              letterSpacing: 1.4,
                              shadows: [
                                Shadow(
                                  blurRadius: 12,
                                  color: Colors.black87,
                                ),
                                Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 6,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // DRUGI RED - Driver, Tema, Update i Dropdown
                        Row(
                          children: [
                            // DRIVER - levo
                            if (_currentDriver != null && _currentDriver!.isNotEmpty)
                              Expanded(
                                flex: 35,
                                child: Container(
                                  height: 33,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: VozacBoja.get(_currentDriver), // opaque (100%)
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).glassBorder,
                                      width: 1.5,
                                    ),
                                    // no boxShadow — keep transparent glass + border only
                                  ),
                                  child: Center(
                                    child: Text(
                                      _currentDriver!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black87,
                                          ),
                                          Shadow(
                                            offset: Offset(1, 1),
                                            blurRadius: 4,
                                            color: Colors.black54,
                                          ),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(width: 2),

                            // TEMA - levo-sredina (sada konzistentan sa dugmićima ispod appbara)
                            Expanded(
                              flex: 25,
                              child: InkWell(
                                onTap: () async {
                                  await ThemeManager().nextTheme();
                                  if (mounted) setState(() {});
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 33,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).glassContainer,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context).glassBorder,
                                      width: 1.5,
                                    ),
                                    // no boxShadow — keep transparent glass + border only
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Tema',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(blurRadius: 8, color: Colors.black87),
                                          Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 2),

                            // DROPDOWN - desno (sada ima isti glassmorphism izgled kao dugmad)
                            Expanded(
                              flex: 35,
                              child: Container(
                                height: 33,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).glassContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Theme.of(context).glassBorder,
                                    width: 1.5,
                                  ),
                                  // no boxShadow — keep transparent glass + border only
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton2<String>(
                                    value: _selectedDay,
                                    // custom button will include arrow icon to preserve layout
                                    customButton: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              _selectedDay,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    dropdownStyleData: DropdownStyleData(
                                      decoration: BoxDecoration(
                                        gradient: Theme.of(context).backgroundGradient,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).glassBorder,
                                          width: 1.5,
                                        ),
                                      ),
                                      elevation: 8,
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black87,
                                        ),
                                        Shadow(
                                          offset: Offset(1, 1),
                                          blurRadius: 4,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                    // button decoration: keep a glass look for the closed button
                                    buttonStyleData: ButtonStyleData(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).glassContainer,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).glassBorder,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    isExpanded: true,
                                    // using customButton, selectedItemBuilder is not needed
                                    items: _dani
                                        .map(
                                          (dan) => DropdownMenuItem(
                                            value: dan,
                                            child: Center(
                                              child: Text(
                                                dan,
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (mounted) setState(() => _selectedDay = value!);
                                      // 🔄 Stream će se automatski ažurirati preko StreamBuilder-a
                                      // Ne treba eksplicitno pozivati _loadPutnici()
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Dugmad za akcije
                      Expanded(
                        child: _HomeScreenButton(
                          label: 'Dodaj',
                          icon: Icons.person_add,
                          onTap: _showAddPutnikDialog,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (_currentDriver == 'Bruda' ||
                          _currentDriver == 'Bilevski' ||
                          _currentDriver == 'Bojan' ||
                          _currentDriver == 'Svetlana')
                        Expanded(
                          child: _HomeScreenButton(
                            label: 'Danas',
                            icon: Icons.today,
                            onTap: () {
                              // Navigate to DanasScreen
                              AnimatedNavigation.pushSmooth(
                                context,
                                const DanasScreen(),
                              );
                            },
                          ),
                        ),
                      if (['Bojan', 'Svetlana'].contains(_currentDriver)) const SizedBox(width: 4),
                      if (['Bojan', 'Svetlana'].contains(_currentDriver))
                        Expanded(
                          child: _HomeScreenButton(
                            label: 'Admin',
                            icon: Icons.admin_panel_settings,
                            onTap: () {
                              // Navigate to AdminScreen
                              AnimatedNavigation.pushSmooth(
                                context,
                                const AdminScreen(),
                              );
                            },
                          ),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _HomeScreenButton(
                          label: 'Štampaj',
                          icon: Icons.print,
                          onTap: () async {
                            await PrintingService.printPutniksList(
                              _selectedDay,
                              _selectedVreme,
                              _selectedGrad,
                              context,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _HomeScreenButton(
                          label: 'Logout',
                          icon: Icons.logout,
                          onTap: _logout,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista putnika
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).glassContainer, // 🌟 GLASSMORPHISM
                      border: Border.all(
                        color: Theme.of(context).glassBorder,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        Theme.of(context).glassShadow,
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: putniciZaPrikaz.isEmpty
                          ? const Center(
                              child: Text(
                                'Nema putnika za ovaj polazak.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black87,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: putniciZaPrikaz.length,
                              itemBuilder: (context, index) {
                                final putnik = putniciZaPrikaz[index];
                                return AnimatedCard(
                                  delay: index * 100, // Staggered animation
                                  child: PutnikCard(
                                    putnik: putnik,
                                    currentDriver: _currentDriver,
                                    redniBroj: index + 1,
                                    selectedVreme: _selectedVreme, // 🆕 Proslijedi trenutno vreme
                                    selectedGrad: _selectedGrad, // 🆕 Proslijedi trenutni grad
                                    onChanged: () {
                                      // 🚀 FORSIRAJ UI REFRESH kada se putnik ažurira
                                      if (mounted) {
                                        if (mounted)
                                          setState(() {
                                            // Trigger rebuild-a StreamBuilder-a
                                          });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ), // Zatvaranje Column
            bottomNavigationBar: isZimski(DateTime.now())
                ? BottomNavBarZimski(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    onPolazakChanged: (grad, vreme) {
                      // Najpre ažuriraj UI selekciju — odmah prikažemo prave brojeve
                      if (mounted)
                        setState(() {
                          _selectedGrad = grad;
                          _selectedVreme = vreme;
                          _selectedGradSubject.add(grad); // Ažuriraj stream
                        });
                    },
                  )
                : BottomNavBarLetnji(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    onPolazakChanged: (grad, vreme) async {
                      if (mounted)
                        setState(() {
                          _selectedGrad = grad;
                          _selectedVreme = vreme;
                          _selectedGradSubject.add(grad);
                        });
                    },
                  ),
          ), // Zatvaranje Container wrapper-a
        );
      }, // Zatvaranje StreamBuilder builder funkcije
    ); // Zatvaranje StreamBuilder widgeta
  } // Zatvaranje build metode

  @override
  void dispose() {
    // 🕐 KORISTI TIMER MANAGER za cleanup - SPREČAVA MEMORY LEAK
    TimerManager.cancelTimer('home_screen_smart_notifikacije');
    TimerManager.cancelTimer('home_screen_realtime_health');

    // 🧹 KOMPLETNO ZATVARANJE STREAM CONTROLLER-A
    try {
      if (!_selectedGradSubject.isClosed) {
        _selectedGradSubject.close();
      }
    } catch (e) {}

    // 🧹 CLEANUP REAL-TIME SUBSCRIPTIONS
    try {
      _realtimeSubscription?.cancel();
      _networkStatusSubscription?.cancel();
    } catch (e) {}

    // No overlay cleanup needed currently

    // 🧹 SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
      }
    } catch (e) {}
    super.dispose();
  }
}

// AnimatedActionButton widget sa hover efektima
class AnimatedActionButton extends StatefulWidget {
  const AnimatedActionButton({
    Key? key,
    required this.child,
    required this.onTap,
    required this.width,
    required this.height,
    required this.margin,
    required this.gradientColors,
    required this.boxShadow,
  }) : super(key: key);
  final Widget child;
  final VoidCallback onTap;
  final double width;
  final double height;
  final EdgeInsets margin;
  final List<Color> gradientColors;
  final List<BoxShadow> boxShadow;

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        if (mounted) setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        if (mounted) setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              margin: widget.margin,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _isPressed
                    ? widget.boxShadow.map((shadow) {
                        return BoxShadow(
                          color: shadow.color.withValues(
                            alpha: (shadow.color.a * 1.5).clamp(0.0, 1.0),
                          ),
                          blurRadius: shadow.blurRadius * 1.2,
                          offset: shadow.offset,
                        );
                      }).toList()
                    : widget.boxShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {}, // Handled by GestureDetector
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Originalna _HomeScreenButton klasa sa seksi bojama
class _HomeScreenButton extends StatelessWidget {
  const _HomeScreenButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(6), // Smanjeno sa 12 na 6
        decoration: BoxDecoration(
          color: Theme.of(context).glassContainer, // Transparentni glassmorphism
          border: Border.all(
            color: Theme.of(context).glassBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          // no boxShadow — keep transparent glass + border only
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              // keep icons consistent with the current theme (onPrimary may be white or themed)
              color: Theme.of(context).colorScheme.onPrimary,
              size: 18, // Smanjeno sa 24 na 18
            ),
            const SizedBox(height: 4), // Smanjeno sa 8 na 4
            // Keep the label to a single centered line; scale down if it's too big for narrow buttons
            SizedBox(
              height: 16,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black87,
                      ),
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 4,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
