import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // DODANO za kDebugMode
import 'package:supabase_flutter/supabase_flutter.dart'; // DODANO za direktne pozive
import '../models/putnik.dart';
import '../models/realtime_route_data.dart'; // 🛰️ DODANO za realtime tracking
import '../services/advanced_route_optimization_service.dart';
import '../services/firebase_service.dart';
import '../services/depozit_service.dart'; // 💸 DODANO za real-time depozit
import '../services/realtime_notification_counter_service.dart'; // 🔔 DODANO za notification count
import '../services/realtime_gps_service.dart'; // 🛰️ DODANO za GPS tracking
import '../services/realtime_notification_service.dart';
import '../services/route_optimization_service.dart';
import '../services/statistika_service.dart'; // DODANO za jedinstvenu logiku pazara
import '../services/realtime_route_tracking_service.dart'; // 🚗 NOVO
import '../services/putnik_service.dart'; // 🆕 DODANO za nove metode
import '../widgets/putnik_list.dart';
import '../widgets/real_time_navigation_widget.dart'; // 🧭 NOVO navigation widget

import '../widgets/bottom_nav_bar_letnji.dart'; // 🚀 DODANO za letnji nav bar
import 'dugovi_screen.dart';
import '../services/local_notification_service.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju gradova

class DanasScreen extends StatefulWidget {
  final String? highlightPutnikIme;
  final String? filterGrad;
  final String? filterVreme;

  const DanasScreen({
    Key? key,
    this.highlightPutnikIme,
    this.filterGrad,
    this.filterVreme,
  }) : super(key: key);

  @override
  State<DanasScreen> createState() => _DanasScreenState();
}

class _DanasScreenState extends State<DanasScreen> {
  final supabase = Supabase.instance.client; // DODANO za direktne pozive
  final _putnikService = PutnikService(); // 🆕 DODANO PutnikService instanca

  // ✨ DIGITALNI BROJAČ DATUM WIDGET - ISTI STIL KAO REZERVACIJE
  Widget _buildDigitalDateDisplay() {
    return StreamBuilder<DateTime>(
      stream:
          Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final dayNames = [
          'PONEDELJAK',
          'UTORAK',
          'SREDA',
          'ČETVRTAK',
          'PETAK',
          'SUBOTA',
          'NEDELJA'
        ];
        final dayName = dayNames[now.weekday - 1];
        final dayStr = now.day.toString().padLeft(2, '0');
        final monthStr = now.month.toString().padLeft(2, '0');
        final yearStr = now.year.toString();

        // VREME - sati, minuti, sekunde
        final hourStr = now.hour.toString().padLeft(2, '0');
        final minuteStr = now.minute.toString().padLeft(2, '0');
        final secondStr = now.second.toString().padLeft(2, '0');

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // GLAVNI TEKST - "SUBOTA 02.08.2025. 14:30:45"
            Container(
              height: 24,
              alignment: Alignment.center,
              child: Text(
                '$dayName $dayStr.$monthStr.$yearStr. $hourStr:$minuteStr:$secondStr',
                style: const TextStyle(
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
          ],
        );
      },
    );
  }

