import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/firebase_service.dart';
import '../utils/vozac_boja.dart'; // Dodato za centralizovane boje vozača

import '../widgets/bottom_nav_bar_letnji.dart';
import '../widgets/putnik_card.dart';
import '../utils/page_transitions.dart';

import 'danas_screen.dart';
import 'admin_screen.dart';
import 'welcome_screen.dart';

import '../services/local_notification_service.dart';
import '../main.dart' show globalThemeToggler; // Za theme toggle
import '../services/printing_service.dart';
import '../widgets/autocomplete_ime_field.dart';
import '../widgets/autocomplete_adresa_field.dart';
import '../widgets/shimmer_widgets.dart';
import '../services/haptic_service.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju
import '../utils/animation_utils.dart';
import '../utils/text_utils.dart';
import '../services/update_service.dart'; // 🔄 Update sistem aktiviran!

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PutnikService _putnikService = PutnikService();
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isAddingPutnik = false; // DODANO za loading state kad se dodaje putnik
  String _selectedDay =
      'Ponedeljak'; // Biće postavljeno na današnji dan u initState
  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';

  // Stream kontroleri za reaktivno ažuriranje
  final StreamController<String> _selectedGradSubject =
      StreamController<String>.broadcast();

  String? _currentDriver;

  // CACHE UKLONJEN - nepotrebne varijable uklonjene
  Timer? _smartNotifikacijeTimer;
  List<Putnik> _allPutnici = [];

  // Real-time subscription variables
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _mesecniSubscription;

  final List<String> _dani = [
    'Ponedeljak',
    'Utorak',
    'Sreda',
    'Četvrtak',
    'Petak',
    'Subota',
    'Nedelja'
  ];

