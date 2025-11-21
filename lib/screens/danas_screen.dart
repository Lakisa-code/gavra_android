import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // 🗺️ DODANO za OpenStreetMap
import 'package:supabase_flutter/supabase_flutter.dart'; // DODANO za direktne pozive

// url_launcher unused here - navigacija delegirana SmartNavigationService

import '../models/mesecni_putnik.dart';
import '../models/putnik.dart';
import '../services/daily_checkin_service.dart'; // 🔧 DODANO za kusur stream initialize
import '../services/fail_fast_stream_manager_new.dart'; // 🚨 NOVO fail-fast stream manager
import '../services/firebase_service.dart';
import '../services/local_notification_service.dart';
import '../services/mesecni_putnik_service.dart'; // 🎓 DODANO za đačke statistike
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_gps_service.dart'; // 🛰️ DODANO za GPS tracking
import '../services/realtime_network_status_service.dart'; // 🚥 NOVO network status service
import '../services/realtime_notification_counter_service.dart'; // 🔔 DODANO za notification count
import '../services/realtime_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/route_optimization_service.dart';
import '../services/simplified_daily_checkin.dart'; // 🚀 OPTIMIZOVANI servis za kusur
import '../services/smart_navigation_service.dart';
import '../services/statistika_service.dart'; // DODANO za jedinstvenu logiku pazara
import '../services/theme_manager.dart';
import '../services/timer_manager.dart'; // 🕐 DODANO za heartbeat management
import '../theme.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju gradova
import '../utils/schedule_utils.dart'; // Za isZimski funkciju
import '../utils/text_utils.dart'; // 🎯 DODANO za standardizovano filtriranje statusa
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje vozača
import '../widgets/bottom_nav_bar_letnji.dart'; // 🚀 DODANO za letnji nav bar
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/clock_ticker.dart';
import '../widgets/putnik_list.dart';
import '../widgets/real_time_navigation_widget.dart'; // 🧭 NOVO navigation widget
import 'dugovi_screen.dart';
import 'welcome_screen.dart';

// Using centralized logger

class DanasScreen extends StatefulWidget {
  const DanasScreen({Key? key, this.highlightPutnikIme, this.filterGrad, this.filterVreme}) : super(key: key);
  final String? highlightPutnikIme;
  final String? filterGrad;
  final String? filterVreme;

  @override
  State<DanasScreen> createState() => _DanasScreenState();
}