  // ✨ DUGME ZA OPTIMIZACIJU RUTE U APPBAR-U
  Widget _buildOptimizeRouteButton() {
    return StreamBuilder<List<Putnik>>(
      stream: _putnikService.streamKombinovaniPutnici(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();

        final sviPutnici = snapshot.data!;
        final danasnjiDan = _getTodayForDatabase();
        final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

        final danasPutnici = sviPutnici.where((p) {
          final dayMatch =
              p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
          bool timeMatch = true;
          if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
            timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
          }
          return dayMatch && timeMatch;
        }).toList();

        final filtriraniPutnici = danasPutnici.where((putnik) {
          final normalizedStatus = (putnik.status ?? '').toLowerCase().trim();
          final vremeMatch =
              GradAdresaValidator.normalizeTime(putnik.polazak) ==
                  GradAdresaValidator.normalizeTime(_selectedVreme);
          final gradMatch = _isGradMatch(
              putnik.grad, putnik.adresa, _selectedGrad,
              isMesecniPutnik: putnik.mesecnaKarta == true);
          final statusOk = (normalizedStatus != 'otkazano' &&
              normalizedStatus != 'otkazan' &&
              normalizedStatus != 'bolovanje' &&
              normalizedStatus != 'godisnji' &&
              normalizedStatus != 'godišnji' &&
              normalizedStatus != 'obrisan');
          return vremeMatch && gradMatch && statusOk;
        }).toList();

        // Prikaži dugme uvek, ali onemogući ga ako nema putnika
        final hasPassengers = filtriraniPutnici.isNotEmpty;

        return SizedBox(
          height: 24,
          child: ElevatedButton.icon(
            onPressed: _isLoading || !hasPassengers
                ? null
                : () => _optimizeCurrentRoute(filtriraniPutnici),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRouteOptimized
                  ? Colors.green
                  : (hasPassengers ? Colors.white : Colors.grey[300]),
              foregroundColor: _isRouteOptimized
                  ? Colors.white
                  : (hasPassengers ? Colors.blue[700] : Colors.grey[600]),
              elevation: hasPassengers ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            icon: Icon(
              _isRouteOptimized ? Icons.check_circle : Icons.route,
              size: 14,
            ),
            label: Text(
              _isRouteOptimized
                  ? 'OPTIMIZOVANO'
                  : (hasPassengers ? 'OPTIMIZUJ RUTU' : 'NEMA PUTNIKA'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isLoading = false;

  Future<void> _loadPutnici() async {
    setState(() => _isLoading = true);
    // Osloni se na stream, ali možeš ovde dodati logiku za ručno osvežavanje ako bude potrebno
    await Future.delayed(const Duration(milliseconds: 100)); // simulacija
    setState(() => _isLoading = false);
  }

  // _filteredDuznici već postoji, ne treba duplirati
  // VRATITI NA PUTNIK SERVICE - BEZ CACHE-A

  // Depozit kontroler
  final TextEditingController _depozitController = TextEditingController();

  // Optimizacija rute - zadržavam zbog postojeće logike
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];

  // Status varijable - pojednostavljeno
  String _navigationStatus = '';

  // Praćenje navigacije
  bool _isGpsTracking = false;
  DateTime? _lastGpsUpdate;

  // Lista varijable - zadržavam zbog UI
  int _currentPassengerIndex = 0;
  bool _isListReordered = false;
  final bool _useAdvancedNavigation = true;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';
  String? _currentDriver; // Dodato za dohvat vozača

  // Lista polazaka za chipove - LETNJI RASPORED
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

  // Dobij današnji dan u formatu koji se koristi u bazi
  String _getTodayForDatabase() {
    final now = DateTime.now();
    final dayNames = [
      'pon',
      'uto',
      'sre',
      'cet',
      'pet',
      'sub',
      'ned'
    ]; // Koristi iste kratice kao Home screen
    final todayName = dayNames[now.weekday - 1];

    // ✅ UKLONJENA LOGIKA AUTOMATSKOG PREBACIVANJA NA PONEDELJAK
    // Sada vraća pravi trenutni dan u nedelji
    debugPrint('🗓️ [DANAS SCREEN] Današnji dan: $todayName');
    return todayName;
  }

  // ✅ SINHRONIZACIJA SA HOME SCREEN - postavi trenutno vreme i grad
  void _initializeCurrentTime() {
    final now = DateTime.now();
    final currentHour = now.hour;

    // Logika kao u home_screen - odaberi najbliže vreme
    String closestTime = '5:00';
    int minDiff = 24;

    final availableTimes = [
      '5:00',
      '6:00',
      '7:00',
      '8:00',
      '9:00',
      '10:00',
      '11:00',
      '12:00',
      '13:00',
      '14:00',
      '15:30',
      '16:15',
      '18:00',
      '19:00'
    ];

    for (String time in availableTimes) {
      final timeHour = int.tryParse(time.split(':')[0]) ?? 5;
      final diff = (timeHour - currentHour).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestTime = time;
      }
    }

    setState(() {
      _selectedVreme = closestTime;
      // Određi grad na osnovu vremena - kao u home_screen
      if ([
        '5:00',
        '6:00',
        '8:00',
        '10:00',
        '12:00',
        '13:00',
        '14:00',
        '15:30',
        '18:00'
      ].contains(closestTime)) {
        _selectedGrad = 'Bela Crkva';
      } else {
        _selectedGrad = 'Vršac';
      }
    });

    debugPrint(
        '🕐 [DANAS SCREEN] Inicijalizovano vreme: $_selectedVreme, grad: $_selectedGrad');
  }

  @override
  void initState() {
    super.initState();

    // ✅ SETUP FILTERS FROM NOTIFICATION DATA
    if (widget.filterGrad != null) {
      _selectedGrad = widget.filterGrad!;
      debugPrint('🔔 [NOTIFICATION] Setting filter grad: ${widget.filterGrad}');
    }
    if (widget.filterVreme != null) {
      _selectedVreme = widget.filterVreme!;
      debugPrint(
          '🔔 [NOTIFICATION] Setting filter vreme: ${widget.filterVreme}');
    }

    // Ako nema filter podataka iz notifikacije, koristi default logiku
    if (widget.filterGrad == null || widget.filterVreme == null) {
      _initializeCurrentTime(); // ✅ SINHRONIZACIJA - postavi trenutno vreme i grad kao home_screen
    }

    _initializeCurrentDriver();
    _loadPutnici();
    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    RealtimeNotificationService.listenForForegroundNotifications(context);
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
      }
    });
    // Dodato: NIŠTA - koristimo direktne supabase pozive bez cache
    // 🛰️ REALTIME ROUTE TRACKING LISTENER
    _initializeRealtimeTracking();

    // 💸 REAL-TIME DEPOZIT SYNC
    // 💸 DEPOZIT SYNC - SA REAL-TIME
    DepozitService.startRealtimeSync();

    // 🔔 REAL-TIME NOTIFICATION COUNTER
    RealtimeNotificationCounterService.initialize();

    // 🛰️ START GPS TRACKING
    RealtimeGpsService.startTracking().catchError((e) {
      debugPrint('🚨 GPS tracking failed: $e');
    });

    // 🔔 SHOW NOTIFICATION MESSAGE IF PASSENGER NAME PROVIDED
    if (widget.highlightPutnikIme != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationMessage();
      });
    }
  }

  void _initializeRealtimeTracking() {
    // Slušaj realtime route data updates
    RealtimeRouteTrackingService.routeDataStream.listen((routeData) {
      if (mounted) {
        // Ažuriraj poslednji GPS update time
        setState(() {
          _lastGpsUpdate = routeData.timestamp;
        });
      }
    });

    // Slušaj traffic alerts
    RealtimeRouteTrackingService.trafficAlertsStream.listen((alerts) {
      if (mounted && alerts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚨 SAOBRAĆAJNI ALERT!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...alerts.map((alert) => Text('• $alert')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });
  }

  // 🔔 SHOW NOTIFICATION MESSAGE WHEN OPENED FROM NOTIFICATION
  void _showNotificationMessage() {
    if (widget.highlightPutnikIme == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notification_important, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 Otvoreno iz notifikacije',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Putnik: ${widget.highlightPutnikIme} | ${widget.filterGrad} ${widget.filterVreme}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// 🔍 GRAD POREĐENJE - razlikuj mesečne i obične putnike
  bool _isGradMatch(
      String? putnikGrad, String? putnikAdresa, String selectedGrad,
      {bool isMesecniPutnik = false}) {
    // Za mesečne putnike - direktno poređenje grada
    if (isMesecniPutnik) {
      return putnikGrad == selectedGrad;
    }
    // Za obične putnike - koristi adresnu validaciju
    return GradAdresaValidator.isGradMatch(
        putnikGrad, putnikAdresa, selectedGrad);
  }

  Future<void> _initializeCurrentDriver() async {
    _currentDriver = await FirebaseService.getCurrentDriver();
    // Učitaj depozit tek kada se vozač učita
    if (_currentDriver != null) {
      _initializeDepozit();
    }
  }

  Future<void> _initializeDepozit() async {
    final value = await _loadDepozit();
    if (value != null && mounted) {
      setState(() {
        _depozitController.text = value;
      });
    }
  }

  @override
  void dispose() {
    // Uklonjen cache listener poziv
    _depozitController.dispose();

    // 🛑 Zaustavi realtime tracking kad se ekran zatvori
    RealtimeRouteTrackingService.stopRouteTracking();

    super.dispose();
  }

  // Uklonjeno ručno učitavanje putnika, koristi se stream

  // Uklonjeno: _calculateDnevniPazar

  // Uklonjeno, filtriranje ide u StreamBuilder

  // Filtriranje dužnika ide u StreamBuilder

  Future<void> _saveDepozit(String value) async {
    if (_currentDriver == null) return; // Proveri da li je vozač logovan

    final iznos = double.tryParse(value) ?? 0.0;
    await DepozitService.saveDepozit(
        _currentDriver!, iznos); // 💸 REAL-TIME SAVE
  }

  Future<String?> _loadDepozit() async {
    if (_currentDriver == null) return null; // Proveri da li je vozač logovan

    final iznos =
        await DepozitService.loadDepozit(_currentDriver!); // 💸 REAL-TIME LOAD
    return iznos > 0 ? iznos.toString() : null;
  }

  double _getDepozitValue() {
    final text = _depozitController.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  // Optimizacija rute za trenutni polazak (napredna verzija)
  void _optimizeCurrentRoute(List<Putnik> putnici) async {
    // 🎯 SAMO REORDER PUTNIKA - bez otvaranja mape
    final filtriraniPutnici = putnici.where((p) {
      final normalizedStatus = (p.status ?? '').toLowerCase().trim();

      final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) ==
          GradAdresaValidator.normalizeTime(_selectedVreme);

      // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - samo Bela Crkva i Vršac
      final gradMatch = _isGradMatch(p.grad, p.adresa, _selectedGrad);

      final danMatch = p.dan == _getTodayForDatabase();
      final statusOk = (normalizedStatus != 'otkazano' &&
          normalizedStatus != 'otkazan' &&
          normalizedStatus != 'bolovanje' &&
          normalizedStatus != 'godisnji' &&
          normalizedStatus != 'godišnji' &&
          normalizedStatus != 'obrisan');
      final hasAddress = p.adresa != null && p.adresa!.isNotEmpty;

      return vremeMatch && gradMatch && danMatch && statusOk && hasAddress;
    }).toList();

    if (filtriraniPutnici.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Nema putnika sa adresama za reorder'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // 🎯 OPTIMIZUJ REDOSLED PUTNIKA (bez mape)
      final optimizedPutnici =
          await AdvancedRouteOptimizationService.optimizeRouteAdvanced(
        filtriraniPutnici,
        startAddress: _selectedGrad == 'Bela Crkva'
            ? 'Bela Crkva, Serbia'
            : 'Vršac, Serbia',
        departureTime: DateTime.now(),
        useTrafficData: true,
        useMLOptimization: true,
      );

      setState(() {
        _optimizedRoute = optimizedPutnici;
        _isRouteOptimized = true;
        _isListReordered = true; // ✅ Lista je reorderovana
        _currentPassengerIndex = 0; // ✅ Počni od prvog putnika
        _isGpsTracking = true; // 🛰️ Pokreni GPS tracking
        _lastGpsUpdate = DateTime.now(); // 🛰️ Zapamti vreme
      });

      // Prikaži rezultat reorderovanja
      final routeString = optimizedPutnici
          .take(3) // Prikaži prva 3 putnika
          .map((p) => p.adresa?.split(',').first ?? p.ime)
          .join(' → ');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '🎯 LISTA PUTNIKA REORDEROVANA za $_selectedGrad $_selectedVreme!',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    '📍 Sledeći putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
                Text('🎯 Broj putnika: ${optimizedPutnici.length}'),
                const Text('🛰️ Sledite listu odozgo nadole!'),
              ],
            ),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Fallback na osnovnu optimizaciju
      final fallbackOptimized =
          await RouteOptimizationService.optimizeRouteGeographically(
        filtriraniPutnici,
        startAddress: _selectedGrad == 'Bela Crkva'
            ? 'Bela Crkva, Serbia'
            : 'Vršac, Serbia',
      );

      setState(() {
        _optimizedRoute = fallbackOptimized;
        _isRouteOptimized = true;
        _isListReordered = true;
        _currentPassengerIndex = 0;
        _isGpsTracking = true;
        _lastGpsUpdate = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '⚠️ Koristim osnovnu GPS optimizaciju (napredna nije dostupna)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // DATUM TEKST - kao rezervacije
                  _buildDigitalDateDisplay(),
                  const SizedBox(height: 4),
                  // DUGME ZA OPTIMIZACIJU RUTE
                  _buildOptimizeRouteButton(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Putnik>>(
              stream: _putnikService
                  .streamKombinovaniPutnici(), // 🔄 KOMBINOVANI STREAM (mesečni + dnevni)
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Greška: ${snapshot.error}'),
                  );
                }

                final sviPutnici = snapshot.data ?? [];
                final danasnjiDan = _getTodayForDatabase();

                debugPrint(
                    '🕐 [DANAS SCREEN] Filter: $danasnjiDan, $_selectedVreme, $_selectedGrad'); // ✅ DEBUG

                // 🔄 REAL-TIME FILTRIRANJE - kombinuj sa vremenskim filterom poslednje nedelje
                final oneWeekAgo =
                    DateTime.now().subtract(const Duration(days: 7));

                final danasPutnici = sviPutnici.where((p) {
                  // Dan u nedelji filter
                  final dayMatch =
                      p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());

                  // Vremski filter - samo poslednja nedelja za dnevne putnike
                  bool timeMatch = true;
                  if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
                    timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
                  }

                  return dayMatch && timeMatch;
                }).toList();

                final vreme = _selectedVreme;
                final grad = _selectedGrad;

                final filtriraniPutnici = danasPutnici.where((putnik) {
                  final normalizedStatus =
                      (putnik.status ?? '').toLowerCase().trim();

                  final vremeMatch =
                      GradAdresaValidator.normalizeTime(putnik.polazak) ==
                          GradAdresaValidator.normalizeTime(vreme);

                  // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                  final gradMatch = _isGradMatch(
                      putnik.grad, putnik.adresa, grad,
                      isMesecniPutnik: putnik.mesecnaKarta == true);

                  final statusOk = (normalizedStatus != 'otkazano' &&
                      normalizedStatus != 'otkazan' &&
                      normalizedStatus != 'bolovanje' &&
                      normalizedStatus != 'godisnji' &&
                      normalizedStatus != 'godišnji' &&
                      normalizedStatus != 'obrisan');

                  return vremeMatch && gradMatch && statusOk;
                }).toList();

                // Koristiti optimizovanu rutu ako postoji, ali filtriraj je po trenutnom polazaku
                final finalPutnici = _isRouteOptimized
                    ? _optimizedRoute.where((putnik) {
                        final normalizedStatus =
                            (putnik.status ?? '').toLowerCase().trim();

                        final vremeMatch =
                            GradAdresaValidator.normalizeTime(putnik.polazak) ==
                                GradAdresaValidator.normalizeTime(vreme);

                        // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                        final gradMatch = _isGradMatch(
                            putnik.grad, putnik.adresa, grad,
                            isMesecniPutnik: putnik.mesecnaKarta == true);

                        final statusOk = (normalizedStatus != 'otkazano' &&
                            normalizedStatus != 'otkazan' &&
                            normalizedStatus != 'bolovanje' &&
                            normalizedStatus != 'godisnji' &&
                            normalizedStatus != 'godišnji' &&
                            normalizedStatus != 'obrisan');

                        return vremeMatch && gradMatch && statusOk;
                      }).toList()
                    : filtriraniPutnici;
                final filteredDuznici = danasPutnici.where((putnik) {
                  final nijePlatio = (putnik.iznosPlacanja == null ||
                      putnik.iznosPlacanja == 0);
                  final nijeOtkazan =
                      putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                  final jesteMesecni = putnik.mesecnaKarta == true;
                  final pokupljen = putnik.pokupljen == true;
                  return nijePlatio &&
                      nijeOtkazan &&
                      !jesteMesecni &&
                      pokupljen;
                }).toList();
                // KORISTI NOVU STANDARDIZOVANU LOGIKU ZA PAZAR 💰
                final today = DateTime.now();
                final dayStart = DateTime(today.year, today.month, today.day);
                final dayEnd =
                    DateTime(today.year, today.month, today.day, 23, 59, 59);

                if (kDebugMode) {}

                return StreamBuilder<double>(
                  stream: StatistikaService.streamPazarZaVozaca(
                      _currentDriver ?? '',
                      from: dayStart,
                      to: dayEnd), // 🔄 REAL-TIME PAZAR STREAM
                  builder: (context, pazarSnapshot) {
                    if (!pazarSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    double ukupnoPazarVozac = pazarSnapshot.data!;

                    // Mesečne karte su već uključene u pazarZaVozaca funkciju
                    final depozitValue = _getDepozitValue();
                    final ukupnoPazar = ukupnoPazarVozac + depozitValue;
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 70,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.green[300]!),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Pazar',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green)),
                                      const SizedBox(height: 4),
                                      Text(ukupnoPazar.toStringAsFixed(0),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                          textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 70,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.yellow[700]!),
                                  ),
                                  child: StreamBuilder<Map<String, double>>(
                                    stream: DepozitService
                                        .depozitStream, // 💸 REAL-TIME DEPOZIT STREAM
                                    builder: (context, depozitSnapshot) {
                                      // Koristi real-time vrednost ako je dostupna, inače local controller
                                      final currentValue =
                                          depozitSnapshot.hasData &&
                                                  _currentDriver != null
                                              ? (depozitSnapshot
                                                      .data![_currentDriver!] ??
                                                  0.0)
                                              : _getDepozitValue();

                                      // Ažuriraj controller samo ako se vrednost promenila
                                      if (currentValue > 0 &&
                                          _depozitController.text !=
                                              currentValue.toString()) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          _depozitController.text =
                                              currentValue.toString();
                                        });
                                      }

                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Depozit',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange)),
                                          const SizedBox(height: 4),
                                          Flexible(
                                            child: SizedBox(
                                              height: 24,
                                              child: TextField(
                                                controller: _depozitController,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.orange,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                decoration:
                                                    const InputDecoration(
                                                  hintText: '0',
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  isDense: true,
                                                ),
                                                textAlign: TextAlign.center,
                                                onChanged: (value) {
                                                  _saveDepozit(
                                                      value); // 💸 REAL-TIME SAVE
                                                  setState(
                                                      () {}); // Trigger rebuild za pazar
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 70,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.purple[300]!),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Mesečne',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple)),
                                      SizedBox(height: 4),
                                      Text(
                                        '0',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 70,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DugoviScreen(
                                              currentDriver: _currentDriver),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Dugovi',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red)),
                                        const SizedBox(height: 4),
                                        Text(
                                          filteredDuznici.length.toString(),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: finalPutnici.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Nema putnika za izabrani polazak',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : Column(
                                  children: [
                                    if (_isRouteOptimized)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: _isGpsTracking
                                              ? Colors.blue[50]
                                              : Colors.green[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: _isGpsTracking
                                                  ? Colors.blue[300]!
                                                  : Colors.green[300]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                                _isGpsTracking
                                                    ? Icons.gps_fixed
                                                    : Icons.route,
                                                color: _isGpsTracking
                                                    ? Colors.blue
                                                    : Colors.green,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _isListReordered
                                                        ? '🎯 Lista Reorderovana (${_currentPassengerIndex + 1}/${_optimizedRoute.length})'
                                                        : (_isGpsTracking
                                                            ? '🛰️ GPS Tracking AKTIVAN'
                                                            : 'Ruta optimizovana'),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _isListReordered
                                                          ? Colors.orange[700]
                                                          : (_isGpsTracking
                                                              ? Colors.blue
                                                              : Colors.green),
                                                    ),
                                                  ),
                                                  // 🎯 PRIKAZ TRENUTNOG PUTNIKA
                                                  if (_isListReordered &&
                                                      _currentPassengerIndex <
                                                          _optimizedRoute
                                                              .length)
                                                    Text(
                                                      '👤 SLEDEĆI: ${_optimizedRoute[_currentPassengerIndex].ime}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.orange[600],
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  // 🧭 PRIKAZ NAVIGATION STATUS-A
                                                  if (_useAdvancedNavigation &&
                                                      _navigationStatus
                                                          .isNotEmpty)
                                                    Text(
                                                      '🧭 $_navigationStatus',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            Colors.indigo[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  if (_isGpsTracking &&
                                                      _lastGpsUpdate != null)
                                                    StreamBuilder<
                                                        RealtimeRouteData>(
                                                      stream:
                                                          RealtimeRouteTrackingService
                                                              .routeDataStream,
                                                      builder: (context,
                                                          realtimeSnapshot) {
                                                        if (realtimeSnapshot
                                                            .hasData) {
                                                          final data =
                                                              realtimeSnapshot
                                                                  .data!;
                                                          final speed = data
                                                                  .currentSpeed
                                                                  ?.toStringAsFixed(
                                                                      1) ??
                                                              '0.0';
                                                          final completion = data
                                                              .routeCompletionPercentage
                                                              .toStringAsFixed(
                                                                  0);
                                                          return Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'REALTIME: $speed km/h • $completion% završeno',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                          .blue[
                                                                      700],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                              if (data.nextDestination !=
                                                                  null)
                                                                Text(
                                                                  'Sledeći: ${data.nextDestination!.ime}',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize: 9,
                                                                    color: Colors
                                                                            .blue[
                                                                        600],
                                                                  ),
                                                                ),
                                                            ],
                                                          );
                                                        } else {
                                                          return Text(
                                                            'Poslednji update: ${_lastGpsUpdate!.hour}:${_lastGpsUpdate!.minute.toString().padLeft(2, '0')}',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .blue[700],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  // 🔄 REAL-TIME ROUTE STRING
                                                  StreamBuilder<String>(
                                                    stream: Stream
                                                        .fromIterable([
                                                      finalPutnici
                                                    ]).map((putnici) =>
                                                        RouteOptimizationService
                                                            .generateRouteStringSync(
                                                                putnici)),
                                                    initialData:
                                                        RouteOptimizationService
                                                            .generateRouteStringSync(
                                                                finalPutnici),
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Text(
                                                          snapshot.data!,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                _isGpsTracking
                                                                    ? Colors
                                                                        .blue
                                                                    : Colors
                                                                        .green,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        );
                                                      } else {
                                                        return const Text(
                                                          'Učitavanje...',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.green,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // 🧭 NOVO: Real-time navigation widget
                                    if (_useAdvancedNavigation &&
                                        _optimizedRoute.isNotEmpty)
                                      RealTimeNavigationWidget(
                                        optimizedRoute: _optimizedRoute,
                                        onStatusUpdate: (message) {
                                          setState(() {
                                            _navigationStatus = message;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(message),
                                                duration:
                                                    const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        onRouteUpdate: (newRoute) {
                                          setState(() {
                                            _optimizedRoute = newRoute;
                                          });
                                        },
                                        showDetailedInstructions: true,
                                        enableVoiceInstructions: false,
                                      ),
                                    Expanded(
                                      child: PutnikList(
                                        putnici: finalPutnici,
                                        currentDriver: _currentDriver,
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
                                          '18:00'
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
                                          '19:00'
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: StreamBuilder<List<Putnik>>(
        stream: _putnikService
            .streamKombinovaniPutnici(), // 🔄 KOMBINOVANI STREAM (mesečni + dnevni)
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              snapshot.hasError ||
              !snapshot.hasData) {
            return Container(
                height: 0); // Ne prikazuj nav bar ako nema podataka
          }

          final allPutnici = snapshot.data!;
          final danasnjiDan = _getTodayForDatabase();
          final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

          debugPrint(
              '🔍 [DANAS SCREEN] Ukupno putnika iz stream-a: ${allPutnici.length}');
          debugPrint('🔍 [DANAS SCREEN] Današnji dan: $danasnjiDan');

          // 🔄 REAL-TIME FILTRIRANJE za bottom nav
          final todayPutnici = allPutnici.where((p) {
            final dayMatch =
                p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
            bool timeMatch = true;
            if (p.mesecnaKarta != true && p.vremeDodavanja != null) {
              timeMatch = p.vremeDodavanja!.isAfter(oneWeekAgo);
            }

            debugPrint(
                '📍 [DANAS SCREEN] Putnik: ${p.ime}, dan: ${p.dan}, dayMatch: $dayMatch, timeMatch: $timeMatch');

            return dayMatch && timeMatch;
          }).toList();

          debugPrint(
              '🔍 [DANAS SCREEN] Filtrirani putnici za danas: ${todayPutnici.length}');

          // Funkcija za brojanje putnika po gradu, vremenu i danu (samo aktivni)
          int getPutnikCount(String grad, String vreme) {
            final matchingPutnici = todayPutnici.where((putnik) {
              final normalizedStatus =
                  (putnik.status ?? '').toLowerCase().trim();

              // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
              final gradMatch = _isGradMatch(putnik.grad, putnik.adresa, grad,
                  isMesecniPutnik: putnik.mesecnaKarta == true);

              final vremeMatch =
                  GradAdresaValidator.normalizeTime(putnik.polazak) ==
                      GradAdresaValidator.normalizeTime(vreme);
              final danMatch =
                  putnik.dan.toLowerCase().contains(danasnjiDan.toLowerCase());
              final statusOk = (normalizedStatus != 'otkazano' &&
                  normalizedStatus != 'otkazan' &&
                  normalizedStatus != 'bolovanje' &&
                  normalizedStatus != 'godisnji' &&
                  normalizedStatus != 'obrisan');

              debugPrint(
                  '🎯 [COUNT] Putnik: ${putnik.ime}, grad: "${putnik.grad}" vs "$grad", vreme: "${putnik.polazak}" vs "$vreme", status: "${putnik.status}", gradMatch: $gradMatch, vremeMatch: $vremeMatch, statusOk: $statusOk');

              return gradMatch && vremeMatch && danMatch && statusOk;
            }).toList();

            debugPrint(
                '📊 [COUNT] Za $grad $vreme: ${matchingPutnici.length} putnika');
            return matchingPutnici.length;
          }

          return BottomNavBarLetnji(
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
                // Force rebuild da prikaže nove putnike
              });

              // 🔄 REFRESH putnika kada se promeni vreme polaska
              // setState() će automatski reload-ovati widget sa novom logikom
              debugPrint(
                  '🔄 VREME POLASKA PROMENJENO: $grad $vreme - widget će se ažurirati nakon resetovanja pokupljanja');
            },
          );
        },
      ),
    );
  }
}
