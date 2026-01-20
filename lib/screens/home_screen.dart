import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
import '../models/registrovani_putnik.dart';
import '../services/adresa_supabase_service.dart';
import '../services/auth_manager.dart';
import '../services/biometric_service.dart';
import '../services/cena_obracun_service.dart';
import '../services/firebase_service.dart';
import '../services/haptic_service.dart';
import '../services/kapacitet_service.dart'; // 🎫 Kapacitet za bottom nav bar
import '../services/local_notification_service.dart';
import '../services/popis_service.dart'; // 📊 Centralizovani popis servis
import '../services/printing_service.dart';
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/racun_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/registrovani_putnik_service.dart';
import '../services/slobodna_mesta_service.dart'; // 🎫 Provera kapaciteta
import '../services/theme_manager.dart'; // 🎨 Tema sistem
import '../services/timer_manager.dart'; // 🕐 TIMER MANAGEMENT
import '../theme.dart'; // 🎨 Import za prelepe gradijente
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju
import '../utils/page_transitions.dart';
import '../utils/putnik_count_helper.dart'; // 🔢 Za brojanje putnika po gradu
import '../utils/schedule_utils.dart';
import '../utils/text_utils.dart';
import '../utils/vozac_boja.dart'; // Dodato za centralizovane boje vozača
import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/putnik_list.dart';
import '../widgets/registracija_countdown_widget.dart';
import '../widgets/shimmer_widgets.dart';
import 'admin_screen.dart';
import 'danas_screen.dart';
import 'promena_sifre_screen.dart';
import 'vozac_screen.dart';
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

  // Key and overlay entry for custom days dropdown
  // (removed overlay support for now) - will use DropdownButton2 built-in overlay

  String? _currentDriver;

  bool _isPopisLoading = false; // 📊 Loading state za POPIS dugme

  // 👆 Biometrija
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  // Real-time subscription variables
  StreamSubscription<dynamic>? _realtimeSubscription;

  // 🚨 REALTIME MONITORING VARIABLES
  final ValueNotifier<bool> _isRealtimeHealthy = ValueNotifier(true);
  StreamSubscription<dynamic>? _networkStatusSubscription;

  final List<String> _dani = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Četvrtak',
    'Petak',
  ];

  // 🕐 DINAMIČKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> get bcVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.bcVremenaPraznici;
      case 'zimski':
        return RouteConfig.bcVremenaZimski;
      case 'letnji':
        return RouteConfig.bcVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.bcVremenaZimski : RouteConfig.bcVremenaLetnji;
    }
  }

  List<String> get vsVremena {
    final navType = navBarTypeNotifier.value;
    switch (navType) {
      case 'praznici':
        return RouteConfig.vsVremenaPraznici;
      case 'zimski':
        return RouteConfig.vsVremenaZimski;
      case 'letnji':
        return RouteConfig.vsVremenaLetnji;
      default: // 'auto'
        return isZimski(DateTime.now()) ? RouteConfig.vsVremenaZimski : RouteConfig.vsVremenaLetnji;
    }
  }

  // 📝 DINAMIČKA LISTA POLAZAKA za BottomNavBar
  List<String> get _sviPolasci {
    final bcList = bcVremena.map((v) => '$v Bela Crkva').toList();
    final vsList = vsVremena.map((v) => '$v Vršac').toList();
    return [...bcList, ...vsList];
  }

  // ✅ KORISTI UTILS FUNKCIJU ZA DROPDOWN DAN
  String _getTodayName() {
    return app_date_utils.DateUtils.getTodayFullName();
  }

  // target date calculation handled elsewhere

  // Convert selected full day name (Ponedeljak) into ISO date string for target week
  // 🎯 FIX: Uvek idi u budućnost - ako je dan prošao ove nedelje, koristi sledeću nedelju
  // Ovo je konzistentno sa Putnik._getDateForDay() koji se koristi za upis u bazu
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

    int daysToAdd = targetDayIndex - currentDayIndex;

    // 🎯 UVEK U BUDUĆNOST: Ako je dan već prošao ove nedelje, idi na sledeću nedelju
    // Ovo je konzistentno sa Putnik._getDateForDay() koji se koristi za upis u bazu
    if (daysToAdd < 0) {
      daysToAdd += 7;
    }

    final targetDate = now.add(Duration(days: daysToAdd));
    return targetDate.toIso8601String().split('T')[0];
  }

  // Konvertuj pun naziv dana u kraticu za poređenje sa bazom
  // ✅ KORISTI CENTRALNU FUNKCIJU IZ DateUtils
  String _getDayAbbreviation(String fullDayName) {
    return app_date_utils.DateUtils.getDayAbbreviation(fullDayName);
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
      // 🎫 Učitaj kapacitet cache na startu
      await KapacitetService.ensureCacheLoaded();
      // 👆 Proveri biometriju
      await _checkBiometricStatus();
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

      // 🚨 Setup realtime monitoring
      _setupRealtimeMonitoring();
      // StreamBuilder će automatski učitati data - ne treba eksplicitno _loadPutnici()
      _setupRealtimeListener();

      // CACHE UKLONJEN - koristimo direktne Supabase pozive

      // Inicijalizuj lokalne notifikacije za heads-up i zvuk
      if (mounted) {
        LocalNotificationService.initialize(context);
        RealtimeNotificationService.listenForForegroundNotifications(context);
      }

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

    if (mounted) {
      setState(() {
        // Inicijalizacija driver-a
        _currentDriver = driver;
      });
    }
  }

  /// 👆 Proveri status biometrije
  Future<void> _checkBiometricStatus() async {
    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  /// 👆 Toggle biometrija ON/OFF
  Future<void> _toggleBiometric() async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrija nije dostupna na ovom uređaju'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newValue = !_biometricEnabled;

    if (newValue) {
      // Uključuje se - zahtevaj potvrdu otiskom
      final authenticated = await BiometricService.authenticate(
        reason: 'Potvrdi identitet da omogućiš prijavu otiskom prsta',
      );

      if (!authenticated) return;
    }

    await BiometricService.setBiometricEnabled(newValue);

    if (mounted) {
      setState(() {
        _biometricEnabled = newValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue ? '✅ Prijava otiskom prsta je UKLJUČENA' : '❌ Prijava otiskom prsta je ISKLJUČENA'),
          backgroundColor: newValue ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  // 🚨 Setup realtime monitoring system
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
    } catch (e) {
      // Silently ignore timer errors
    }
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
    _realtimeSubscription?.cancel();
    // Direktan Supabase realtime umesto RealtimeHubService
    _realtimeSubscription = RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici().listen((_) {});
  }

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

  /// Prikazuje dijalog sa listom putnika kojima treba račun
  Future<void> _showRacunDialog(BuildContext ctx) async {
    // Sačuvaj reference pre await
    final scaffoldMessenger = ScaffoldMessenger.of(ctx);

    // Učitaj putnike kojima treba račun
    final putnici = await RegistrovaniPutnikService().getPutniciZaRacun();

    if (!mounted) return;

    if (putnici.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Nema putnika kojima treba račun'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Map za praćenje selektovanih putnika
    final Map<String, bool> selected = {for (var p in putnici) p.id: true};
    // Map za broj dana (default 22)
    final Map<String, int> brojDana = {for (var p in putnici) p.id: 22};
    // Map za TextEditingController-e (da se ne kreiraju ponovo pri svakom rebuild-u)
    final Map<String, TextEditingController> danaControllers = {
      for (var p in putnici) p.id: TextEditingController(text: '22')
    };

    if (!mounted) return;

    showDialog(
      context: context, // Koristi State.context nakon mounted provere
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          double ukupno = 0;
          for (var p in putnici) {
            if (selected[p.id] == true) {
              final cena = CenaObracunService.getCenaPoDanu(p);
              ukupno += cena * (brojDana[p.id] ?? 22);
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
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
                  // Header
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
                        Icon(Icons.receipt_long, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Računi za štampanje',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Lista putnika
                          ...putnici.map((p) {
                            final cena = CenaObracunService.getCenaPoDanu(p);
                            final dana = brojDana[p.id] ?? 22;
                            final iznos = cena * dana;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    // Checkbox
                                    Checkbox(
                                      value: selected[p.id],
                                      activeColor: Colors.white,
                                      checkColor: Theme.of(context).colorScheme.primary,
                                      side: BorderSide(color: Colors.white70),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          selected[p.id] = val ?? false;
                                        });
                                      },
                                    ),
                                    // Ime i detalji - fleksibilno
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.putnikIme,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  offset: const Offset(1, 1),
                                                  blurRadius: 2,
                                                  color: Colors.black.withValues(alpha: 0.5),
                                                ),
                                                Shadow(
                                                  offset: const Offset(-0.5, -0.5),
                                                  blurRadius: 1,
                                                  color: Colors.white.withValues(alpha: 0.3),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (p.firmaNaziv != null && p.firmaNaziv!.isNotEmpty)
                                            Text(
                                              p.firmaNaziv!,
                                              style: TextStyle(fontSize: 11, color: Colors.white70),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          Text(
                                            '${cena.toStringAsFixed(0)} RSD × $dana dana = ${iznos.toStringAsFixed(0)} RSD',
                                            style: TextStyle(fontSize: 11, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Dana input - fiksna širina
                                    SizedBox(
                                      width: 55,
                                      child: Column(
                                        children: [
                                          Text('Dana', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                          TextField(
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                              border:
                                                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                              enabledBorder:
                                                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                                              focusedBorder:
                                                  UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                            ),
                                            controller: danaControllers[p.id],
                                            onChanged: (val) {
                                              setDialogState(() {
                                                brojDana[p.id] = int.tryParse(val) ?? 22;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const Divider(color: Colors.white30),
                          // Ukupno
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('UKUPNO:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              Text(
                                '${ukupno.toStringAsFixed(0)} RSD',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.greenAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).glassContainer,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Otkaži', style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Štampaj sve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogContext);

                            // Pripremi podatke za štampanje
                            final List<Map<String, dynamic>> racuniPodaci = [];
                            for (var p in putnici) {
                              if (selected[p.id] == true) {
                                final cena = CenaObracunService.getCenaPoDanu(p);
                                final dana = brojDana[p.id] ?? 22;
                                racuniPodaci.add({
                                  'putnik': p,
                                  'brojDana': dana,
                                  'cenaPoDanu': cena,
                                  'ukupno': cena * dana,
                                });
                              }
                            }

                            if (racuniPodaci.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Izaberite bar jednog putnika'), backgroundColor: Colors.orange),
                              );
                              return;
                            }

                            await RacunService.stampajRacuneZaFirme(
                              racuniPodaci: racuniPodaci,
                              context: context,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Prikazuje dijalog za ručni unos računa (za nekoga ko nije registrovan)
  void _showNoviRacunDialog(BuildContext context) {
    final imeController = TextEditingController();
    final iznosController = TextEditingController();
    final opisController = TextEditingController(text: 'Usluga prevoza putnika');
    String jedinicaMere = 'usluga';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.orange),
                SizedBox(width: 8),
                Text('Novi račun'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: imeController,
                      decoration: const InputDecoration(
                        labelText: 'Ime i prezime kupca *',
                        hintText: 'npr. Marko Marković',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: opisController,
                      decoration: const InputDecoration(
                        labelText: 'Opis usluge *',
                        hintText: 'npr. Prevoz Beograd-Vršac',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: jedinicaMere,
                      decoration: const InputDecoration(
                        labelText: 'Jedinica mere',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'usluga', child: Text('usluga')),
                        DropdownMenuItem(value: 'dan', child: Text('dan')),
                        DropdownMenuItem(value: 'kom', child: Text('kom')),
                        DropdownMenuItem(value: 'sat', child: Text('sat')),
                        DropdownMenuItem(value: 'km', child: Text('km')),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          jedinicaMere = val ?? 'usluga';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: iznosController,
                      decoration: const InputDecoration(
                        labelText: 'Iznos (RSD) *',
                        hintText: 'npr. 5000',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '* Obavezna polja',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Otkaži'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Štampaj'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () async {
                  // Validacija
                  if (imeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unesite ime kupca'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (opisController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unesite opis usluge'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  final iznos = double.tryParse(iznosController.text.trim());
                  if (iznos == null || iznos <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unesite validan iznos'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  // Sačuvaj podatke pre zatvaranja dijaloga
                  final imePrezime = imeController.text.trim();
                  final opis = opisController.text.trim();
                  final jm = jedinicaMere;
                  final ctx = context;

                  Navigator.pop(dialogContext);

                  // Dohvati sledeći broj računa
                  final brojRacuna = await RacunService.getTrenutniBrojRacuna();

                  // Proveri mounted pre korišćenja context-a
                  if (!ctx.mounted) return;

                  // Štampaj račun
                  await RacunService.stampajRacun(
                    brojRacuna: brojRacuna,
                    imePrezimeKupca: imePrezime,
                    adresaKupca: '', // Fizičko lice bez adrese
                    opisUsluge: opis,
                    cena: iznos,
                    kolicina: 1,
                    jedinicaMere: jm,
                    datumPrometa: DateTime.now(),
                    context: ctx,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    // Prikaži confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(dialogContext).colorScheme.dangerPrimary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        title: Column(
          children: [
            Icon(
              Icons.logout,
              color: Theme.of(dialogContext).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Da li ste sigurni da se želite odjaviti?',
          style: TextStyle(
            color: Theme.of(dialogContext).colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Otkaži',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          HapticElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            hapticType: HapticType.medium,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await AuthManager.logout(context);
    }
  }

  // 📊 POPIS DANA - KORISTI CENTRALIZOVANI POPIS SERVICE
  Future<void> _showPopisDana() async {
    if (_currentDriver == null || _currentDriver!.isEmpty || !VozacBoja.isValidDriver(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovlašćeni da biste koristili Popis.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final vozac = _currentDriver!;

    // Pokreni loading indikator
    if (mounted) setState(() => _isPopisLoading = true);

    try {
      // 1. UČITAJ PODATKE PREKO POPIS SERVICE
      final popisData = await PopisService.loadPopisData(
        vozac: vozac,
        selectedGrad: _selectedGrad,
        selectedVreme: _selectedVreme,
      );

      // 2. PRIKAŽI DIALOG
      if (!mounted) return;
      final bool sacuvaj = await PopisService.showPopisDialog(context, popisData);

      // 3. SAČUVAJ AKO JE POTVRĐEN
      if (sacuvaj) {
        await PopisService.savePopis(popisData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Popis je uspešno sačuvan!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Greška pri učitavanju popisa: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPopisLoading = false);
    }
  }

  void _showAddPutnikDialog() async {
    final adresaController = TextEditingController();
    final telefonController = TextEditingController(); // 📞 OPCIONO: Broj telefona
    final searchPutnikController = TextEditingController(); // 🔍 Za pretragu putnika
    RegistrovaniPutnik? selectedPutnik; // 🎯 Izabrani putnik iz liste
    int brojMesta = 1; // 🆕 Broj rezervisanih mesta (default 1)
    bool promeniAdresuSamoDanas = false; // 🆕 Opcija za promenu adrese samo za danas
    String? samoDanasAdresa; // 🆕 Adresa samo za danas
    String? samoDanasAdresaId; // 🆕 ID adrese samo za danas (za brži geocoding)
    List<Map<String, String>> dostupneAdrese = []; // 🆕 Lista adresa za dropdown

    // Povuci SVE registrovane putnike iz registrovani_putnici tabele (učenici, radnici, dnevni)
    final serviceInstance = RegistrovaniPutnikService();
    final lista = await serviceInstance.getAllRegistrovaniPutnici();
    // 📋 Filtrirana lista aktivnih putnika za brzu pretragu
    final aktivniPutnici = lista.where((RegistrovaniPutnik putnik) => !putnik.obrisan && putnik.aktivan).toList()
      ..sort((a, b) => a.putnikIme.toLowerCase().compareTo(b.putnikIme.toLowerCase()));

    // 🆕 Učitaj adrese za selektovani grad
    final adreseZaGrad = await AdresaSupabaseService.getAdreseZaGrad(_selectedGrad);
    dostupneAdrese = adreseZaGrad.map((a) => {'id': a.id, 'naziv': a.naziv}).toList()
      ..sort((a, b) => (a['naziv'] ?? '').compareTo(b['naziv'] ?? ''));

    if (!mounted) return;

    bool isDialogLoading = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // 📱 Dinamički računaj dostupnu visinu (oduzmi tastaturу)
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final screenHeight = MediaQuery.of(context).size.height;
          final availableHeight = screenHeight - keyboardHeight;

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 24,
              bottom: keyboardHeight > 0 ? 8 : 24, // Manje padding kad je tastatura
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: keyboardHeight > 0
                    ? availableHeight * 0.85 // Više prostora kad je tastatura
                    : screenHeight * 0.7,
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

                                // 🎯 DROPDOWN ZA IZBOR PUTNIKA IZ LISTE
                                DropdownButtonFormField2<RegistrovaniPutnik>(
                                  isExpanded: true,
                                  value: selectedPutnik,
                                  decoration: InputDecoration(
                                    labelText: 'Izaberi putnika',
                                    hintText: 'Pretraži i izaberi...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_search,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    fillColor: Colors.white,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    maxHeight: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                    ),
                                  ),
                                  dropdownSearchData: DropdownSearchData(
                                    searchController: searchPutnikController,
                                    searchInnerWidgetHeight: 50,
                                    searchInnerWidget: Container(
                                      height: 50,
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        bottom: 4,
                                        right: 8,
                                        left: 8,
                                      ),
                                      child: TextFormField(
                                        controller: searchPutnikController,
                                        expands: true,
                                        maxLines: null,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          hintText: 'Pretraži po imenu...',
                                          hintStyle: const TextStyle(fontSize: 14),
                                          prefixIcon: const Icon(Icons.search, size: 20),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    searchMatchFn: (item, searchValue) {
                                      final putnik = item.value;
                                      if (putnik == null) return false;
                                      return putnik.putnikIme.toLowerCase().contains(searchValue.toLowerCase());
                                    },
                                  ),
                                  items: aktivniPutnici
                                      .map(
                                        (RegistrovaniPutnik putnik) => DropdownMenuItem<RegistrovaniPutnik>(
                                          value: putnik,
                                          child: Row(
                                            children: [
                                              // Ikonica tipa putnika
                                              Icon(
                                                putnik.tip == 'radnik'
                                                    ? Icons.engineering
                                                    : putnik.tip == 'dnevni'
                                                        ? Icons.today
                                                        : Icons.school,
                                                size: 18,
                                                color: putnik.tip == 'radnik'
                                                    ? Colors.blue.shade600
                                                    : putnik.tip == 'dnevni'
                                                        ? Colors.orange.shade600
                                                        : Colors.green.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  putnik.putnikIme,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (RegistrovaniPutnik? putnik) async {
                                    setStateDialog(() {
                                      selectedPutnik = putnik;
                                      telefonController.text = putnik?.brojTelefona ?? '';
                                      adresaController.text = 'Učitavanje...';
                                    });
                                    if (putnik != null) {
                                      // 🔄 AUTO-POPUNI adresu async - SAMO za selektovani grad
                                      final adresa = await putnik.getAdresaZaSelektovaniGrad(_selectedGrad);
                                      setStateDialog(() {
                                        adresaController.text = adresa == 'Nema adresa' ? '' : adresa;
                                        // Reset "samo danas" opcije kad se promeni putnik
                                        promeniAdresuSamoDanas = false;
                                        samoDanasAdresa = null;
                                        samoDanasAdresaId = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // ADRESA FIELD (readonly - popunjava se automatski)
                                TextField(
                                  controller: adresaController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: promeniAdresuSamoDanas ? 'Stalna adresa' : 'Adresa',
                                    hintText: 'Automatski se popunjava...',
                                    prefixIcon: const Icon(Icons.location_on),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                  ),
                                ),

                                // 🆕 OPCIJA ZA PROMENU ADRESE SAMO ZA DANAS
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    setStateDialog(() {
                                      promeniAdresuSamoDanas = !promeniAdresuSamoDanas;
                                      if (!promeniAdresuSamoDanas) {
                                        samoDanasAdresa = null;
                                        samoDanasAdresaId = null;
                                      }
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: promeniAdresuSamoDanas,
                                        onChanged: (value) {
                                          setStateDialog(() {
                                            promeniAdresuSamoDanas = value ?? false;
                                            if (!promeniAdresuSamoDanas) {
                                              samoDanasAdresa = null;
                                              samoDanasAdresaId = null;
                                            }
                                          });
                                        },
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        side: const BorderSide(color: Colors.white, width: 2),
                                        checkColor: Colors.white,
                                        activeColor: Colors.orange,
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'Promeni adresu samo za danas',
                                          style: TextStyle(fontSize: 14, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🆕 DROPDOWN ZA IZBOR ADRESE SAMO ZA DANAS
                                if (promeniAdresuSamoDanas) ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    // ignore: deprecated_member_use
                                    value: samoDanasAdresaId,
                                    isExpanded: true, // ✅ Sprečava overflow
                                    decoration: InputDecoration(
                                      labelText: 'Adresa samo za danas',
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                      prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.orange),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.orange),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.orange.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    dropdownColor: Colors.white, // Bela pozadina dropdown-a
                                    style: const TextStyle(color: Colors.black), // Crni tekst
                                    items: dostupneAdrese.map((adresa) {
                                      return DropdownMenuItem<String>(
                                        value: adresa['id'], // Čuvamo ID kao value
                                        child: Text(
                                          adresa['naziv'] ?? '',
                                          overflow: TextOverflow.ellipsis, // ✅ Skraćuje dugačak tekst
                                          style: const TextStyle(color: Colors.black),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        samoDanasAdresaId = value;
                                        // Nađi naziv po ID-u
                                        samoDanasAdresa = dostupneAdrese.firstWhere((a) => a['id'] == value,
                                            orElse: () => {})['naziv'];
                                      });
                                    },
                                    hint: Text(
                                      'Izaberi adresu',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // 📞 TELEFON FIELD (readonly - popunjava se automatski)
                                TextField(
                                  controller: telefonController,
                                  readOnly: true,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Telefon',
                                    hintText: 'Automatski se popunjava...',
                                    prefixIcon: const Icon(Icons.phone),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // 🆕 BROJ MESTA - dropdown za izbor broja rezervisanih mesta
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_seat, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Broj mesta:',
                                          style: const TextStyle(fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<int>(
                                        value: brojMesta,
                                        underline: const SizedBox(),
                                        isDense: true,
                                        items: [1, 2, 3, 4, 5].map((int value) {
                                          return DropdownMenuItem<int>(
                                            value: value,
                                            child: Text(
                                              value == 1 ? '1 mesto' : '$value mesta',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (int? newValue) {
                                          if (newValue != null) {
                                            setStateDialog(() {
                                              brojMesta = newValue;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // 🏷️ PRIKAZ TIPA PUTNIKA (ako je izabran)
                                if (selectedPutnik != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: selectedPutnik!.tip == 'radnik'
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : selectedPutnik!.tip == 'dnevni'
                                              ? Colors.orange.withValues(alpha: 0.15)
                                              : Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: selectedPutnik!.tip == 'radnik'
                                            ? Colors.blue.withValues(alpha: 0.4)
                                            : selectedPutnik!.tip == 'dnevni'
                                                ? Colors.orange.withValues(alpha: 0.4)
                                                : Colors.green.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selectedPutnik!.tip == 'radnik'
                                              ? Icons.engineering
                                              : selectedPutnik!.tip == 'dnevni'
                                                  ? Icons.today
                                                  : Icons.school,
                                          size: 20,
                                          color: selectedPutnik!.tip == 'radnik'
                                              ? Colors.blue.shade700
                                              : selectedPutnik!.tip == 'dnevni'
                                                  ? Colors.orange.shade700
                                                  : Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Tip: ${selectedPutnik!.tip.toUpperCase()}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: selectedPutnik!.tip == 'radnik'
                                                ? Colors.blue.shade700
                                                : selectedPutnik!.tip == 'dnevni'
                                                    ? Colors.orange.shade700
                                                    : Colors.green.shade700,
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
                                      // Validacija - mora biti odabran putnik
                                      if (selectedPutnik == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('❌ Morate odabrati putnika iz liste'),
                                            backgroundColor: Colors.red,
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
                                        // STRIKTNA VALIDACIJA VOZAČA - PROVERI NULL, EMPTY I VALID DRIVER
                                        if (_currentDriver == null ||
                                            _currentDriver!.isEmpty ||
                                            !VozacBoja.isValidDriver(_currentDriver)) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '❌ GREŠKA: Vozač "$_currentDriver" nije registrovan. Molimo ponovo se ulogujte.',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // ✅ Validacija vozača koristi VozacBoja.isValidDriver()

                                        // 🎫 PROVERA KAPACITETA - da li ima slobodnih mesta
                                        // ⚠️ SAMO ZA PUTNIKE - vozači mogu dodavati bez ograničenja
                                        final isVozac = VozacBoja.isValidDriver(_currentDriver);
                                        if (!isVozac) {
                                          final gradKey = _selectedGrad.toLowerCase().contains('bela') ? 'BC' : 'VS';
                                          final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta(
                                            gradKey,
                                            _selectedVreme,
                                          );
                                          if (!imaMesta) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '❌ Termin $_selectedVreme ($_selectedGrad) je PUN! Izaberite drugo vreme.',
                                                ),
                                                backgroundColor: Colors.red,
                                                duration: const Duration(seconds: 3),
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        // POKAZI LOADING STATE - lokalno za dijalog
                                        setStateDialog(() {
                                          isDialogLoading = true;
                                        });

                                        // 🕐 KORISTI SELEKTOVANO VREME SA HOME SCREEN-A
                                        // ✅ SADA: Mesečna karta = true za SVE tipove (radnik, ucenik, dnevni)
                                        // Svi tipovi koriste istu logiku i registrovani_putnici tabelu
                                        const isMesecnaKarta = true;

                                        // 🆕 Koristi "samo danas" adresu ako je postavljena, inače stalnu
                                        final adresaZaKoristiti = promeniAdresuSamoDanas && samoDanasAdresa != null
                                            ? samoDanasAdresa
                                            : (adresaController.text.isEmpty ? null : adresaController.text);
                                        // 🆕 Koristi "samo danas" adresaId ako je postavljen
                                        final adresaIdZaKoristiti = promeniAdresuSamoDanas && samoDanasAdresaId != null
                                            ? samoDanasAdresaId
                                            : null; // Stalna adresa ima adresaId u registrovani_putnici

                                        final putnik = Putnik(
                                          ime: selectedPutnik!.putnikIme,
                                          polazak: _selectedVreme,
                                          grad: _selectedGrad,
                                          dan: _getDayAbbreviation(_selectedDay),
                                          mesecnaKarta: isMesecnaKarta,
                                          vremeDodavanja: DateTime.now(),
                                          dodeljenVozac: _currentDriver!, // Safe non-null assertion nakon validacije
                                          adresa: adresaZaKoristiti,
                                          adresaId: adresaIdZaKoristiti, // 🆕 Za brži geocoding
                                          brojTelefona: selectedPutnik!.brojTelefona,
                                          brojMesta: brojMesta, // 🆕 Prosleđujemo broj rezervisanih mesta
                                        );

                                        // Duplikat provera se vrši u PutnikService.dodajPutnika()
                                        await _putnikService.dodajPutnika(putnik);

                                        // Supabase realtime automatski triggeruje refresh

                                        if (!context.mounted) return;

                                        // Ukloni loading state
                                        setStateDialog(() {
                                          isDialogLoading = false;
                                        });

                                        Navigator.pop(context);

                                        // 🔄 FIX: Forsiraj setState da se UI osveži
                                        if (mounted) {
                                          setState(() {});
                                        }

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✅ Putnik je uspešno dodat',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      } catch (e) {
                                        // ensure dialog loading is cleared
                                        setStateDialog(() {
                                          isDialogLoading = false;
                                        });

                                        if (!context.mounted) return;

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '❌ Greška pri dodavanju: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
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
                                          Icons.person_add,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PROVERAVAJ LOADING STANJE ODMAH
    if (_isLoading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
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
          bottomNavigationBar: ValueListenableBuilder<String>(
            valueListenable: navBarTypeNotifier,
            builder: (context, navType, _) {
              return _buildBottomNavBar(navType, (grad, vreme) => 0);
            },
          ),
        ),
      );
    }

    // 🔄 SUPABASE REALTIME STREAM: streamKombinovaniPutnici()
    // Auto-refresh kada se promeni status putnika (pokupljen/naplaćen/otkazan)
    // Use a parametric stream filtered to the currently selected day
    // so monthly passengers (registrovani_putnici) are created for that day
    // and will appear in the list/counts for arbitrary selected day.
    // ✅ FIX: Ne prosleđujemo vreme da bismo dobili SVE putnike za dan (za bottom nav bar brojače)
    // Filtriranje po gradu/vremenu se radi client-side za prikaz liste
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: StreamBuilder<List<Putnik>>(
        stream: _putnikService.streamKombinovaniPutniciFiltered(
          isoDate: _getTargetDateIsoFromSelectedDay(_selectedDay),
          // grad i vreme NAMERNO IZOSTAVLJENI - treba nam SVA vremena za bottom nav bar
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
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

            return dayMatch;
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
          // DEDUPLICIRAJ za računanje brojača (id + polazak + dan)
          final Map<String, Putnik> uniqueForCounts = {};
          for (final p in putniciZaDan) {
            final key = '${p.id}_${p.polazak}_${p.dan}';
            uniqueForCounts[key] = p;
          }
          final countCandidates = uniqueForCounts.values.toList();

          // 🔧 REFAKTORISANO: Koristi PutnikCountHelper za centralizovano brojanje
          final countHelper = PutnikCountHelper.fromPutnici(
            putnici: countCandidates,
            targetDateIso: targetDateIso,
            targetDayAbbr: targetDayAbbr,
          );

          // 🔄 UKLONJEN DUPLI SORT - PutnikList sada sortira konzistentno sa DanasScreen i VozacScreen
          // Sortiranje se vrši u PutnikList widgetu sa istom logikom za sva tri ekrana
          final putniciZaPrikaz = sviPutniciBezDuplikata;

          // Funkcija za brojanje putnika po gradu, vremenu i danu (samo aktivni)
          int getPutnikCount(String grad, String vreme) {
            try {
              return countHelper.getCount(grad, vreme);
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
                          // PRVI RED - Tablica levo, Rezervacije sredina, Dana desno
                          Row(
                            // increase height slightly and reduce font so it never drifts under the control row below
                            children: [
                              // LEVO - Tablica vozila (ako ističe registracija)
                              const RegistracijaTablicaWidget(),
                              const SizedBox(width: 8),
                              // SREDINA - "R E Z E R V A C I J E"
                              Expanded(
                                child: Container(
                                  height: 28,
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
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
                                ),
                              ),
                              const SizedBox(width: 8),
                              // DESNO - Brojač dana do isteka registracije
                              const RegistracijaBrojacWidget(),
                            ],
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
                                        if (mounted) {
                                          setState(() => _selectedDay = value!);
                                        }
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
                        if (_currentDriver == 'Bojan' || _currentDriver == 'Svetlana')
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
                        if (_currentDriver == 'Bruda' || _currentDriver == 'Bilevski') const SizedBox(width: 4),
                        if (_currentDriver == 'Bruda' || _currentDriver == 'Bilevski')
                          Expanded(
                            child: _HomeScreenButton(
                              label: 'Ja',
                              icon: Icons.person,
                              onTap: () {
                                // Navigate to VozacScreen sa trenutnim vozačem
                                AnimatedNavigation.pushSmooth(
                                  context,
                                  VozacScreen(previewAsDriver: _currentDriver),
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
                          child: PopupMenuButton<String>(
                            tooltip: 'Štampaj',
                            offset: const Offset(0, -150),
                            onSelected: (value) async {
                              if (value == 'spisak') {
                                await PrintingService.printPutniksList(
                                  _selectedDay,
                                  _selectedVreme,
                                  _selectedGrad,
                                  context,
                                );
                              } else if (value == 'racun_postojeci') {
                                _showRacunDialog(context);
                              } else if (value == 'racun_novi') {
                                _showNoviRacunDialog(context);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'spisak',
                                child: Row(
                                  children: [
                                    Icon(Icons.list_alt, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Štampaj spisak'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'racun_postojeci',
                                child: Row(
                                  children: [
                                    Icon(Icons.people, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Račun - postojeći'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'racun_novi',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Račun - novi'),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).glassContainer,
                                border: Border.all(
                                  color: Theme.of(context).glassBorder,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.print,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 16,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Štampaj',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          shadows: [
                                            Shadow(blurRadius: 8, color: Colors.black87),
                                            Shadow(offset: Offset(1, 1), blurRadius: 4, color: Colors.black54),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'logout') {
                                _logout();
                              } else if (value == 'sifra') {
                                final vozac = await AuthManager.getCurrentDriver();
                                if (!mounted || vozac == null) return;
                                Navigator.push(
                                  this.context,
                                  MaterialPageRoute(
                                    builder: (ctx) => PromenaSifreScreen(vozacIme: vozac),
                                  ),
                                );
                              } else if (value == 'popis') {
                                _showPopisDana();
                              } else if (value == 'biometric') {
                                _toggleBiometric();
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'popis',
                                enabled: !_isPopisLoading,
                                child: Row(
                                  children: [
                                    _isPopisLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.list_alt, color: Colors.teal),
                                    const SizedBox(width: 8),
                                    const Text('Popis'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'sifra',
                                child: Row(
                                  children: [
                                    Icon(Icons.lock, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text('Promeni šifru'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Logout'),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).glassContainer,
                                border: Border.all(
                                  color: Theme.of(context).glassBorder,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 16,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Opcije',
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista putnika
                  Expanded(
                    child: putniciZaPrikaz.isEmpty
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).glassContainer,
                                border: Border.all(
                                  color: Theme.of(context).glassBorder,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  Theme.of(context).glassShadow,
                                ],
                              ),
                              child: const Text(
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
                            ),
                          )
                        : PutnikList(
                            putnici: putniciZaPrikaz,
                            currentDriver: _currentDriver!,
                            selectedGrad: _selectedGrad, // 📍 NOVO: za GPS navigaciju mesečnih putnika
                            selectedVreme: _selectedVreme, // 📍 NOVO: za GPS navigaciju
                            onPutnikStatusChanged: () {
                              // 🔄 Forsiraj rebuild kad se promeni status putnika
                              if (mounted) setState(() {});
                            },
                            bcVremena: const [
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
                              '18:00',
                            ],
                            vsVremena: const [
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
                              '19:00',
                            ],
                          ),
                  ),
                ],
              ), // Zatvaranje Column
              bottomNavigationBar: ValueListenableBuilder<String>(
                valueListenable: navBarTypeNotifier,
                builder: (context, navType, _) {
                  return _buildBottomNavBar(navType, getPutnikCount);
                },
              ),
            ), // Zatvaranje Container wrapper-a
          );
        }, // Zatvaranje StreamBuilder builder funkcije
      ), // Zatvaranje StreamBuilder widgeta
    ); // Zatvaranje AnnotatedRegion
  } // Zatvaranje build metode

  /// Helper metoda za kreiranje bottom nav bar-a prema tipu
  Widget _buildBottomNavBar(String navType, int Function(String, String) getPutnikCount) {
    void onChanged(String grad, String vreme) {
      if (mounted) {
        setState(() {
          _selectedGrad = grad;
          _selectedVreme = vreme;
        });
      }
    }

    switch (navType) {
      case 'praznici':
        return BottomNavBarPraznici(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: onChanged,
          selectedDan: _selectedDay,
        );
      case 'zimski':
        return BottomNavBarZimski(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: onChanged,
          selectedDan: _selectedDay,
        );
      case 'letnji':
        return BottomNavBarLetnji(
          sviPolasci: _sviPolasci,
          selectedGrad: _selectedGrad,
          selectedVreme: _selectedVreme,
          getPutnikCount: getPutnikCount,
          getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
          onPolazakChanged: onChanged,
          selectedDan: _selectedDay,
        );
      default: // 'auto'
        return isZimski(DateTime.now())
            ? BottomNavBarZimski(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: getPutnikCount,
                getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                onPolazakChanged: onChanged,
                selectedDan: _selectedDay,
              )
            : BottomNavBarLetnji(
                sviPolasci: _sviPolasci,
                selectedGrad: _selectedGrad,
                selectedVreme: _selectedVreme,
                getPutnikCount: getPutnikCount,
                getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                onPolazakChanged: onChanged,
                selectedDan: _selectedDay,
              );
    }
  }

  @override
  void dispose() {
    // 🕐 KORISTI TIMER MANAGER za cleanup - SPREČAVA MEMORY LEAK
    TimerManager.cancelTimer('home_screen_realtime_health');

    // 🧹 CLEANUP REAL-TIME SUBSCRIPTIONS
    try {
      _realtimeSubscription?.cancel();
      _networkStatusSubscription?.cancel();
    } catch (e) {
      // Silently ignore
    }

    // No overlay cleanup needed currently

    // 🧹 SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
      }
    } catch (e) {
      // Silently ignore
    }
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
