import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎨 DODANO za SystemUiOverlayStyle
import 'package:geolocator/geolocator.dart'; // 🗺️ DODANO za OpenStreetMap
import 'package:supabase_flutter/supabase_flutter.dart'; // DODANO za direktne pozive

import '../config/route_config.dart';
import '../globals.dart';
import '../models/putnik.dart';
// url_launcher unused here - navigacija delegirana SmartNavigationService

import '../models/registrovani_putnik.dart';
import '../services/driver_location_service.dart'; // 🚐 DODANO za realtime ETA putnicima
import '../services/firebase_service.dart';
import '../services/kapacitet_service.dart'; // 🎫 Kapacitet za bottom nav bar
import '../services/local_notification_service.dart';
import '../services/putnik_push_service.dart'; // 📱 DODANO za push notifikacije putnicima
import '../services/putnik_service.dart'; // ⏪ VRAĆEN na stari servis zbog grešaka u novom
import '../services/realtime_gps_service.dart'; // 🛰️ DODANO za GPS tracking
import '../services/realtime_notification_service.dart';
import '../services/registrovani_putnik_service.dart'; // 🎓 DODANO za đačke statistike
import '../services/smart_navigation_service.dart';
import '../services/theme_manager.dart';
import '../services/timer_manager.dart'; // 🕐 DODANO za heartbeat management
import '../services/weather_service.dart'; // 🌤️ DODANO za vremensku prognozu
import '../theme.dart';
import '../utils/grad_adresa_validator.dart'; // 🏘️ NOVO za validaciju gradova
import '../utils/putnik_count_helper.dart'; // 🔢 Za brojanje putnika po gradu
import '../utils/schedule_utils.dart'; // Za isZimski funkciju
import '../utils/text_utils.dart'; // 🎯 DODANO za standardizovano filtriranje statusa
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje vozača
import '../widgets/bottom_nav_bar_letnji.dart'; // 🚀 DODANO za letnji nav bar
import '../widgets/bottom_nav_bar_praznici.dart';
import '../widgets/bottom_nav_bar_zimski.dart';
import '../widgets/clock_ticker.dart';
import '../widgets/putnik_list.dart';
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
  Set<String> _lastMatchingIds = {};

  // 🕐 DINAMIČKA VREMENA - prate navBarTypeNotifier (praznici/zimski/letnji)
  List<String> _getBcVremena() {
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

  List<String> _getVsVremena() {
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

  // 📅 MIDNIGHT RESET TRACKER
  DateTime _currentDate = DateTime.now();

  // 🔧 CACHED STREAMS - sprečava kreiranje novih stream-ova na svaki build
  Stream<Map<String, int>>? _cachedDjackiStream;

  // 🕒 THROTTLING ZA REALTIME SYNC - sprečava prekomerne UI rebuilde
  // ✅ Povećano na 800ms da spreči race conditions, ali i dalje dovoljno brzo za UX
  DateTime? _lastSyncTime;
  static const Duration _syncThrottleDuration = Duration(milliseconds: 800);

  // 🔄 PENDING SYNC - čuva poslednje promene ako je throttling aktivan
  List<Putnik>? _pendingSyncPutnici;

  // 🔒 LOCK ZA KONKURENTNE REOPTIMIZACIJE
  bool _isReoptimizing = false;

  // 🆕 SET ID-ova putnika koji su već uključeni u optimizovanu rutu
  // Sprečava beskonačnu petlju reoptimizacije za iste putnike
  Set<String> _optimizedPassengerIds = {};

  // 💓 HEARTBEAT MONITORING FUNCTIONS
  void _registerStreamHeartbeat(String streamName) {
    _streamHeartbeats[streamName] = DateTime.now();
  }

  // Auto-refetch is disabled; method kept for future re-enable

  void _checkStreamHealth() {
    final now = DateTime.now();

    // 🌙 MIDNIGHT RESET CHECK
    // Proveri da li se datum promenio od poslednje provere
    if (now.day != _currentDate.day || now.month != _currentDate.month || now.year != _currentDate.year) {
      print('🌙 MIDNIGHT DETECTED: Clearing caches and refreshing...');
      _currentDate = now;

      // Clear all caches
      PutnikService.clearCache();
      RegistrovaniPutnikService.clearRealtimeCache();
      _cachedDjackiStream = null;

      if (mounted) {
        setState(() {
          // Force rebuild
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📅 Novi dan je počeo! Lista putnika je osvežena.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; // Skip standard health check for this tick
    }

    bool isHealthy = true;

    for (final entry in _streamHeartbeats.entries) {
      final timeSinceLastHeartbeat = now.difference(entry.value);
      if (timeSinceLastHeartbeat.inSeconds > 30) {
        isHealthy = false;
        break;
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

  // 🎓 FUNKCIJA ZA RAČUNANJE ĐAČKIH STATISTIKA
  // 🔥 REALTIME STREAM ZA ĐAČKI BROJAČ - direktan Supabase stream
  // 🔧 CACHED: Stream se kreira jednom i reuse-uje, ne na svaki build
  Stream<Map<String, int>> _streamDjackieBrojevi() {
    // Ako već postoji keširan stream, koristi ga
    if (_cachedDjackiStream != null) {
      return _cachedDjackiStream!;
    }

    final registrovaniStream = RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici();

    final resultStream = registrovaniStream.asyncMap((sviRegistrovaniPutnici) async {
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
        // UKUPNO = svi koji su krenuli u školu (BC polazak)
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

        // Uključi današnje "zakupljeno" iz registrovani_putnici
        int zakupljenoCount = 0;
        try {
          final zakupljenoRows = await RegistrovaniPutnikService.getZakupljenoDanas();
          for (final z in zakupljenoRows) {
            try {
              final putnikZ = Putnik.fromRegistrovaniPutnici(z);
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

    // 🔧 KESIRAJ stream za reuse
    _cachedDjackiStream = resultStream;
    return resultStream;
  }

  // ✨ DIGITALNI BROJAČ DATUM WIDGET - BEZ STREAMBUILDER-a
  Widget _buildDigitalDateDisplay() {
    final now = DateTime.now();
    final dayNames = ['PONEDELJAK', 'UTORAK', 'SREDA', 'ČETVRTAK', 'PETAK', 'SUBOTA', 'NEDELJA'];
    final dayName = dayNames[now.weekday - 1];
    final dayStr = now.day.toString().padLeft(2, '0');
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString().substring(2);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. RED: DATUM - DAN - VREME
        SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEVO - DATUM
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$dayStr.$monthStr.$yearStr',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 1.5,
                      shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
              // SREDINA - DAN (menja boju na osnovu stream health-a)
              Expanded(
                flex: 2,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isRealtimeHealthy,
                  builder: (context, isHealthy, child) {
                    return GestureDetector(
                      onTap: () => _showHealthDialog(),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isHealthy ? Colors.green.shade300 : Colors.red.shade300,
                            letterSpacing: 1.5,
                            shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // DESNO - VREME
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: ClockTicker(
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimary,
                      letterSpacing: 1.5,
                      shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
                    ),
                    showSeconds: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // 2. RED: TEMP BC - RUTA - TEMP VS
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(child: Center(child: _buildWeatherCompact('BC'))),
              const SizedBox(width: 4),
              Expanded(child: _buildOptimizeButton()),
              const SizedBox(width: 4),
              Expanded(child: Center(child: _buildWeatherCompact('VS'))),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // 3. RED: ĐAČKI BROJAČ - NAV - SPEEDOMETER
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(child: _buildDjackiBrojacButton()),
              const SizedBox(width: 4),
              Expanded(child: _buildMapsButton()),
              const SizedBox(width: 4),
              Expanded(child: _buildSpeedometerButton()),
            ],
          ),
        ),
      ],
    );
  }

  // 🌤️ KOMPAKTAN PRIKAZ TEMPERATURE ZA DATUM RED SA IKONOM
  Widget _buildWeatherCompact(String grad) {
    // Koristi StreamBuilder za real-time update temperature
    final stream = grad == 'BC' ? WeatherService.bcWeatherStream : WeatherService.vsWeatherStream;

    return StreamBuilder<WeatherData?>(
      stream: stream,
      builder: (context, snapshot) {
        // Stream sada automatski emituje cached vrednost, nema potrebe za dodatnim pozivom
        final data = snapshot.data;
        final temp = data?.temperature;
        final icon = data?.icon ?? '🌡️';
        final tempStr = temp != null ? '${temp.round()}°' : '--';
        final tempColor = temp != null
            ? (temp < 0
                ? Colors.lightBlue
                : temp < 15
                    ? Colors.cyan
                    : temp < 25
                        ? Colors.green
                        : Colors.orange)
            : Colors.grey;

        // Widget za ikonu - slika ili emoji (usklađene veličine)
        Widget iconWidget;
        if (WeatherData.isAssetIcon(icon)) {
          iconWidget = Image.asset(
            WeatherData.getAssetPath(icon),
            width: 32,
            height: 32,
          );
        } else {
          iconWidget = Text(icon, style: const TextStyle(fontSize: 14));
        }

        return GestureDetector(
          onTap: () => _showWeatherDialog(grad, data),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 2),
              Text(
                '$grad $tempStr',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tempColor,
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🌤️ DIJALOG ZA DETALJNU VREMENSKU PROGNOZU
  void _showWeatherDialog(String grad, WeatherData? data) {
    final gradPun = grad == 'BC' ? 'Bela Crkva' : 'Vršac';

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
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
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).glassContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🌤️ Vreme - $gradPun',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: data != null
                    ? Column(
                        children: [
                          // Upozorenje za kišu/sneg
                          if (data.willSnow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('❄️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SNEG ${data.precipitationStartTime ?? 'SADA'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (data.willRain)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🌧️', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'KIŠA ${data.precipitationStartTime ?? 'SADA'}${data.precipitationProbability != null ? ' (${data.precipitationProbability}%)' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Velika ikona i temperatura
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (WeatherData.isAssetIcon(data.icon))
                                Image.asset(
                                  WeatherData.getAssetPath(data.icon),
                                  width: 80,
                                  height: 80,
                                )
                              else
                                Text(data.icon, style: const TextStyle(fontSize: 60)),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data.temperature.round()}°C',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: data.temperature < 0
                                          ? Colors.lightBlue
                                          : data.temperature < 15
                                              ? Colors.cyan
                                              : data.temperature < 25
                                                  ? Colors.white
                                                  : Colors.orange,
                                      shadows: const [
                                        Shadow(offset: Offset(2, 2), blurRadius: 4, color: Colors.black54),
                                      ],
                                    ),
                                  ),
                                  if (data.tempMin != null && data.tempMax != null)
                                    Text(
                                      '${data.tempMin!.round()}° / ${data.tempMax!.round()}°',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Opis baziran na weather code
                          Text(
                            _getWeatherDescription(data.dailyWeatherCode ?? data.weatherCode),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Podaci nisu dostupni',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return 'Vedro nebo';
    if (code == 1) return 'Pretežno vedro';
    if (code == 2) return 'Delimično oblačno';
    if (code == 3) return 'Oblačno';
    if (code >= 45 && code <= 48) return 'Magla';
    if (code >= 51 && code <= 55) return 'Sitna kiša';
    if (code >= 56 && code <= 57) return 'Ledena kiša';
    if (code >= 61 && code <= 65) return 'Kiša';
    if (code >= 66 && code <= 67) return 'Ledena kiša';
    if (code >= 71 && code <= 77) return 'Sneg';
    if (code >= 80 && code <= 82) return 'Pljuskovi';
    if (code >= 85 && code <= 86) return 'Snežni pljuskovi';
    if (code >= 95 && code <= 99) return 'Grmljavina';
    return '';
  }

  // 💓 REALTIME HEARTBEAT INDICATOR
  // Prikazuje dijalog sa statusom stream health-a (poziva se klikom na dan u AppBar-u)
  void _showHealthDialog() {
    final isHealthy = _isRealtimeHealthy.value;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Realtime Health Status'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${isHealthy ? 'ZDRAVO ✅' : 'PROBLEM ❌'}'),
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
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zatvori'))],
      ),
    );
  }

  // 🎓 FINALNO DUGME - OSTALO/UKUPNO FORMAT
  Widget _buildDjackiBrojacButton() {
    return StreamBuilder<Map<String, int>>(
      stream: _streamDjackieBrojevi(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Heartbeat indikator će pokazati grešku - ne prikazujemo dodatne error widget-e
          return SizedBox(
            height: 24,
            child: Center(
              child: Text(
                'ERR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ),
          );
        }

        final statistike = snapshot.data ?? {'ukupno_ujutro': 0, 'reseni': 0, 'otkazali': 0, 'ostalo': 0};
        final ostalo = statistike['ostalo'] ?? 0; // 10 - ostalo da se vrati
        final ukupnoUjutro = statistike['ukupno_ujutro'] ?? 0; // 30 - ukupno ujutro

        // Boja teksta - narandžasta ako ima ostalo, inače bela
        final textColor = ostalo > 0 ? Colors.orange : Theme.of(context).colorScheme.onPrimary;

        return SizedBox(
          height: 24,
          child: GestureDetector(
            onTap: () => _showDjackiDialog(statistike),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$ostalo/$ukupnoUjutro',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                  ),
                ),
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

    // Boja teksta zavisi od stanja
    final textColor = _isRouteOptimized
        ? Colors.green.shade300
        : (hasPassengers && isDriverValid ? Theme.of(context).colorScheme.onPrimary : Colors.grey.shade400);

    return SizedBox(
      height: 24,
      child: GestureDetector(
        onTap: _isRouteOptimized
            ? () {
                _resetOptimization();
              }
            : () {
                _optimizeCurrentRoute(_currentPutnici, isAlreadyOptimized: false);
              },
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route,
                  size: 16,
                  color: textColor,
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                ),
                const SizedBox(width: 2),
                Text(
                  'START',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: textColor,
                    shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
                  ),
                ),
              ],
            ),
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

        // Boja pozadine zavisi od brzine (providno kad je 0)
        final bgColor = speed >= 90
            ? Colors.red
            : speed >= 60
                ? Colors.orange
                : speed > 0
                    ? Colors.green
                    : Colors.transparent;

        // Tekst beo kad ima pozadinu, inače beo sa senkom
        final textColor = speed > 0 ? Colors.white : Theme.of(context).colorScheme.onPrimary;

        return SizedBox(
          height: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor != Colors.transparent ? bgColor : null,
              borderRadius: BorderRadius.circular(16),
              border: speed == 0 ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                speed.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontFamily: 'monospace',
                  shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black54)],
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
      height: 24,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: hasOptimizedRoute
                ? BorderSide.none
                : BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isGpsTracking ? Icons.stop : Icons.navigation,
                size: 12,
                color: hasOptimizedRoute ? Theme.of(context).colorScheme.onPrimary : Colors.white,
              ),
              const SizedBox(width: 2),
              Text(
                _isGpsTracking ? 'STOP' : 'NAV',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: hasOptimizedRoute ? null : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🗺️ DIJALOG SA OPCIJAMA NAVIGACIJE
  void _showNavigationOptionsDialog() {
    // 🎯 Koristi isti filter kao kod prikaza "Lista Reorderovana" - samo aktivni nepokupljeni putnici
    final putnikCount = _optimizedRoute.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length;
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
                'Đaci ($ostalo/$ukupnoUjutro)',
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
                    'Učenici koji su otkazali',
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
        _optimizedPassengerIds.clear(); // 🆕 Resetuj set obrađenih putnika
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

    // 🔄 BATCH DOHVATI SVEŽE PODATKE IZ BAZE - efikasnije od pojedinačnih poziva
    final putnikService = PutnikService();
    final ids = _optimizedRoute.where((p) => p.id != null).map((p) => p.id!).toList();
    final sveziPutnici = await putnikService.getPutniciByIds(ids);

    // Razdvoji pokupljene/otkazane od preostalih
    final pokupljeniIOtkazani = sveziPutnici.where((p) {
      return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo;
    }).toList();

    final preostaliPutnici = sveziPutnici.where((p) {
      return !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo;
    }).toList();

    if (preostaliPutnici.isEmpty) {
      // Svi putnici su pokupljeni ili otkazani - zadrži ih u listi
      if (mounted) {
        setState(() {
          _optimizedRoute = pokupljeniIOtkazani; // ✅ ZADRŽI pokupljene u listi
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
            // ✅ KOMBINUJ: optimizovani preostali + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
            _currentPassengerIndex = 0;
          });

          final sledeci = result.optimizedPutnici!.isNotEmpty ? result.optimizedPutnici!.first.ime : 'N/A';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔄 Ruta ažurirana! Sledeći: $sledeci (${preostaliPutnici.length} preostalo)'),
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

  // 🔄 SINHRONIZACIJA OPTIMIZOVANE RUTE SA REALTIME STREAM-om
  // Ažurira statuse putnika u optimizovanoj listi kada se promene u bazi
  // ✅ SA THROTTLING-om: Sprečava prekomerne UI rebuilde (max ~1.25x/sec)
  // ✅ AUTO-REOPTIMIZACIJA: Kada se doda ili otkaže putnik, automatski reoptimizuje rutu
  // ✅ PENDING SYNC: Ne gubi važne promene tokom throttling-a
  void _syncOptimizedRouteWithStream(List<Putnik> streamPutnici) {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    // 🕒 THROTTLING: Ignoriši ako je prošlo manje od 800ms od poslednje sinhronizacije
    // ✅ ALI: Sačuvaj pending podatke za sledeći sync
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncThrottleDuration) {
      _pendingSyncPutnici = streamPutnici; // Sačuvaj za kasnije
      // Zakaži odloženi sync ako nije već zakazan
      Future.delayed(_syncThrottleDuration, () {
        if (_pendingSyncPutnici != null && mounted) {
          final pending = _pendingSyncPutnici!;
          _pendingSyncPutnici = null;
          _syncOptimizedRouteWithStream(pending);
        }
      });
      return;
    }
    _lastSyncTime = now;
    _pendingSyncPutnici = null; // Očisti pending jer procesiramo sada

    // Kreiraj Set ID-ova iz stream-a za brzu pretragu
    final streamIds = streamPutnici.map((p) => p.id).toSet();
    final optimizedIds = _optimizedRoute.map((p) => p.id).toSet();

    bool hasChanges = false;
    bool hasNewPassengers = false;
    bool hasCancelledOrDeleted = false;
    final newPassengerNames = <String>[];
    final cancelledNames = <String>[];
    final updatedRoute = <Putnik>[];

    // 1️⃣ Ažuriraj postojeće putnike i detektuj obrisane/otkazane
    for (final optimizedPutnik in _optimizedRoute) {
      // Proveri da li putnik još postoji u stream-u
      if (!streamIds.contains(optimizedPutnik.id)) {
        // 🗑️ Putnik obrisan iz baze
        hasChanges = true;
        hasCancelledOrDeleted = true;
        cancelledNames.add(optimizedPutnik.ime);
        continue;
      }

      // Pronađi putnika u stream-u po ID-u
      final streamPutnik = streamPutnici.firstWhere(
        (p) => p.id == optimizedPutnik.id,
      );

      // Proveri da li je putnik UPRAVO otkazan (bio aktivan, sada nije)
      final wasActive = !optimizedPutnik.jeOtkazan && !optimizedPutnik.jeOdsustvo;
      final isNowCancelled = streamPutnik.jeOtkazan || streamPutnik.jeOdsustvo;
      if (wasActive && isNowCancelled) {
        hasCancelledOrDeleted = true;
        cancelledNames.add(streamPutnik.ime);
      }

      // Proveri da li se status promenio
      if (streamPutnik.jePokupljen != optimizedPutnik.jePokupljen ||
          streamPutnik.jeOtkazan != optimizedPutnik.jeOtkazan ||
          streamPutnik.jeOdsustvo != optimizedPutnik.jeOdsustvo ||
          streamPutnik.status != optimizedPutnik.status) {
        hasChanges = true;
        updatedRoute.add(streamPutnik);
      } else {
        updatedRoute.add(optimizedPutnik);
      }
    }

    // 2️⃣ Detektuj nove putnike koji nisu u optimizovanoj ruti
    // 🔧 FIX: Filtriraj nove putnike SAMO za trenutni grad i vreme
    // 🔧 FIX 2: Koristi _optimizedPassengerIds da spreči beskonačnu petlju
    final newPassengers = <Putnik>[];
    final normFilterTime = GradAdresaValidator.normalizeTime(_selectedVreme);
    for (final streamPutnik in streamPutnici) {
      final putnikId = streamPutnik.id;
      // ✅ Preskoči ako je već obrađen u ovoj optimizaciji
      if (putnikId != null && _optimizedPassengerIds.contains(putnikId)) {
        continue;
      }
      if (!optimizedIds.contains(putnikId)) {
        // ✅ Proveri da li putnik pripada trenutnom gradu i vremenu
        final normStreamTime = GradAdresaValidator.normalizeTime(streamPutnik.polazak);
        final vremeMatch = normStreamTime == normFilterTime;

        final gradMatch = _isGradMatch(
          streamPutnik.grad,
          streamPutnik.adresa,
          _selectedGrad,
          isRegistrovaniPutnik: streamPutnik.mesecnaKarta == true,
        );

        // ✅ Samo aktivni putnici (ne otkazani/obrisani)
        final isActive = !streamPutnik.jeOtkazan && !streamPutnik.jeOdsustvo && !streamPutnik.obrisan;

        if (vremeMatch && gradMatch && isActive) {
          // 🆕 UVEK dodaj u set obrađenih čim detektujemo - sprečava beskonačnu petlju
          // Ovo je bitno za putnike BEZ ADRESE koji se preskačaju u optimizaciji
          if (putnikId != null) {
            _optimizedPassengerIds.add(putnikId);
          }

          hasNewPassengers = true;
          newPassengers.add(streamPutnik);
          newPassengerNames.add(streamPutnik.ime);
        }
      }
    }

    // 🆕 AUTO-REOPTIMIZACIJA: Ako ima novih ILI otkazanih putnika
    if ((hasNewPassengers || hasCancelledOrDeleted) && mounted) {
      // Prikaži notifikaciju
      String message;
      Color bgColor;
      if (hasNewPassengers && hasCancelledOrDeleted) {
        message = '🔄 Promene: +${newPassengerNames.join(", ")} / -${cancelledNames.join(", ")} - Reoptimizujem...';
        bgColor = Colors.purple;
      } else if (hasNewPassengers) {
        message = '🆕 Novi putnik: ${newPassengerNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.blue;
      } else {
        message = '❌ Otkazano: ${cancelledNames.join(", ")} - Reoptimizujem rutu...';
        bgColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Kombinuj postojeće + nove putnike i pokreni reoptimizaciju
      final allPassengers = [...updatedRoute, ...newPassengers];
      _autoReoptimizeRoute(allPassengers);
      return; // Ne ažuriraj state ovde, _autoReoptimizeRoute će to uraditi
    }

    // Samo ažuriraj ako ima promena (bez novih/otkazanih putnika)
    if (hasChanges && mounted) {
      setState(() {
        _optimizedRoute = updatedRoute;
      });
    }
  }

  // 🔄 AUTO-REOPTIMIZACIJA RUTE SA NOVIM PUTNICIMA
  // Poziva OSRM da dobije novu optimalnu rutu
  // ✅ SA LOCK MEHANIZMOM: Sprečava konkurentne reoptimizacije
  // ✅ ČUVA pokupljene/otkazane putnike na kraju liste
  Future<void> _autoReoptimizeRoute(List<Putnik> allPassengers) async {
    // 🔒 LOCK: Ako je već u toku reoptimizacija, preskoči
    if (_isReoptimizing) {
      return;
    }
    _isReoptimizing = true;

    try {
      // 🔄 Razdvoji pokupljene/otkazane/tuđe od aktivnih putnika
      final pokupljeniIOtkazani = allPassengers.where((p) {
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        return p.jePokupljen || p.jeOtkazan || p.jeOdsustvo || jeTudji;
      }).toList();

      // Filtriraj samo AKTIVNE putnike sa validnim adresama za optimizaciju
      final filtriraniPutnici = allPassengers.where((p) {
        final hasValidAddress = (p.adresaId != null && p.adresaId!.isNotEmpty) ||
            (p.adresa != null && p.adresa!.isNotEmpty && p.adresa != p.grad);
        // 🔘 Isključi pokupljene, otkazane i tuđe putnike
        final jeTudji = p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver;
        final isActive = !p.jePokupljen && !p.jeOtkazan && !p.jeOdsustvo && !jeTudji;
        return hasValidAddress && isActive;
      }).toList();

      // ✅ Ako nema aktivnih putnika, zadrži samo pokupljene/otkazane
      if (filtriraniPutnici.isEmpty) {
        if (pokupljeniIOtkazani.isNotEmpty && mounted) {
          setState(() {
            _optimizedRoute = pokupljeniIOtkazani;
          });
        }
        return;
      }

      final result = await SmartNavigationService.optimizeRouteOnly(
        putnici: filtriraniPutnici,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
      );

      if (result.success && result.optimizedPutnici != null && result.optimizedPutnici!.isNotEmpty) {
        if (mounted) {
          setState(() {
            // ✅ KOMBINUJ: optimizovani aktivni + pokupljeni/otkazani na kraju
            _optimizedRoute = [...result.optimizedPutnici!, ...pokupljeniIOtkazani];
            _cachedCoordinates = result.cachedCoordinates;
          });

          // Ažuriraj ETA u DriverLocationService ako je tracking aktivan
          if (DriverLocationService.instance.isTracking && result.putniciEta != null) {
            // 🔄 REALTIME FIX: Koristi novu updatePutniciEta metodu
            await DriverLocationService.instance.updatePutniciEta(result.putniciEta!);
          }

          // ✅ FIX: Ponovna provera mounted posle await operacije
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Ruta uspešno reoptimizovana sa novim putnikom!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Greška pri reoptimizaciji - zadrži postojeću rutu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Greška pri reoptimizaciji: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // 🔓 UNLOCK: Uvek oslobodi lock
      _isReoptimizing = false;
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

    // 🌤️ Pokreni periodično osvežavanje vremenske prognoze
    WeatherService.startPeriodicRefresh();

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
    // Nakon inicijalizacije vozača, proveri whitelist i poveži realtime stream za daily_reports
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

    // Otkaži pretplatu za daily_reports ako postoji
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
                Text(
                    '🎯 Broj putnika: ${_optimizedRoute.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
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
    // ❌ Isključi otkazane, pokupljene, odsutne i tuđe putnike - samo bele kartice idu u optimizaciju
    final filtriraniPutnici = putnici.where((p) {
      // Isključi otkazane putnike
      if (p.jeOtkazan) return false;
      // Isključi već pokupljene putnike
      if (p.jePokupljen) return false;
      // 🆕 Isključi odsutne putnike (bolovanje/godišnji) - žute kartice ne idu u rutu
      if (p.jeOdsustvo) return false;
      // 🔘 Isključi tuđe putnike (dodeljeni drugom vozaču) - sive kartice ne idu u rutu
      if (p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver) {
        return false;
      }
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

        // 🆕 Dodaj putnike BEZ ADRESE na početak liste kao podsetnik
        final skippedPutnici = result.skippedPutnici ?? [];
        final finalRoute = [...skippedPutnici, ...optimizedPutnici];

        if (mounted) {
          setState(() {
            _optimizedRoute = finalRoute; // Preskočeni + optimizovani
            _cachedCoordinates = result.cachedCoordinates; // 🎯 Sačuvaj koordinate za NAV
            _isRouteOptimized = true;
            _isListReordered = true; // ✅ Lista je reorderovana
            _currentPassengerIndex = 0; // ✅ Počni od prvog putnika
            // NE postavljaj _isGpsTracking - aktivira se tek kad korisnik pritisne NAV
            _isLoading = false; // ✅ ZAUSTAVI LOADING
            // 🆕 Inicijalizuj set obrađenih putnika sa svim iz optimizacije
            _optimizedPassengerIds = optimizedPutnici.where((p) => p.id != null).map((p) => p.id! as String).toSet();
          });
        }

        // 🚐 ODMAH POKRENI GPS TRACKING I POŠALJI NOTIFIKACIJE
        // ✅ Čim vozač pritisne "Ruta", putnici dobijaju notifikaciju i vide realtime ETA
        if (_currentDriver != null && result.putniciEta != null) {
          final smer = _selectedGrad.toLowerCase().contains('bela') || _selectedGrad == 'BC' ? 'BC_VS' : 'VS_BC';

          // 🆕 Konvertuj koordinate: Map<Putnik, Position> -> Map<String, Position>
          Map<String, Position>? coordsByName;
          if (_cachedCoordinates != null) {
            coordsByName = {};
            for (final entry in _cachedCoordinates!.entries) {
              coordsByName[entry.key.ime] = entry.value;
            }
          }

          // 🆕 Izvuci redosled imena putnika
          final putniciRedosled = _optimizedRoute.map((p) => p.ime).toList();

          // ✅ STARTUJ GPS TRACKING ODMAH - čim se ruta optimizuje
          await DriverLocationService.instance.startTracking(
            vozacId: _currentDriver!,
            vozacIme: _currentDriver!,
            grad: _selectedGrad,
            vremePolaska: _selectedVreme,
            smer: smer,
            putniciEta: result.putniciEta,
            putniciCoordinates: coordsByName, // 🆕 Za realtime ETA
            putniciRedosled: putniciRedosled, // 🆕 Optimizovan redosled
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

          // 📱 POŠALJI PUSH NOTIFIKACIJE PUTNICIMA ODMAH
          // ✅ Putnici dobijaju "🚐 Kombi je krenuo!" čim se ruta optimizuje
          await _sendTransportStartedNotifications(
            putniciEta: result.putniciEta!,
            vozacIme: _currentDriver!,
          );

          // ✅ Postavi GPS tracking flag
          if (mounted) {
            setState(() {
              _isGpsTracking = true;
            });
          }
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
                  Text(
                      '🎯 Broj putnika: ${optimizedPutnici.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length}'),
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
                      Flexible(
                        child: Text(
                          '${skipped.length} PUTNIKA BEZ LOKACIJE',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
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
        // ❌ OSRM/SmartNavigationService nije uspeo - NE koristi fallback, prikaži grešku
        if (mounted) {
          setState(() {
            _isLoading = false;
            // NE postavljaj _isRouteOptimized = true jer ruta NIJE optimizovana!
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Optimizacija neuspešna: ${result.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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
      }
    } catch (e) {
      // Error sending notifications
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
            preferredSize: const Size.fromHeight(95),
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
                      // APP BAR SADRŽAJ - 3 REDA
                      _buildDigitalDateDisplay(),
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
                    // ✅ FIX: Ne prosleđujemo grad/vreme u stream - filtriramo client-side
                    // Ovo omogućava prikaz putnika na bolovanju koji imaju drugačiji grad (npr. selo)
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

                      // If the set changed compared to last matching ids, refresh UI
                      if (!_setEquals(_lastMatchingIds, matchingIds)) {
                        _lastMatchingIds = matchingIds;
                        // Stream automatski ažurira podatke - samo osvežimo UI
                        // ✅ FIX: Defer setState to after build phase to avoid "setState called during build"
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() {});
                        });
                      }
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

                    // 🔄 REALTIME SYNC: Ažuriraj statuse u optimizovanoj ruti
                    if (_isRouteOptimized && sviPutnici.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _syncOptimizedRouteWithStream(sviPutnici);
                      });
                    }

                    final danasnjiDan = _getTodayForDatabase();
                    final todayIso = DateTime.now().toIso8601String().split('T')[0];

                    // Real-time filtriranje
                    final danasPutnici = sviPutnici.where((p) {
                      // Dan u nedelji filter - ISTA LOGIKA KAO HOME_SCREEN
                      // Koristimo dan ili datum za filtriranje
                      final dayMatch = p.datum != null
                          ? p.datum == todayIso
                          : p.dan.toLowerCase().contains(danasnjiDan.toLowerCase());

                      return dayMatch;
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

                      // 🔄 UJEDNAČENA LOGIKA SA HOME_SCREEN: Prikaži sve putnike osim obrisanih
                      // Otkazani SE PRIKAZUJU (crvenom bojom) - vozač treba da vidi ko je otkazao
                      final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');
                      final statusOk = normalizedStatus != 'obrisan';
                      return vremeMatch && gradMatch && statusOk;
                    }).toList();

                    // 🎯 Ažuriraj _currentPutnici za Ruta dugme - SAMO BELE KARTICE (nepokupljeni, neotkazani, bez odsustva)
                    final belePutnici = filtriraniPutnici.where((p) {
                      if (p.jePokupljen) return false;
                      if (p.jeOtkazan) return false;
                      if (p.jeOdsustvo) return false;
                      // Isključi tuđe putnike
                      if (p.dodeljenVozac != null && p.dodeljenVozac!.isNotEmpty && p.dodeljenVozac != _currentDriver) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (_currentPutnici.length != belePutnici.length ||
                        !_currentPutnici.every((p) => belePutnici.any((fp) => fp.id == p.id))) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _currentPutnici = belePutnici;
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

                            // 🔄 UJEDNAČENA LOGIKA SA HOME_SCREEN: Prikaži sve putnike osim obrisanih
                            // Otkazani SE PRIKAZUJU (crvenom bojom) - vozač treba da vidi ko je otkazao
                            final normalizedStatus = TextUtils.normalizeText(putnik.status ?? '');
                            final statusOk = normalizedStatus != 'obrisan';

                            return vremeMatch && gradMatch && statusOk;
                          }).toList()
                        : filtriraniPutnici;
                    // 💳 DUŽNICI - putnici sa PLAVOM KARTICOM (nisu mesečni tip) koji nisu platili
                    final filteredDuzniciRaw = danasPutnici.where((putnik) {
                      final nijeMesecni = !putnik.isMesecniTip;
                      if (!nijeMesecni) return false; // ✅ FIX: Plava kartica = nije mesečni tip

                      final nijePlatio = putnik.vremePlacanja == null; // ✅ FIX: Nije platio ako nema vremePlacanja
                      final nijeOtkazan = putnik.status != 'otkazan' && putnik.status != 'Otkazano';
                      final pokupljen = putnik.jePokupljen;

                      // ✅ NOVA LOGIKA: Vozači vide SVE dužnike (mogu naplatiti bilo koji dug)
                      // Uklonjeno filtriranje po vozaču - jeOvajVozac filter

                      return nijePlatio && nijeOtkazan && pokupljen;
                    }).toList();

                    // ✅ DEDUPLIKACIJA: Jedan putnik može imati više termina, ali je jedan dužnik
                    final seenIds = <dynamic>{};
                    final filteredDuznici = filteredDuzniciRaw.where((p) {
                      final key = p.id ?? '${p.ime}_${p.dan}';
                      if (seenIds.contains(key)) return false;
                      seenIds.add(key);
                      return true;
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

                    return Column(
                      children: [
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
                                                        ? '🎯 Lista Reorderovana (${_currentPassengerIndex + 1}/${finalPutnici.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length})'
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
                                                  Text(
                                                    'Optimizovana ruta: ${finalPutnici.where((p) => TextUtils.isStatusActive(p.status) && !p.jePokupljen).length} putnika',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: _isGpsTracking ? Colors.blue : Colors.green,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
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
                                        currentDriver: _currentDriver!,
                                        selectedGrad: _selectedGrad, // 📍 NOVO: za GPS navigaciju mesečnih putnika
                                        selectedVreme: _selectedVreme, // 📍 NOVO: za GPS navigaciju
                                        onPutnikStatusChanged: _reoptimizeAfterStatusChange, // 🎯 NOVO
                                        bcVremena: _getBcVremena(),
                                        vsVremena: _getVsVremena(),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
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

              // 🔧 REFAKTORISANO: Koristi PutnikCountHelper za centralizovano brojanje
              final targetDateIso = DateTime.now().toIso8601String().split('T')[0];
              final targetDayAbbr = _isoDateToDayAbbr(targetDateIso);
              final countHelper = PutnikCountHelper.fromPutnici(
                putnici: allPutnici,
                targetDateIso: targetDateIso,
                targetDayAbbr: targetDayAbbr,
              );

              // Helper funkcija za brojanje putnika
              int getPutnikCount(String grad, String vreme) {
                return countHelper.getCount(grad, vreme);
              }

              // Return Widget - Helper funkcija za kreiranje nav bar-a
              Widget buildNavBar(String navType) {
                // Get full day name for VremeVozacService
                final dayNames = ['Ponedeljak', 'Utorak', 'Sreda', 'Četvrtak', 'Petak', 'Subota', 'Nedelja'];
                final selectedDan = dayNames[DateTime.now().weekday - 1];

                void onChanged(String grad, String vreme) {
                  DriverLocationService.instance.stopTracking();
                  if (mounted) {
                    setState(() {
                      _selectedGrad = grad;
                      _selectedVreme = vreme;
                      if (_isRouteOptimized) {
                        _isRouteOptimized = false;
                        _isListReordered = false;
                        _optimizedRoute.clear();
                        _currentPassengerIndex = 0;
                      }
                    });
                  }
                  TimerManager.debounce('danas_screen_reset_debounce', const Duration(milliseconds: 150), () async {
                    final key = '$grad|$vreme';
                    if (mounted) setState(() => _resettingSlots.add(key));
                    try {
                      await _putnikService.resetPokupljenjaNaPolazak(vreme, grad, _currentDriver!);
                    } finally {
                      if (mounted) setState(() => _resettingSlots.remove(key));
                    }
                  });
                }

                switch (navType) {
                  case 'praznici':
                    return BottomNavBarPraznici(
                      sviPolasci: _sviPolasci,
                      selectedGrad: _selectedGrad,
                      selectedVreme: _selectedVreme,
                      getPutnikCount: getPutnikCount,
                      getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                      isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                      onPolazakChanged: onChanged,
                      selectedDan: selectedDan,
                    );
                  case 'zimski':
                    return BottomNavBarZimski(
                      sviPolasci: _sviPolasci,
                      selectedGrad: _selectedGrad,
                      selectedVreme: _selectedVreme,
                      getPutnikCount: getPutnikCount,
                      getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                      isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                      onPolazakChanged: onChanged,
                      selectedDan: selectedDan,
                    );
                  case 'letnji':
                    return BottomNavBarLetnji(
                      sviPolasci: _sviPolasci,
                      selectedGrad: _selectedGrad,
                      selectedVreme: _selectedVreme,
                      getPutnikCount: getPutnikCount,
                      getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                      isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                      onPolazakChanged: onChanged,
                      selectedDan: selectedDan,
                    );
                  default: // 'auto'
                    return isZimski(DateTime.now())
                        ? BottomNavBarZimski(
                            sviPolasci: _sviPolasci,
                            selectedGrad: _selectedGrad,
                            selectedVreme: _selectedVreme,
                            getPutnikCount: getPutnikCount,
                            getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                            isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                            onPolazakChanged: onChanged,
                            selectedDan: selectedDan,
                          )
                        : BottomNavBarLetnji(
                            sviPolasci: _sviPolasci,
                            selectedGrad: _selectedGrad,
                            selectedVreme: _selectedVreme,
                            getPutnikCount: getPutnikCount,
                            getKapacitet: (grad, vreme) => KapacitetService.getKapacitetSync(grad, vreme),
                            isSlotLoading: (grad, vreme) => _resettingSlots.contains('$grad|$vreme'),
                            onPolazakChanged: onChanged,
                            selectedDan: selectedDan,
                          );
                }
              }

              return ValueListenableBuilder<String>(
                valueListenable: navBarTypeNotifier,
                builder: (context, navType, _) => buildNavBar(navType),
              );
            },
          ),
        ), // Zatvaranje Scaffold
      ), // Zatvaranje Container
    ); // Zatvaranje AnnotatedRegion
  }

  // 🗺️ SAMO OTVORI NAVIGACIJU - GPS tracking je već pokrenut nakon "Ruta" dugmeta

  Future<void> _startSmartNavigation() async {
    if (!_isRouteOptimized || _optimizedRoute.isEmpty) return;

    try {
      // Koristi HERE WeGo navigaciju (GPS tracking je već aktivan)
      final result = await SmartNavigationService.startMultiProviderNavigation(
        context: context,
        putnici: _optimizedRoute,
        startCity: _selectedGrad.isNotEmpty ? _selectedGrad : 'Vršac',
        cachedCoordinates: _cachedCoordinates,
      );

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('🗺️ ${result.message}'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ ${result.message}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Greška pri pokretanju navigacije: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _stopSmartNavigation() {
    // ✅ Zaustavi GPS tracking i notifikacije
    DriverLocationService.instance.stopTracking();

    if (mounted) {
      setState(() {
        _isGpsTracking = false;
        _navigationStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛑 GPS tracking zaustavljen'), backgroundColor: Colors.orange),
      );
    }
  }
}