class _DanasScreenState extends State<DanasScreen> {
  final supabase = Supabase.instance.client; // DODANO za direktne pozive
  final _putnikService = PutnikService(); // ⏪ VRAĆEN na stari servis zbog grešaka u novom
  final Set<String> _resettingSlots = {};
  final RouteOptimizationService _routeOptimizationService = RouteOptimizationService();
  Set<String> _lastMatchingIds = {};

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }

  Position? _lastDriverPosition;
  StreamSubscription<Position>? _driverPositionSubscription;
  // 🕐 TIMER MANAGEMENT - sada koristi TimerManager singleton umesto direktnih Timer-a

  // 💓 HEARTBEAT MONITORING VARIABLES
  final ValueNotifier<bool> _isRealtimeHealthy = ValueNotifier(true);
  final Map<String, DateTime> _streamHeartbeats = {};
  // Listen to higher-level network status (better than raw heartbeat)
  NetworkStatus? _prevNetworkStatus;
  // Previously used to compare heartbeat state; kept for potential future re-enable
  // bool _wasRealtimeHealthy = true;

  // 🎯 DANAS SCREEN - UVEK KORISTI TRENUTNI DATUM

  Widget _buildPopisButton() {
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: (_currentDriver == null || !VozacBoja.isValidDriver(_currentDriver)) ? null : () => _showPopisDana(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        child: const Text('POPIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
      ),
    );
  }

  // 💓 HEARTBEAT MONITORING FUNCTIONS
  void _registerStreamHeartbeat(String streamName) {
    final now = DateTime.now();
    final prev = _streamHeartbeats[streamName];
    final responseTime = prev != null ? now.difference(prev) : const Duration(milliseconds: 250);
    _streamHeartbeats[streamName] = now;

    try {
      // Update global network status metrics using the computed response time
      RealtimeNetworkStatusService.instance.registerStreamResponse(streamName, responseTime, hasError: false);
    } catch (_) {}
  }

  void _onNetworkStatusChanged() {
    final status = RealtimeNetworkStatusService.instance.networkStatus.value;
    if (_prevNetworkStatus != status) {
      // If we've recovered to good/excellent, force cache invalidation for current filters
      if ((status == NetworkStatus.excellent || status == NetworkStatus.good) &&
          (_prevNetworkStatus == NetworkStatus.offline || _prevNetworkStatus == NetworkStatus.poor)) {
        final selectedGrad = widget.filterGrad ?? _selectedGrad;
        final selectedVreme = widget.filterVreme ?? _selectedVreme;
        try {
          _routeOptimizationService.invalidateCacheFor(grad: selectedGrad, vreme: selectedVreme);
          if (mounted) setState(() {});
        } catch (_) {}
      }
      _prevNetworkStatus = status;
    }
  }

  // Auto-refetch is disabled; method kept for future re-enable

  void _checkStreamHealth() {
    final now = DateTime.now();
    bool isHealthy = true;

    for (final entry in _streamHeartbeats.entries) {
      final timeSinceLastHeartbeat = now.difference(entry.value);
      if (timeSinceLastHeartbeat.inSeconds > 30) {
        // 30 sekundi timeout
        isHealthy = false;
        break;
      }
    }

    // Detect stale streams and notify the network status service about errors
    for (final entry in _streamHeartbeats.entries) {
      final timeSinceLastHeartbeat = now.difference(entry.value);
      if (timeSinceLastHeartbeat.inSeconds > 45) {
        try {
          RealtimeNetworkStatusService.instance.registerStreamResponse(
            entry.key,
            const Duration(milliseconds: 0),
            hasError: true,
          );
        } catch (_) {}
      }
    }

    if (_isRealtimeHealthy.value != isHealthy) {
      _isRealtimeHealthy.value = isHealthy;
    }
  }

  void _startHealthMonitoring() {
    // Koristi TimerManager za konzistentnost
    TimerManager.createTimer(
      'danas_screen_heartbeat',
      const Duration(seconds: 5),
      _checkStreamHealth,
      isPeriodic: true,
    );
  }

  // 🚨 BUILD FAIL-FAST STATUS WIDGETS
  List<Widget> _buildFailFastStatus() {
    final status = FailFastStreamManager.instance.getSubscriptionStatus();
    final subscriptions = status['subscriptions'] as List<dynamic>;

    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Active: ${status['activeCount']}'),
          Text('Critical: ${status['criticalCount']}'),
          Text('Errors: ${status['totalErrors']}'),
        ],
      ),
      const SizedBox(height: 4),
      if (subscriptions.isEmpty)
        const Text(
          'No subscriptions',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange),
        )
      else
        ...subscriptions.map((sub) {
          final isCritical = sub['isCritical'] as bool;
          final errorCount = sub['errorCount'] as int;
          final isStale = sub['isStale'] as bool;

          Color statusColor = Colors.green;
          if (isStale) statusColor = Colors.orange;
          if (errorCount > 0) statusColor = Colors.red;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  sub['name'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (errorCount > 0)
                  Text(
                    '${errorCount}E',
                    style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                if (isCritical)
                  const Text(
                    'CRIT',
                    style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          );
        }).toList(),
    ];
  }

  // 🎓 FUNKCIJA ZA RAČUNANJE ĐAČKIH STATISTIKA
  // 🔥 REALTIME STREAM ZA ĐAČKI BROJAČ
  Stream<Map<String, int>> _streamDjackieBrojevi() {
    final mesecniStream = MesecniPutnikService.streamAktivniMesecniPutnici();

    return mesecniStream.asyncMap((sviMesecniPutnici) async {
      try {
        final danasnjiDan = _getTodayForDatabase();
        final selectedGrad = widget.filterGrad ?? _selectedGrad;

        // 🔧 REORGANIZOVANA LOGIKA: Prvo filtriraj osnovne kriterijume, zatim računaj status unutar
        final ucenici = sviMesecniPutnici.where((MesecniPutnik mp) {
          // 🔧 ISPRAVKA: Tokenize days and trim; robust tip matching
          final radniDaniList =
              mp.radniDani.toLowerCase().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final dayMatch = radniDaniList.contains(danasnjiDan.toLowerCase());

          final tipNormalized = TextUtils.normalizeTip(mp.tip);
          final isUcenik = tipNormalized.contains('ucenik');

          final gradNormalized = TextUtils.normalizeText(mp.grad ?? '');
          final selectedGradNorm = TextUtils.normalizeText(selectedGrad);
          final gradMatch = selectedGrad.isEmpty || gradNormalized == selectedGradNorm;

          return dayMatch && isUcenik && gradMatch;
        }).toList();

        // FINALNA LOGIKA: OSTALO/UKUPNO
        int ukupnoUjutro = 0; // ukupno učenika koji idu ujutro (Bela Crkva)
        int reseniUcenici = 0; // učenici upisani za OBA pravca (automatski rešeni)
        int otkazaliUcenici = 0; // učenici koji su otkazali

        for (final ucenik in ucenici) {
          // 🔧 PROVERA: Da li je aktivni učenik (standardizovano)
          final jeAktivan = TextUtils.isStatusActive(ucenik.status);

          // 🔧 PROVERA: Da li je otkazao (standardizovano)
          final jeOtkazao = !jeAktivan;

          // Da li ide ujutro (Bela Crkva)?
          final polazakBC = ucenik.getPolazakBelaCrkvaZaDan(danasnjiDan);
          final ideBelaCrkva = polazakBC != null && polazakBC.isNotEmpty;

          // Da li se vraća (Vršac)?
          final polazakVS = ucenik.getPolazakVrsacZaDan(danasnjiDan);
          final vraca = polazakVS != null && polazakVS.isNotEmpty;

          // 🔧 LOGIKA: Samo oni koji idu ujutro u Belu Crkvu se računaju
          if (ideBelaCrkva) {
            ukupnoUjutro++; // broji sve koji idu ujutro (nezavisno od statusa)

            if (jeOtkazao) {
              otkazaliUcenici++; // otkazao nakon upisa
            } else if (jeAktivan && vraca) {
              reseniUcenici++; // aktivan + upisan za oba pravca = rešen
            }
          }
        }

        // RAČUNAJ OSTALO
        final ostalo = ukupnoUjutro - reseniUcenici - otkazaliUcenici;

        // Uključi današnje "zakupljeno" iz putovanja_istorija da ne bismo propustili grupne rezervacije
        int zakupljenoCount = 0;
        try {
          final zakupljenoRows = await MesecniPutnikService.getZakupljenoDanas();
          for (final z in zakupljenoRows) {
            try {
              final putnikZ = Putnik.fromPutovanjaIstorija(z);
              // Filtriraj po gradu/selectedGrad
              final gradNorm = TextUtils.normalizeText(putnikZ.grad);
              if (TextUtils.normalizeText(selectedGrad) != gradNorm && selectedGrad.isNotEmpty) continue;
              // Proveri da li polazak odgovara BC (jutarnji) - heuristika: if grad == 'Bela Crkva'
              if (putnikZ.grad.toLowerCase().contains('bela')) {
                // De-dupe using name match to avoid double counting the same mesecni putnik
                final nameMatch = sviMesecniPutnici.any(
                  (mp) => mp.putnikIme.trim().toLowerCase() == putnikZ.ime.trim().toLowerCase(),
                );
                if (!nameMatch) {
                  zakupljenoCount++;
                }
              }
            } catch (_) {}
          }
        } catch (_) {}

        // Po defaultu uključujemo zakupljeno u ukupnoUjutro
        final ukupnoSaZakupljeno = ukupnoUjutro + zakupljenoCount;

        return {
          'ukupno_ujutro': ukupnoSaZakupljeno, // 30 - ukupno koji idu ujutro (incl. zakupljeno)
          'reseni': reseniUcenici, // 15 - upisani za oba pravca
          'otkazali': otkazaliUcenici, // 5 - otkazani
          'ostalo': ostalo, // 10 - ostalo da se vrati
        };
      } catch (e) {
        return {'ukupno_ujutro': 0, 'reseni': 0, 'otkazali': 0, 'ostalo': 0};
      }
    });
  }

  // ✨ DIGITALNI BROJAČ DATUM WIDGET - OPTIMIZOVANO (30s umesto 1s)
  Widget _buildDigitalDateDisplay() {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now()), // 🚀 PERFORMANCE: 30s umesto 1s
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final dayNames = ['PONEDELJAK', 'UTORAK', 'SREDA', 'ČETVRTAK', 'PETAK', 'SUBOTA', 'NEDELJA'];
        final dayName = dayNames[now.weekday - 1];
        final dayStr = now.day.toString().padLeft(2, '0');
        final monthStr = now.month.toString().padLeft(2, '0');
        final yearStr = now.year.toString().substring(2);

        // hour/minute/second are handled by ClockTicker (optimized) -
        // don't compute them here to avoid redundant rebuilds.

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEVO - DATUM
                  Text(
                    '$dayStr.$monthStr.$yearStr',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 1.8,
                      shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                  ),
                  // SREDINA - DAN
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 1.8,
                      shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                  ),
                  // DESNO - VREME
                  ClockTicker(
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 1.8,
                      shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                    showSeconds: true,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 💓 REALTIME HEARTBEAT INDICATOR
  Widget _buildHeartbeatIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isRealtimeHealthy,
      builder: (context, isHealthy, child) {
        return GestureDetector(
          onTap: () {
            // Pokaži heartbeat debug info
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Realtime Health Status'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Status: ${isHealthy ? 'ZDRAVO' : 'PROBLEM'}'),
                      const SizedBox(height: 8),
                      const Text('Stream Heartbeats:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._streamHeartbeats.entries.map((entry) {
                        final timeSince = DateTime.now().difference(entry.value);
                        return Text(
                          '${entry.key}: ${timeSince.inSeconds}s ago',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: timeSince.inSeconds > 30 ? Colors.red : Colors.green,
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      // 🚨 FAIL-FAST STREAM STATUS
                      const Text('Fail-Fast Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._buildFailFastStatus(),
                    ],
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
              ),
            );
          },
          child: SizedBox(
            height: 26,
            child: Container(
              decoration: BoxDecoration(
                color: isHealthy ? Colors.green.shade700 : Colors.red.shade700,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Icon(isHealthy ? Icons.favorite : Icons.heart_broken, color: Colors.white, size: 14),
            ),
          ),
        );
      },
    );
  }

  // �🎓 FINALNO DUGME - OSTALO/UKUPNO FORMAT
  Widget _buildDjackiBrojacButton() {
    return StreamBuilder<Map<String, int>>(
      stream: _streamDjackieBrojevi(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Heartbeat indikator će pokazati grešku - ne prikazujemo dodatne error widget-e
          return SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
              child: const Text(
                'ERR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          );
        }

        final statistike = snapshot.data ?? {'ukupno_ujutro': 0, 'reseni': 0, 'otkazali': 0, 'ostalo': 0};
        final ostalo = statistike['ostalo'] ?? 0; // 10 - ostalo da se vrati
        final ukupnoUjutro = statistike['ukupno_ujutro'] ?? 0; // 30 - ukupno ujutro

        return SizedBox(
          height: 26, // povećao sa 24 na 26
          child: ElevatedButton(
            onPressed: () => _showDjackiDialog(statistike),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$ukupnoUjutro',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '$ostalo',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🚀 KOMPAKTNO DUGME ZA OPTIMIZACIJU
  Widget _buildOptimizeButton() {
    return FutureBuilder<List<Putnik>>(
      future: _routeOptimizationService.fetchPassengersForRoute(
        grad: _selectedGrad,
        vreme: _selectedVreme,
        driverPosition: _lastDriverPosition,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        final filtriraniPutnici = snapshot.data!;
        final hasPassengers = filtriraniPutnici.isNotEmpty;
        final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
        return SizedBox(
          height: 26,
          child: ElevatedButton(
            onPressed: _isLoading || !hasPassengers || !isDriverValid
                ? null
                : () {
                    if (_isRouteOptimized) {
                      _resetOptimization();
                    } else {
                      _optimizeCurrentRoute(filtriraniPutnici, isAlreadyOptimized: true);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRouteOptimized
                  ? Colors.green.shade600
                  : (hasPassengers ? Theme.of(context).primaryColor : Colors.grey.shade400),
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: hasPassengers ? 2 : 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            ),
            child: Text(
              _isRouteOptimized ? 'Reset' : 'Ruta',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        );
      },
    );
  }

  // ⚡ SPEEDOMETER DUGME U APPBAR-U
  Widget _buildSpeedometerButton() {
    return StreamBuilder<double>(
      stream: RealtimeGpsService.speedStream,
      builder: (context, speedSnapshot) {
        final speed = speedSnapshot.data ?? 0.0;
        final speedColor = speed >= 90
            ? Colors.red
            : speed >= 60
                ? Colors.orange
                : speed > 0
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurface;

        return SizedBox(
          height: 26,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: speedColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    speed.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: speedColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🗺️ DUGME ZA NAVIGACIJU (OpenStreetMap / slobodne opcije)
  Widget _buildMapsButton() {
    final hasOptimizedRoute = _isRouteOptimized && _optimizedRoute.isNotEmpty;
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: hasOptimizedRoute && isDriverValid
            ? () => (_isGpsTracking ? _stopSmartNavigation() : _startSmartNavigation())
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isGpsTracking
              ? Colors.orange.shade700
              : (hasOptimizedRoute ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: hasOptimizedRoute ? 2 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isGpsTracking ? Icons.stop : Icons.navigation,
              size: 12,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 4),
            Text(
              _isGpsTracking ? 'STOP' : (hasOptimizedRoute ? 'NAV' : 'NAV'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // 🎓 POPUP SA DETALJNIM ĐAČKIM STATISTIKAMA - OPTIMIZOVAN
  void _showDjackiDialog(Map<String, int> statistike) {
    final ukupnoUjutro = statistike['ukupno_ujutro'] ?? 0; // ukupno učenika ujutro (Bela Crkva)
    final reseni = statistike['reseni'] ?? 0; // upisani za oba pravca (BC + VS)
    final ostalo = statistike['ostalo'] ?? 0; // ostalo da se vrati (samo BC)
    final otkazali = statistike['otkazali'] ?? 0; // otkazani učenici

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.school, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Đaci - Danas ($reseni/$ostalo)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Ukupno ujutro (BC)', '$ukupnoUjutro', Icons.group, Colors.blue),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Rešeni ($reseni)',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Učenici koji imaju i jutarnji (BC) i popodnevni (VS) polazak',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ostalo ($ostalo)',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Učenici koji imaju samo jutarnji polazak (BC)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Otkazali ($otkazali)',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Učenici koji su otkazali, na bolovanju ili godišnjem',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[700], fontSize: 14), // 🎨 Tamniji tekst
          ),
          Text(
            value.toString(),
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 📊 POPIS DANA - REALTIME PODACI SA ISTIM NAZIVIMA KAO U STATISTIKA SCREEN
  Future<void> _showPopisDana() async {
    if (_currentDriver == null || _currentDriver!.isEmpty || !VozacBoja.isValidDriver(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Morate biti ulogovani i ovlašćeni da biste koristili Popis.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final vozac = _currentDriver!;

    try {
      // 1. OSNOVNI PODACI
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // 2. REALTIME STREAM ZA KOMBINOVANE PUTNIKE
      late List<Putnik> putnici;
      try {
        final isoDate = DateTime.now().toIso8601String().split('T')[0];
        final stream = PutnikService().streamKombinovaniPutniciFiltered(
          isoDate: isoDate,
          grad: widget.filterGrad ?? _selectedGrad,
          vreme: widget.filterVreme ?? _selectedVreme,
        );
        putnici = await stream.first.timeout(const Duration(seconds: 10));
      } catch (e) {
        putnici = []; // Prazan list kao fallback
      }

      // 3. REALTIME DETALJNE STATISTIKE - IDENTIČNE SA STATISTIKA SCREEN
      final detaljneStats = await StatistikaService.instance.detaljneStatistikePoVozacima(putnici, dayStart, dayEnd);
      final vozacStats = detaljneStats[vozac] ?? {};

      // 4. REALTIME PAZAR STREAM - PERSONALIZOVANO ZA ULOGOVANOG VOZAČA
      late double ukupanPazar;
      try {
        ukupanPazar = await StatistikaService.streamPazarZaVozaca(
          vozac,
          from: dayStart,
          to: dayEnd,
        ).first.timeout(const Duration(seconds: 10));
      } catch (e) {
        ukupanPazar = 0.0; // Fallback vrednost
      }

      // 5. SITAN NOVAC
      final sitanNovac = await SimplifiedDailyCheckInService.getTodayAmount(vozac);

      // 6. MAPIRANJE PODATAKA - IDENTIČNO SA STATISTIKA SCREEN
      final dodatiPutnici = (vozacStats['dodati'] ?? 0) as int;
      final otkazaniPutnici = (vozacStats['otkazani'] ?? 0) as int;
      final naplaceniPutnici = (vozacStats['naplaceni'] ?? 0) as int;
      final pokupljeniPutnici = (vozacStats['pokupljeni'] ?? 0) as int;
      final dugoviPutnici = (vozacStats['dugovi'] ?? 0) as int;
      final mesecneKarte = (vozacStats['mesecneKarte'] ?? 0) as int;

      // 🚗 REALTIME GPS KILOMETRAŽA (umesto statične vrednosti)
      late double kilometraza;
      try {
        kilometraza = await StatistikaService.instance.getKilometrazu(vozac, dayStart, dayEnd);
      } catch (e) {
        kilometraza = 0.0; // Fallback vrednost
      }

      // 7. PRIKAŽI POPIS DIALOG SA REALTIME PODACIMA
      final bool sacuvaj = await _showPopisDialog(
        vozac: vozac,
        datum: today,
        ukupanPazar: ukupanPazar,
        sitanNovac: sitanNovac,
        dodatiPutnici: dodatiPutnici,
        otkazaniPutnici: otkazaniPutnici,
        naplaceniPutnici: naplaceniPutnici,
        pokupljeniPutnici: pokupljeniPutnici,
        dugoviPutnici: dugoviPutnici,
        mesecneKarte: mesecneKarte,
        kilometraza: kilometraza,
      );

      // 8. SAČUVAJ POPIS AKO JE POTVRĐEN
      if (sacuvaj) {
        await _sacuvajPopis(vozac, today, {
          'ukupanPazar': ukupanPazar,
          'sitanNovac': sitanNovac,
          'dodatiPutnici': dodatiPutnici,
          'otkazaniPutnici': otkazaniPutnici,
          'naplaceniPutnici': naplaceniPutnici,
          'pokupljeniPutnici': pokupljeniPutnici,
          'dugoviPutnici': dugoviPutnici,
          'mesecneKarte': mesecneKarte,
          'kilometraza': kilometraza,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Greška pri učitavanju popisa: $e'), backgroundColor: Colors.red));
      }
    }
  }

  bool _isLoading = false;

  Future<void> _loadPutnici() async {
    if (mounted) setState(() => _isLoading = true);
    // Osloni se na stream, ali možeš ovde dodati logiku za ručno osvežavanje ako bude potrebno
    await Future<void>.delayed(const Duration(milliseconds: 100)); // simulacija
    if (mounted) setState(() => _isLoading = false);
  }

  // _filteredDuznici već postoji, ne treba duplirati
  // VRATITI NA PUTNIK SERVICE - BEZ CACHE-A

  // Optimizacija rute - zadržavam zbog postojeće logike
  bool _isRouteOptimized = false;
  List<Putnik> _optimizedRoute = [];

  // Status varijable - pojednostavljeno
  String _navigationStatus = '';

  // Praćenje navigacije
  bool _isGpsTracking = false;
  // DateTime? _lastGpsUpdate; // REMOVED - Google APIs disabled

  // Lista varijable - zadržavam zbog UI
  int _currentPassengerIndex = 0;
  bool _isListReordered = false;

  // 🔄 RESET OPTIMIZACIJE RUTE
  void _resetOptimization() {
    if (mounted)
      setState(() {
        _isRouteOptimized = false;
        _isListReordered = false;
        _optimizedRoute.clear();
        _currentPassengerIndex = 0;
        _isGpsTracking = false;
        // _lastGpsUpdate = null; // REMOVED - Google APIs disabled
        _navigationStatus = '';
      });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Optimizacija rute je isključena'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 📊 DIALOG ZA PRIKAZ POPISA DANA - IDENTIČAN FORMAT SA STATISTIKA SCREEN
  Future<bool> _showPopisDialog({
    required String vozac,
    required DateTime datum,
    required double ukupanPazar,
    required double sitanNovac,
    required int dodatiPutnici,
    required int otkazaniPutnici,
    required int naplaceniPutnici,
    required int pokupljeniPutnici,
    required int dugoviPutnici,
    required int mesecneKarte,
    required double kilometraza,
  }) async {
    final vozacColor = VozacBoja.get(vozac);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: vozacColor, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'POPIS - ${datum.day}.${datum.month}.${datum.year}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(0),
              elevation: 4,
              color: vozacColor.withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: vozacColor.withValues(alpha: 0.6), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER SA VOZAČEM
                    Row(
                      children: [
                        Icon(Icons.person, color: vozacColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          vozac,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // DETALJNE STATISTIKE - IDENTIČNE SA STATISTIKA SCREEN
                    _buildStatRow('Dodati putnici', dodatiPutnici, Icons.add_circle, Colors.blue),
                    _buildStatRow('Otkazani', otkazaniPutnici, Icons.cancel, Colors.red),
                    _buildStatRow('Naplaćeni', naplaceniPutnici, Icons.payment, Colors.green),
                    _buildStatRow('Pokupljeni', pokupljeniPutnici, Icons.check_circle, Colors.orange),
                    _buildStatRow('Dugovi', dugoviPutnici, Icons.warning, Colors.redAccent),
                    _buildStatRow('Mesečne karte', mesecneKarte, Icons.card_membership, Colors.purple),
                    _buildStatRow('Kilometraža', '${kilometraza.toStringAsFixed(1)} km', Icons.route, Colors.teal),

                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24)),

                    // UKUPAN PAZAR - GLAVNI PODATAK
                    _buildStatRow(
                      'Ukupno pazar',
                      '${ukupanPazar.toStringAsFixed(0)} RSD',
                      Icons.monetization_on,
                      Colors.amber,
                    ),

                    const SizedBox(height: 12),

                    // DODATNE INFORMACIJE
                    if (sitanNovac > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Sitan novac: ${sitanNovac.toStringAsFixed(0)} RSD',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        '📋 Ovaj popis će biti sačuvan i prikazan pri sledećem check-in-u.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Otkaži')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Sačuvaj popis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: vozacColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  //  SAČUVAJ POPIS U DAILY CHECK-IN SERVICE
  Future<void> _sacuvajPopis(String vozac, DateTime datum, Map<String, dynamic> podaci) async {
    try {
      // Uklonjena striktna provera vozača
      // Sačuvaj kompletan popis
      await SimplifiedDailyCheckInService.saveDailyReport(vozac, datum, podaci);

      // Takođe sačuvaj i sitan novac (za kompatibilnost)
      await SimplifiedDailyCheckInService.saveCheckIn(vozac, podaci['sitanNovac'] as double);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Popis je uspešno sačuvan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Greška pri čuvanju popisa: $e'), backgroundColor: Colors.red));
      }
    }
  }

  final bool _useAdvancedNavigation = true;

  String _selectedGrad = 'Bela Crkva';
  String _selectedVreme = '5:00';
  String? _currentDriver; // Dodato za dohvat vozača
  StreamSubscription<dynamic>? _dailyCheckinSub;

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
    '19:00 Vršac',
  ];

  // Dobij današnji dan u formatu koji se koristi u bazi
  String _getTodayForDatabase() {
    final now = DateTime.now();
    final dayNames = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned']; // Koristi iste kratice kao Home screen
    final todayName = dayNames[now.weekday - 1];

    // 🎯 DANAS SCREEN PRIKAZUJE SAMO TRENUTNI DAN - ne prebacuje na Ponedeljak
    return todayName;
  }

  // 🔧 IDENTIČNA LOGIKA SA HOME SCREEN - konvertuj ISO datum u kraći dan
  String _isoDateToDayAbbr(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      return dani[date.weekday - 1];
    } catch (e) {
      return 'pon'; // fallback
    }
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
      '19:00',
    ];

    for (String time in availableTimes) {
      final timeHour = int.tryParse(time.split(':')[0]) ?? 5;
      final diff = (timeHour - currentHour).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestTime = time;
      }
    }

    if (mounted)
      setState(() {
        _selectedVreme = closestTime;
        // Određi grad na osnovu vremena - kao u home_screen
        if ([
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
        ].contains(closestTime)) {
          _selectedGrad = 'Bela Crkva';
        } else {
          _selectedGrad = 'Vršac';
        }
      });
  }

  @override
  void initState() {
    super.initState();

    // 🚥 INICIJALIZUJ NETWORK STATUS SERVICE
    RealtimeNetworkStatusService.instance.initialize();

    // 🚨 INICIJALIZUJ FAIL-FAST STREAM MANAGER
    // Registruj kritične stream-ove koji ne smeju da ne rade
    FailFastStreamManager.instance.registerCriticalStream('putnici_stream');
    FailFastStreamManager.instance.registerCriticalStream('pazar_stream');

    // ✅ SETUP FILTERS FROM NOTIFICATION DATA
    if (widget.filterGrad != null) {
      _selectedGrad = widget.filterGrad!;
    }
    if (widget.filterVreme != null) {
      _selectedVreme = widget.filterVreme!;
    }

    // Ako nema filter podataka iz notifikacije, koristi default logiku
    if (widget.filterGrad == null && widget.filterVreme == null) {
      // Koristi WidgetsBinding da osigura da se setState pozove nakon build ciklusa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeCurrentTime(); // ✅ SINHRONIZACIJA - postavi trenutno vreme i grad kao home_screen
      });
    }

    _initializeCurrentDriver();
    // Nakon inicijalizacije vozača, proveri whitelist i poveži realtime stream za daily_checkins
    _initializeCurrentDriver().then((_) {
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
      if (_currentDriver != null && _currentDriver!.isNotEmpty) {
        try {
          // Initialize kusur stream to show current value
          DailyCheckInService.initializeStreamForVozac(_currentDriver!);

          _dailyCheckinSub = SimplifiedDailyCheckInService.initializeRealtimeForDriver(_currentDriver!);

          // 💓 POKRENI HEARTBEAT MONITORING
          _startHealthMonitoring();
        } catch (e) {}
      }
    });
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

    // Start network status listener to auto-refetch when we recover connectivity
    _prevNetworkStatus = RealtimeNetworkStatusService.instance.networkStatus.value;
    RealtimeNetworkStatusService.instance.networkStatus.addListener(_onNetworkStatusChanged);

    //  REAL-TIME NOTIFICATION COUNTER
    RealtimeNotificationCounterService.initialize();

    // 🛰️ START GPS TRACKING
    RealtimeGpsService.startTracking().catchError((Object e) {});

    // Auto-refetch disabled (manual refresh only for now)
    // _wasRealtimeHealthy = _isRealtimeHealthy.value;
    // _isRealtimeHealthy.addListener(_onRealtimeHealthyChanged);

    // Subscribe to driver GPS position updates to pass to route optimization
    _driverPositionSubscription = RealtimeGpsService.positionStream.listen((pos) {
      _lastDriverPosition = pos;
    });

    // 🔔 SHOW NOTIFICATION MESSAGE IF PASSENGER NAME PROVIDED
    if (widget.highlightPutnikIme != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNotificationMessage();
      });
    }
  }

  void _initializeRealtimeTracking() {
    // DISABLED: Google APIs removed to keep app 100% FREE - method does nothing now
  }

  // 🔔 SHOW NOTIFICATION MESSAGE WHEN OPENED FROM NOTIFICATION
  void _showNotificationMessage() {
    if (widget.highlightPutnikIme == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notification_important, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔔 Otvoreno iz notifikacije',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  Text(
                    'Putnik: ${widget.highlightPutnikIme} | ${widget.filterGrad} ${widget.filterVreme}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        action: SnackBarAction(label: 'OK', textColor: Theme.of(context).colorScheme.onPrimary, onPressed: () {}),
      ),
    );
  }

  /// 🔍 GRAD POREĐENJE - razlikuj mesečne i obične putnike
  bool _isGradMatch(String? putnikGrad, String? putnikAdresa, String selectedGrad, {bool isMesecniPutnik = false}) {
    // Za mesečne putnike - direktno poređenje grada
    if (isMesecniPutnik) {
      return putnikGrad == selectedGrad;
    }
    // Za obične putnike - koristi adresnu validaciju
    return GradAdresaValidator.isGradMatch(putnikGrad, putnikAdresa, selectedGrad);
  }

  Future<void> _initializeCurrentDriver() async {
    _currentDriver = await FirebaseService.getCurrentDriver();
    // Inicijalizacija vozača završena
  }

  @override
  void dispose() {
    // 🛑 Zaustavi realtime tracking kad se ekran zatvori
    // DISABLED: Google APIs removed
    // RealtimeRouteTrackingService.stopRouteTracking();

    // 🧹 CLEANUP TIMER MEMORY LEAKS - KORISTI TIMER MANAGER
    TimerManager.cancelTimer('danas_screen_reset_debounce');
    TimerManager.cancelTimer('danas_screen_reset_debounce_2');

    // Otkaži pretplatu za daily_checkins ako postoji
    try {
      _dailyCheckinSub?.cancel();
    } catch (e) {}

    // 💓 CLEANUP HEARTBEAT MONITORING
    TimerManager.cancelTimer('danas_screen_heartbeat');

    // 🧹 SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
      }
    } catch (e) {}

    // 🚨 FAIL-FAST CLEANUP - DISPOSE ALL STREAMS
    FailFastStreamManager.instance.disposeAll();
    try {
      RealtimeNetworkStatusService.instance.networkStatus.removeListener(_onNetworkStatusChanged);
    } catch (e) {}
    try {
      _driverPositionSubscription?.cancel();
    } catch (e) {}
    super.dispose();
  }

  // Uklonjeno ručno učitavanje putnika, koristi se stream

  // Uklonjeno: _calculateDnevniPazar

  // Uklonjeno, filtriranje ide u StreamBuilder

  // Filtriranje dužnika ide u StreamBuilder

  // Optimizacija rute za trenutni polazak (napredna verzija)
  void _optimizeCurrentRoute(List<Putnik> putnici, {bool isAlreadyOptimized = false}) async {
    // Proveri da li je ulogovan i valjan vozač
    if (_currentDriver == null || !VozacBoja.isValidDriver(_currentDriver)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Morate biti ulogovani i ovlašćeni da biste koristili optimizaciju rute.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    if (mounted)
      setState(() {
        _isLoading = true; // ✅ POKRENI LOADING
      });

    // Optimizacija rute

    // 🎯 Ako je lista već optimizovana od strane servisa, koristi je direktno
    if (isAlreadyOptimized) {
      if (putnici.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Nema putnika sa adresama za reorder'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      if (mounted)
        setState(() {
          _optimizedRoute = List<Putnik>.from(putnici);
          _isRouteOptimized = true;
          _isListReordered = true;
          _currentPassengerIndex = 0;
          _isGpsTracking = true;
          _isLoading = false;
        });

      final routeString = _optimizedRoute.take(3).map((p) => p.adresa?.split(',').first ?? p.ime).join(' → ');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎯 Lista putnika optimizovana (server) za $_selectedGrad $_selectedVreme!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('📍 Sledeći putnici: $routeString${_optimizedRoute.length > 3 ? "..." : ""}'),
                Text('🎯 Broj putnika: ${_optimizedRoute.length}'),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
      return; // gotova optimizacija
    }

    // 🎯 SAMO REORDER PUTNIKA - bez otvaranja mape
    final filtriraniPutnici = putnici.where((p) {
      final vremeMatch =
          GradAdresaValidator.normalizeTime(p.polazak) == GradAdresaValidator.normalizeTime(_selectedVreme);

      // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - samo Bela Crkva i Vršac
      final gradMatch = _isGradMatch(p.grad, p.adresa, _selectedGrad);

      final danMatch = p.dan == _getTodayForDatabase();
      final statusOk = TextUtils.isStatusActive(p.status);
      final hasAddress = p.adresa != null && p.adresa!.isNotEmpty;

      return vremeMatch && gradMatch && danMatch && statusOk && hasAddress;
    }).toList();
    if (filtriraniPutnici.isEmpty) {
      if (mounted)
        setState(() {
          _isLoading = false; // ✅ RESETUJ LOADING
        });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nema putnika sa adresama za reorder'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      // 🎯 JEDNOSTAVNA OPTIMIZACIJA - sortuj putnice po adresi
      final optimizedPutnici = List<Putnik>.from(filtriraniPutnici)
        ..sort((a, b) => (a.adresa ?? '').compareTo(b.adresa ?? ''));

      if (mounted)
        setState(() {
          _optimizedRoute = optimizedPutnici;
          _isRouteOptimized = true;
          _isListReordered = true; // ✅ Lista je reorderovana
          _currentPassengerIndex = 0; // ✅ Počni od prvog putnika
          _isGpsTracking = true; // 🛰️ Pokreni GPS tracking
          // _lastGpsUpdate = DateTime.now(); // 🛰️ REMOVED - Google APIs disabled
          _isLoading = false; // ✅ ZAUSTAVI LOADING
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('📍 Sledeći putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
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
      try {
        // Fallback na osnovnu optimizaciju
        final fallbackOptimized = await RouteOptimizationService.optimizeRouteGeographically(
          filtriraniPutnici,
          startAddress: _selectedGrad == 'Bela Crkva' ? 'Bela Crkva, Serbia' : 'Vršac, Serbia',
        );

        if (mounted)
          setState(() {
            _optimizedRoute = fallbackOptimized;
            _isRouteOptimized = true;
            _isListReordered = true;
            _currentPassengerIndex = 0;
            _isGpsTracking = true;
            // _lastGpsUpdate = DateTime.now(); // REMOVED - Google APIs disabled
            _isLoading = false; // ✅ RESETUJ LOADING
          });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Koristim osnovnu GPS optimizaciju (napredna nije dostupna)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (fallbackError) {
        // Kompletno neuspešna optimizacija - resetuj sve
        if (mounted)
          setState(() {
            _isLoading = false; // ✅ RESETUJ LOADING
            _isRouteOptimized = false;
            _isListReordered = false;
          });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nije moguće optimizovati rutu. Pokušajte ponovo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager().currentGradient, // Theme-aware gradijent
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Transparentna pozadina
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).glassContainer, // Transparentni glassmorphism
              border: Border.all(color: Theme.of(context).glassBorder, width: 1.5),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
              // No boxShadow — AppBar should be fully transparent and show only the glass border
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // DATUM TEKST - kao rezervacije
                    Center(child: _buildDigitalDateDisplay()), // dodano Center widget
                    const SizedBox(height: 4),
                    // DUGMAD U APP BAR-U - dinamički broj dugmića
                    Row(
                      children: [
                        // � CLEAN STATS INDIKATOR
                        Expanded(child: _buildHeartbeatIndicator()),
                        const SizedBox(width: 2),
                        // �🎓 ĐAČKI BROJAČ
                        Expanded(child: _buildDjackiBrojacButton()),
                        const SizedBox(width: 2),
                        // 🚀 DUGME ZA OPTIMIZACIJU RUTE
                        Expanded(child: _buildOptimizeButton()),
                        const SizedBox(width: 2),
                        // 📋 DUGME ZA POPIS DANA
                        Expanded(child: _buildPopisButton()),
                        const SizedBox(width: 2),
                        // 🗺️ DUGME ZA NAVIGACIJU (OpenStreetMap / free)
                        Expanded(child: _buildMapsButton()),
                        const SizedBox(width: 2),
                        // ⚡ SPEEDOMETER
                        Expanded(child: _buildSpeedometerButton()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<Putnik>>(
                stream: _putnikService.streamKombinovaniPutniciFiltered(
                  isoDate: DateTime.now().toIso8601String().split('T')[0],
                  grad: widget.filterGrad ?? _selectedGrad,
                  vreme: widget.filterVreme ?? _selectedVreme,
                ), // 🔄 KOMBINOVANI STREAM (mesečni + dnevni)
                builder: (context, snapshot) {
                  // 💓 REGISTRUJ HEARTBEAT ZA GLAVNI PUTNICI STREAM
                  _registerStreamHeartbeat('putnici_stream');

                  // Ako se lista putnika promenila, invalidiraj cache za trenutni grad/vreme/dan
                  // Ako je lista putnika promenjena u real-time, invalidiraj cache
                  // kako bi optimizovana ruta prema novim podacima bila ponovo kalkulisana
                  if (snapshot.hasData) {
                    final list = snapshot.data!;
                    // Build set of ids that match current grad/vreme/dan
                    final Set<String> matchingIds = {};
                    final selectedGrad = widget.filterGrad ?? _selectedGrad;
                    final selectedVreme = widget.filterVreme ?? _selectedVreme;
                    final selectedDan = _getTodayForDatabase();
                    for (final p in list) {
                      final gradMatch = _isGradMatch(p.grad, p.adresa, selectedGrad);
                      final vremeMatch = GradAdresaValidator.normalizeTime(p.polazak) ==
                          GradAdresaValidator.normalizeTime(selectedVreme);
                      final danMatch = p.dan == selectedDan ||
                          p.datum == selectedDan ||
                          (p.datum == null &&
                              GradAdresaValidator.normalizeString(
                                p.dan,
                              ).contains(GradAdresaValidator.normalizeString(selectedDan)));
                      if (gradMatch && vremeMatch && danMatch) {
                        matchingIds.add(p.id.toString());
                      }
                    }

                    // If the set changed compared to last matching ids, invalidate only the relevant cache key
                    if (!_setEquals(_lastMatchingIds, matchingIds)) {
                      _lastMatchingIds = matchingIds;
                      try {
                        _routeOptimizationService.invalidateCacheFor(grad: selectedGrad, vreme: selectedVreme);
                        if (mounted) setState(() {});
                      } catch (_) {}
                    }
                  }

                  // 🚥 REGISTRUJ NETWORK STATUS - SUCCESS/ERROR
                  if (snapshot.hasData && !snapshot.hasError) {
                    RealtimeNetworkStatusService.instance.registerStreamResponse(
                      'putnici_stream',
                      const Duration(milliseconds: 500), // Estimated response time
                    );
                  } else if (snapshot.hasError) {
                    RealtimeNetworkStatusService.instance.registerStreamResponse(
                      'putnici_stream',
                      const Duration(seconds: 30), // Error timeout
                      hasError: true,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    // Heartbeat indicator shows connection status
                    return const Center(
                      child: Text(
                        'Nema putnika za izabrani polazak',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  final sviPutnici = snapshot.data ?? [];
                  final danasnjiDan = _getTodayForDatabase();

                  // Real-time filtriranje
                  final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

                  final danasPutnici = sviPutnici.where((p) {
                    // Dan u nedelji filter
                    final dayMatch = p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());

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
                    final vremeMatch =
                        GradAdresaValidator.normalizeTime(putnik.polazak) == GradAdresaValidator.normalizeTime(vreme);

                    // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                    final gradMatch = _isGradMatch(
                      putnik.grad,
                      putnik.adresa,
                      grad,
                      isMesecniPutnik: putnik.mesecnaKarta == true,
                    );

                    // MESEČNI PUTNICI - isto kao u home_screen
                    if (putnik.mesecnaKarta == true) {
                      // Za mesečne putnike, samo isključi obrisane
                      final statusOk = putnik.status != 'obrisan';
                      return vremeMatch && gradMatch && statusOk;
                    } else {
                      // DNEVNI PUTNICI - standardno filtriranje
                      final statusOk = TextUtils.isStatusActive(putnik.status);
                      return vremeMatch && gradMatch && statusOk;
                    }
                  }).toList();

                  // Koristiti optimizovanu rutu ako postoji, ali filtriraj je po trenutnom polazaku
                  final finalPutnici = _isRouteOptimized
                      ? _optimizedRoute.where((putnik) {
                          final vremeMatch = GradAdresaValidator.normalizeTime(putnik.polazak) ==
                              GradAdresaValidator.normalizeTime(vreme);

                          // 🏘️ KORISTI NOVU OGRANIČENU LOGIKU - razlikuj mesečne i obične putnike
                          final gradMatch = _isGradMatch(
                            putnik.grad,
                            putnik.adresa,
                            grad,
                            isMesecniPutnik: putnik.mesecnaKarta == true,
                          );

                          // MESEČNI PUTNICI - isto kao u home_screen
                          bool statusOk;
                          if (putnik.mesecnaKarta == true) {
                            // Za mesečne putnike, samo isključi obrisane
                            statusOk = putnik.status != 'obrisan';
                          } else {
                            // DNEVNI PUTNICI - standardno filtriranje
                            statusOk = TextUtils.isStatusActive(putnik.status);
                          }

                          return vremeMatch && gradMatch && statusOk;
                        }).toList()
                      : filtriraniPutnici;
                  // 💳 SVIH DUŽNIKA SORTIRANIH PO DATUMU (najnoviji na vrhu)
                  final filteredDuznici = danasPutnici.where((putnik) {
                    final nijePlatio = (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0);
                    final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                    final jesteMesecni = putnik.mesecnaKarta == true;
                    final pokupljen = putnik.jePokupljen;

                    // ✅ NOVA LOGIKA: Vozači vide SVE dužnike (mogu naplatiti bilo koji dug)
                    // Uklonjeno filtriranje po vozaču - jeOvajVozac filter

                    return nijePlatio && nijeOtkazan && !jesteMesecni && pokupljen;
                  }).toList();

                  // Sortiraj po vremenu pokupljenja (najnoviji na vrhu)
                  filteredDuznici.sort((a, b) {
                    final aTime = a.vremePokupljenja;
                    final bTime = b.vremePokupljenja;

                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;

                    return bTime.compareTo(aTime);
                  });
                  // KORISTI NOVU STANDARDIZOVANU LOGIKU ZA PAZAR 💰
                  // ✅ UVEK KORISTI SAMO DANAŠNJI DAN
                  final today = DateTime.now();
                  final dayStart = DateTime(today.year, today.month, today.day);
                  final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
                  return StreamBuilder<double>(
                    stream: StatistikaService.streamPazarZaVozaca(
                      _currentDriver ?? '',
                      from: dayStart,
                      to: dayEnd,
                    ), // 🔄 REAL-TIME PAZAR STREAM
                    builder: (context, pazarSnapshot) {
                      // 💓 REGISTRUJ HEARTBEAT ZA PAZAR STREAM
                      _registerStreamHeartbeat('pazar_stream');

                      // 🚥 REGISTRUJ NETWORK STATUS - SUCCESS/ERROR
                      if (pazarSnapshot.hasData && !pazarSnapshot.hasError) {
                        RealtimeNetworkStatusService.instance.registerStreamResponse(
                          'pazar_stream',
                          const Duration(milliseconds: 800), // Estimated response time
                        );
                      } else if (pazarSnapshot.hasError) {
                        RealtimeNetworkStatusService.instance.registerStreamResponse(
                          'pazar_stream',
                          const Duration(seconds: 30), // Error timeout
                          hasError: true,
                        );
                      }

                      if (pazarSnapshot.hasError) {
                        // Heartbeat indicator shows connection status
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!pazarSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      double ukupnoPazarVozac = pazarSnapshot.data!;

                      // Mesečne karte su već uključene u pazarZaVozaca funkciju
                      return Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 69, // smanjio sa 70 na 69
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[300]!),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Pazar',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ukupnoPazarVozac.toStringAsFixed(0),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    height: 69, // smanjio sa 70 na 69
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.purple[300]!),
                                    ),
                                    child: StreamBuilder<int>(
                                      stream: StatistikaService.streamBrojMesecnihKarataZaVozaca(
                                        _currentDriver ?? '',
                                        from: dayStart,
                                        to: dayEnd,
                                      ),
                                      builder: (context, mesecneSnapshot) {
                                        final brojMesecnih = mesecneSnapshot.data ?? 0;
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Mesečne',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              brojMesecnih.toString(),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    height: 69, // smanjio sa 70 na 69
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red[300]!),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (context) => DugoviScreen(currentDriver: _currentDriver),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Dugovi',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            filteredDuznici.length.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // 🌅 NOVA KOCKA ZA SITAN NOVAC
                                Expanded(
                                  child: Container(
                                    height: 69, // smanjio sa 70 na 69
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange[300]!),
                                    ),
                                    child: StreamBuilder<double>(
                                      stream: SimplifiedDailyCheckInService.streamTodayAmount(_currentDriver ?? ''),
                                      builder: (context, sitanSnapshot) {
                                        final sitanNovac = sitanSnapshot.data ?? 0.0;
                                        return Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Kusur',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              sitanNovac > 0 ? sitanNovac.toStringAsFixed(0) : '-',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        );
                                      },
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
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      if (_isRouteOptimized)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(8),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: _isGpsTracking ? Colors.blue[50] : Colors.green[50],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _isGpsTracking ? Colors.blue[300]! : Colors.green[300]!,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _isGpsTracking ? Icons.gps_fixed : Icons.route,
                                                color: _isGpsTracking ? Colors.blue : Colors.green,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _isListReordered
                                                          ? '🎯 Lista Reorderovana (${_currentPassengerIndex + 1}/${_optimizedRoute.length})'
                                                          : (_isGpsTracking
                                                              ? '🛰️ GPS Tracking AKTIVAN'
                                                              : 'Ruta optimizovana'),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: _isListReordered
                                                            ? Colors.orange[700]
                                                            : (_isGpsTracking ? Colors.blue : Colors.green),
                                                      ),
                                                    ),
                                                    // 🎯 PRIKAZ TRENUTNOG PUTNIKA
                                                    if (_isListReordered &&
                                                        _currentPassengerIndex < _optimizedRoute.length)
                                                      Text(
                                                        '👤 SLEDEĆI: ${_optimizedRoute[_currentPassengerIndex].ime}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.orange[600],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    // 🧭 PRIKAZ NAVIGATION STATUS-A
                                                    if (_useAdvancedNavigation && _navigationStatus.isNotEmpty)
                                                      Text(
                                                        '🧭 $_navigationStatus',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.indigo[600],
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    // DISABLED: Google APIs removed - StreamBuilder completely removed
                                                    // REMOVED: Complete StreamBuilder block - Google APIs disabled
                                                    // 🔄 REAL-TIME ROUTE STRING
                                                    StreamBuilder<String>(
                                                      stream: Stream.fromIterable([finalPutnici]).map(
                                                        (putnici) => 'Optimizovana ruta: ${putnici.length} putnika',
                                                      ),
                                                      initialData: 'Pripremi rutu...',
                                                      builder: (context, snapshot) {
                                                        if (snapshot.hasData) {
                                                          return Text(
                                                            snapshot.data!,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: _isGpsTracking ? Colors.blue : Colors.green,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          );
                                                        } else {
                                                          return const Text(
                                                            'Učitavanje...',
                                                            style: TextStyle(fontSize: 10, color: Colors.green),
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
                                      if (_useAdvancedNavigation && _optimizedRoute.isNotEmpty)
                                        RealTimeNavigationWidget(
                                          optimizedRoute: _optimizedRoute,
                                          onStatusUpdate: (message) {
                                            if (mounted)
                                              setState(() {
                                                _navigationStatus = message;
                                              });
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
                                              );
                                            }
                                          },
                                          onRouteUpdate: (newRoute) {
                                            if (mounted)
                                              setState(() {
                                                _optimizedRoute = newRoute;
                                              });
                                          },
                                        ),
                                      Expanded(
                                        child: PutnikList(
                                          putnici: finalPutnici,
                                          useProvidedOrder: _isListReordered,
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
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
        bottomNavigationBar: StreamBuilder<List<Putnik>>(
          // 🔧 IDENTIČAN PRISTUP KAO HOME_SCREEN: dobijamo SVE putničke za dan, bez filtera
          stream: _putnikService.streamKombinovaniPutniciFiltered(
            isoDate: DateTime.now().toIso8601String().split('T')[0],
            // UKLONJENO grad/vreme filteri da bi brojevi bili identični kao u home_screen
          ),
          builder: (context, snapshot) {
            // Koristi prazan lista putnika ako nema podataka
            final allPutnici = snapshot.hasData ? snapshot.data! : <Putnik>[];

            // 🔧 IDENTIČNA LOGIKA SA HOME SCREEN ZA BROJANJE PUTNIKA
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

            for (final p in allPutnici) {
              if (!TextUtils.isStatusActive(p.status)) continue;

              // 🔧 IDENTIČNA LOGIKA SA HOME SCREEN - filtriranje po datumu
              final targetDateIso = DateTime.now().toIso8601String().split('T')[0];
              final targetDayAbbr = _isoDateToDayAbbr(targetDateIso);
              final dayMatch = p.datum != null
                  ? p.datum == targetDateIso
                  : p.dan.toLowerCase().contains(targetDayAbbr.toLowerCase());
              if (!dayMatch) continue;

              final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
              // 🔧 ISPRAVKA: Koristi grad umesto adrese za klasifikaciju polazaka
              final putnikGrad = p.grad.toLowerCase();

              final jeBelaCrkva =
                  putnikGrad.contains('bela') || putnikGrad.contains('bc') || putnikGrad == 'bela crkva';
              final jeVrsac = putnikGrad.contains('vrsac') || putnikGrad.contains('vs') || putnikGrad == 'vršac';

              if (jeBelaCrkva && brojPutnikaBC.containsKey(normVreme)) {
                brojPutnikaBC[normVreme] = (brojPutnikaBC[normVreme] ?? 0) + 1;
              }
              if (jeVrsac && brojPutnikaVS.containsKey(normVreme)) {
                brojPutnikaVS[normVreme] = (brojPutnikaVS[normVreme] ?? 0) + 1;
              }
            }

            // Helper funkcija za brojanje putnika
            int getPutnikCount(String grad, String vreme) {
              if (grad == 'Bela Crkva') return brojPutnikaBC[vreme] ?? 0;
              if (grad == 'Vršac') return brojPutnikaVS[vreme] ?? 0;
              return 0;
            }

            // Return Widget
            return isZimski(DateTime.now())
                ? BottomNavBarZimski(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                    onPolazakChanged: (grad, vreme) {
                      if (mounted)
                        setState(() {
                          _selectedGrad = grad;
                          _selectedVreme = vreme;
                        });

                      // 🕐 KORISTI TIMER MANAGER za debounce - SPREČAVA MEMORY LEAK
                      TimerManager.debounce('danas_screen_reset_debounce', const Duration(milliseconds: 150), () async {
                        final key = '$grad|$vreme';
                        if (mounted) setState(() => _resettingSlots.add(key));
                        try {
                          await _putnikService.resetPokupljenjaNaPolazak(vreme, grad, _currentDriver ?? 'Unknown');
                          await RealtimeService.instance.refreshNow();
                        } catch (e) {
                        } finally {
                          if (mounted) {
                            if (mounted) setState(() => _resettingSlots.remove(key));
                          }
                        }
                      });
                    },
                  )
                : BottomNavBarLetnji(
                    sviPolasci: _sviPolasci,
                    selectedGrad: _selectedGrad,
                    selectedVreme: _selectedVreme,
                    getPutnikCount: getPutnikCount,
                    isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                    onPolazakChanged: (grad, vreme) async {
                      if (mounted)
                        setState(() {
                          _selectedGrad = grad;
                          _selectedVreme = vreme;
                        });

                      // 🕐 KORISTI TIMER MANAGER za debounce - SPREČAVA MEMORY LEAK
                      TimerManager.debounce(
                        'danas_screen_reset_debounce_2',
                        const Duration(milliseconds: 150),
                        () async {
                          final key = '$grad|$vreme';
                          if (mounted) setState(() => _resettingSlots.add(key));
                          try {
                            await _putnikService.resetPokupljenjaNaPolazak(vreme, grad, _currentDriver ?? 'Unknown');
                            await RealtimeService.instance.refreshNow();
                          } catch (e) {
                          } finally {
                            if (mounted) {
                              if (mounted) setState(() => _resettingSlots.remove(key));
                            }
                          }
                        },
                      );
                    },
                  );
          },
        ),
      ), // Zatvaranje Container wrapper-a
    );
  }

  // 🗺️ NAVIGATION HANDLING IS MANAGED BY SmartNavigationService

  Future<void> _startSmartNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      final result = await SmartNavigationService.startOptimizedNavigation(
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _optimizedRoute = result.optimizedPutnici ?? _optimizedRoute;
            _isRouteOptimized = true;
            _isGpsTracking = true;
            _navigationStatus = result.message;
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('🗺️ ${result.message}'), backgroundColor: Colors.green));
      } else {
        if (mounted)
          setState(() {
            _isGpsTracking = false;
            _navigationStatus = result.message;
          });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ ${result.message}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGpsTracking = false;
          _navigationStatus = 'Greška pri pokretanju navigacije: $e';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Greška pri pokretanju navigacije: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _stopSmartNavigation() {
    if (mounted)
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🛑 Navigacija zaustavljena'), backgroundColor: Colors.orange));
  }
}