// Kompletna lista polazaka za BottomNavBar (bez "Svi polasci") - LETNJI RASPORED
  final List<String> _sviPolasci = [
    '5:00 Bela Crkva',
    '6:00 Bela Crkva',
    '8:00 Bela Crkva',
    '10:00 Bela Crkva',
    '12:00 Bela Crkva',
    '13:00 Bela Crkva',
    '14:00 Bela Crkva',
    '15:30 Bela Crkva',
    '18:00 Bela Crkva',
    '6:00 Vršac',
    '7:00 Vršac',
    '9:00 Vršac',
    '11:00 Vršac',
    '13:00 Vršac',
    '14:00 Vršac',
    '15:30 Vršac',
    '16:15 Vršac',
    '19:00 Vršac'
  ];

  // Mapiranje punih naziva na kratke nazive u bazi
  String _getTodayName() {
    final now = DateTime.now();
    final dayNames = [
      'Ponedeljak',
      'Utorak',
      'Sreda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedelja'
    ];
    final todayName = dayNames[now.weekday - 1];

    // ✅ PAMETNA LOGIKA - vikendom prebaci na Ponedeljak jer ne vozite
    if (todayName == 'Subota' || todayName == 'Nedelja') {
      debugPrint('🔄 [HOME SCREEN] Vikend je - prebacujem na Ponedeljak');
      return 'Ponedeljak';
    }

    return todayName;
  }

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
    _loadPutnici();
    _setupRealtimeListener();
    _startSmartNotifikacije();

    // CACHE UKLONJEN - koristimo direktne Supabase pozive

    // Inicijalizuj lokalne notifikacije za heads-up i zvuk
    LocalNotificationService.initialize(context);
    RealtimeNotificationService.listenForForegroundNotifications(context);

    // 🔄 Automatska provera update-a - AKTIVNA!
    Timer(Duration(seconds: 5), () {
      if (mounted) {
        UpdateChecker.checkAndShowUpdate(context);
      }
    });

    // Inicijalizuj realtime notifikacije za aktivnog vozača
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        // First request notification permissions
        RealtimeNotificationService.requestNotificationPermissions()
            .then((hasPermissions) {
          print(
              '🔔 HomeScreen notification permissions result: $hasPermissions');

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
    setState(() {
      // Osiguraj da _currentDriver uvek ima validnu vrednost
      _currentDriver = driver; // Ne postavljaj fallback 'Nepoznat'
    });

    // Debug log za praćenje driver initialization
    debugPrint('🔍 DEBUG: Current driver initialized: $_currentDriver');
  }

  Future<void> _initializeRealtimeService() async {
    try {
      // Inicijalizuj optimized realtime service
      // OptimizedSupabaseRealtimeService je uklonjen - placeholder
      // await OptimizedSupabaseRealtimeService.initialize();
    } catch (e) {
      // Ignoriši grešku ako realtime ne može da se pokrene
    }
  }

  void _setupRealtimeListener() {
    // Slušaj promene u putovanja_istorija tabeli za real-time ažuriranja
    _realtimeSubscription = supabase
        .from('putovanja_istorija')
        .stream(primaryKey: ['id']).listen((data) {
      debugPrint('🔄 Real-time update detected in putovanja_istorija');
      // Stream će automatski ažurirati StreamBuilder u build() metodi
    });

    // Slušaj promene u mesecni_putnici tabeli
    _mesecniSubscription = supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id']).listen((data) {
      debugPrint('🔄 Real-time update detected in mesecni_putnici');
      // Stream će automatski ažurirati StreamBuilder u build() metodi
    });
  }

  void _startSmartNotifikacije() {
    // Pokreni smart notifikacije svakih 15 minuta
    _smartNotifikacijeTimer?.cancel();
    _smartNotifikacijeTimer =
        Timer.periodic(const Duration(minutes: 15), (timer) async {
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
      // 🆕 NOVI NAČIN: Koristi PutnikService za učitavanje iz obe tabele
      return await _putnikService.getAllPutniciFromBothTables();
    } catch (e) {
      debugPrint('🔥 Greška pri učitavanju putnika: $e');
      return [];
    }
  }

  Future<void> _loadPutnici() async {
    setState(() => _isLoading = true);
    try {
      final putnici = await _getAllPutnici();
      setState(() {
        _allPutnici = putnici;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Greška pri učitavanju: $e');
    }
  }

  // _getPutnikCount je uklonjen jer nije korišćen

  void _showErrorDialog(String message) {
    showDialog(
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

  // GitHub Actions automation has replaced manual updates
  Future<void> _showAutomationInfo() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Automatska Ažuriranja'),
        content: const Text(
          'Aplikacija se sada automatski ažurira preko:\n\n'
          '📱 Android: GitHub Actions sa email delivery\n\n'
          'Nema potrebe za manuelne update-ove! 😊',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Razumem'),
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
            color: Colors.red.withOpacity(0.5),
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
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  void _showAddPutnikDialog() async {
    final imeController = TextEditingController();
    final adresaController = TextEditingController();
    bool mesecnaKarta = false;
    bool manuelnoOznaceno = false; // 🔧 NOVO: prati da li je manuelno označeno

    // Povuci dozvoljena imena iz mesecni_putnici tabele
    final lista = await MesecniPutnikService.getAllMesecniPutnici();
    final dozvoljenaImena = lista
        .where((putnik) => !putnik.obrisan && putnik.aktivan)
        .map((putnik) => putnik.putnikIme)
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Dodaj Putnika'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prikaz aktivnog vremena i grada
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Dodaje se za: $_selectedVreme - $_selectedGrad ($_selectedDay)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    )),
                const SizedBox(height: 16),
                AutocompleteImeField(
                  controller: imeController,
                  mesecnaKarta: mesecnaKarta,
                  dozvoljenaImena: dozvoljenaImena,
                  onChanged: (ime) {
                    // Automatski označi mesečnu kartu ako je pronađen mesečni putnik
                    final isMesecniPutnik =
                        dozvoljenaImena.contains(ime.trim());
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
                // Novo AutocompleteAdresaField - filtrira po gradu!
                AutocompleteAdresaField(
                  controller: adresaController,
                  grad: _selectedGrad,
                  labelText: 'Adresa (opciono)',
                  hintText: 'Npr: Glavna 15, Zmaj Jovina 22...',
                ),
                // Dodatno obaveštenje
                if (adresaController.text.trim().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.route, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✅ Adresa će biti korišćena za optimizaciju Google Maps rute!',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (mesecnaKarta)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.green[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Prikazuju se samo dozvoljena imena za mesečnu kartu',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mesečna karta'),
                  subtitle: const Text('Označite ako putnik ima mesečnu kartu'),
                  value: mesecnaKarta,
                  onChanged: (value) {
                    setStateDialog(() {
                      mesecnaKarta = value ?? false;
                      manuelnoOznaceno =
                          true; // 🔧 Označi da je manuelno podešeno
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            HapticElevatedButton(
              hapticType: HapticType.success,
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
                                '❌ Grad "$_selectedGrad" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // 🏘️ VALIDACIJA ADRESE
                      final adresa = adresaController.text.trim();
                      if (adresa.isNotEmpty &&
                          !GradAdresaValidator.validateAdresaForCity(
                              adresa, _selectedGrad)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '❌ Adresa "$adresa" nije validna za grad "$_selectedGrad". Dozvoljene su samo adrese iz Bele Crkve i Vršca.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Validacija za mesečnu kartu
                      if (mesecnaKarta &&
                          !dozvoljenaImena
                              .contains(imeController.text.trim())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('❌ Ime nije dozvoljeno za mesečnu kartu'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (_selectedVreme.isEmpty || _selectedGrad.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('❌ Greška: Nije odabrano vreme polaska'),
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
                                  'NEPOZNAT VOZAČ! Morate biti ulogovani kao jedan od: ${VozacBoja.validDrivers.join(", ")}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // POKAZI LOADING STATE
                        setState(() {
                          _isAddingPutnik = true;
                        });

                        debugPrint(
                            '🔥 [HOME SCREEN] Kreiram putnik objekat...');
                        final putnik = Putnik(
                          ime: imeController.text.trim(),
                          polazak: _selectedVreme,
                          grad: _selectedGrad,
                          dan: _getDayAbbreviation(_selectedDay),
                          mesecnaKarta: mesecnaKarta,
                          vremeDodavanja: DateTime.now(),
                          dodaoVozac: _currentDriver,
                          adresa: adresaController.text.trim().isEmpty
                              ? null
                              : adresaController.text.trim(),
                        );

                        debugPrint('🔥 [HOME SCREEN] Pozivam dodajPutnika...');
                        await _putnikService.dodajPutnika(putnik);
                        debugPrint(
                            '🔥 [HOME SCREEN] dodajPutnika završen, refreshujem listu...');

                        debugPrint(
                            '🔥 [HOME SCREEN] dodajPutnika završen, refreshujem listu...');

                        // ✅ FORSIRANA REFRESH LISTE
                        await _loadPutnici();
                        debugPrint(
                            '🔥 [HOME SCREEN] Lista putnika refreshovana');

                        if (!mounted) return;

                        setState(() {
                          _isAddingPutnik = false;
                        });
                        debugPrint('🔥 [HOME SCREEN] Loading state isključen');

                        if (mounted) {
                          debugPrint('🔥 [HOME SCREEN] Zatvarám dialog...');
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
                          debugPrint(
                              '🔥 [HOME SCREEN] SUCCESS snackbar prikazan');
                        }
                      } catch (e) {
                        debugPrint(
                            '💥 [HOME SCREEN] GREŠKA pri dodavanju putnika: $e');
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
                  : const Text('Dodaj'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            horizontal: 12, vertical: 6),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
      );
    }

    // ✅ KORISTI REAL-TIME STREAM umesto statičke _allPutnici liste
    return StreamBuilder<List<Putnik>>(
      stream: _putnikService.streamKombinovaniPutnici(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPutnici = snapshot.data ?? [];

        // Debug log za praćenje broja putnika
        debugPrint(
            '🔍 DEBUG: HomeScreen build() - ukupno putnika: ${allPutnici.length}');
        debugPrint(
            '📊 [HOME SCREEN] Filter: $_selectedDay, $_selectedVreme, $_selectedGrad'); // ✅ KORISTI SELEKTOVANI DAN

        final sviPutnici = allPutnici.where((putnik) {
          final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');

          // Uklonjen verbose debug log - problem je rešen

          // MESEČNI PUTNICI - sada imaju polazak kolonu!
          if (putnik.mesecnaKarta == true) {
            // ✅ JEDNOSTAVNA LOGIKA - direktno poređenje grada i polaska
            final odgovarajuciGrad = putnik.grad == _selectedGrad;

            // Poređenje vremena - normalizuj oba formata
            final putnikPolazak = putnik.polazak.toString().trim();
            final selectedVreme = _selectedVreme.trim();
            final odgovarajuciPolazak = _normalizeTime(putnikPolazak) ==
                    _normalizeTime(selectedVreme) ||
                (_normalizeTime(putnikPolazak)
                    .startsWith(_normalizeTime(selectedVreme)));

            // DODAJ FILTRIRANJE PO DANU I ZA MESEČNE PUTNIKE - KORISTI SELEKTOVANI DAN
            final danBaza =
                _selectedDay; // ✅ KORISTI SELEKTOVANI DAN umesto _getTodayName()
            final normalizedPutnikDan =
                GradAdresaValidator.normalizeString(putnik.dan);
            final normalizedDanBaza = GradAdresaValidator.normalizeString(
                _getDayAbbreviation(danBaza));
            final odgovarajuciDan =
                normalizedPutnikDan.contains(normalizedDanBaza);

            final result = odgovarajuciGrad &&
                odgovarajuciPolazak &&
                odgovarajuciDan &&
                normalizedStatus != 'obrisan';

            // Debug za mesečne putnike
            if (result) {
              debugPrint('✅ MESEČNI PUTNIK PROŠAO: ${putnik.ime}');
              debugPrint(
                  '   - polazak: ${putnik.polazak} vs $_selectedVreme -> ${_normalizeTime(putnikPolazak)} vs ${_normalizeTime(selectedVreme)}');
              debugPrint('   - grad: ${putnik.grad} vs $_selectedGrad');
              debugPrint(
                  '   - dan: ${putnik.dan} vs ${_getDayAbbreviation(danBaza)} -> odgovarajuciDan: $odgovarajuciDan');
              debugPrint('   - MESEČNA KARTA - sada PROVERAVA I DAN!');
            }

            return result;
          } else {
            // DNEVNI/OBIČNI PUTNICI - standardno filtriranje
            // 🆕 KORISTI NOVU VALIDACIJU GRADOVA
            final gradMatch = GradAdresaValidator.isGradMatch(
                putnik.grad, putnik.adresa, _selectedGrad);

            // Konvertuj pun naziv dana u kraticu za poređenje sa bazom - KORISTI SELEKTOVANI DAN
            final danBaza =
                _selectedDay; // ✅ KORISTI SELEKTOVANI DAN umesto _getTodayName()
            final normalizedPutnikDan =
                GradAdresaValidator.normalizeString(putnik.dan);
            final normalizedDanBaza = GradAdresaValidator.normalizeString(
                _getDayAbbreviation(danBaza));

            final odgovara = gradMatch &&
                _normalizeTime(putnik.polazak) ==
                    _normalizeTime(_selectedVreme) &&
                normalizedPutnikDan.contains(normalizedDanBaza) &&
                normalizedStatus != 'obrisan';

            // Debug za dnevne putnike
            if (odgovara) {
              debugPrint('✅ DNEVNI PUTNIK PROŠAO: ${putnik.ime}');
              debugPrint(
                  '   - polazak: ${putnik.polazak} vs $_selectedVreme -> ${_normalizeTime(putnik.polazak)} vs ${_normalizeTime(_selectedVreme)}');
              debugPrint(
                  '   - dan: ${putnik.dan} vs ${_getDayAbbreviation(danBaza)} -> $normalizedPutnikDan vs $normalizedDanBaza');
              debugPrint('   - grad: ${putnik.grad} vs $_selectedGrad');
            } else {
              // Debug za neprošle putnike
              debugPrint('❌ DNEVNI PUTNIK NIJE PROŠAO: ${putnik.ime}');
              debugPrint('   - gradMatch: $gradMatch');
              debugPrint(
                  '   - vremeMatch: ${_normalizeTime(putnik.polazak) == _normalizeTime(_selectedVreme)}');
              debugPrint(
                  '   - danMatch: ${normalizedPutnikDan.contains(normalizedDanBaza)} ($normalizedPutnikDan vs $normalizedDanBaza)');
              debugPrint('   - status: $normalizedStatus');
            }

            return odgovara;
          }
        }).toList();

        // Sortiraj po statusu: bele (nepokupljeni), plave (pokupljeni neplaćeni), zelene (pokupljeni sa mesečnom/plaćeni), žute/narandžaste (bolovanje/godišnji), crvene (otkazani)
        List<Putnik> sortiraniPutnici(List<Putnik> lista) {
          int sortKey(Putnik p) {
            final status = TextUtils.normalizeText(p.status ?? '');

            // PRVO proveri status - najvažnije
            if (status == 'bolovanje' || status == 'godisnji') {
              return 4; // žute/narandžaste pre crvenih
            }
            if (status == 'otkazano' || status == 'otkazan') {
              return 5; // crvene na dno liste
            }

            // MESEČNI PUTNICI - NOVA LOGIKA
            if (p.mesecnaKarta == true) {
              // Koristi vremePokupljenja za determininaciju stanja
              return p.vremePokupljenja == null ? 0 : 3; // bela ili zelena
            }

            // OBIČNI PUTNICI - stara logika
            if (p.vremePokupljenja == null) return 0; // bela
            if (p.vremePokupljenja != null &&
                (p.iznosPlacanja == null || p.iznosPlacanja == 0)) {
              return 1; // plava
            }
            if (p.vremePokupljenja != null &&
                (p.iznosPlacanja != null && p.iznosPlacanja! > 0)) {
              return 2; // zelena
            }
            return 99;
          }

          final kopija = [...lista];
          kopija.sort((a, b) {
            final cmp = sortKey(a).compareTo(sortKey(b));
            if (cmp != 0) return cmp;
            return 0;
          });

          // Uklonjen DEBUG ispis sortirane liste - problem je rešen
          // if (kopija.isNotEmpty) {
          //   for (int i = 0; i < kopija.length; i++) {
          //     final sk = sortKey(kopija[i]);
          //   }
          // }

          return kopija;
        }

        final putniciZaPrikaz = sortiraniPutnici(sviPutnici);

        // Funkcija za brojanje putnika po gradu, vremenu i danu (samo aktivni)
        int getPutnikCount(String grad, String vreme) {
          return allPutnici.where((putnik) {
            final normalizedStatus =
                TextUtils.normalizeText(putnik.status ?? '');

            // MESEČNI PUTNICI - sada se broje i po polazku
            if (putnik.mesecnaKarta == true) {
              // ✅ JEDNOSTAVNA LOGIKA - direktno poređenje grada
              final gradMatch = putnik.grad == grad;

              // Poređenje vremena - normalizuj oba formata
              final putnikPolazak = putnik.polazak.toString().trim();
              final vremeStr = vreme.trim();
              final odgovarajuciPolazak =
                  _normalizeTime(putnikPolazak) == _normalizeTime(vremeStr) ||
                      (_normalizeTime(putnikPolazak)
                          .startsWith(_normalizeTime(vremeStr)));

              // DODAJ FILTRIRANJE PO DANU I ZA BROJANJE MESEČNIH PUTNIKA
              final danBaza = _selectedDay; // ✅ KORISTI SELEKTOVANI DAN
              final normalizedPutnikDan =
                  GradAdresaValidator.normalizeString(putnik.dan);
              final normalizedDanBaza = GradAdresaValidator.normalizeString(
                  _getDayAbbreviation(danBaza));
              final odgovarajuciDan =
                  normalizedPutnikDan.contains(normalizedDanBaza);

              return gradMatch &&
                  odgovarajuciPolazak &&
                  odgovarajuciDan &&
                  (normalizedStatus != 'otkazano' &&
                      normalizedStatus != 'otkazan' &&
                      normalizedStatus != 'bolovanje' &&
                      normalizedStatus != 'godisnji' &&
                      normalizedStatus != 'obrisan');
            } else {
              // DNEVNI/OBIČNI PUTNICI
              // ✅ KORISTI NOVU VALIDACIJU - isto kao u glavnom filteru
              final gradMatch = GradAdresaValidator.isGradMatch(
                  putnik.grad, putnik.adresa, grad);

              // Konvertuj pun naziv dana u kraticu za poređenje sa bazom - KORISTI SELEKTOVANI DAN
              final danBaza = _selectedDay; // ✅ KORISTI SELEKTOVANI DAN

              // ✅ KORISTI NORMALIZACIJU - isto kao u glavnom filteru
              final normalizedPutnikDan =
                  GradAdresaValidator.normalizeString(putnik.dan);
              final normalizedDanBaza = GradAdresaValidator.normalizeString(
                  _getDayAbbreviation(danBaza));

              return gradMatch &&
                  _normalizeTime(putnik.polazak) == _normalizeTime(vreme) &&
                  normalizedPutnikDan.contains(normalizedDanBaza) &&
                  (normalizedStatus != 'otkazano' &&
                      normalizedStatus != 'otkazan' &&
                      normalizedStatus != 'bolovanje' &&
                      normalizedStatus != 'godisnji' &&
                      normalizedStatus != 'obrisan');
            }
          }).length;
        }

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
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                          if (_currentDriver != null &&
                              _currentDriver!.isNotEmpty)
                            Expanded(
                              flex: 35,
                              child: Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: VozacBoja.get(_currentDriver),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: VozacBoja.get(_currentDriver)
                                          .withOpacity(0.3),
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
                                      fontSize: 15,
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
                                height: 28,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4)),
                                ),
                                child: const Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.palette,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'Tema',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 2),

                          // UPDATE - desno-sredina
                          Expanded(
                            flex: 25,
                            child: InkWell(
                              onTap: _showAutomationInfo,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.4)),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Auto',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                        ),
                                      ],
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
                              height: 28,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDay,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                  dropdownColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.95),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  isExpanded: true,
                                  items: _dani
                                      .map((dan) => DropdownMenuItem(
                                            value: dan,
                                            child: Text(
                                              dan,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ))
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_currentDriver == 'Bruda' ||
                        _currentDriver == 'Bilevski' ||
                        _currentDriver == 'Bojan' ||
                        _currentDriver == 'Svetlana')
                      Expanded(
                        flex: 1,
                        child: _HomeScreenButton(
                          label: 'Dodaj',
                          icon: Icons.person_add,
                          onTap: _showAddPutnikDialog,
                        ),
                      ),
                    if (_currentDriver == 'Bruda' ||
                        _currentDriver == 'Bilevski' ||
                        _currentDriver == 'Bojan' ||
                        _currentDriver == 'Svetlana')
                      const SizedBox(width: 4),
                    if (_currentDriver == 'Bruda' ||
                        _currentDriver == 'Bilevski' ||
                        _currentDriver == 'Bojan' ||
                        _currentDriver == 'Svetlana')
                      Expanded(
                        flex: 1,
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
                    if (['Bojan', 'Svetlana'].contains(_currentDriver))
                      const SizedBox(width: 4),
                    if (['Bojan', 'Svetlana'].contains(_currentDriver))
                      Expanded(
                        flex: 1,
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
                      flex: 1,
                      child: _HomeScreenButton(
                        label: 'Štampaj',
                        icon: Icons.print,
                        onTap: () async {
                          await PrintingService.printPutniksList(_selectedDay,
                              _selectedVreme, _selectedGrad, context);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 1,
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: putniciZaPrikaz.isEmpty
                        ? const Center(
                            child: Text('Nema putnika za ovaj polazak.'))
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
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavBarLetnji(
            sviPolasci: _sviPolasci,
            selectedGrad: _selectedGrad,
            selectedVreme: _selectedVreme,
            getPutnikCount: getPutnikCount,
            onPolazakChanged: (grad, vreme) async {
              // Prvo resetuj pokupljanje za novo vreme polaska
              await _putnikService.resetPokupljenjaNaPolazak(
                  vreme, grad, _currentDriver ?? 'Unknown');

              setState(() {
                _selectedGrad = grad;
                _selectedVreme = vreme;
                _selectedGradSubject.add(grad); // Ažuriraj stream
              });

              // 🔄 REFRESH putnika kada se promeni vreme polaska
              // setState() će automatski reload-ovati StreamBuilder sa novom logikom
              debugPrint(
                  '🔄 VREME POLASKA PROMENJENO: $grad $vreme - StreamBuilder će se ažurirati nakon resetovanja pokupljanja');
            },
          ),
        );
      }, // Zatvaranje StreamBuilder builder funkcije
    ); // Zatvaranje StreamBuilder widgeta
  } // Zatvaranje build metode

  @override
  void dispose() {
    _smartNotifikacijeTimer?.cancel();
    _selectedGradSubject.close();

    // Cleanup real-time subscriptions
    _realtimeSubscription?.cancel();
    _mesecniSubscription?.cancel();

    // CACHE UKLONJEN - nema više cache listener-a

    super.dispose();
  }
}

// AnimatedActionButton widget sa hover efektima
class AnimatedActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double width;
  final double height;
  final EdgeInsets margin;
  final List<Color> gradientColors;
  final List<BoxShadow> boxShadow;

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

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
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
                              (shadow.color.opacity * 1.5).clamp(0.0, 1.0)),
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
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeScreenButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

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
                fontSize: 10, // Smanjeno sa 12 na 10
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
