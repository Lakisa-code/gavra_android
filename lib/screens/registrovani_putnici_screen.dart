import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../helpers/putnik_statistike_helper.dart';
import '../models/registrovani_putnik.dart';
import '../services/admin_audit_service.dart';
import '../services/adresa_supabase_service.dart';
import '../services/cena_obracun_service.dart';
import '../services/geocoding_service.dart';
import '../services/permission_service.dart';
import '../services/registrovani_putnik_service.dart';
import '../services/timer_manager.dart';
import '../theme.dart';
import '../utils/time_validator.dart';
import '../utils/vozac_boja.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/registrovani_putnik_dialog.dart';

// 🔌 HELPER EXTENSION za Set poredenje
extension SetExtensions<T> on Set<T> {
  bool isEqualTo(Set<T> other) {
    if (length != other.length) return false;
    return containsAll(other) && other.containsAll(this);
  }
}

class RegistrovaniPutniciScreen extends StatefulWidget {
  const RegistrovaniPutniciScreen({Key? key}) : super(key: key);

  @override
  State<RegistrovaniPutniciScreen> createState() => _RegistrovaniPutniciScreenState();
}

class _RegistrovaniPutniciScreenState extends State<RegistrovaniPutniciScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'svi'; // 'svi', 'radnik', 'ucenik', 'dnevni'
  String _paymentFilter = 'svi'; // 'svi', 'platili', 'nisu_platili'

  // 🔄 REFRESH KEY: Forsira kreiranje novog stream-a nakon cuvanja
  int _streamRefreshKey = 0;

  // Novi servis instance
  final RegistrovaniPutnikService _registrovaniPutnikService = RegistrovaniPutnikService();

  // ?? OPTIMIZACIJA: Connection resilience
  StreamSubscription<dynamic>? _connectionSubscription;
  bool _isConnected = true;

  // ⚡ REALTIME MONITORING STATE (V3.0 Clean Architecture) - STANDARDIZED TIMERS
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _registrovaniPutniciStreamHealthy;
  // ? UKLONJENO: Timer? _monitoringTimer; - koristi TimerManager!
  late ValueNotifier<String> _realtimeHealthStatus;
  late ValueNotifier<bool> _isNetworkConnected;

  // Working days state
  final Map<String, bool> _noviRadniDani = {
    'pon': true,
    'uto': true,
    'sre': true,
    'cet': true,
    'pet': true,
  };

  // Controllers for new passenger (declared but initialized in _initializeControllers)
  late TextEditingController _imeController;
  late TextEditingController _tipSkoleController;
  late TextEditingController _brojTelefonaController;
  late TextEditingController _brojTelefonaOcaController;
  late TextEditingController _brojTelefonaMajkeController;
  late TextEditingController _adresaBelaCrkvaController;
  late TextEditingController _adresaVrsacController;

  // Departure time controllers for new passenger (map-based per day)
  final Map<String, TextEditingController> _polazakBcControllers = {};
  final Map<String, TextEditingController> _polazakVsControllers = {};

  // Time input controllers for new passenger
  final Map<String, TextEditingController> _vremenaBcControllers = {};
  final Map<String, TextEditingController> _vremenaVsControllers = {};

  // Services
  final List<StreamSubscription> _subscriptions = [];

  // 💳 PLACANJE STATE
  Map<String, double> _stvarnaPlacanja = {};
  DateTime? _lastPaymentUpdate;
  Set<String> _lastPutnikIds = {};
  Timer? _paymentUpdateDebounceTimer; // ⏱️ DEBOUNCE TIMER za payment updates

  // 📍 CACHE ZA NAZIVE ADRESA - batch loaded
  final Map<String, String> _adreseNazivi = {};

  // 📅 CACHE ZA PLACENE MESECE - Set meseci (format: "mesec-godina") za svakog putnika
  final Map<String, Set<String>> _placeniMeseci = {};

  // ?? CACHE za broj radnika da se izbegnu višestruki StreamBuilder-i
  int _cachedBrojRadnika = 0;
  int _cachedBrojUcenika = 0;
  int _cachedBrojDnevnih = 0;

  // ⚙️ OPTIMIZACIJA: Update cache umesto StreamBuilder-a
  void _updateCacheValues(List<RegistrovaniPutnik> putnici) {
    final noviRadnici = putnici
        .where(
          (p) => p.tip == 'radnik' && p.aktivan && !p.obrisan && p.status != 'bolovanje' && p.status != 'godišnje',
        )
        .length;
    final noviUcenici = putnici
        .where(
          (p) => p.tip == 'ucenik' && p.aktivan && !p.obrisan && p.status != 'bolovanje' && p.status != 'godišnje',
        )
        .length;
    final noviDnevni = putnici
        .where(
          (p) => p.tip == 'dnevni' && p.aktivan && !p.obrisan && p.status != 'bolovanje' && p.status != 'godišnje',
        )
        .length;

    if (_cachedBrojRadnika != noviRadnici || _cachedBrojUcenika != noviUcenici || _cachedBrojDnevnih != noviDnevni) {
      if (mounted) {
        setState(() {
          _cachedBrojRadnika = noviRadnici;
          _cachedBrojUcenika = noviUcenici;
          _cachedBrojDnevnih = noviDnevni;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeOptimizations();
  }

  void _initializeControllers() {
    _imeController = TextEditingController();
    _tipSkoleController = TextEditingController();
    _brojTelefonaController = TextEditingController();
    _brojTelefonaOcaController = TextEditingController();
    _brojTelefonaMajkeController = TextEditingController();
    _adresaBelaCrkvaController = TextEditingController();
    _adresaVrsacController = TextEditingController();

    // Initialize departure time controllers (map-based)
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
    for (final dan in dani) {
      _polazakBcControllers[dan] = TextEditingController();
      _polazakVsControllers[dan] = TextEditingController();
    }
    for (final dan in dani) {
      _vremenaBcControllers[dan] = TextEditingController();
      _vremenaVsControllers[dan] = TextEditingController();
    }
  }

  // ⚙️ OPTIMIZACIJA: Inicijalizacija debounced search i error handling
  void _initializeOptimizations() {
    // Listen za search promene - rebuild UI
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    // 🔌 Connection monitoring - prati konekciju ka serveru
    _setupConnectionMonitoring();

    // ⚡ V3.0 REALTIME MONITORING SETUP (Clean Architecture)
    _setupRealtimeMonitoring();
  }

  // 🔌 PRAVI CONNECTION MONITORING - Periodiski ping server
  void _setupConnectionMonitoring() {
    // Periodiski ping server da proveri konekciju (svakih 30 sekundi)
    _connectionSubscription = Stream.periodic(const Duration(seconds: 30)).listen((_) async {
      try {
        // Pokušaj da učitaš jedan registrovani putnik - brz test konekcije
        await supabase.from('registrovani_putnici').select().limit(1).maybeSingle();
        if (_isConnected == false && mounted) {
          setState(() => _isConnected = true);
        }
      } catch (e) {
        // Nema konekcije
        if (_isConnected == true && mounted) {
          setState(() => _isConnected = false);
        }
      }
    });
  }

  // ⚡ V3.0 REALTIME MONITORING SETUP (Backend only - no visual heartbeat)
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _registrovaniPutniciStreamHealthy = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');
    _isNetworkConnected = ValueNotifier(_isConnected);

    // 🔒 TIMER MEMORY LEAK FIX: Koristi TimerManager umesto direktnog Timer.periodic
    TimerManager.createTimer(
      'registrovani_putnici_monitoring',
      const Duration(seconds: 5),
      () => _updateHealthStatus(),
      isPeriodic: true,
    );
  }

  // 🚀 BATCH UCITAVANJE - sve tri operacije odjednom za optimalne performanse
  /// Učitaj stvarna plaćanja, adrese i plaćene mesece odjednom korišćenjem Future.wait()
  Future<void> _ucitajSvePodatke(List<RegistrovaniPutnik> putnici) async {
    if (putnici.isEmpty) return;

    try {
      // Pokreni sve tri operacije paralelno
      await Future.wait([
        _ucitajStvarnaPlacanja(putnici),
        _ucitajAdreseZaPutnike(putnici),
        _ucitajPlaceneMeseceZaSvePutnike(putnici),
      ]);
    } catch (e) {
      debugPrint('🔴 [RegistrovaniPutnici._ucitajSvePodatke] Error: $e');
    }
  }

  // 💰 UCITAJ STVARNA PLACANJA iz voznje_log
  Future<void> _ucitajStvarnaPlacanja(List<RegistrovaniPutnik> putnici) async {
    try {
      if (putnici.isEmpty) return; // ? Early exit - nema šta učitavati

      // ?? FIX: Ucitaj STVARNE uplate iz voznje_log tabele
      final Map<String, double> placanja = {};

      // Dohvati poslednje placanje za svakog putnika
      for (final putnik in putnici) {
        try {
          final response = await supabase
              .from('voznje_log')
              .select('iznos')
              .eq('putnik_id', putnik.id)
              .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
              .order('datum', ascending: false)
              .limit(1)
              .maybeSingle();

          if (response != null && response['iznos'] != null) {
            placanja[putnik.id] = (response['iznos'] as num).toDouble();
          } else {
            // Ako nema uplate, stavi 0
            placanja[putnik.id] = 0.0;
          }
        } catch (e) {
          placanja[putnik.id] = 0.0;
        }
      }
      if (mounted) {
        // ?? ANTI-REBUILD OPTIMIZATION: Samo update ako su se podaci stvarno promenili
        final existingKeys = _stvarnaPlacanja.keys.toSet();
        final newKeys = placanja.keys.toSet();

        bool hasChanges = !existingKeys.isEqualTo(newKeys);
        if (!hasChanges) {
          // Proveri vrednosti za postojece kljuceve
          for (final key in existingKeys) {
            if (_stvarnaPlacanja[key] != placanja[key]) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          _stvarnaPlacanja = placanja;
          // ?? SAMO JEDNOM setState() umesto kontinuiranih rebuild-a
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      // Greška u učitavanju stvarnih plaćanja
    }
  }

  // ?? UCITAJ PLACENE MESECE ZA SVE PUTNIKE - batch load za filter
  Future<void> _ucitajPlaceneMeseceZaSvePutnike(List<RegistrovaniPutnik> putnici) async {
    try {
      if (putnici.isEmpty) return; // ? Early exit - nema šta učitavati

      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      // Dohvati sve uplate za tekucu godinu
      final response = await supabase
          .from('voznje_log')
          .select('putnik_id, placeni_mesec, placena_godina')
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .gte('datum', startOfYear.toIso8601String().split('T')[0])
          .not('placeni_mesec', 'is', null)
          .not('placena_godina', 'is', null);

      final Map<String, Set<String>> placeniMeseci = {};

      for (final row in response) {
        final putnikId = row['putnik_id'] as String?;
        final mesec = row['placeni_mesec'] as int?;
        final godina = row['placena_godina'] as int?;

        if (putnikId != null && mesec != null && godina != null) {
          placeniMeseci[putnikId] = placeniMeseci[putnikId] ?? {};
          placeniMeseci[putnikId]!.add('$mesec-$godina');
        }
      }

      if (mounted) {
        setState(() {
          _placeniMeseci.addAll(placeniMeseci);
        });
      }
    } catch (e) {
      // Greška u učitavanju plaćenih meseci
    }
  }

  // ?? UCITAJ PLACENE MESECE za putnika - sva placanja sa placeni_mesec i placena_godina
  Future<void> _ucitajPlaceneMesece(RegistrovaniPutnik putnik) async {
    try {
      final svaPlacanja = await _registrovaniPutnikService.dohvatiPlacanjaZaPutnika(putnik.putnikIme);
      final Set<String> placeni = {};

      for (var placanje in svaPlacanja) {
        final mesec = placanje['placeniMesec'];
        final godina = placanje['placenaGodina'];
        if (mesec != null && godina != null) {
          placeni.add('$mesec-$godina');
        }
      }

      if (mounted) {
        setState(() {
          _placeniMeseci[putnik.id] = placeni;
        });
      }
    } catch (e) {
      // Greška u učitavanju plaćenih meseci
    }
  }

  /// ?? BATCH UCITAVANJE ADRESA - ucitaj sve adrese odjednom za performanse
  Future<void> _ucitajAdreseZaPutnike(List<RegistrovaniPutnik> putnici) async {
    try {
      if (putnici.isEmpty) return; // ? Early exit - nema šta učitavati

      // Sakupi sve UUID-ove adresa
      final Set<String> adresaIds = {};
      for (final p in putnici) {
        if (p.adresaBelaCrkvaId != null && p.adresaBelaCrkvaId!.isNotEmpty) {
          adresaIds.add(p.adresaBelaCrkvaId!);
        }
        if (p.adresaVrsacId != null && p.adresaVrsacId!.isNotEmpty) {
          adresaIds.add(p.adresaVrsacId!);
        }
      }

      if (adresaIds.isEmpty) return;

      // Batch ucitavanje svih adresa
      final adrese = await AdresaSupabaseService.getAdreseByUuids(adresaIds.toList());

      // Popuni mapu naziva
      final Map<String, String> noviNazivi = {};
      for (final a in adrese.values) {
        noviNazivi[a.id] = a.naziv;
      }

      // Samo update ako ima promena
      if (mounted && noviNazivi.isNotEmpty) {
        setState(() {
          _adreseNazivi.addAll(noviNazivi);
        });
      }
    } catch (e) {
      // Error loading addresses
    }
  }

  void _updateHealthStatus() {
    final streamHealthy = _registrovaniPutniciStreamHealthy.value;
    _isRealtimeHealthy.value = streamHealthy;

    // Update network status
    _isNetworkConnected.value = _isConnected;

    // Update health status
    if (!_isConnected) {
      _realtimeHealthStatus.value = 'error';
    } else if (!streamHealthy) {
      _realtimeHealthStatus.value = 'error';
    } else {
      _realtimeHealthStatus.value = 'healthy';
    }
  }

  @override
  void dispose() {
    // Cleanup debounce timer
    _paymentUpdateDebounceTimer?.cancel();

    // CRITICAL TIMER MEMORY LEAK FIX - KORISTI TIMER MANAGER!
    TimerManager.cancelTimer('registrovani_putnici_monitoring');

    // SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
        _registrovaniPutniciStreamHealthy.dispose();
        _realtimeHealthStatus.dispose();
        _isNetworkConnected.dispose();
      }
    } catch (e) {
      // Warning disposing ValueNotifiers
    }

    // OPTIMIZACIJA: Cleanup resources
    try {
      _connectionSubscription?.cancel();
    } catch (e) {
      // Warning disposing streams
    }

    // COMPREHENSIVE TEXTCONTROLLER CLEANUP
    try {
      _searchController.dispose();
      _imeController.dispose();
      _tipSkoleController.dispose();
      _brojTelefonaController.dispose();
      _brojTelefonaOcaController.dispose();
      _brojTelefonaMajkeController.dispose();
      _adresaBelaCrkvaController.dispose();
      _adresaVrsacController.dispose();

      // CRITICAL FIX: Dispose ALL time controllers
      for (final controller in _vremenaBcControllers.values) {
        controller.dispose();
      }
      for (final controller in _vremenaVsControllers.values) {
        controller.dispose();
      }

      // Dispose departure time controllers
      for (final c in _polazakBcControllers.values) {
        c.dispose();
      }
      for (final c in _polazakVsControllers.values) {
        c.dispose();
      }

      _subscriptions.forEach((subscription) => subscription.cancel());
    } catch (e) {
      // Warning disposing controllers
    }

    super.dispose();
  }

  /// ?? DIREKTNO FILTRIRANJE - dodaje search i filterType na vec filtrirane podatke iz streama
  /// Stream vec vraca aktivne putnike sa validnim statusom, ovde samo dodajemo dinamicke filtere
  List<RegistrovaniPutnik> _filterPutniciDirect(
    List<RegistrovaniPutnik> putnici,
    String searchTerm,
    String filterType,
  ) {
    var filtered = putnici;

    // Filter po tipu (radnik/ucenik)
    if (filterType != 'svi') {
      filtered = filtered.where((p) => p.tip == filterType).toList();
    }

    // Filter po placanju (samo za mesecne - radnik i ucenik)
    if (_paymentFilter != 'svi') {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      filtered = filtered.where((p) {
        // Preskoci dnevne putnike - oni ne placaju mesecno
        if (p.tip == 'dnevni') {
          return false;
        }

        final placeniMeseci = _placeniMeseci[p.id] ?? {};
        final jePlatioTrenutniMesec = placeniMeseci.contains('$currentMonth-$currentYear');

        if (_paymentFilter == 'platili') {
          return jePlatioTrenutniMesec;
        } else {
          return !jePlatioTrenutniMesec;
        }
      }).toList();
    }

    // Filter po search term
    if (searchTerm.isNotEmpty) {
      final searchLower = searchTerm.toLowerCase();
      filtered = filtered.where((p) {
        return p.putnikIme.toLowerCase().contains(searchLower) ||
            p.tip.toLowerCase().contains(searchLower) ||
            (p.tipSkole?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // ?? BINARYBITCH SORTING BLADE: A Ž (Serbian alphabet)
    filtered.sort((a, b) => a.putnikIme.toLowerCase().compareTo(b.putnikIme.toLowerCase()));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
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
              // No boxShadow - keep AppBar fully transparent and only glassBorder
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox.shrink(),
                    const Expanded(
                      child: SizedBox.shrink(),
                    ),
                    // Filter za placanja
                    IconButton(
                      icon: Icon(
                        _paymentFilter == 'svi'
                            ? Icons.payments_outlined
                            : _paymentFilter == 'platili'
                                ? Icons.check_circle
                                : Icons.cancel,
                        color: _paymentFilter == 'svi' ? Colors.white70 : Colors.white,
                        shadows: const [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      onPressed: () {
                        setState(() {
                          if (_paymentFilter == 'svi') {
                            _paymentFilter = 'platili';
                          } else if (_paymentFilter == 'platili') {
                            _paymentFilter = 'nisu_platili';
                          } else {
                            _paymentFilter = 'svi';
                          }
                        });
                      },
                      tooltip: _paymentFilter == 'svi'
                          ? 'Svi putnici'
                          : _paymentFilter == 'platili'
                              ? 'Samo koji su platili'
                              : 'Samo koji nisu platili',
                    ),
                    // Filter za radnike sa brojem
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.engineering,
                            color: _selectedFilter == 'radnik' ? Colors.white : Colors.white70,
                            shadows: const [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          onPressed: () {
                            final newFilter = _selectedFilter == 'radnik' ? 'svi' : 'radnik';
                            setState(() {
                              _selectedFilter = newFilter;
                            });
                          },
                          tooltip: 'Filtriraj radnike',
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFFF8E53),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            child: Text(
                              '$_cachedBrojRadnika',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Filter za ucenike sa brojem
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.school,
                            color: _selectedFilter == 'ucenik' ? Colors.white : Colors.white70,
                            shadows: const [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          onPressed: () {
                            final newFilter = _selectedFilter == 'ucenik' ? 'svi' : 'ucenik';
                            setState(() {
                              _selectedFilter = newFilter;
                            });
                          },
                          tooltip: 'Filtriraj ucenike',
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF4ECDC4),
                                  Color(0xFF44A08D),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            child: Text(
                              '$_cachedBrojUcenika',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Filter za dnevne putnike sa brojem
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.today,
                            color: _selectedFilter == 'dnevni' ? Colors.white : Colors.white70,
                            shadows: const [
                              Shadow(
                                offset: Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          onPressed: () {
                            final newFilter = _selectedFilter == 'dnevni' ? 'svi' : 'dnevni';
                            setState(() {
                              _selectedFilter = newFilter;
                            });
                          },
                          tooltip: 'Filtriraj dnevne putnike',
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF5C9CE6),
                                  Color(0xFF3B7DD8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            child: Text(
                              '$_cachedBrojDnevnih',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                      onPressed: () => _pokaziDijalogZaDodavanje(),
                      tooltip: 'Dodaj novog putnika',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // ?? SEARCH BAR
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Pretraži putnike...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).primaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ?? LISTA PUTNIKA - direktan Supabase realtime stream
            Expanded(
              child: StreamBuilder<List<RegistrovaniPutnik>>(
                // ? REMOVED: ValueKey - ispravljeno memory leak problem sa stream lifecycle-om
                stream: RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    // Heartbeat indicator shows connection status
                    return const Center(
                      child: Text(
                        'Greška pri učitavanju mesečnih putnika',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  final sviPutnici = snapshot.data ?? [];

                  // Filtriraj lokalno
                  final filteredPutnici = _filterPutniciDirect(
                    sviPutnici,
                    _searchController.text,
                    _selectedFilter,
                  );

                  // ? UPDATE CACHE VALUES za brojace (zamenjuje dodatne StreamBuilder-e)
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateCacheValues(snapshot.data!);
                    });
                  }

                  // ??? UCITAJ STVARNA PLACANJA kada se dobiju novi podaci - DEBOUNCED
                  if (filteredPutnici.isNotEmpty) {
                    final currentIds = filteredPutnici.map((p) => p.id).toSet();

                    // ?? PRAVI DEBOUNCE: Ako se putnici promenili, resetuj timer
                    if (!_lastPutnikIds.isEqualTo(currentIds)) {
                      _lastPutnikIds = currentIds;

                      // Otkaži stari timer ako postoji
                      _paymentUpdateDebounceTimer?.cancel();

                      // Kreiraj novi timer - čekaj 2 sekunde pre nego što učitaš podatke
                      _paymentUpdateDebounceTimer = Timer(const Duration(seconds: 2), () {
                        if (mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            // 🚀 BATCH UCITAVANJE - sve tri operacije odjednom za performanse
                            _ucitajSvePodatke(filteredPutnici);
                          });
                        }
                      });
                    }
                  }

                  // Prikaži samo prvih 50 rezultata
                  final prikazaniPutnici =
                      filteredPutnici.length > 50 ? filteredPutnici.sublist(0, 50) : filteredPutnici;

                  if (prikazaniPutnici.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchController.text.isNotEmpty ? Icons.search_off : Icons.group_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ? 'Nema rezultata pretrage' : 'Nema mesecnih putnika',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Pokušajte sa drugim terminom',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    key: ValueKey(prikazaniPutnici.length),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: prikazaniPutnici.length,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemBuilder: (context, index) {
                      final putnik = prikazaniPutnici[index];
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(putnik.id),
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: _buildPutnikCard(putnik, index + 1),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPutnikCard(RegistrovaniPutnik putnik, int redniBroj) {
    final bool bolovanje = putnik.status == 'bolovanje';
    // Sačuvaj sva vremena po danima (pon -> pet) i prikaži ih na kartici.
    // Prethodna logika je prikazivala samo PRVI dan koji je imao vreme.
    // Sada prikazujemo sve dane koji imaju bar jedan polazak (BC i/ili VS)
    final List<String> _daniOrder = ['pon', 'uto', 'sre', 'cet', 'pet'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: bolovanje
              ? LinearGradient(
                  colors: [Colors.amber[50]!, Colors.orange[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: bolovanje ? Colors.orange[200]! : Colors.grey[200]!,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ?? HEADER - Ime, broj i aktivnost switch
              Row(
                children: [
                  // Redni broj i ime
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '$redniBroj.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            putnik.putnikIme,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: bolovanje ? Colors.orange : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Switch za aktivnost ili bolovanje
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bolovanje ? 'BOLUJE' : (putnik.aktivan ? 'AKTIVAN' : 'PAUZIRAN'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: bolovanje ? Colors.orange : (putnik.aktivan ? Colors.green : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: putnik.aktivan,
                        onChanged: bolovanje ? null : (value) => _toggleAktivnost(putnik),
                        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.green;
                          }
                          return Colors.grey;
                        }),
                        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.green.shade200;
                          }
                          return Colors.grey.shade300;
                        }),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ?? OSNOVNE INFORMACIJE - tip, telefon, škola, statistike u jednom redu
              Row(
                children: [
                  // Tip putnika
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(
                          putnik.tip == 'radnik'
                              ? Icons.engineering
                              : putnik.tip == 'dnevni'
                                  ? Icons.today
                                  : Icons.school,
                          size: 16,
                          color: putnik.tip == 'radnik'
                              ? Colors.blue.shade600
                              : putnik.tip == 'dnevni'
                                  ? Colors.orange.shade600
                                  : Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          putnik.tip.toUpperCase(),
                          style: TextStyle(
                            color: putnik.tip == 'radnik'
                                ? Colors.blue.shade700
                                : putnik.tip == 'dnevni'
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Telefon - prikaže broj dostupnih kontakata
                  if (putnik.brojTelefona != null || putnik.brojTelefonaOca != null || putnik.brojTelefonaMajke != null)
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          // Ikone za dostupne kontakte
                          if (putnik.brojTelefona != null)
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                          if (putnik.brojTelefonaOca != null)
                            Icon(
                              Icons.man,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                          if (putnik.brojTelefonaMajke != null)
                            Icon(
                              Icons.woman,
                              size: 14,
                              color: Colors.pink.shade600,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '${_prebrojKontakte(putnik)} kontakt${_prebrojKontakte(putnik) == 1 ? '' : 'a'}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tip škole/ustanova (ako postoji)
                  if (putnik.tipSkole != null)
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            putnik.tip == 'ucenik' ? Icons.school_outlined : Icons.business_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              putnik.tipSkole!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ?? ADRESE - BC i VS
              if (putnik.adresaBelaCrkvaId != null || putnik.adresaVrsacId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (putnik.adresaBelaCrkvaId != null && _adreseNazivi[putnik.adresaBelaCrkvaId] != null)
                        _buildAdresaRow(
                          label: 'BC',
                          color: Colors.blue,
                          naziv: _adreseNazivi[putnik.adresaBelaCrkvaId],
                          adresaId: putnik.adresaBelaCrkvaId,
                        ),
                      if (putnik.adresaVrsacId != null && _adreseNazivi[putnik.adresaVrsacId] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildAdresaRow(
                            label: 'VS',
                            color: Colors.purple,
                            naziv: _adreseNazivi[putnik.adresaVrsacId],
                            adresaId: putnik.adresaVrsacId,
                          ),
                        ),
                    ],
                  ),
                ),

              // ?? RADNO VREME - prikaži polazak vremena ako je definisan bar jedan dan
              if (_daniOrder
                  .any((d) => putnik.getPolazakBelaCrkvaZaDan(d) != null || putnik.getPolazakVrsacZaDan(d) != null))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kompaktni prikaz - sve u jednom Wrap-u
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _daniOrder.map((dan) {
                          final bc = putnik.getPolazakBelaCrkvaZaDan(dan);
                          final vs = putnik.getPolazakVrsacZaDan(dan);
                          if (bc == null && vs == null) {
                            return const SizedBox.shrink();
                          }

                          final label =
                              {'pon': 'Pon', 'uto': 'Uto', 'sre': 'Sre', 'cet': 'Cet', 'pet': 'Pet'}[dan] ?? dan;

                          // Formatiranje: "Pon: 13?6" umesto dugackog teksta
                          String timeText = '';
                          if (bc != null && vs != null) {
                            // Oba smera - skraceno
                            final bcShort = bc.replaceAll(':00', '');
                            final vsShort = vs.replaceAll(':00', '');
                            timeText = '$bcShort?$vsShort';
                          } else if (bc != null) {
                            timeText = '???${bc.replaceAll(':00', '')}';
                          } else if (vs != null) {
                            timeText = '??${vs.replaceAll(':00', '')}';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$label: $timeText',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Radni dani
                      if (putnik.radniDani.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Radni dani: ${putnik.radniDani}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // ??? PLACANJE I STATISTIKE - jednaki elementi u redu
              Row(
                children: [
                  // ?? DUGME ZA PLACANJE
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _prikaziPlacanje(putnik),
                      icon:
                          (_stvarnaPlacanja[putnik.id] ?? 0) > 0 ? Icons.check_circle_outline : Icons.payments_outlined,
                      label: (_stvarnaPlacanja[putnik.id] ?? 0) > 0
                          ? '${(_stvarnaPlacanja[putnik.id]!).toStringAsFixed(0)} RSD'
                          : 'Plati',
                      color: (_stvarnaPlacanja[putnik.id] ?? 0) > 0 ? Colors.green : Colors.purple,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ?? DUGME ZA DETALJE
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _prikaziDetaljneStatistike(putnik),
                      icon: Icons.analytics_outlined,
                      label: 'Detalji',
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ?? BROJAC PUTOVANJA
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          FutureBuilder<int>(
                            future: RegistrovaniPutnikService.izracunajBrojPutovanjaIzIstorije(putnik.id),
                            builder: (context, snapshot) => Text(
                              '${snapshot.data ?? 0}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ? BROJAC OTKAZIVANJA
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          FutureBuilder<int>(
                            future: RegistrovaniPutnikService.izracunajBrojOtkazivanjaIzIstorije(putnik.id),
                            builder: (context, snapshot) => Text(
                              '${snapshot.data ?? 0}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ??? ACTION BUTTONS - samo najvažnije
              Row(
                children: [
                  // Pozovi (ako ima bilo koji telefon)
                  if (putnik.brojTelefona != null ||
                      putnik.brojTelefonaOca != null ||
                      putnik.brojTelefonaMajke != null) ...[
                    Expanded(
                      child: _buildCompactActionButton(
                        onPressed: () => _pokaziKontaktOpcije(putnik),
                        icon: Icons.phone,
                        label: 'Pozovi',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Uredi
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _editPutnik(putnik),
                      icon: Icons.edit_outlined,
                      label: 'Uredi',
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ?? PIN
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _showPinDialog(putnik),
                      icon: Icons.lock_outline,
                      label: 'PIN',
                      color: Colors.amber,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Obriši
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _obrisiPutnika(putnik),
                      icon: Icons.delete_outline,
                      label: 'Obriši',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdresaRow({
    required String label,
    required Color color,
    required String? naziv,
    required String? adresaId,
  }) {
    if (naziv == null) return const SizedBox.shrink();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            naziv,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Navigation button
        GestureDetector(
          onTap: () => _navigirajDoAdrese(adresaId, label),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.navigation_outlined,
              size: 14,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  void _navigirajDoAdrese(String? adresaId, String gradLabel) async {
    if (adresaId == null) return;

    final adrese = await AdresaSupabaseService.getAdreseByUuids([adresaId]);
    if (adrese.isEmpty) return;

    final adresa = adrese.values.first;
    double? lat = adresa.koordinate?['lat'];
    double? lng = adresa.koordinate?['lng'];

    // ?? Odredi grad iz labela (BC -> Bela Crkva, VS -> Vršac)
    final grad = gradLabel.toUpperCase() == 'BC' ? 'Bela Crkva' : 'Vršac';

    // ?? Ako nema koordinate, pokušaj geocoding
    if (lat == null || lng == null) {
      try {
        final coordsString = await GeocodingService.getKoordinateZaAdresu(
          grad,
          adresa.naziv,
        );
        if (coordsString != null) {
          final parts = coordsString.split(',');
          if (parts.length == 2) {
            lat = double.tryParse(parts[0]);
            lng = double.tryParse(parts[1]);
            // Sačuvaj koordinate za buduće korišćenje
            if (lat != null && lng != null) {
              await AdresaSupabaseService.updateKoordinate(
                adresaId,
                lat: lat,
                lng: lng,
              );
            }
          }
        }
      } catch (e) {
        // Geocoding greška
      }
    }

    // Ako i dalje nema koordinata, prikaži poruku
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adresa "${adresa.naziv}" nema koordinate. Pokušajte ručno pretražiti.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // HERE WeGo navigacija - besplatno, radi na svim uredajima
    final hereWeGoUrl = 'https://share.here.com/r/$lat,$lng';
    final uri = Uri.parse(hereWeGoUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback - otvori HERE WeGo store
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instalirajte HERE WeGo za navigaciju')),
        );
      }
    }
  }

  Widget _buildCompactActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 14, color: color),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: color,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAktivnost(RegistrovaniPutnik putnik) async {
    final success = await _registrovaniPutnikService.toggleAktivnost(putnik.id, !putnik.aktivan);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${putnik.putnikIme} je ${!putnik.aktivan ? "aktiviran" : "deaktiviran"}',
          ),
          backgroundColor: !putnik.aktivan ? Colors.green : Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri promeni statusa'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPutnik(RegistrovaniPutnik putnik) {
    showDialog(
      context: context,
      builder: (context) => RegistrovaniPutnikDialog(
        existingPutnik: putnik,
        onSaved: () {
          // ?? REFRESH: Inkrementiraj key da forsira novi stream sa svježim podacima
          if (mounted) {
            setState(() {
              _streamRefreshKey++;
            });
          }
        },
      ),
    );
  }

  /// ?? Prikaži PIN dijalog za putnika
  void _showPinDialog(RegistrovaniPutnik putnik) {
    showDialog(
      context: context,
      builder: (context) => PinDialog(
        putnikId: putnik.id,
        putnikIme: putnik.putnikIme,
        trenutniPin: putnik.pin,
        brojTelefona: putnik.brojTelefona,
      ),
    );
  }

  void _pokaziDijalogZaDodavanje() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RegistrovaniPutnikDialog(
        existingPutnik: null, // null indicates adding mode
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }

  /// ?? SACUVAJ VREME POLASKA U ISTORIJU ZA AUTOCOMPLETEthere to reduce duplication)

  void _obrisiPutnika(RegistrovaniPutnik putnik) async {
    // Pokaži potvrdu za brisanje
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdi brisanje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Da li ste sigurni da želite da obrišete putnika "${putnik.putnikIme}"?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Važne informacije:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Putnik će biti označen kao obrisan'),
                  const Text('• Postojeća istorija putovanja se čuva'),
                  const Text('• Istorija vožnji ostaje u voznje_log'),
                  const Text('• Možete kasnije ponovo aktivirati putnika'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (potvrda == true && mounted) {
      try {
        final success = await _registrovaniPutnikService.obrisiRegistrovaniPutnik(putnik.id);

        if (success) {
          // logic simplified slightly if not needing immediate mount check
          // ??? AUDIT LOG
          final currentUser = supabase.auth.currentUser;
          await AdminAuditService.logAction(
            adminName: currentUser?.email ?? 'Unknown Admin',
            actionType: 'delete_passenger',
            details: 'Obrisan putnik: ${putnik.putnikIme}',
            metadata: {'putnik_id': putnik.id, 'ime': putnik.putnikIme},
          );
        }

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${putnik.putnikIme} je uspešno obrisan'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri brisanju putnika'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Greška: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper funkcija za brojanje kontakata
  int _prebrojKontakte(RegistrovaniPutnik putnik) {
    int brojKontakata = 0;
    if (putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty) {
      brojKontakata++;
    }
    if (putnik.brojTelefonaOca != null && putnik.brojTelefonaOca!.isNotEmpty) {
      brojKontakata++;
    }
    if (putnik.brojTelefonaMajke != null && putnik.brojTelefonaMajke!.isNotEmpty) {
      brojKontakata++;
    }
    return brojKontakata;
  }

  // ??????????? NOVA FUNKCIJA - Prikazuje sve dostupne kontakte
  Future<void> _pokaziKontaktOpcije(RegistrovaniPutnik putnik) async {
    final List<Widget> opcije = [];

    // Glavni broj telefona
    if (putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.person, color: Colors.green),
          title: const Text('Pozovi putnika'),
          subtitle: Text(putnik.brojTelefona!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefona!);
          },
        ),
      );
    }

    // Otac
    if (putnik.brojTelefonaOca != null && putnik.brojTelefonaOca!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.man, color: Colors.blue),
          title: const Text('Pozovi oca'),
          subtitle: Text(putnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefonaOca!);
          },
        ),
      );
    }

    // Majka
    if (putnik.brojTelefonaMajke != null && putnik.brojTelefonaMajke!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.woman, color: Colors.pink),
          title: const Text('Pozovi majku'),
          subtitle: Text(putnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefonaMajke!);
          },
        ),
      );
    }

    if (opcije.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih kontakata')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kontaktiraj ${putnik.putnikIme}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ...opcije,
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Otkaži'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pozovi(String brojTelefona) async {
    try {
      // ?? HUAWEI KOMPATIBILNO - koristi Huawei specificnu logiku (konzistentno sa putnik_card)
      final hasPermission = await PermissionService.ensurePhonePermissionHuawei();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('? Dozvola za pozive je potrebna'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final phoneUrl = Uri.parse('tel:$brojTelefona');
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('? Nije moguce pozivanje sa ovog uredaja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri pozivanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ?? PRIKAZ DIJALOGA ZA PLACANJE
  Future<void> _prikaziPlacanje(RegistrovaniPutnik putnik) async {
    // Ucitaj sva placanja za ovog putnika da bi se prikazali placeni meseci zeleno
    await _ucitajPlaceneMesece(putnik);

    // ??? Proveri da li je widget još uvek mountovan nakon async operacije
    if (!mounted) return;

    final TextEditingController iznosController = TextEditingController();
    String selectedMonth = _getCurrentMonthYear(); // Default current month

    // ?? FIX: Ucitaj stvarni ukupni iznos iz baze
    final ukupnoPlaceno = await RegistrovaniPutnikService.dohvatiUkupnoPlaceno(putnik.id);

    // Default cena po danu za input field
    final cenaPoDanu = CenaObracunService.getCenaPoDanu(putnik);
    iznosController.text = cenaPoDanu.toStringAsFixed(0);

    final tipLower = putnik.tip.toLowerCase();
    final imeLower = putnik.putnikIme.toLowerCase();

    // ?? FIKSNE CENE (Vozaci/Admini prate isti standard)
    final jeZubi = tipLower == 'posiljka' && imeLower.contains('zubi');
    final jePosiljka = tipLower == 'posiljka';
    final jeDnevni = tipLower == 'dnevni';
    final jeFiksna = jeZubi || jePosiljka || jeDnevni;

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    jeFiksna ? Icons.lock : Icons.payments_outlined,
                    color: jeFiksna ? Colors.orange : Colors.purple.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      jeFiksna ? 'Fiksna naplata - ${putnik.putnikIme}' : 'Placanje - ${putnik.putnikIme}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (jeFiksna)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          jeZubi
                              ? 'Tip: Pošiljka ZUBI (300 RSD po pokupljenju)'
                              : (jePosiljka
                                  ? 'Tip: Pošiljka (500 RSD po pokupljenju)'
                                  : 'Tip: Dnevni (600 RSD po pokupljenju)'),
                          style: TextStyle(
                            color: jeZubi ? Colors.purple : (jePosiljka ? Colors.blue : Colors.orange),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (ukupnoPlaceno > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ukupno placeno: ${ukupnoPlaceno.toStringAsFixed(0)} RSD',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      // ?? REALTIME: Vozac i datum poslednjeg placanja iz voznje_log
                                      StreamBuilder<Map<String, dynamic>?>(
                                        stream: RegistrovaniPutnikService.streamPoslednjePlacanje(putnik.id),
                                        builder: (context, snapshot) {
                                          final placanje = snapshot.data;
                                          if (placanje == null) return const SizedBox.shrink();
                                          final vozacIme = placanje['vozac_ime'] as String?;
                                          final datum = placanje['datum'] as String?;
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (datum != null)
                                                Text(
                                                  'Poslednje placanje: $datum',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green.shade600,
                                                  ),
                                                ),
                                              if (vozacIme != null)
                                                Text(
                                                  'Placeno: $datum',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    // Ako imamo ime vozaca iz strema, koristimo njegovu boju
                                                    color: VozacBoja.getColorOrDefault(
                                                      vozacIme,
                                                      Colors.green.shade600,
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              if (vozacIme != null)
                                                Text(
                                                  'Naplatio: $vozacIme',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: VozacBoja.get(
                                                      vozacIme,
                                                    ),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blue.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Dodavanje novog placanja (bice dodato na postojeca)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                        fontStyle: FontStyle.italic,
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
                    ],

                    // ?? IZBOR MESECA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          icon: Icon(
                            Icons.calendar_month,
                            color: Colors.purple.shade600,
                          ),
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 16,
                          ),
                          menuMaxHeight: 300, // Ogranici visinu dropdown menija
                          onChanged: (String? newValue) {
                            if (mounted) {
                              setState(() {
                                selectedMonth = newValue!;
                              });
                            }
                          },
                          items: _getMonthOptions().map<DropdownMenuItem<String>>((String value) {
                            // Proveri da li je mesec placen
                            final bool isPlacen = _isMonthPaid(value, putnik);

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: isPlacen ? Colors.green[700] : null,
                                  fontWeight: isPlacen ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ?? IZNOS
                    TextField(
                      controller: iznosController,
                      enabled: !jeFiksna, // ?? Onemoguci izmenu za fiksne cene
                      readOnly: jeFiksna, // ?? Read only
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: jeFiksna ? 'Fiksni iznos (dinari)' : 'Iznos (dinari)',
                        prefixIcon: Icon(
                          jeFiksna ? Icons.lock_outline : Icons.attach_money,
                          color: jeFiksna ? Colors.grey : Colors.purple.shade600,
                        ),
                        helperText: jeFiksna ? 'Fiksna cena za ovaj tip putnika.' : null,
                        fillColor: jeFiksna ? Colors.grey.shade100 : null,
                        filled: jeFiksna,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.purple.shade600,
                            width: 2,
                          ),
                        ),
                      ),
                      autofocus: !jeFiksna,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Otkaži'),
                ),
                // ?? DUGME ZA DETALJNE STATISTIKE
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Zatvori trenutni dialog
                    _prikaziDetaljneStatistike(putnik); // Otvori statistike
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Detaljno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final iznos = double.tryParse(iznosController.text);
                    if (iznos != null && iznos > 0) {
                      Navigator.of(context).pop();
                      await _sacuvajPlacanje(putnik.id, iznos, selectedMonth);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unesite valjan iznos'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: Icon(ukupnoPlaceno > 0 ? Icons.add : Icons.save),
                  label: Text(ukupnoPlaceno > 0 ? 'Dodaj placanje' : 'Sacuvaj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } // ?? CUVANJE PLACANJA

  // ?? PRIKAŽI DETALJNE STATISTIKE PUTNIKA
  Future<void> _prikaziDetaljneStatistike(RegistrovaniPutnik putnik) async {
    await PutnikStatistikeHelper.prikaziDetaljneStatistike(
      context: context,
      putnikId: putnik.id,
      putnikIme: putnik.putnikIme,
      tip: putnik.tip,
      tipSkole: putnik.tipSkole,
      brojTelefona: putnik.brojTelefona,
      radniDani: putnik.radniDani,
      createdAt: putnik.createdAt,
      updatedAt: putnik.updatedAt,
      aktivan: putnik.aktivan,
    );
  }

  Future<void> _sacuvajPlacanje(
    String putnikId,
    double iznos,
    String mesec,
  ) async {
    try {
      // ?? FIX: Koristi IME vozaca, ne UUID
      final currentDriverName = await _getCurrentDriverName();

      // ?? Konvertuj string meseca u datume
      final Map<String, dynamic> datumi = _konvertujMesecUDatume(mesec);

      final uspeh = await _registrovaniPutnikService.azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        currentDriverName, // ?? FIX: Koristi IME vozaca za prikaz boja
        datumi['pocetakMeseca'] as DateTime,
        datumi['krajMeseca'] as DateTime,
      );

      if (uspeh) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '? Dodato placanje od ${iznos.toStringAsFixed(0)} RSD za $mesec',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri čuvanju plaćanja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ?? HELPER FUNKCIJE ZA MESECE
  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return '${_getMonthName(now.month)} ${now.year}';
  }

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthName(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  // ?? PROVERI DA LI JE MESEC PLACEN
  bool _isMonthPaid(String monthYear, RegistrovaniPutnik putnik) {
    // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
    final parts = monthYear.split(' ');
    if (parts.length != 2) return false;

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) return false;

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) return false;

    // Proveri cache placenih meseci (sva placanja iz voznje_log)
    final placeniZaPutnika = _placeniMeseci[putnik.id];
    if (placeniZaPutnika != null && placeniZaPutnika.contains('$monthNumber-$year')) {
      return true;
    }

    return false;
  }

  // ?? HELPER: DOBIJ BROJ MESECA IZ IMENA
  int _getMonthNumber(String monthName) {
    const months = [
      '', // 0 - ne postoji
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
      'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];

    for (int i = 1; i < months.length; i++) {
      if (months[i] == monthName) {
        return i;
      }
    }
    return 0; // Ne postoji
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Jun',
      'Jul',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar',
    ];
    return months[month];
  }

  // Helper za konvertovanje meseca u datume
  Map<String, dynamic> _konvertujMesecUDatume(String izabranMesec) {
    // Parsiraj izabrani mesec (format: "Septembar 2025")
    final parts = izabranMesec.split(' ');
    if (parts.length != 2) {
      throw Exception('Neispravno format meseca: $izabranMesec');
    }

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) {
      throw Exception('Neispravna godina: ${parts[1]}');
    }

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) {
      throw Exception('Neispravno ime meseca: $monthName');
    }

    DateTime pocetakMeseca = DateTime(year, monthNumber);
    DateTime krajMeseca = DateTime(year, monthNumber + 1, 0, 23, 59, 59);

    return {
      'pocetakMeseca': pocetakMeseca,
      'krajMeseca': krajMeseca,
      'mesecBroj': monthNumber,
      'godina': year,
    };
  }

  // ?? BUILDER ZA CHECKBOX RADNIH DANA
  // ignore: unused_element
  Widget _buildRadniDanCheckbox(String danKod, String danNaziv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: _noviRadniDani[danKod] ?? false,
                  onChanged: (bool? value) {
                    if (mounted) {
                      setState(() {
                        _noviRadniDani[danKod] = value ?? false;
                      });
                    }
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                danNaziv,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ? BUILDER ZA VREMENA POLASKA PO DANIMA
  // ignore: unused_element
  Widget _buildVremenaPolaskaSekcija() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).glassContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vremena polaska po danima',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Unesite vremena polaska za svaki radni dan:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                tooltip: 'Standardna vremena',
                onSelected: (value) => _popuniStandardnaVremena(value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'jutarnja_smena',
                    child: Text(
                      'Jutarnja smena (06:00-14:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'popodnevna_smena',
                    child: Text(
                      'Popodnevna smena (14:00-22:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'skola',
                    child: Text(
                      'škola (07:30-14:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ocisti',
                    child: Text(
                      'Ocisti sva vremena',
                      style: TextStyle(fontSize: 13, color: Colors.red[300], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dinamicki prikaz samo za oznacene dane
          ..._noviRadniDani.entries
              .where((entry) => entry.value) // Samo oznaceni dani
              .map((entry) => _buildDanVremeInput(entry.key))
              .toList(),
        ],
      ),
    );
  }

  // Helper za dobijanje kontrolera za odredeni dan i smer
  TextEditingController _getControllerBelaCrkva(String dan) {
    return _polazakBcControllers[dan] ?? TextEditingController();
  }

  TextEditingController _getControllerVrsac(String dan) {
    return _polazakVsControllers[dan] ?? TextEditingController();
  }

  // ?? VALIDACIJA VREMENA POLASKA - Using standardized TimeValidator
  String? _validateTime(String? value) {
    return TimeValidator.validateTime(value);
  }

  // Helper za input polja za vreme po danu
  Widget _buildDanVremeInput(String danKod) {
    final daniMapa = {
      'pon': 'Pon',
      'uto': 'Uto',
      'sre': 'Sre',
      'cet': 'Cet',
      'pet': 'Pet',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dan nazad sa opcijama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                daniMapa[danKod] ?? danKod,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 12),
                    onPressed: () => _kopirajVremenaNaDrugeRadneDane(danKod),
                    tooltip: 'Kopiraj na ostale dane',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 12),
                    onPressed: () => _ocistiVremenaZaDan(danKod),
                    tooltip: 'Ocisti vremena',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Vremena u kompaktnom redu
          IntrinsicHeight(
            child: Row(
              children: [
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: _getControllerBelaCrkva(danKod),
                      keyboardType: TextInputType.datetime,
                      validator: _validateTime,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'BC',
                        hintText: '05:00',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.1),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: _getControllerVrsac(danKod),
                      keyboardType: TextInputType.datetime,
                      validator: _validateTime,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'VS',
                        hintText: '05:30',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ?? KOPIRAJ VREMENA NA DRUGE RADNE DANE
  void _kopirajVremenaNaDrugeRadneDane(String izvorDan) {
    final bcVreme = _getControllerBelaCrkva(izvorDan).text.trim();
    final vsVreme = _getControllerVrsac(izvorDan).text.trim();

    if (bcVreme.isEmpty && vsVreme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema vremena za kopiranje'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        // Kopiraj na sve ostale oznacene radne dane
        for (final dan in _noviRadniDani.entries) {
          if (dan.value && dan.key != izvorDan) {
            if (bcVreme.isNotEmpty) {
              _getControllerBelaCrkva(dan.key).text = bcVreme;
            }
            if (vsVreme.isNotEmpty) {
              _getControllerVrsac(dan.key).text = vsVreme;
            }
          }
        }
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vremena polaska su kopirana na ostale dane'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// ??? OCISTI VREMENA ZA DAN
  void _ocistiVremenaZaDan(String dan) {
    if (mounted) {
      setState(() {
        _getControllerBelaCrkva(dan).clear();
        _getControllerVrsac(dan).clear();
      });
    }
  }

  /// ? POPUNI STANDARDNA VREMENA
  void _popuniStandardnaVremena(String template) {
    if (mounted) {
      setState(() {
        // Popuni samo oznacene radne dane
        final daniZaPopunjavanje =
            _noviRadniDani.entries.where((entry) => entry.value).map((entry) => entry.key).toList();

        switch (template) {
          case 'jutarnja_smena':
            for (final dan in daniZaPopunjavanje) {
              _getControllerBelaCrkva(dan).text = '06:00';
              _getControllerVrsac(dan).text = '14:00';
            }
            break;
          case 'popodnevna_smena':
            for (final dan in daniZaPopunjavanje) {
              _getControllerBelaCrkva(dan).text = '14:00';
              _getControllerVrsac(dan).text = '22:00';
            }
            break;
          case 'skola':
            for (final dan in daniZaPopunjavanje) {
              _getControllerBelaCrkva(dan).text = '07:30';
              _getControllerVrsac(dan).text = '14:00';
            }
            break;
          case 'ocisti':
            for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
              _getControllerBelaCrkva(dan).clear();
              _getControllerVrsac(dan).clear();
            }
            break;
        }
      });
    }

    // Prikaži potvrdu
    final message =
        template == 'ocisti' ? 'Vremena polaska su obrisana' : 'Vremena polaska su popunjena za oznacene dane';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> _getCurrentDriverName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('ime_vozaca') ?? 'Gavra';
  }
}
