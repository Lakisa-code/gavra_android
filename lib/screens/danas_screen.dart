import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎨 DODANO za SystemUiOverlayStyle
import 'package:geolocator/geolocator.dart'; // 🗺️ DODANO za OpenStreetMap
import 'package:supabase_flutter/supabase_flutter.dart'; // DODANO za direktne pozive

import '../models/putnik.dart';
// url_launcher unused here - navigacija delegirana SmartNavigationService

import '../models/registrovani_putnik.dart';
import '../services/daily_checkin_service.dart'; // 🔧 DODANO za kusur stream initialize
import '../services/driver_location_service.dart'; // 🚐 DODANO za realtime ETA putnicima
import '../services/fail_fast_stream_manager_new.dart'; // 🚨 NOVO fail-fast stream manager
import '../services/firebase_service.dart';
import '../services/kapacitet_service.dart'; // 🎫 Kapacitet za bottom nav bar
import '../services/local_notification_service.dart';
import '../services/pickup_tracking_service.dart'; // 🛰️ DODANO za GPS pickup tracking
import '../services/putnik_push_service.dart'; // 📱 DODANO za push notifikacije putnicima
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_gps_service.dart'; // 🛰️ DODANO za GPS tracking
import '../services/realtime_network_status_service.dart'; // 🚥 NOVO network status service
import '../services/realtime_notification_counter_service.dart'; // 🔔 DODANO za notification count
import '../services/realtime_notification_service.dart';
import '../services/realtime_service.dart';
import '../services/registrovani_putnik_service.dart'; // 🎓 DODANO za đačke statistike
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
  bool _isPopisLoading = false; // ✅ ISPRAVKA: Loading state za POPIS dugme

  Widget _buildPopisButton() {
    final bool isDriverValid = _currentDriver != null && VozacBoja.isValidDriver(_currentDriver);
    return SizedBox(
      height: 26,
      child: ElevatedButton(
        onPressed: (!isDriverValid || _isPopisLoading) ? null : () => _showPopisDana(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isPopisLoading ? Colors.grey.shade400 : Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        child: _isPopisLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('POPIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.3)),
              ),
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
    final registrovaniStream = RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici();

    return registrovaniStream.asyncMap((sviRegistrovaniPutnici) async {
      try {
        final danasnjiDan = _getTodayForDatabase();

        // 🎓 ĐAČKI BROJAČ - FIKSNA LOGIKA:
        // - UKUPNO = učenici koji su KRENULI UJUTRU U ŠKOLU (BC → VS, polazak iz Bele Crkve)
        // - OSTALO = učenici koji još treba da se VRATE IZ ŠKOLE (VS → BC, povratak iz Vršca)
        // Ovo je UVEK BC→VS smer, nezavisno od selektovanog grada u filteru!

        // 🔧 FILTER: Uzmi SVE učenike koji imaju BC polazak danas (idu u školu)
        final ucenici = sviRegistrovaniPutnici.where((RegistrovaniPutnik mp) {
          // 🔧 ISPRAVKA: Tokenize days and trim; robust tip matching
          final radniDaniList =
              mp.radniDani.toLowerCase().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final dayMatch = radniDaniList.contains(danasnjiDan.toLowerCase());

          final tipNormalized = TextUtils.normalizeTip(mp.tip);
          final isUcenik = tipNormalized.contains('ucenik');

          // 🎓 FIKSNO: Učenik MORA imati BC polazak da bi bio ubrojan (ide u školu ujutru)
          final polazakBC = mp.getPolazakBelaCrkvaZaDan(danasnjiDan);
          final ideUSkolu = polazakBC != null && polazakBC.isNotEmpty;

          return dayMatch && isUcenik && ideUSkolu;
        }).toList();

        // 🎓 FINALNA LOGIKA: UKUPNO/OSTALO
        // UKUPNO = svi koji su krenuli ujutru u školu (BC polazak)
        // OSTALO = oni koji još nemaju upisan povratak (VS polazak) ili su otkazali
        int ukupnoUjutro = 0; // ukupno učenika koji su krenuli u školu
        int reseniUcenici = 0; // učenici upisani za povratak (imaju VS polazak)
        int otkazaliUcenici = 0; // učenici koji su otkazali

        for (final ucenik in ucenici) {
          // 🔧 PROVERA: Da li je aktivni učenik (standardizovano)
          final jeAktivan = TextUtils.isStatusActive(ucenik.status);

          // 🔧 PROVERA: Da li je otkazao (standardizovano)
          final jeOtkazao = !jeAktivan;

          // Da li ima upisan povratak iz škole (VS polazak)?
          final polazakVS = ucenik.getPolazakVrsacZaDan(danasnjiDan);
          final imaUpisanPovratak = polazakVS != null && polazakVS.isNotEmpty;

          // Svi koji idu u školu se broje
          ukupnoUjutro++;

          if (jeOtkazao) {
            otkazaliUcenici++; // otkazao
          } else if (jeAktivan && imaUpisanPovratak) {
            reseniUcenici++; // aktivan + upisan povratak = rešen
          }
        }

        // Uključi današnje "zakupljeno" iz putovanja_istorija da ne bismo propustili grupne rezervacije
        int zakupljenoCount = 0;
        try {
          final zakupljenoRows = await RegistrovaniPutnikService.getZakupljenoDanas();
          for (final z in zakupljenoRows) {
            try {
              final putnikZ = Putnik.fromPutovanjaIstorija(z);
              // 🎓 FIKSNO: Broji samo zakupljene koji su krenuli iz Bele Crkve (u školu)
              final gradNorm = TextUtils.normalizeText(putnikZ.grad);
              final jeIzBeleCrkve = gradNorm.contains('bela');

              if (!jeIzBeleCrkve) {
                continue;
              }

              // De-dupe using name match to avoid double counting the same registrovani putnik
              final nameMatch = sviRegistrovaniPutnici.any(
                (mp) => mp.putnikIme.trim().toLowerCase() == putnikZ.ime.trim().toLowerCase(),
              );
              if (!nameMatch) {
                zakupljenoCount++;
              }
            } catch (_) {}
          }
        } catch (_) {}

        // ✅ ISPRAVKA: Računaj ukupno SA zakupljenim pre računanja ostalo
        final ukupnoSaZakupljeno = ukupnoUjutro + zakupljenoCount;

        // ✅ ISPRAVKA: Računaj ostalo NAKON uključivanja zakupljenih za konzistentnost
        final ostalo = ukupnoSaZakupljeno - reseniUcenici - otkazaliUcenici;

        return {
          'ukupno_ujutro': ukupnoSaZakupljeno, // ukupno koji idu ujutro (incl. zakupljeno)
          'reseni': reseniUcenici, // upisani za oba pravca
          'otkazali': otkazaliUcenici, // otkazani
          'ostalo': ostalo, // ostalo da se vrati (konzistentno sa ukupno)
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
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$dayStr.$monthStr.$yearStr',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimary,
                          letterSpacing: 1.8,
                          shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ),
                  // SREDINA - DAN
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimary,
                          letterSpacing: 1.8,
                          shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ),
                  // DESNO - VREME
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: ClockTicker(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimary,
                          letterSpacing: 1.8,
                          shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                        ),
                        showSeconds: true,
                      ),
                    ),
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🚀 KOMPAKTNO DUGME ZA OPTIMIZACIJU
  // ✅ ISPRAVKA: Koristi _currentPutnici state varijablu
  Widget _buildOptimizeButton() {
    final hasPassengers = _currentPutnici.isNotEmpty;
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
                  _optimizeCurrentRoute(_currentPutnici, isAlreadyOptimized: false);
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isRouteOptimized ? 'Reset' : 'Ruta',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
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
            child: FittedBox(
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
            ? () => (_isGpsTracking ? _stopSmartNavigation() : _showNavigationOptionsDialog())
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isGpsTracking ? Icons.stop : Icons.navigation,
                size: 10,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 2),
              Text(
                _isGpsTracking ? 'STOP' : 'NAV',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🗺️ DIJALOG SA OPCIJAMA NAVIGACIJE
  void _showNavigationOptionsDialog() {
    final putnikCount = _optimizedRoute.length;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.navigation, color: Colors.blue),
            SizedBox(width: 8),
            Text('Navigacija', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opcija 1: Samo sledeći putnik
            ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: const Text('Sledeći putnik'),
              subtitle: Text(
                _optimizedRoute.isNotEmpty
                    ? '${_optimizedRoute.first.ime} - ${_optimizedRoute.first.adresa}'
                    : 'Nema putnika',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _startSmartNavigation();
              },
            ),
            const Divider(),
            // Opcija 2: Svi putnici (multi-waypoint)
            ListTile(
              leading: const Icon(Icons.group, color: Colors.blue),
              title: Text('Svi putnici ($putnikCount)'),
              subtitle: Text(
                putnikCount > 10 ? 'Prvih 10 kao waypoints, ostali posle' : 'Svi kao waypoints u HERE WeGo',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _startAllWaypointsNavigation();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Otkaži'),
          ),
        ],
      ),
    );
  }

  // 🗺️ NAVIGACIJA SA SVIM PUTNICIMA (multi-waypoint)
  Future<void> _startAllWaypointsNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      // Koristi SmartNavigationService sa HERE WeGo navigacijom
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
        cachedCoordinates: _cachedCoordinates,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗺️ ${result.message}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            Flexible(
              child: Text(
                'Đaci - Danas ($reseni/$ostalo)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value.toString(),
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
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

    // ✅ ISPRAVKA: Pokreni loading indikator
    if (mounted) setState(() => _isPopisLoading = true);

    try {
      // 1. OSNOVNI PODACI
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      // 2. REALTIME STREAM ZA KOMBINOVANE PUTNIKE
      // ✅ ISPRAVKA: Koristi postojeću _putnikService instancu
      late List<Putnik> putnici;
      try {
        final isoDate = DateTime.now().toIso8601String().split('T')[0];
        final stream = _putnikService.streamKombinovaniPutniciFiltered(
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
    } finally {
      // ✅ ISPRAVKA: Uvek ugasi loading indikator
      if (mounted) setState(() => _isPopisLoading = false);
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
  List<Putnik> _currentPutnici = []; // 🎯 Trenutni putnici za Ruta dugme
  Map<Putnik, Position>? _cachedCoordinates; // 🎯 Keširane koordinate za HERE WeGo

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
    // 🚐 ZAUSTAVI REALTIME TRACKING ZA PUTNIKE
    DriverLocationService.instance.stopTracking();

    if (mounted) {
      setState(() {
        _isRouteOptimized = false;
        _isListReordered = false;
        _optimizedRoute.clear();
        _currentPassengerIndex = 0;
        _isGpsTracking = false;
        // _lastGpsUpdate = null; // REMOVED - Google APIs disabled
        _navigationStatus = '';
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Optimizacija rute je isključena'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🎯 REOPTIMIZACIJA RUTE NAKON PROMENE STATUSA PUTNIKA
  Future<void> _reoptimizeAfterStatusChange() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // 🔄 DOHVATI SVEŽE PODATKE IZ BAZE - lokalni objekti mogu biti zastareli
    final putnikService = PutnikService();
    final sveziPutnici = <Putnik>[];

    for (final p in _optimizedRoute) {
      if (p.id != null) {
        final svez = await putnikService.getPutnikFromAnyTable(p.id!);
        if (svez != null) {
          sveziPutnici.add(svez);
        }
      }
    }

    // Filtriraj samo nepokupljene i neotkazane putnike
    final preostaliPutnici = sveziPutnici.where((p) {
      final isPokupljen = p.jePokupljen;
      final isOtkazan = p.jeOtkazan;
      final isOdsustvo = p.jeOdsustvo;
      return !isPokupljen && !isOtkazan && !isOdsustvo;
    }).toList();

    if (preostaliPutnici.isEmpty) {
      // Svi putnici su pokupljeni ili otkazani
      if (mounted) {
        setState(() {
          _optimizedRoute.clear();
          _isRouteOptimized = false;
          _isListReordered = false;
          _currentPassengerIndex = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Svi putnici su pokupljeni!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // Reoptimizuj rutu od trenutne GPS pozicije
    try {
      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: preostaliPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null) {
        if (mounted) {
          setState(() {
            _optimizedRoute = result.optimizedPutnici!;
            _currentPassengerIndex = 0;
          });

          final sledeci = _optimizedRoute.isNotEmpty ? _optimizedRoute.first.ime : 'N/A';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔄 Ruta ažurirana! Sledeći: $sledeci (${_optimizedRoute.length} preostalo)'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      // Greška pri reoptimizaciji
    }
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

    if (mounted) {
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
  }

  @override
  void initState() {
    super.initState();

    // 🎫 Učitaj kapacitet cache na startu
    KapacitetService.ensureCacheLoaded();

    // 🚥 INICIJALIZUJ NETWORK STATUS SERVICE
    RealtimeNetworkStatusService.instance.initialize();

    // 🚨 INICIJALIZUJ FAIL-FAST STREAM MANAGER
    // Registruj kritične stream-ove koji ne smeju da ne rade
    FailFastStreamManager.instance.registerCriticalStream('putnici_stream');
    // NAPOMENA: pazar_stream NIJE kritičan - to je samo prikaz statistike

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
        } catch (e) {
          // Silently ignore initialization errors
        }
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

    // Subscribe to driver GPS position updates (for future use)
    _driverPositionSubscription = RealtimeGpsService.positionStream.listen((_) {
      // GPS updates available via RealtimeGpsService streams
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
  bool _isGradMatch(String? putnikGrad, String? putnikAdresa, String selectedGrad,
      {bool isRegistrovaniPutnik = false}) {
    // Za mesečne putnike - direktno poređenje grada
    if (isRegistrovaniPutnik) {
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

    // ✅ ISPRAVKA: Zaustavi GPS tracking da se spreči memory leak
    RealtimeGpsService.stopTracking();

    // 🧹 CLEANUP TIMER MEMORY LEAKS - KORISTI TIMER MANAGER
    TimerManager.cancelTimer('danas_screen_reset_debounce');
    TimerManager.cancelTimer('danas_screen_reset_debounce_2');

    // Otkaži pretplatu za daily_checkins ako postoji
    try {
      _dailyCheckinSub?.cancel();
    } catch (e) {
      // Silently ignore
    }

    // 💓 CLEANUP HEARTBEAT MONITORING
    TimerManager.cancelTimer('danas_screen_heartbeat');

    // 🧹 SAFE DISPOSAL ValueNotifier-a
    try {
      if (mounted) {
        _isRealtimeHealthy.dispose();
      }
    } catch (e) {
      // Silently ignore
    }

    // 🚨 FAIL-FAST CLEANUP - DISPOSE ALL STREAMS
    FailFastStreamManager.instance.disposeAll();
    try {
      RealtimeNetworkStatusService.instance.networkStatus.removeListener(_onNetworkStatusChanged);
    } catch (e) {
      // Silently ignore
    }
    try {
      _driverPositionSubscription?.cancel();
    } catch (e) {
      // Silently ignore
    }
    super.dispose();
  }

  // Uklonjeno ručno učitavanje putnika, koristi se stream

  // Uklonjeno: _calculateDnevniPazar

  // Uklonjeno, filtriranje ide u StreamBuilder

  // Filtriranje dužnika ide u StreamBuilder

  // Optimizacija rute za trenutni polazak (napredna verzija)
  void _optimizeCurrentRoute(List<Putnik> putnici, {bool isAlreadyOptimized = false}) async {
    // 🔍 DEBUG: Prikaži koliko putnika dolazi
    debugPrint('🔍 _optimizeCurrentRoute: primljeno ${putnici.length} putnika za $_selectedGrad $_selectedVreme');
    for (final p in putnici) {
      debugPrint('   - ${p.ime} | grad=${p.grad} | polazak=${p.polazak} | mesecna=${p.mesecnaKarta}');
    }

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
    if (mounted) {
      setState(() {
        _isLoading = true; // ✅ POKRENI LOADING
      });
    }

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
      if (mounted) {
        setState(() {
          _optimizedRoute = List<Putnik>.from(putnici);
          _isRouteOptimized = true;
          _isListReordered = true;
          _currentPassengerIndex = 0;
          // NE postavljaj _isGpsTracking ovde - to se radi samo kad korisnik pritisne NAV
          _isLoading = false;
        });
      }

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

    // 🎯 PRAVI FILTER - koristi putnike koji su već prikazani na ekranu
    // Mesečni putnici imaju adresaId koji pokazuje na pravu adresu
    final filtriraniPutnici = putnici.where((p) {
      // Za mesečne putnike: imaju adresaId koji pokazuje na pravu adresu
      // Za dnevne putnike: imaju adresu direktno
      final hasValidAddress = (p.adresaId != null && p.adresaId!.isNotEmpty) ||
          (p.adresa != null && p.adresa!.isNotEmpty && p.adresa != p.grad);
      return hasValidAddress;
    }).toList();
    if (filtriraniPutnici.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false; // ✅ RESETUJ LOADING
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nema putnika sa adresama za reorder'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      // 🎯 KORISTI SMART NAVIGATION SERVICE ZA PRAVU OPTIMIZACIJU RUTE
      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: filtriraniPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null && result.optimizedPutnici!.isNotEmpty) {
        final optimizedPutnici = result.optimizedPutnici!;
        if (mounted) {
          setState(() {
            _optimizedRoute = optimizedPutnici;
            _cachedCoordinates = result.cachedCoordinates; // 🎯 Sačuvaj koordinate za NAV
            _isRouteOptimized = true;
            _isListReordered = true; // ✅ Lista je reorderovana
            _currentPassengerIndex = 0; // ✅ Počni od prvog putnika
            // NE postavljaj _isGpsTracking - aktivira se tek kad korisnik pritisne NAV
            _isLoading = false; // ✅ ZAUSTAVI LOADING
          });
        }

        // 🚐 POKRENI REALTIME TRACKING ZA PUTNIKE
        // Šalje GPS lokaciju + ETA za svakog putnika u Supabase
        if (_currentDriver != null && result.putniciEta != null) {
          final smer = _selectedGrad.toLowerCase().contains('bela') || _selectedGrad == 'BC' ? 'BC_VS' : 'VS_BC';

          // 🆕 Konvertuj koordinate za dinamički ETA
          Map<String, Position>? putniciCoordinates;
          if (result.cachedCoordinates != null) {
            putniciCoordinates = {};
            for (final entry in result.cachedCoordinates!.entries) {
              putniciCoordinates[entry.key.ime] = entry.value;
            }
          }

          await DriverLocationService.instance.startTracking(
            vozacId: _currentDriver!,
            vozacIme: _currentDriver!,
            grad: _selectedGrad,
            vremePolaska: _selectedVreme,
            smer: smer,
            putniciEta: result.putniciEta,
            putniciCoordinates: putniciCoordinates, // 🆕 Za dinamički ETA
            onAllPassengersPickedUp: () {
              // 🆕 Auto-stop callback
              if (mounted) {
                setState(() {
                  _isGpsTracking = false;
                  _navigationStatus = '';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Svi putnici pokupljeni! Tracking automatski zaustavljen.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          );
          debugPrint('🚐 Realtime tracking pokrenut: ${result.putniciEta?.length ?? 0} putnika sa ETA');

          // 📱 POŠALJI PUSH NOTIFIKACIJE PUTNICIMA
          await _sendTransportStartedNotifications(
            putniciEta: result.putniciEta!,
            vozacIme: _currentDriver!,
          );
        }

        // Prikaži rezultat reorderovanja
        final routeString = optimizedPutnici
            .take(3) // Prikaži prva 3 putnika
            .map((p) => p.adresa?.split(',').first ?? p.ime)
            .join(' → ');

        // 🆕 Proveri da li ima preskočenih putnika
        final skipped = result.skippedPutnici;
        final hasSkipped = skipped != null && skipped.isNotEmpty;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 RUTA OPTIMIZOVANA za $_selectedGrad $_selectedVreme!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('📍 Sledeći putnici: $routeString${optimizedPutnici.length > 3 ? "..." : ""}'),
                  Text('🎯 Broj putnika: ${optimizedPutnici.length}'),
                  if (result.totalDistance != null)
                    Text('📏 Ukupno: ${(result.totalDistance! / 1000).toStringAsFixed(1)} km'),
                ],
              ),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.green,
            ),
          );

          // 🆕 Prikaži POSEBAN DIALOG za preskočene putnike - upadljivije!
          if (hasSkipped) {
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.orange.shade100,
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                      const SizedBox(width: 8),
                      Text(
                        '${skipped.length} PUTNIKA BEZ LOKACIJE',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ovi putnici nisu uključeni u optimizovanu rutu:',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      ...skipped.take(5).map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.location_off, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.ime,
                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (skipped.length > 5)
                        Text(
                          '... i još ${skipped.length - 5}',
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue, size: 24),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pokupite ih ručno!\nAplikacija će zapamtiti lokaciju za sledeći put.',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('RAZUMEM', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          }
        }
      } else {
        // SmartNavigationService nije uspeo - fallback na osnovno sortiranje
        final optimizedPutnici = List<Putnik>.from(filtriraniPutnici)
          ..sort((a, b) => (a.adresa ?? '').compareTo(b.adresa ?? ''));

        if (mounted) {
          setState(() {
            _optimizedRoute = optimizedPutnici;
            _isRouteOptimized = true;
            _isListReordered = true;
            _currentPassengerIndex = 0;
            // NE postavljaj _isGpsTracking - aktivira se tek kad korisnik pritisne NAV
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${result.message}\nKoristim osnovno sortiranje.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Greška pri optimizaciji - resetuj loading i prikaži poruku
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRouteOptimized = false;
          _isListReordered = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri optimizaciji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 📱 Pošalji push notifikacije putnicima da je prevoz krenuo
  Future<void> _sendTransportStartedNotifications({
    required Map<String, int> putniciEta,
    required String vozacIme,
  }) async {
    try {
      // Dohvati tokene za sve putnike
      final putnikImena = putniciEta.keys.toList();
      final tokens = await PutnikPushService.getTokensForPutnici(putnikImena);

      if (tokens.isEmpty) {
        debugPrint('📱 Nema registrovanih tokena za putnike');
        return;
      }

      // Pošalji notifikaciju svakom putniku
      for (final entry in tokens.entries) {
        final putnikIme = entry.key;
        final tokenInfo = entry.value;
        final eta = putniciEta[putnikIme] ?? 0;

        await RealtimeNotificationService.sendPushNotification(
          title: '🚐 Kombi je krenuo!',
          body: 'Vozač $vozacIme kreće ka vama. Stiže za ~$eta min.',
          tokens: [
            {'token': tokenInfo['token']!, 'provider': tokenInfo['provider']!}
          ],
          data: {
            'type': 'transport_started',
            'eta_minutes': eta,
            'vozac': vozacIme,
          },
        );

        debugPrint('📱 Notifikacija poslata: $putnikIme (ETA: $eta min)');
      }

      debugPrint('✅ Poslato ${tokens.length} notifikacija putnicima');
    } catch (e) {
      debugPrint('❌ Greška pri slanju notifikacija: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // 🎨 Bele ikonice u status baru
      child: Container(
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
                borderRadius:
                    const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
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
                          const SizedBox(width: 1),
                          // �🎓 ĐAČKI BROJAČ
                          Expanded(child: _buildDjackiBrojacButton()),
                          const SizedBox(width: 1),
                          // 🚀 DUGME ZA OPTIMIZACIJU RUTE
                          Expanded(child: _buildOptimizeButton()),
                          const SizedBox(width: 1),
                          // 📋 DUGME ZA POPIS DANA
                          Expanded(child: _buildPopisButton()),
                          const SizedBox(width: 1),
                          // 🗺️ DUGME ZA NAVIGACIJU (OpenStreetMap / free)
                          Expanded(child: _buildMapsButton()),
                          const SizedBox(width: 1),
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
                        isRegistrovaniPutnik: putnik.mesecnaKarta == true,
                      );

                      // 🔄 UJEDNAČENA LOGIKA: Isti filter za mesečne i dnevne putnike
                      // Isključuje: otkazane, bolovanje, godišnji, obrisane
                      final statusOk = TextUtils.isStatusActive(putnik.status);
                      return vremeMatch && gradMatch && statusOk;
                    }).toList();

                    // 🎯 Ažuriraj _currentPutnici za Ruta dugme (bez setState u build)
                    if (_currentPutnici.length != filtriraniPutnici.length ||
                        !_currentPutnici.every((p) => filtriraniPutnici.any((fp) => fp.id == p.id))) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _currentPutnici = filtriraniPutnici;
                          });
                        }
                      });
                    }

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
                              isRegistrovaniPutnik: putnik.mesecnaKarta == true,
                            );

                            // 🔄 UJEDNAČENA LOGIKA: Isti filter za sve putnike
                            // Isključuje: otkazane, bolovanje, godišnji, obrisane
                            final statusOk = TextUtils.isStatusActive(putnik.status);

                            return vremeMatch && gradMatch && statusOk;
                          }).toList()
                        : filtriraniPutnici;
                    // 💳 DUŽNICI - SAMO DNEVNI PUTNICI koji nisu platili (najnoviji na vrhu)
                    final filteredDuznici = danasPutnici.where((putnik) {
                      final jesteRegistrovani = putnik.mesecnaKarta == true;
                      if (jesteRegistrovani) return false; // ✅ ISKLJUČI mesečne putnike

                      final nijePlatio = (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0);
                      final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                      final pokupljen = putnik.jePokupljen;

                      // ✅ NOVA LOGIKA: Vozači vide SVE dužnike (mogu naplatiti bilo koji dug)
                      // Uklonjeno filtriranje po vozaču - jeOvajVozac filter

                      return nijePlatio && nijeOtkazan && pokupljen;
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
                      ),
                      builder: (context, pazarSnapshot) {
                        // Pazar vrednost - 0.0 ako nema podataka
                        final ukupnoPazarVozac = pazarSnapshot.data ?? 0.0;

                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 69,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green[300]!),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Pazar',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
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
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 69,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.purple[300]!),
                                      ),
                                      child: StreamBuilder<int>(
                                        stream: StatistikaService.streamBrojRegistrovanihZaVozaca(
                                          _currentDriver ?? '',
                                          from: dayStart,
                                          to: dayEnd,
                                        ),
                                        builder: (context, registrovaniSnapshot) {
                                          final brojRegistrovanih = registrovaniSnapshot.data ?? 0;
                                          return FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
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
                                                const SizedBox(height: 2),
                                                Text(
                                                  brojRegistrovanih.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      height: 69,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
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
                                              const SizedBox(height: 2),
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
                                  ),
                                  const SizedBox(width: 6),
                                  // 🌅 NOVA KOCKA ZA SITAN NOVAC
                                  Expanded(
                                    child: Container(
                                      height: 69,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange[300]!),
                                      ),
                                      child: StreamBuilder<double>(
                                        stream: SimplifiedDailyCheckInService.streamTodayAmount(_currentDriver ?? ''),
                                        builder: (context, sitanSnapshot) {
                                          final sitanNovac = sitanSnapshot.data ?? 0.0;
                                          return FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Column(
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
                                                const SizedBox(height: 2),
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
                                            ),
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
                                                            ? '🎯 Lista Reorderovana (${_currentPassengerIndex + 1}/${finalPutnici.length})'
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
                                                      if (_isListReordered && finalPutnici.isNotEmpty)
                                                        Text(
                                                          '👤 SLEDEĆI: ${finalPutnici.first.ime}',
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
                                        // 🧭 RealTimeNavigationWidget UKLONJEN - koriste se samo kartice + dugme za mapu
                                        Expanded(
                                          child: PutnikList(
                                            putnici: finalPutnici,
                                            useProvidedOrder: _isListReordered,
                                            currentDriver: _currentDriver,
                                            selectedGrad: _selectedGrad, // 📍 NOVO: za GPS navigaciju mesečnih putnika
                                            selectedVreme: _selectedVreme, // 📍 NOVO: za GPS navigaciju
                                            onPutnikStatusChanged: _reoptimizeAfterStatusChange, // 🎯 NOVO
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
                      getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                      isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                      onPolazakChanged: (grad, vreme) {
                        // 🚐 ZAUSTAVI STARI TRACKING pre promene polaska
                        DriverLocationService.instance.stopTracking();

                        if (mounted) {
                          setState(() {
                            _selectedGrad = grad;
                            _selectedVreme = vreme;

                            // 🔄 Isključi optimizaciju jer se odnosi na prethodni polazak
                            if (_isRouteOptimized) {
                              _isRouteOptimized = false;
                              _isListReordered = false;
                              _optimizedRoute.clear();
                              _currentPassengerIndex = 0;
                            }
                          });
                        }

                        // 🕐 KORISTI TIMER MANAGER za debounce - SPREČAVA MEMORY LEAK
                        TimerManager.debounce('danas_screen_reset_debounce', const Duration(milliseconds: 150),
                            () async {
                          final key = '$grad|$vreme';
                          if (mounted) setState(() => _resettingSlots.add(key));
                          try {
                            await _putnikService.resetPokupljenjaNaPolazak(vreme, grad, _currentDriver ?? 'Unknown');
                            await RealtimeService.instance.refreshNow();
                          } finally {
                            if (mounted) {
                              setState(() => _resettingSlots.remove(key));
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
                      getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                      isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                      onPolazakChanged: (grad, vreme) async {
                        // 🚐 ZAUSTAVI STARI TRACKING pre promene polaska
                        DriverLocationService.instance.stopTracking();

                        if (mounted) {
                          setState(() {
                            _selectedGrad = grad;
                            _selectedVreme = vreme;

                            // 🔄 Isključi optimizaciju jer se odnosi na prethodni polazak
                            if (_isRouteOptimized) {
                              _isRouteOptimized = false;
                              _isListReordered = false;
                              _optimizedRoute.clear();
                              _currentPassengerIndex = 0;
                            }
                          });
                        }

                        // 🕐 KORISTI TIMER MANAGER za debounce - SPREČAVA MEMORY LEAK
                        TimerManager.debounce(
                          'danas_screen_reset_debounce_2',
                          const Duration(milliseconds: 150),
                          () async {
                            final key = '$grad|$vreme';
                            if (mounted) {
                              setState(() => _resettingSlots.add(key));
                            }
                            try {
                              await _putnikService.resetPokupljenjaNaPolazak(vreme, grad, _currentDriver ?? 'Unknown');
                              await RealtimeService.instance.refreshNow();
                            } finally {
                              if (mounted) {
                                setState(() => _resettingSlots.remove(key));
                              }
                            }
                          },
                        );
                      },
                    );
            },
          ),
        ), // Zatvaranje Scaffold
      ), // Zatvaranje Container
    ); // Zatvaranje AnnotatedRegion
  }

  // 🗺️ NAVIGATION HANDLING IS MANAGED BY SmartNavigationService

  Future<void> _startSmartNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      // Koristi HERE WeGo navigaciju
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
        cachedCoordinates: _cachedCoordinates,
      );

      if (result.success) {
        // 🛰️ POKRENI PICKUP TRACKING SA GPS PRAĆENJEM
        await _startPickupTracking();

        if (mounted) {
          setState(() {
            _optimizedRoute = result.optimizedPutnici ?? _optimizedRoute;
            _cachedCoordinates = result.cachedCoordinates; // 🎯 Ažuriraj keširane koordinate
            _isRouteOptimized = true;
            _isGpsTracking = true;
            _navigationStatus = result.message;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('🗺️ ${result.message}'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          setState(() {
            _isGpsTracking = false;
            _navigationStatus = result.message;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ ${result.message}'), backgroundColor: Colors.red));
        }
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

  // 🛰️ START PICKUP TRACKING (GPS + NOTIFIKACIJE)
  Future<void> _startPickupTracking() async {
    final coords = _cachedCoordinates;
    if (coords == null || coords.isEmpty) {
      return;
    }

    final pickupService = PickupTrackingService();
    await pickupService.initialize();

    final started = await pickupService.startTracking(
      putnici: _optimizedRoute,
      coordinates: coords,
      onPickedUp: (putnik, status) async {
        // 🔄 REALTIME: Ažuriraj status putnika u bazi
        if (putnik.id != null && _currentDriver != null) {
          try {
            await _putnikService.oznaciPokupljen(putnik.id!, _currentDriver!);
          } catch (_) {
            // Greška pri označavanju
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${putnik.ime} pokupljen'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onSkipped: (putnik) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏭️ ${putnik.ime} preskočen'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onApproaching: (putnik, distance) {
        // Opciono: prikaži distancu u UI
      },
      onCompleted: () {
        if (mounted) {
          setState(() {
            _isGpsTracking = false;
            _navigationStatus = 'Svi putnici pokupljeni!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Svi putnici pokupljeni!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
    );

    if (started) {
    } else {}
  }

  void _stopSmartNavigation() {
    // 🛰️ ZAUSTAVI PICKUP TRACKING
    PickupTrackingService().stopTracking();

    if (mounted) {
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
      // ✅ ISPRAVKA: SnackBar unutar mounted provere
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛑 Navigacija zaustavljena'), backgroundColor: Colors.orange),
      );
    }
  }
}
