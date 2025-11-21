import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';
import '../theme.dart';
// foundation import not needed; using centralized logger
import '../widgets/custom_back_button.dart';

class MesecniPutnikDetaljiScreen extends StatefulWidget {
  const MesecniPutnikDetaljiScreen({
    super.key,
    required this.putnik,
  });

  final MesecniPutnik putnik;

  @override
  State<MesecniPutnikDetaljiScreen> createState() => _MesecniPutnikDetaljiScreenState();
}

class _MesecniPutnikDetaljiScreenState extends State<MesecniPutnikDetaljiScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true; // 🔄 PERFORMANCE: Keep state alive

  List<Map<String, dynamic>> _svaUkrcavanja = [];
  List<Map<String, dynamic>> _sviOtkazi = [];
  List<Map<String, dynamic>> _svaPlacanja = [];
  bool _loading = true;

  late final MesecniPutnikService _service;

  // 🔄 PERFORMANCE: Cached computed values
  Map<String, List<Map<String, dynamic>>>? _cachedNedeljniPodaci;
  Map<String, List<Map<String, dynamic>>>? _cachedMesecniPodaci;

  // 🔄 V3.0 REALTIME MONITORING STATE (Clean Architecture - bez heartbeat)
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _dataStreamHealthy;
  late ValueNotifier<String> _realtimeHealthStatus;
  late ValueNotifier<bool> _isNetworkConnected;
  Timer? _monitoringTimer;
  StreamSubscription<bool>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    _service = MesecniPutnikService();

    // 🔄 V3.0: Setup realtime monitoring
    _setupRealtimeMonitoring();

    _ucitajSveDetalje();
  }

  // 🔄 V3.0 REALTIME MONITORING SETUP (Backend only - no visual heartbeat)
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _dataStreamHealthy = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');
    _isNetworkConnected = ValueNotifier(true);

    // 🔄 V3.0: Simple network status monitoring (simplified for now)
    _isNetworkConnected.value = true;

    // Health monitoring timer
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateHealthStatus();
    });
  }

  void _updateHealthStatus() {
    final networkHealthy = _isNetworkConnected.value;
    final dataHealthy = _dataStreamHealthy.value;

    _isRealtimeHealthy.value = networkHealthy && dataHealthy;

    if (!networkHealthy) {
      _realtimeHealthStatus.value = 'network_error';
    } else if (!dataHealthy) {
      _realtimeHealthStatus.value = 'data_error';
    } else {
      _realtimeHealthStatus.value = 'healthy';
    }
  }

  Future<void> _ucitajSveDetalje() async {
    if (mounted) setState(() => _loading = true);

    // 🔄 V3.0: Mark data stream as healthy at start
    _dataStreamHealthy.value = true;

    // 🔄 PERFORMANCE: Clear cached data when reloading
    _cachedNedeljniPodaci = null;
    _cachedMesecniPodaci = null;

    try {
      // 🔄 RESILIENCE: Check network before loading
      if (!_isNetworkConnected.value) {
        throw Exception('Nema internetske konekcije');
      }

      // 🔄 PERFORMANCE: Parallel loading for better performance
      final results = await Future.wait([
        _service.dohvatiUkrcavanjaZaPutnika(widget.putnik.putnikIme),
        _service.dohvatiOtkazeZaPutnika(widget.putnik.putnikIme),
        _service.dohvatiPlacanjaZaPutnika(widget.putnik.putnikIme),
      ]);

      if (!mounted) return; // 🔄 RESILIENCE: Check after async operation

      _svaUkrcavanja = results[0];
      _sviOtkazi = results[1];
      _svaPlacanja = results[2];

      // 🔄 V3.0: Mark data stream as healthy after successful load
      _dataStreamHealthy.value = true;
    } catch (e) {
      if (!mounted) return; // 🔄 RESILIENCE: Check before updating state

      // 🔄 V3.0: Mark data stream as unhealthy on error
      _dataStreamHealthy.value = false;

      // 🔄 RESILIENCE: Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNetworkConnected.value
                  ? 'Greška pri učitavanju podataka. Pokušajte ponovo.'
                  : 'Nema internetske konekcije. Proverite konekciju i pokušajte ponovo.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Pokušaj ponovo',
              textColor: Colors.white,
              onPressed: _ucitajSveDetalje,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        if (mounted) setState(() => _loading = false);
        _updateHealthStatus();
      }
    }
  }

  @override
  void dispose() {
    // 🔄 V3.0 REALTIME MONITORING CLEANUP
    _monitoringTimer?.cancel();
    _networkSubscription?.cancel();
    _isRealtimeHealthy.dispose();
    _dataStreamHealthy.dispose();
    _realtimeHealthStatus.dispose();
    _isNetworkConnected.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(
      context,
    ); // 🔄 PERFORMANCE: Required for AutomaticKeepAliveClientMixin

    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const GradientBackButton(),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer,
              border: Border.all(
                color: Theme.of(context).glassBorder,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          title: Text(
            'Detalji - ${widget.putnik.putnikIme}',
            style: const TextStyle(
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 3,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: _ucitajSveDetalje,
              icon: const Icon(
                Icons.refresh,
                color: Colors.white,
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
        body: _buildBody(),
      ),
    );
  }

  // 🔄 V3.0: Enhanced body with better error handling
  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Učitavam detalje...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Heartbeat indicator pokazuje status konekcije
    if (!_dataStreamHealthy.value && _svaUkrcavanja.isEmpty && _sviOtkazi.isEmpty && _svaPlacanja.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // Osnovne informacije
          _buildBasicInfoCard(),

          // Tab bar
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              indicatorWeight: 3,
              splashFactory: InkRipple.splashFactory,
              tabs: [
                Tab(
                  text: 'Nedeljno',
                  icon: Icon(Icons.calendar_view_week),
                ),
                Tab(text: 'Mesečno', icon: Icon(Icons.calendar_month)),
                Tab(text: 'Godišnje', icon: Icon(Icons.calendar_today)),
                Tab(text: 'Plaćanja', icon: Icon(Icons.payments)),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              children: [
                _buildNedeljniTab(),
                _buildMesecniTab(),
                _buildGodisnjiTab(),
                _buildPlacanjaTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  widget.putnik.putnikIme[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.putnik.putnikIme,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.putnik.aktivan
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.putnik.tip.toUpperCase()} • ${widget.putnik.aktivan ? "AKTIVAN" : "NEAKTIVAN"}',
                        style: TextStyle(
                          color: widget.putnik.aktivan
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.tertiary,
                          Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.putnik.brojPutovanja} vožnji',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.errorContainer,
                          Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.putnik.brojOtkazivanja} otkaza',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Radni dani i vremena
          if (widget.putnik.radniDani.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Radni dani: ${_formatRadniDani(widget.putnik.radniDani)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._buildVremenaPolaska(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatRadniDani(String radniDani) {
    final daniMapa = {
      'pon': 'Pon',
      'uto': 'Uto',
      'sre': 'Sre',
      'cet': 'Čet',
      'pet': 'Pet',
    };

    final dani = radniDani.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    return dani.map((dan) => daniMapa[dan] ?? dan).join(', ');
  }

  List<Widget> _buildVremenaPolaska() {
    final daniMapa = {
      'pon': 'Pon',
      'uto': 'Uto',
      'sre': 'Sre',
      'cet': 'Čet',
      'pet': 'Pet',
    };

    final dani = widget.putnik.radniDani.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    List<Widget> vremenaWidgets = [];

    for (String dan in dani) {
      final vremeBc = widget.putnik.getPolazakBelaCrkvaZaDan(dan);
      final vremeVs = widget.putnik.getPolazakVrsacZaDan(dan);

      if (vremeBc != null || vremeVs != null) {
        List<String> vremena = [];
        if (vremeBc != null) vremena.add('BC: $vremeBc');
        if (vremeVs != null) vremena.add('VS: $vremeVs');

        vremenaWidgets.add(
          Text(
            '${daniMapa[dan]}: ${vremena.join(', ')}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }
    }

    return vremenaWidgets;
  }

  Widget _buildNedeljniTab() {
    // 🔄 PERFORMANCE: Cache expensive grouping operations
    _cachedNedeljniPodaci ??= _grupisiPoNedeljama(_svaUkrcavanja);
    final nedeljniPodaci = _cachedNedeljniPodaci!;
    final nedeljniOtkazi = _grupisiPoNedeljama(_sviOtkazi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nedeljni pregled',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (nedeljniPodaci.isEmpty)
            const Center(
              child: Text('Nema podataka o vožnjama'),
            )
          else
            ...nedeljniPodaci.keys.map((nedelja) {
              final voznjeUNedelji = nedeljniPodaci[nedelja]!;
              final otkaziUNedelji = nedeljniOtkazi[nedelja] ?? [];

              return _buildNedeljaCard(nedelja, voznjeUNedelji, otkaziUNedelji);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildNedeljaCard(
    String nedelja,
    List<Map<String, dynamic>> voznje,
    List<Map<String, dynamic>> otkazi,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nedelja,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildStatChip('${voznje.length} vožnji', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip('${otkazi.length} otkaza', Colors.orange),
                  ],
                ),
              ],
            ),
            if (voznje.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Vožnje:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...voznje.map((voznja) => _buildVoznjaItem(voznja)),
            ],
            if (otkazi.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Otkazi:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...otkazi.map((otkaz) => _buildOtkazItem(otkaz)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMesecniTab() {
    // 🔄 PERFORMANCE: Cache expensive grouping operations
    _cachedMesecniPodaci ??= _grupisiPoMesecima(_svaUkrcavanja);
    final mesecniPodaci = _cachedMesecniPodaci!;
    final mesecniOtkazi = _grupisiPoMesecima(_sviOtkazi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mesečni pregled',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (mesecniPodaci.isEmpty)
            const Center(
              child: Text('Nema podataka o vožnjama'),
            )
          else
            ...mesecniPodaci.keys.map((mesec) {
              final voznjeUMesecu = mesecniPodaci[mesec]!;
              final otkaziUMesecu = mesecniOtkazi[mesec] ?? [];

              return _buildMesecCard(mesec, voznjeUMesecu, otkaziUMesecu);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMesecCard(
    String mesec,
    List<Map<String, dynamic>> voznje,
    List<Map<String, dynamic>> otkazi,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mesec,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildStatChip('${voznje.length} vožnji', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip('${otkazi.length} otkaza', Colors.orange),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grafička reprezentacija dana u mesecu
            _buildMesecniKalendar(voznje, otkazi),
          ],
        ),
      ),
    );
  }

  Widget _buildGodisnjiTab() {
    // Grupisanje po godinama
    final godisnjiPodaci = _grupisiPoGodinama(_svaUkrcavanja);
    final godisnjiOtkazi = _grupisiPoGodinama(_sviOtkazi);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Godišnji pregled',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (godisnjiPodaci.isEmpty)
            const Center(
              child: Text('Nema podataka o vožnjama'),
            )
          else
            ...godisnjiPodaci.keys.map((godina) {
              final voznjeUGodini = godisnjiPodaci[godina]!;
              final otkaziUGodini = godisnjiOtkazi[godina] ?? [];

              return _buildGodinaCard(godina, voznjeUGodini, otkaziUGodini);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildGodinaCard(
    String godina,
    List<Map<String, dynamic>> voznje,
    List<Map<String, dynamic>> otkazi,
  ) {
    // Grupisanje po mesecima unutar godine
    final mesecniPodaci = <String, int>{};
    final mesecniOtkazi = <String, int>{};

    for (var voznja in voznje) {
      final datum = DateTime.parse(voznja['created_at'] as String);
      final mesec = DateFormat('MMMM', 'sr').format(datum);
      mesecniPodaci[mesec] = (mesecniPodaci[mesec] ?? 0) + 1;
    }

    for (var otkaz in otkazi) {
      final datum = DateTime.parse(otkaz['created_at'] as String);
      final mesec = DateFormat('MMMM', 'sr').format(datum);
      mesecniOtkazi[mesec] = (mesecniOtkazi[mesec] ?? 0) + 1;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  godina,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildStatChip('${voznje.length} vožnji', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip('${otkazi.length} otkaza', Colors.orange),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Mesečni pregled za godinu
            Text(
              'Mesečni pregled:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            ...mesecniPodaci.keys.map((mesec) {
              final brojVoznji = mesecniPodaci[mesec] ?? 0;
              final brojOtkaza = mesecniOtkazi[mesec] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(mesec),
                    Row(
                      children: [
                        Text(
                          '$brojVoznji vožnji',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$brojOtkaza otkaza',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacanjaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Istorija plaćanja',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          if (_svaPlacanja.isEmpty)
            const Center(
              child: Text('Nema podataka o plaćanjima'),
            )
          else
            ..._svaPlacanja.map((placanje) => _buildPlacanjeCard(placanje)),
        ],
      ),
    );
  }

  Widget _buildPlacanjeCard(Map<String, dynamic> placanje) {
    final datum = DateTime.parse(placanje['created_at'] as String);
    final iznos = placanje['cena']?.toDouble() ?? 0.0;
    final vozac = placanje['vozac_ime'] ?? placanje['vozac'] ?? 'Nepoznato';
    final tipPlacanja = placanje['tip'] ?? 'redovno';

    // Dodatne informacije za mesečne karte
    String subtitle = 'Vozač: $vozac\n${DateFormat('dd.MM.yyyy HH:mm').format(datum)}';
    if (tipPlacanja == 'mesecna_karta') {
      final mesec = placanje['placeniMesec'] ?? 0;
      final godina = placanje['placenaGodina'] ?? 0;
      final mesecNaziv = _getNazivMeseca(mesec as int);
      subtitle = 'Mesečna karta: $mesecNaziv $godina\nVozač: $vozac\n${DateFormat('dd.MM.yyyy HH:mm').format(datum)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tipPlacanja == 'mesecna_karta'
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.2),
          child: Icon(
            tipPlacanja == 'mesecna_karta' ? Icons.credit_card : Icons.payments,
            color: tipPlacanja == 'mesecna_karta'
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.successPrimary,
          ),
        ),
        title: Text(
          '${iznos.toStringAsFixed(0)} RSD',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          tipPlacanja == 'mesecna_karta' ? Icons.event_available : Icons.receipt,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  String _getNazivMeseca(int mesec) {
    const meseci = [
      '',
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Juni',
      'Juli',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar',
    ];
    return mesec > 0 && mesec < meseci.length ? meseci[mesec] : 'Nepoznat';
  }

  Widget _buildStatChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVoznjaItem(Map<String, dynamic> voznja) {
    final datum = DateTime.parse(voznja['created_at'] as String);
    final vozac = voznja['vozac_ime'] ?? 'Nepoznato';
    final relacija = voznja['relacija'] ?? 'Nepoznato';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.directions_bus,
            size: 16,
            color: Theme.of(context).colorScheme.successPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('dd.MM HH:mm').format(datum)} • $vozac • $relacija',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtkazItem(Map<String, dynamic> otkaz) {
    final datum = DateTime.parse(otkaz['created_at'] as String);
    final vozac = otkaz['vozac_ime'] ?? 'Nepoznato';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.cancel,
            size: 16,
            color: Theme.of(context).colorScheme.warningPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('dd.MM HH:mm').format(datum)} • $vozac',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMesecniKalendar(
    List<Map<String, dynamic>> voznje,
    List<Map<String, dynamic>> otkazi,
  ) {
    // Jednostavan kalendar koji pokazuje dane kada je bilo aktivnosti
    final daniSaAktivnoscu = <int, String>{};

    for (var voznja in voznje) {
      final datum = DateTime.parse(voznja['created_at'] as String);
      final dan = datum.day;
      daniSaAktivnoscu[dan] = 'voznja';
    }

    for (var otkaz in otkazi) {
      final datum = DateTime.parse(otkaz['created_at'] as String);
      final dan = datum.day;
      if (daniSaAktivnoscu[dan] == 'voznja') {
        daniSaAktivnoscu[dan] = 'oba';
      } else {
        daniSaAktivnoscu[dan] = 'otkaz';
      }
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(31, (index) {
        final dan = index + 1;
        final aktivnost = daniSaAktivnoscu[dan];

        Color boja = Theme.of(context).colorScheme.surfaceContainerHighest;
        if (aktivnost == 'voznja') {
          boja = Theme.of(context).colorScheme.successPrimary.withValues(alpha: 0.2);
        }
        if (aktivnost == 'otkaz') {
          boja = Theme.of(context).colorScheme.warningPrimary.withValues(alpha: 0.2);
        }
        if (aktivnost == 'oba') {
          boja = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
        }

        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: boja,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              dan.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: aktivnost != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  Map<String, List<Map<String, dynamic>>> _grupisiPoNedeljama(
    List<Map<String, dynamic>> podaci,
  ) {
    final mapa = <String, List<Map<String, dynamic>>>{};

    for (var podatak in podaci) {
      final datum = DateTime.parse(podatak['created_at'] as String);
      final nedelja = _getNedeljaString(datum);

      if (!mapa.containsKey(nedelja)) {
        mapa[nedelja] = [];
      }
      mapa[nedelja]!.add(podatak);
    }

    return mapa;
  }

  Map<String, List<Map<String, dynamic>>> _grupisiPoMesecima(
    List<Map<String, dynamic>> podaci,
  ) {
    final mapa = <String, List<Map<String, dynamic>>>{};

    for (var podatak in podaci) {
      final datum = DateTime.parse(podatak['created_at'] as String);
      final mesec = DateFormat('MMMM yyyy', 'sr').format(datum);

      if (!mapa.containsKey(mesec)) {
        mapa[mesec] = [];
      }
      mapa[mesec]!.add(podatak);
    }

    return mapa;
  }

  Map<String, List<Map<String, dynamic>>> _grupisiPoGodinama(
    List<Map<String, dynamic>> podaci,
  ) {
    final mapa = <String, List<Map<String, dynamic>>>{};

    for (var podatak in podaci) {
      final datum = DateTime.parse(podatak['created_at'] as String);
      final godina = datum.year.toString();

      if (!mapa.containsKey(godina)) {
        mapa[godina] = [];
      }
      mapa[godina]!.add(podatak);
    }

    return mapa;
  }

  String _getNedeljaString(DateTime datum) {
    final pocetak = datum.subtract(Duration(days: datum.weekday - 1));
    final kraj = pocetak.add(const Duration(days: 6));

    return '${DateFormat('dd.MM').format(pocetak)} - ${DateFormat('dd.MM.yyyy').format(kraj)}';
  }
}
