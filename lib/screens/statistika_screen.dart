import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/statistika_service.dart';
import '../services/local_notification_service.dart';
import '../utils/date_utils.dart'
    as app_date_utils; // DODANO: Centralna vikend logika

import '../models/putnik.dart';
import '../services/putnik_service.dart';
import '../widgets/detaljan_pazar_po_vozacima_widget.dart';
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje
import '../theme.dart'; // DODANO za theme extensions

import '../utils/logging.dart';

class StatistikaScreen extends StatefulWidget {
  const StatistikaScreen({Key? key}) : super(key: key);

  @override
  State<StatistikaScreen> createState() => _StatistikaScreenState();
}

class _StatistikaScreenState extends State<StatistikaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _period = 'nedelja'; // nedelja, mesec, godina
  final List<String> _periods = ['nedelja', 'mesec', 'godina'];
  int _selectedYear = DateTime.now().year; // 🆕 Dodato za izbor godine
  List<int> _availableYears = []; // 🆕 Lista dostupnih godina
  String? _currentDriver;
  bool _checkedDriver = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // Promenjeno sa 3 na 2
    _tabController.addListener(() {
      setState(() {}); // Refresh UI kada se promeni tab
    });
    _initializeAvailableYears(); // 🆕 Inicijalizuj dostupne godine
    _checkDriver();
    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty && mounted) {
        RealtimeNotificationService.initialize();
        RealtimeNotificationService.listenForForegroundNotifications(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkDriver() async {
    final driver = await FirebaseService.getCurrentDriver();
    setState(() {
      _currentDriver = driver;
      _checkedDriver = true;
    });
  }

  /// 🆕 INICIJALIZUJ DOSTUPNE GODINE IZ BAZE
  void _initializeAvailableYears() {
    // Za sada dodajem nekoliko godina (možemo kasnije proširiti da čita iz baze)
    final currentYear = DateTime.now().year;
    _availableYears =
        List.generate(5, (i) => currentYear - i); // Poslednje 5 godina
    if (mounted) setState(() {});
  }

  /// 🔄 RESETUJ SVE KILOMETRAŽE - briše sve GPS pozicije
  Future<void> _resetujKilometrazu() async {
    // Pokaži potvrdu pre brisanja
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Resetovanje kilometraže'),
        content: const Text(
          'Da li ste sigurni da želite da resetujete SVE kilometraže na 0?\n\n'
          'Ova akcija će obrisati sve GPS pozicije i NIJE MOGUĆE poništiti je!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.dangerPrimary),
            child: const Text('DA, RESETUJ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (potvrda != true) return;

    // Pokaži loading
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Resetujem kilometražu...'),
          ],
        ),
      ),
    );

    try {
      final uspeh = await StatistikaService.resetujSveKilometraze();

      if (mounted) Navigator.of(context).pop(); // Zatvori loading

      if (uspeh) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Kilometraža je uspešno resetovana na 0'),
              backgroundColor: Theme.of(context).colorScheme.successPrimary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Greška pri resetovanju kilometraže'),
              backgroundColor: Theme.of(context).colorScheme.dangerPrimary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Zatvori loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Theme.of(context).colorScheme.dangerPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedDriver) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!['Bojan', 'Svetlana'].contains(_currentDriver)) {
      // Potpuno nevidljiv: vrati prazan widget
      return const SizedBox.shrink();
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PRVI RED - STATISTIKA naslov
                  Container(
                    height: 32,
                    alignment: Alignment.center,
                    child: const Text(
                      'S T A T I S T I K A',
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
                  const SizedBox(height: 2),
                  // DRUGI RED - Tab-ovi i dropdown
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        // Tab-ovi levo - stilizovani kao dugmići
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _tabController.animateTo(0),
                                  child: Container(
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 0
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Vozači',
                                        style: TextStyle(
                                          color: _tabController.index == 0
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _tabController.animateTo(1),
                                  child: Container(
                                    height: 32,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: _tabController.index == 1
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Detaljno',
                                        style: TextStyle(
                                          color: _tabController.index == 1
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Dropdown desno - stilizovan kao dugme
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _period,
                              dropdownColor:
                                  Theme.of(context).colorScheme.primary,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 18,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              items: _periods
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          child: Center(
                                            child: Text(
                                              _periodLabel(p),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _period = v);
                              },
                            ),
                          ),
                        ),
                        // 🆕 GODINA DROPDOWN - prikaži samo kada je selektovana "godina"
                        if (_period == 'godina') ...[
                          const SizedBox(width: 8),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedYear,
                                dropdownColor:
                                    Theme.of(context).colorScheme.primary,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                items: _availableYears
                                    .map((year) => DropdownMenuItem(
                                          value: year,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            child: Center(
                                              child: Text(
                                                '$year',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedYear = v);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVozaciTab(),
          _buildDetaljnoTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetujKilometrazu,
        tooltip: 'Resetuj kilometražu',
        backgroundColor: Theme.of(context).colorScheme.dangerPrimary,
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
    );
  }

// --- Pomocne/tab funkcije ---

  /// 📅 CENTRALIZOVANA KALKULACIJA PERIODA - koriste oba tab-a identično
  Map<String, DateTime> _calculatePeriod() {
    DateTime now = DateTime.now();
    DateTime from, to;

    // Izračunavanje perioda

    if (_period == 'nedelja') {
      // ✅ KORISTI UTILS FUNKCIJU ZA VIKEND LOGIKU
      final targetDate = app_date_utils.DateUtils.getWeekendTargetDate();
      DateTime ponedeljak;

      if (app_date_utils.DateUtils.isWeekend()) {
        // 🎯 Vikend: koristi target datum (sledeći ponedeljak)
        ponedeljak = targetDate;
      } else {
        // 📅 Radni dan: računaj za ovu nedelju (običan ponedeljak)
        ponedeljak = now.subtract(Duration(days: now.weekday - 1));
      }

      // 🔄 Period ide od subote pre ponedeljka do petka te nedelje
      final subota =
          ponedeljak.subtract(const Duration(days: 2)); // Subota pre ponedeljka
      from = DateTime(subota.year, subota.month, subota.day);

      // 📅 ZAVRŠI U PETAK (dodaj 4 dana od ponedeljka)
      final petak = ponedeljak.add(const Duration(days: 4));
      to = DateTime(petak.year, petak.month, petak.day, 23, 59, 59);
    } else if (_period == 'mesec') {
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else {
      // 🔧 FIX: Koristi selektovanu godinu umesto now.year
      from = DateTime(_selectedYear, 1, 1);
      to = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    }

    return {'from': from, 'to': to};
  }

  Widget _buildVozaciTab() {
    final period = _calculatePeriod(); // 📅 KORISTI CENTRALIZOVANU FUNKCIJU
    final from = period['from']!;
    final to = period['to']!;

    return StreamBuilder<List<Putnik>>(
      stream: PutnikService()
          .streamKombinovaniPutniciFiltered(), // 🔄 KOMBINOVANI STREAM (server-filtered)
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🔄 REAL-TIME PAZAR STREAM sa kombinovanim putnicima (uključuje mesečne karte)
        dlog(
            '🎯 [VOZAČI TAB] Pozivam streamPazarSvihVozaca sa from: ${from.toString()}, to: ${to.toString()}');
        return StreamBuilder<Map<String, double>>(
          stream: StatistikaService.streamPazarSvihVozaca(
            from: from,
            to: to,
          ),
          builder: (context, pazarSnapshot) {
            dlog(
                '📊 VOZAČI TAB STREAM STATE: ${pazarSnapshot.connectionState}');
            dlog('📊 VOZAČI TAB HAS DATA: ${pazarSnapshot.hasData}');
            dlog('📊 VOZAČI TAB DATA: ${pazarSnapshot.data}');

            if (pazarSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (pazarSnapshot.hasError) {
              dlog('❌ VOZAČI TAB ERROR: ${pazarSnapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error,
                        size: 48,
                        color: Theme.of(context).colorScheme.dangerPrimary),
                    const SizedBox(height: 16),
                    Text('Greška: ${pazarSnapshot.error}'),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              );
            }

            final pazarMap = pazarSnapshot.data ?? <String, double>{};
            final ukupno = pazarMap['_ukupno'] ?? 0.0;
            // Ukloni '_ukupno' ključ za čist prikaz
            final Map<String, double> cistPazarMap = Map.from(pazarMap)
              ..remove('_ukupno');
            // Dodaj ukupno u mapu
            cistPazarMap['_ukupno'] = ukupno;

            // 🎯 KORISTI CENTRALIZOVANE BOJE VOZAČA
            final Map<String, Color> vozacBoje = {
              'Bruda': VozacBoja.get('Bruda'),
              'Bilevski': VozacBoja.get('Bilevski'),
              'Bojan': VozacBoja.get('Bojan'),
              'Svetlana': VozacBoja.get('Svetlana'),
            };
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<Map<String, Map<String, dynamic>>>(
                  stream: StatistikaService.streamDetaljneStatistikePoVozacima(
                      from, to),
                  builder: (context, detaljneSnapshot) {
                    if (detaljneSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final detaljneStats = detaljneSnapshot.data ?? {};

                    return DetaljanPazarPoVozacimaWidget(
                      vozaciStatistike: detaljneStats,
                      ukupno: ukupno,
                      periodLabel: _periodLabel(_period),
                      vozacBoje: vozacBoje,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetaljnoTab() {
    final period =
        _calculatePeriod(); // 📅 KORISTI ISTU CENTRALIZOVANU FUNKCIJU
    final from = period['from']!;
    final to = period['to']!;

    // 🔄 DIREKTNO KORISTI STREAM DETALJNIH STATISTIKA
    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: StatistikaService.streamDetaljneStatistikePoVozacima(from, to),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final detaljneStats = statsSnapshot.data ?? {};

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detaljne Statistike - ${_periodLabel(_period)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ...detaljneStats.entries.map((entry) {
                  final vozac = entry.key;
                  final stats = entry.value;
                  final Color vozacColor = _getVozacColor(vozac);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 4, // 🎨 Dodao shadow
                    color: vozacColor
                        .withOpacity(0.25), // 🎨 POJAČAO sa 0.1 na 0.25
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12), // 🎨 Zaobljeni uglovi
                      side: BorderSide(
                        color: vozacColor.withOpacity(0.6), // 🎨 Jasniji border
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: vozacColor, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                vozac,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[
                                      800], // 🎨 Tamniji tekst za bolji kontrast
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                              'Dodati putnici',
                              stats['dodati'],
                              Icons.add_circle,
                              Theme.of(context).colorScheme.primary),
                          _buildStatRow(
                              'Otkazani',
                              stats['otkazani'],
                              Icons.cancel,
                              Theme.of(context).colorScheme.dangerPrimary),
                          _buildStatRow(
                              'Naplaćeni',
                              stats['naplaceni'],
                              Icons.payment,
                              Theme.of(context).colorScheme.successPrimary),
                          _buildStatRow(
                              'Pokupljeni',
                              stats['pokupljeni'],
                              Icons.check_circle,
                              Theme.of(context).colorScheme.studentPrimary),
                          _buildStatRow(
                              'Dugovi',
                              stats['dugovi'],
                              Icons.warning,
                              Theme.of(context).colorScheme.dangerPrimary),
                          _buildStatRow('Mesečne karte', stats['mesecneKarte'],
                              Icons.card_membership, Colors.purple),
                          _buildStatRow(
                              'Kilometraža',
                              '${(stats['kilometraza'] ?? 0.0).toStringAsFixed(1)} km',
                              Icons.route,
                              Theme.of(context).colorScheme.workerPrimary),
                          const Divider(color: Colors.white24),
                          _buildStatRow(
                              'Ukupno pazar',
                              '${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
                              Icons.monetization_on,
                              Colors.amber),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
      String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
                color: Colors.grey[700], fontSize: 14), // 🎨 Tamniji tekst
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getVozacColor(String vozac) {
    // 🎯 KORISTI CENTRALIZOVANE BOJE VOZAČA
    return VozacBoja.get(vozac);
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'nedelja':
        return 'Pon-Pet'; // 📅 Jasno označiti radni dani
      case 'mesec':
        return 'Mesec';
      case 'godina':
        return 'Godina';
      default:
        return period;
    }
  }
}
