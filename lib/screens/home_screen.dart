import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show globalThemeToggler; // Za theme toggle
import '../models/mesecni_putnik.dart';
import '../models/putnik.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import '../services/local_notification_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/printing_service.dart';
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/update_service.dart'; // 🔄 Vraćeno: Update sistem
import '../theme.dart'; // Za theme boje
import '../utils/animation_utils.dart';
import '../utils/date_utils.dart' as app_date_utils; // DODANO: Centralna vikend logika
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju
import '../utils/logging.dart';
import '../utils/page_transitions.dart';
import '../utils/schedule_utils.dart';
import '../utils/slot_utils.dart';
import '../utils/text_utils.dart';
import '../utils/vozac_boja.dart'; // Dodato za centralizovane boje vozača
import '../widgets/autocomplete_adresa_field.dart';
import '../widgets/autocomplete_ime_field.dart';
import '../widgets/bottom_nav_bar_letnji.dart';
// import '../widgets/supabase_analysis_widget.dart'; // REMOVED - file not found
import '../widgets/bottom_nav_bar_zimski.dart';
// import '../widgets/network_status_widget.dart'; // REMOVED - file not found
import '../widgets/putnik_card.dart';
import '../widgets/realtime_error_widgets.dart'; // 🚨 NOVO realtime error widgets
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
  bool _isAddingPutnik = false; // DODANO za loading state kad se dodaje putnik
  String _selectedDay = 'Ponedeljak'; // Biće postavljeno na današnji dan u initState
  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // Stream kontroleri za reaktivno ažuriranje
  final StreamController<String> _selectedGradSubject = StreamController<String>.broadcast();

  String? _currentDriver;

  // CACHE UKLONJEN - nepotrebne varijable uklonjene
  Timer? _smartNotifikacijeTimer;
  // Timer? _updateCheckTimer; // 🔄 Uklonjeno: Timer za periodičnu proveru update-a
  List<Putnik> _allPutnici = [];

  // Real-time subscription variables
  StreamSubscription<dynamic>? _realtimeSubscription;

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
  final List<String> bcVremena = SlotUtils.bcVremena;

  final List<String> vsVremena = SlotUtils.vsVremena;

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
    int daysToAdd =
        targetDayIndex >= currentDayIndex ? targetDayIndex - currentDayIndex : (7 - currentDayIndex) + targetDayIndex;
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

    _selectedDay = _getTodayName(); // Postavi na današnji dan
    _initializeCurrentDriver();
    _initializeRealtimeService();
    _setupRealtimeMonitoring(); // 🚨 NOVO: Setup realtime monitoring
    _loadPutnici();
    _setupRealtimeListener();
    _startSmartNotifikacije();

    // CACHE UKLONJEN - koristimo direktne Supabase pozive

    // Inicijalizuj lokalne notifikacije za heads-up i zvuk
    LocalNotificationService.initialize(context);
    RealtimeNotificationService.listenForForegroundNotifications(context);

    // 🔄 Pokreni automatski update sistem
    UpdateService.startBackgroundUpdateCheck();

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
  }

  Future<void> _initializeCurrentDriver() async {
    final driver = await FirebaseService.getCurrentDriver();
    print('🏠 [HOME SCREEN] Current driver from FirebaseService: "$driver"');
    setState(() {
      // Inicijalizacija driver-a
      _currentDriver = driver; // Ne postavljaj fallback 'Nepoznat'
    });
    print('🏠 [HOME SCREEN] Set _currentDriver to: "$_currentDriver"');
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
      // Setup heartbeat monitoring
      Timer.periodic(const Duration(seconds: 30), (timer) {
        _checkRealtimeHealth();
      });

      dlog('🚨 Realtime monitoring setup completed');
    } catch (e) {
      dlog('Failed to setup realtime monitoring: $e');
    }
  }

  // 🚨 Check realtime system health
  void _checkRealtimeHealth() {
    try {
      final isHealthy = _realtimeSubscription != null;

      if (_isRealtimeHealthy.value != isHealthy) {
        _isRealtimeHealthy.value = isHealthy;
        dlog('💓 Realtime health changed: $isHealthy');
      }
    } catch (e) {
      _isRealtimeHealthy.value = false;
      dlog('Heartbeat check failed: $e');
    }
  }

  void _setupRealtimeListener() {
    // Use centralized RealtimeService to avoid duplicate Supabase subscriptions
    _realtimeSubscription?.cancel();

    // 🔄 STANDARDIZOVANO: koristi putovanja_istorija (glavni naziv tabele)
    _realtimeSubscription = RealtimeService.instance.subscribe('putovanja_istorija', (data) {
      // Stream will update StreamBuilder via service layers
      dlog(
        '🔄 [HOME SCREEN] Received realtime update: ${data?.length ?? 0} records',
      );
    });
  }

  void _startSmartNotifikacije() {
    // Pokreni smart notifikacije svakih 15 minuta
    _smartNotifikacijeTimer?.cancel();
    _smartNotifikacijeTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      await _pokretniSmartFunkcionalnosti();
    });

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

  Future<List<Putnik>> _getAllPutnici() async {
    try {
      dlog('🔍 Getting all putnici for day: $_selectedDay');
      // 🆕 NOVI NAČIN: Koristi PutnikService za učitavanje iz obe tabele
      // 🎯 PROSLIJEDI SELEKTOVANI DAN umesto današnjeg
      final result = await _putnikService.getAllPutniciFromBothTables(
        targetDay: _selectedDay,
      );
      dlog('✅ Got ${result.length} putnici from both tables');
      return result;
    } catch (e) {
      dlog('❌ Error in _getAllPutnici: $e');
      return [];
    }
  }

  Future<void> _loadPutnici() async {
    dlog('🔄 Loading putnici started...');
    setState(() => _isLoading = true);
    try {
      final putnici = await _getAllPutnici();
      dlog('✅ Loading putnici completed: ${putnici.length} putnici');
      setState(() {
        _allPutnici = putnici;
        _isLoading = false;
      });
    } catch (e) {
      dlog('❌ Error loading putnici: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Greška pri učitavanju: $e');
    }
  }

  // _getPutnikCount je uklonjen jer nije korišćen

  // Helper metoda za prikaz redova u sekcijama (kao u statistikama)
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Greška'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            color: Theme.of(context).colorScheme.dangerPrimary.withOpacity(0.5),
            width: 2,
          ),
        ),
        title: const Column(
          children: [
            Icon(Icons.logout, color: Colors.red, size: 40),
            SizedBox(height: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Da li ste sigurni da se želite odjaviti?',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
      // Obriši session iz SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_driver');

      if (!mounted) return;

      // Idi nazad na WelcomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
      );
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

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.person_add,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dodaj Putnika',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 INFORMACIJE O RUTI - Sekcija sa night blue temom
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📋 Informacije o ruti',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow('🕐 Vreme:', _selectedVreme),
                      _buildStatRow('🏘️ Grad:', _selectedGrad),
                      _buildStatRow('📅 Dan:', _selectedDay),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 👤 PODACI O PUTNIKU - Sekcija sa night blue temom
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👤 Podaci o putniku',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // IZBOR IMENA - drugačiji UI za mesečne i obične putnike
                      if (mesecnaKarta)
                        // DROPDOWN ZA MESEČNE PUTNIKE
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izaberite mesečnog putnika:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: imeController.text.trim().isEmpty
                                  ? null
                                  : (dozvoljenaImena.contains(imeController.text.trim())
                                      ? imeController.text.trim()
                                      : null),
                              decoration: InputDecoration(
                                labelText: 'Mesečni putnik',
                                hintText: 'Izaberite putnika...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.green,
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: dozvoljenaImena
                                  .map(
                                    (String ime) => DropdownMenuItem(
                                      value: ime,
                                      child: Text(ime),
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
                        labelText: 'Adresa (opciono)',
                        hintText: 'Npr: Glavna 15, Zmaj Jovina 22...',
                      ),

                      // Dodatno obaveštenje o adresi
                      if (adresaController.text.trim().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
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

                const SizedBox(height: 16),

                // 🎫 TIP KARTE - Sekcija
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎫 Tip karte',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),

                      CheckboxListTile(
                        title: const Text('Mesečna karta'),
                        subtitle: const Text('Označite ako putnik ima mesečnu kartu'),
                        value: mesecnaKarta,
                        activeColor: Colors.orange,
                        onChanged: (value) {
                          setStateDialog(() {
                            mesecnaKarta = value ?? false;
                            manuelnoOznaceno = true;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                      // UPOZORENJE ZA MESEČNE PUTNIKE
                      if (mesecnaKarta)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange[700],
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'SAMO POSTOJEĆI MESEČNI PUTNICI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Možete dodati samo imena koja već postoje u mesečnoj listi.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Za NOVE mesečne putnike → Meni → Mesečni putnici',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[600],
                                  fontStyle: FontStyle.italic,
                                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('Otkaži'),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: HapticElevatedButton(
                hapticType: HapticType.success,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isAddingPutnik
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
                        if (GradAdresaValidator.isCityBlocked(_selectedGrad)) {
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
                        if (mesecnaKarta && !dozvoljenaImena.contains(imeController.text.trim())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '❌ NOVI MESEČNI PUTNICI SE NE MOGU DODATI OVDE!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Možete dodati samo POSTOJEĆE mesečne putnike.',
                                  ),
                                  SizedBox(height: 4),
                                  Text('Za NOVE mesečne putnike idite na:'),
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
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
                              duration: Duration(seconds: 5),
                            ),
                          );
                          return;
                        }

                        if (_selectedVreme.isEmpty || _selectedGrad.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Greška: Nije odabrano vreme polaska'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          // STRIKTNA VALIDACIJA VOZAČA
                          if (!VozacBoja.isValidDriver(_currentDriver)) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'NEPOZNAT VOZAČ! Morate biti ulogovani kao jedan od: ${VozacBoja.validDrivers.join(", ")}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // POKAZI LOADING STATE
                          setState(() {
                            _isAddingPutnik = true;
                          });

                          // 🕐 KORISTI SELEKTOVANO VREME SA HOME SCREEN-A

                          final putnik = Putnik(
                            ime: imeController.text.trim(),
                            polazak: _selectedVreme,
                            grad: _selectedGrad,
                            dan: _getDayAbbreviation(_selectedDay),
                            mesecnaKarta: mesecnaKarta,
                            vremeDodavanja: DateTime.now(),
                            dodaoVozac: _currentDriver,
                            adresa: adresaController.text.trim().isEmpty ? null : adresaController.text.trim(),
                          );

                          dlog('🔥 [HOME SCREEN] Pozivam dodajPutnika...');
                          await _putnikService.dodajPutnika(putnik);
                          // ✅ FORSIRANA REFRESH LISTE
                          await _loadPutnici();

                          if (!mounted) return;

                          setState(() {
                            _isAddingPutnik = false;
                          });
                          dlog('🔥 [HOME SCREEN] Loading state isključen');

                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            Navigator.pop(context);
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Putnik je uspešno dodat'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            _isAddingPutnik = false;
                          });

                          if (!mounted) return;

                          if (mounted) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Greška pri dodavanju: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: _isAddingPutnik
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Dodaje...'),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 4),
                          Text('Dodaj'),
                        ],
                      ),
              ),
            ),
          ],
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
          preferredSize: const Size.fromHeight(80),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
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
                        child: const Text(
                          'Rezervacije',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
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
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Učitavam...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.white,
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
        body: ShimmerWidgets.putnikListShimmer(itemCount: 8),
        // 🔧 DODAJ BOTTOM NAVIGATION BAR I U LOADING STANJU!
        bottomNavigationBar: isZimski(DateTime.now())
            ? BottomNavBarZimski(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: (grad, vreme) => 0, // Loading state - nema putnika
                onPolazakChanged: (grad, vreme) {
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
                  setState(() {
                    _selectedGrad = grad;
                    _selectedVreme = vreme;
                    _selectedGradSubject.add(grad);
                  });
                },
              ),
      );
    }

    // 🎯 KORISTI SVE PUTNICE za ispravno računanje brojača
    return StreamBuilder<List<Putnik>>(
      stream: _putnikService.streamKombinovaniPutniciFiltered(
        isoDate: _getTargetDateIsoFromSelectedDay(_selectedDay),
        // Ne prosleđujemo grad i vreme - trebaju nam SVI putnici za brojač
      ),
      initialData: const [],
      builder: (context, snapshot) {
        // 🚨 NOVO: Error handling sa specialized widgets
        if (snapshot.hasError) {
          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(95),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                ),
                child: const SafeArea(
                  child: Center(
                    child: Text(
                      'REZERVACIJE - ERROR',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            body: Center(
              child: StreamErrorWidget(
                streamName: 'home_planning_stream',
                errorMessage: snapshot.error.toString(),
                onRetry: () {
                  setState(() {
                    // Trigger rebuild
                  });
                },
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPutnici = snapshot.data ?? [];

        // Get target day abbreviation for additional filtering
        final targetDateIso = _getTargetDateIsoFromSelectedDay(_selectedDay);
        final targetDayAbbr = SlotUtils.isoDateToDayAbbr(targetDateIso);

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
        // Additional filters for display
        filtered = filtered.where((putnik) {
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

        // 🎯 BROJAČ PUTNIKA - koristi SVE putnice za SELEKTOVANI DAN
        // Brojač pokazuje ukupan broj putnika po slotovima za ceo dan
        // NEZAVISAN od trenutno selektovanog grada/vremena
        final slotCounts = SlotUtils.computeSlotCountsForDayAbbr(allPutnici, targetDayAbbr);
        final Map<String, int> brojPutnikaBC = Map<String, int>.from(slotCounts['BC'] ?? {});
        final Map<String, int> brojPutnikaVS = Map<String, int>.from(slotCounts['VS'] ?? {});

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
            dlog(
              '⚠️ [GET PUTNIK COUNT] Greška pri računanju broja putnika: $e',
            );
          }

          // Fallback: brzo prebroj ako grad nije standardan
          return allPutnici.where((putnik) {
            final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');
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
            final statusOk = (normalizedStatus != 'otkazano' &&
                normalizedStatus != 'otkazan' &&
                normalizedStatus != 'bolovanje' &&
                normalizedStatus != 'godisnji' &&
                normalizedStatus != 'godišnji' &&
                normalizedStatus != 'obrisan');
            return gradMatch && vremeMatch && danMatch && statusOk;
          }).length;
        }

        // (totalFilteredCount removed)

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(
              95,
            ), // Povećano sa 80 na 95 zbog sezonskog indikatora
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // PRVI RED - Rezervacije
                      Container(
                        height: 24,
                        alignment: Alignment.center,
                        child: const Text(
                          'R E Z E R V A C I J E',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.8,
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
                      const SizedBox(height: 4),
                      // DRUGI RED - Driver, Tema, Update i Dropdown
                      Row(
                        children: [
                          // DRIVER - levo
                          if (_currentDriver != null && _currentDriver!.isNotEmpty)
                            Expanded(
                              flex: 35,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: VozacBoja.get(_currentDriver),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: VozacBoja.get(_currentDriver).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _currentDriver!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(width: 2),

                          // TEMA - levo-sredina
                          Expanded(
                            flex: 25,
                            child: InkWell(
                              onTap: () async {
                                // Koristi globalnu funkciju za theme toggle
                                if (globalThemeToggler != null) {
                                  globalThemeToggler!();
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                child: const Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Tema',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 26,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 2),

                          // DROPDOWN - desno
                          Expanded(
                            flex: 35,
                            child: Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDay,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  dropdownColor: Theme.of(context).colorScheme.primary.withOpacity(0.95),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  isExpanded: true,
                                  selectedItemBuilder: (BuildContext context) {
                                    return _dani.map<Widget>((String value) {
                                      return Center(
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList();
                                  },
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
                                                fontSize: 14,
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
                                    setState(() => _selectedDay = value!);
                                    _loadPutnici();
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
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: putniciZaPrikaz.isEmpty
                        ? const Center(
                            child: Text('Nema putnika za ovaj polazak.'),
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
          ),
          bottomNavigationBar: isZimski(DateTime.now())
              ? BottomNavBarZimski(
                  sviPolasci: _sviPolasci,
                  selectedGrad: _selectedGrad,
                  selectedVreme: _selectedVreme,
                  getPutnikCount: getPutnikCount,
                  onPolazakChanged: (grad, vreme) {
                    // Najpre ažuriraj UI selekciju — odmah prikažemo prave brojeve
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
                    setState(() {
                      _selectedGrad = grad;
                      _selectedVreme = vreme;
                      _selectedGradSubject.add(grad);
                    });
                  },
                ),
        );
      }, // Zatvaranje StreamBuilder builder funkcije
    ); // Zatvaranje StreamBuilder widgeta
  } // Zatvaranje build metode

  @override
  void dispose() {
    _smartNotifikacijeTimer?.cancel();
    // _updateCheckTimer?.cancel(); // 🔄 Uklonjeno: Otkaži update check timer
    _selectedGradSubject.close();

    // Cleanup real-time subscriptions
    _realtimeSubscription?.cancel();

    // 🚨 NOVO: Cleanup realtime monitoring
    _networkStatusSubscription?.cancel();
    _isRealtimeHealthy.dispose();
    // Note: FailFastManager cleanup will be added later

    // CACHE UKLONJEN - nema više cache listener-a

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
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
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
                          color: shadow.color.withOpacity(
                            (shadow.color.opacity * 1.5).clamp(0.0, 1.0),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 18, // Smanjeno sa 24 na 18
            ),
            const SizedBox(height: 4), // Smanjeno sa 8 na 4
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12, // Povećano sa 11 na 12
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
