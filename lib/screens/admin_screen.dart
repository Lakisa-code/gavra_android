import 'package:flutter/material.dart';
import 'package:gavra_android/services/putnik_service.dart';

import '../models/putnik.dart';
import '../services/depozit_service.dart'; // 💸 DODANO za real-time depozit
import '../services/firebase_service.dart';
import '../services/local_notification_service.dart';
import '../services/mesecni_putnik_service.dart'; // DODANO za kreiranje dnevnih putovanja
import '../services/realtime_notification_service.dart';
import '../services/statistika_service.dart'; // DODANO za jedinstvenu logiku pazara
import '../utils/vozac_boja.dart';
import '../widgets/dug_button.dart';
import 'admin_map_screen.dart';
import 'dugovi_screen.dart';
import 'mesecni_putnici_screen.dart'; // DODANO za mesečne putnike
import 'statistika_screen.dart'; // DODANO za statistike

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String? _currentDriver;

  final PutnikService _putnikService = PutnikService();

  // 💸 DEPOZITI - sa real-time stream
  Map<String, double> _depoziti = {};

  //
  // Statistika pazara

  // Filter za dan
  String _selectedDan = '';

  @override
  void initState() {
    super.initState();
    _selectedDan = _getTodayFullName();
    _loadCurrentDriver();

    // Inicijalizuj heads-up i zvuk notifikacije
    try {
      LocalNotificationService.initialize(context);
      RealtimeNotificationService.listenForForegroundNotifications(context);
    } catch (e) {
      // Error handling for notification services
    }

    // 💸 REAL-TIME DEPOZIT SYNC
    // 💸 DEPOZIT SYNC - SA REAL-TIME
    DepozitService.startRealtimeSync();

    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty) {
        RealtimeNotificationService.initialize();
        _initializeDepoziti(); // Učitaj depozite iz baze
      }
    }).catchError((e) {
      // Error handling for getCurrentDriver
    });
  }

  @override
  void dispose() {
    // Real-time stream se automatski zatvaraju
    super.dispose();
  }

  // 💸 DEPOZIT METODE
  Future<void> _initializeDepoziti() async {
    try {
      final depoziti = await DepozitService.loadAllDepozits();
      if (mounted) {
        setState(() {
          _depoziti = depoziti;
        });
      }
    } catch (e) {
      debugPrint('🚨 Greška pri učitavanju depozita: $e');
    }
  }

  void _loadCurrentDriver() async {
    try {
      final driver = await FirebaseService.getCurrentDriver().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          return null;
        },
      );
      setState(() {
        _currentDriver = driver;
      });
    } catch (e) {
      setState(() {
        _currentDriver = null;
      });
    }
  }

  // Vraca puno ime trenutnog dana
  String _getTodayFullName() {
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

    // ✅ UKLONJENA LOGIKA AUTOMATSKOG PREBACIVANJA NA PONEDELJAK
    // Sada vraća pravi trenutni dan u nedelji
    return todayName;
  }

  // Mapiranje punih imena dana u skraćenice za filtriranje
  String _getShortDayName(String fullDayName) {
    final dayMapping = {
      'Ponedeljak': 'Pon',
      'Utorak': 'Uto',
      'Sreda': 'Sre',
      'Četvrtak': 'Čet',
      'Petak': 'Pet',
      'Subota': 'Sub',
      'Nedelja': 'Ned',
      '': '', // Prazno ostaje prazno
    };
    return dayMapping[fullDayName] ?? fullDayName;
  }

  // Filtriranje ide u StreamBuilder

  // Očišćeno: realtime logika je sada u StreamBuilder-u

  // Color _getVozacColor(String vozac) { ... } // unused

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // 🎨 Seksi svetla pozadina
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
                  // PRVI RED - Admin Panel
                  Container(
                    height: 24,
                    alignment: Alignment.center,
                    child: const Text(
                      'A D M I N   P A N E L',
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
                  // DRUGI RED - Admin ikone
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      const spacing = 4.0; // Razmak između dugmića
                      const totalSpacing =
                          spacing * 3; // 3 razmaka između 4 dugmeta
                      final availableWidth = screenWidth - totalSpacing;
                      final buttonWidth =
                          availableWidth / 4; // Maksimalna širina za svaki

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // KREIRAJ PUTOVANJA - levo
                          SizedBox(
                            width: buttonWidth,
                            child: InkWell(
                              onTap: _kreirajDnevnaPutovanja,
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
                                          Icons.auto_awesome,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'Kreiraj',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // MESEČNI PUTNICI - levo-sredina
                          SizedBox(
                            width: buttonWidth,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MesecniPutniciScreen(),
                                ),
                              ),
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
                                          Icons.people_alt,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'Putnici',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // STATISTIKE - desno-sredina
                          SizedBox(
                            width: buttonWidth,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const StatistikaScreen(),
                                ),
                              ),
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
                                          Icons.analytics,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          'Statistike',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // DROPDOWN - desno
                          SizedBox(
                            width: buttonWidth,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedDan.isEmpty
                                      ? null
                                      : _selectedDan,
                                  hint: const Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Icon(
                                        Icons.calendar_today,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                  selectedItemBuilder: (BuildContext context) {
                                    return [
                                      '',
                                      'Ponedeljak',
                                      'Utorak',
                                      'Sreda',
                                      'Četvrtak',
                                      'Petak',
                                      'Subota',
                                      'Nedelja'
                                    ].map<Widget>((String value) {
                                      return Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            value.isEmpty ? '' : value,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  icon: const SizedBox.shrink(),
                                  dropdownColor: const Color(0xFF4F7EFC),
                                  style: const TextStyle(color: Colors.white),
                                  items: [
                                    '',
                                    'Ponedeljak',
                                    'Utorak',
                                    'Sreda',
                                    'Četvrtak',
                                    'Petak',
                                    'Subota',
                                    'Nedelja'
                                  ].map((dan) {
                                    return DropdownMenuItem<String>(
                                      value: dan,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              dan.isEmpty ? 'Svi dani' : dan,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedDan = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Putnik>>(
        stream: _putnikService.streamPutnici(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Učitavanje admin panela...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('Greška: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Pokušaj ponovo
                    },
                    child: const Text('Pokušaj ponovo'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPutnici = snapshot.data!;
          final filteredPutnici = allPutnici.where((putnik) {
            // 🗓️ FILTER PO DANU - Samo po danu nedelje
            if (_selectedDan.isEmpty) return true; // SVE
            final shortDayName = _getShortDayName(_selectedDan);
            return putnik.dan == shortDayName;
          }).toList();
          final filteredDuznici = filteredPutnici.where((putnik) {
            final nijePlatio =
                (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0);
            final nijeOtkazan =
                putnik.status != 'otkazan' && putnik.status != 'Otkazano';
            final jesteMesecni = putnik.mesecnaKarta == true;
            final pokupljen = putnik.pokupljen == true;
            return nijePlatio && nijeOtkazan && !jesteMesecni && pokupljen;
          }).toList();
          // Izračunaj pazar po vozačima - KORISTI DIREKTNO filteredPutnici UMESTO DATUMA 💰
          // ✅ ISPRAVKA: Umesto kalkulacije datuma, koristi već filtrirane putnike po danu
          // Ovo omogućava prikaz pazara za odabrani dan (Pon, Uto, itd.) direktno

          return FutureBuilder<Map<String, double>>(
            future: StatistikaService.pazarSvihVozaca(
              filteredPutnici,
              from: null, // Koristićemo default vrednosti (današnji dan)
              to: null,
            ),
            builder: (context, pazarSnapshot) {
              if (!pazarSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final pazarMap = pazarSnapshot.data!;
              final ukupno = pazarMap['_ukupno'] ?? 0.0;

              // Ukloni '_ukupno' ključ za čist prikaz
              final Map<String, double> pazar = Map.from(pazarMap)
                ..remove('_ukupno');

              // 👥 FILTER PO VOZAČU - Prikaži samo naplate trenutnog vozača ili sve za admin
              final bool isAdmin =
                  _currentDriver == 'Bojan' || _currentDriver == 'Svetlana';

              Map<String, double> filteredPazar;
              if (isAdmin) {
                // Admin vidi sve vozače
                filteredPazar = pazar;
              } else {
                // Vozač vidi samo svoj pazar
                filteredPazar = {
                  if (pazar.containsKey(_currentDriver))
                    _currentDriver!: pazar[_currentDriver!]!
                };
              }

              const Map<String, Color> vozacBoje = VozacBoja.boje;
              final List<String> vozaciRedosled = [
                'Bruda',
                'Bilevski',
                'Bojan',
                'Svetlana'
              ];

              // Filter vozače redosled na osnovu trenutnog vozača
              final List<String> prikazaniVozaci = isAdmin
                  ? vozaciRedosled
                  : vozaciRedosled.where((v) => v == _currentDriver).toList();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            _selectedDan.isEmpty
                                ? (isAdmin
                                    ? 'Sedmični pazar po vozačima'
                                    : 'Moj sedmični pazar')
                                : (isAdmin
                                    ? 'Dnevni pazar - $_selectedDan'
                                    : 'Moj pazar - $_selectedDan'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _selectedDan.isEmpty
                                ? Icons.view_week
                                : Icons.today,
                            color: Colors.blue[600],
                            size: 20,
                          ),
                          if (!isAdmin) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.person,
                              color: Colors.green[600],
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 💡 Info box o sedmičnom prikazu
                    if (_selectedDan.isEmpty && isAdmin)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.blue[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.blue[600], size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Za sedmični pazar (Pon-Pet) idi u Statistike → Vozači → Pon-Pet',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 👤 Info box za individualnog vozača
                    if (!isAdmin)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.green[200]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person,
                                color: Colors.green[600], size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Prikazuju se samo VAŠE naplate, vozač: $_currentDriver',
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
                    const SizedBox(height: 12),
                    // 👥 VOZAČI + DEPOZIT (REAL-TIME)
                    StreamBuilder<Map<String, double>>(
                      stream: DepozitService.depozitStream,
                      initialData: _depoziti,
                      builder: (context, snapshot) {
                        final depoziti = snapshot.data ?? _depoziti;

                        return Column(
                          children: prikazaniVozaci
                              .map(
                                (vozac) => Container(
                                  width: double.infinity,
                                  height: 60,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (vozacBoje[vozac] ?? Colors.blueGrey)
                                        .withAlpha(
                                      20,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (vozacBoje[vozac] ?? Colors.blueGrey)
                                              .withAlpha(
                                        70,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            vozacBoje[vozac] ?? Colors.blueGrey,
                                        radius: 16,
                                        child: Text(
                                          vozac[0],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              vozac,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: vozacBoje[vozac] ??
                                                    Colors.blueGrey,
                                              ),
                                            ),
                                            Text(
                                              isAdmin
                                                  ? 'Vozač (+ depozit)'
                                                  : 'Moje naplate',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.monetization_on,
                                            color: vozacBoje[vozac] ??
                                                Colors.blueGrey,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${((filteredPazar[vozac] ?? 0.0) + (depoziti[vozac] ?? 0.0)).toStringAsFixed(0)} RSD',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: vozacBoje[vozac] ??
                                                  Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    DugButton(
                      brojDuznika: filteredDuznici.length,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DugoviScreen(
                              // duznici: filteredDuznici,
                              currentDriver: _currentDriver,
                            ),
                          ),
                        );
                      },
                      wide: true,
                    ),
                    const SizedBox(height: 4),
                    // 💸 DEPOZIT KOCKE (REAL-TIME)
                    StreamBuilder<Map<String, double>>(
                      stream: DepozitService.depozitStream,
                      initialData: _depoziti,
                      builder: (context, snapshot) {
                        final depoziti = snapshot.data ?? _depoziti;

                        return Container(
                          width: double.infinity,
                          height: 60,
                          margin: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              // Depozit za Bruda
                              Expanded(
                                child: Container(
                                  height: 60,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.purple[300]!, width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.savings,
                                        color: Colors.purple[700],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DEPOZIT',
                                        style: TextStyle(
                                          color: Colors.purple[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[100],
                                            border: Border.all(
                                              color: Colors.purple[300]!,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${(depoziti['Bruda'] ?? 0.0).toStringAsFixed(0)} RSD',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.purple[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Depozit za Bilevski
                              Expanded(
                                child: Container(
                                  height: 60,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange[300]!, width: 1.2),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.savings,
                                        color: Colors.orange[700],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'DEPOZIT',
                                        style: TextStyle(
                                          color: Colors.orange[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            border: Border.all(
                                              color: Colors.orange[300]!,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${(depoziti['Bilevski'] ?? 0.0).toStringAsFixed(0)} RSD',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // UKUPAN PAZAR
                    Container(
                      width: double.infinity,
                      height: 70,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green[300]!, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Text(
                                isAdmin ? 'UKUPAN PAZAR' : 'MOJ UKUPAN PAZAR',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              // 💰 REAL-TIME UKUPAN PAZAR
                              // 💰 UKUPAN PAZAR (REAL-TIME)
                              StreamBuilder<Map<String, double>>(
                                stream: DepozitService.depozitStream,
                                initialData: _depoziti,
                                builder: (context, snapshot) {
                                  final depoziti = snapshot.data ?? _depoziti;
                                  final double mojPazar = isAdmin
                                      ? ukupno
                                      : filteredPazar.values
                                          .fold(0.0, (sum, val) => sum + val);
                                  final double depozitTotal = isAdmin
                                      ? (depoziti['Bruda'] ?? 0.0) +
                                          (depoziti['Bilevski'] ?? 0.0)
                                      : 0.0;
                                  final double ukupnoFinal =
                                      mojPazar + depozitTotal;

                                  return Text(
                                    '${ukupnoFinal.toStringAsFixed(0)} RSD',
                                    style: TextStyle(
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 🗺️ SEKSI ADMIN MAPA KOCKA - Depozit Style
                    Container(
                      width: double.infinity,
                      height: 60,
                      margin: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // 🗺️ OTVORI FLUTTER MAPU SA SVIM VOZAČIMA
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminMapScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                height: 60,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00D4FF),
                                      Color(0xFF0077BE)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF0077BE),
                                      width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D4FF)
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'GPS MAPA',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 14,
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
              );
            },
          );
        },
      ),
    );
  }

  // Kreiraj dnevna putovanja iz mesečnih putnika
  Future<void> _kreirajDnevnaPutovanja() async {
    // Pokaži dialog za odabir perioda
    final rezultat = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kreiranje dnevnih putovanja'),
          content: const Text(
              'Za koliko dana unapred želite da kreirate putovanja iz mesečnih putnika?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(1),
              child: const Text('Samo danas'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(7),
              child: const Text('7 dana (nedelja)'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(30),
              child: const Text('30 dana (mesec)'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Otkaži'),
            ),
          ],
        );
      },
    );

    if (rezultat == null) return;

    // Pokaži indikator učitavanja
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Kreiram putovanja...'),
            ],
          ),
        );
      },
    );

    try {
      final brojKreiranih =
          await MesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
              danaUnapred: rezultat);

      // Sakri indikator učitavanja
      if (mounted) Navigator.of(context).pop();

      // Pokaži rezultat
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kreirano $brojKreiranih novih putovanja za $rezultat ${rezultat == 1 ? 'dan' : 'dana'}!',
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Sakri indikator učitavanja
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // String _getTodayName() { ... } // unused

  // (Funkcija za dijalog sa dužnicima je uklonjena - sada se koristi DugoviScreen)
}
