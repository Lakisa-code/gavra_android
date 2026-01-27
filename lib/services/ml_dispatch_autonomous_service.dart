import 'dart:async';
import 'dart:convert'; // Added for safe JSON parsing

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../utils/grad_adresa_validator.dart';
import 'kapacitet_service.dart';

///  BEBA DISPEČER (ML Dispatch Autonomous Service)
///
/// 100% AUTONOMNA: Ne veruje u fiksne sektore ili "human" kategorije.
/// Uči isključivo iz protoka podataka i istorijskih afiniteta putnika.

class MLDispatchAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  //  REALTIME
  RealtimeChannel? _bookingStream;

  // Interna memorija bebe (100% Unsupervised)
  final Map<String, double> _recurrentFactors = {};
  final Map<String, String> _passengerAffinity = {}; // putnik_id -> vozac_ime (Naučeno)
  double _avgHourlyBookings = 0.5;

  bool _isActive = false;
  bool _isAutopilotEnabled = false; //  100% Autonomija
  Timer? _velocityTimer;

  // Rezultati analize za UI
  final List<DispatchAdvice> _currentAdvice = <DispatchAdvice>[];

  // Singleton
  static final MLDispatchAutonomousService _instance = MLDispatchAutonomousService._internal();
  factory MLDispatchAutonomousService() => _instance;
  MLDispatchAutonomousService._internal();

  List<DispatchAdvice> get activeAdvice => List<DispatchAdvice>.unmodifiable(_currentAdvice);
  bool get isAutopilotEnabled => _isAutopilotEnabled;

  /// Prekidač za 100% Autonomiju
  void toggleAutopilot(bool value) {
    _isAutopilotEnabled = value;
    if (kDebugMode) print(' [ML Dispatch] Autopilot: ');
    notifyListeners();
  }

  /// Broj putnika za koje je sistem naučio afinitet iz istorije (Pure Data)
  double get learnedAffinityCount => _passengerAffinity.length.toDouble();

  /// HELPER za bezbedno kastovanje JSONB podataka koji mogu doći kao String ili Map
  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  ///  LEARN FLOW (Unsupervised Affinity Learning)
  Future<void> _learnFromHistory() async {
    try {
      if (kDebugMode) print(' [ML Dispatch] Beba uči afinitete iz istorije...');

      final List<dynamic> logs = await _supabase
          .from('voznje_log')
          .select('putnik_id, vozac_id')
          .eq('tip', 'voznja')
          .order('created_at', ascending: false)
          .limit(1000);

      final Map<String, Map<String, int>> counts = {};
      for (var log in logs) {
        final pId = log['putnik_id']?.toString();
        final vId = log['vozac_id']?.toString();
        if (pId == null || vId == null) continue;

        counts.putIfAbsent(pId, () => {});
        counts[pId]![vId] = (counts[pId]![vId] ?? 0) + 1;
      }

      counts.forEach((pId, drivers) {
        final sorted = drivers.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (sorted.isNotEmpty && sorted.first.value >= 3) {
          _passengerAffinity[pId] = sorted.first.key;
        }
      });

      final List<dynamic> recentRequests =
          await _supabase.from('seat_requests').select('created_at').order('created_at', ascending: false).limit(100);

      if (recentRequests.length > 10) {
        _avgHourlyBookings = recentRequests.length / 48.0;
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Greška pri učenju: ');
    } finally {
      notifyListeners();
    }
  }

  ///  POKRENI DISPEČERA
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    await _learnFromHistory();
    _startVelocityMonitoring();
    _startIntegrityCheck();

    _subscribeToBookingStream();
  }

  void _subscribeToBookingStream() {
    try {
      _bookingStream = _supabase
          .channel('public:seat_requests')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'seat_requests',
            callback: (payload) => _analyzeRealtimeDemand(),
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Stream error: ');
    }
  }

  void stop() {
    _isActive = false;
    _velocityTimer?.cancel();
    _bookingStream?.unsubscribe();
  }

  void _startVelocityMonitoring() {
    _velocityTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _analyzeRealtimeDemand();
    });
  }

  void _startIntegrityCheck() {
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      _currentAdvice.clear();
      await _analyzeMultiVanSplits();
      await _analyzeOptimalGrouping();
      await _analyzeCapacityOverflow();

      if (_isAutopilotEnabled) {
        await _executeAutopilotActions();
      }

      notifyListeners();
    });
  }

  ///  AUTOPILOT EXECUTION
  Future<void> _executeAutopilotActions() async {
    for (var advice in _currentAdvice) {
      if (advice.priority == AdvicePriority.critical) {
        if (kDebugMode) print(' [Autopilot] REŠAVAM KRITIČNO: ${advice.title}');
        if (advice.title.contains('Preopterećenje')) {
          await _sendAutonomousAlert('Potreban rezervni kombi za: ${advice.description}');
        }
      }
    }
  }

  Future<void> _sendAutonomousAlert(String message) async {
    try {
      await _supabase.from('admin_audit_logs').insert({
        'action': 'AUTOPILOT_ACTION',
        'details': message,
        'severity': 'critical',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  ///  TATA, TATA! (Capacity Overflow Alert)
  Future<void> _analyzeCapacityOverflow() async {
    try {
      final String danDanas = _getDanKratica();
      final dynamic shadowData =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu, tip').neq('tip', 'posiljka');

      Map<String, List<String>> demandMap = {};
      Map<String, Set<String>> driverMap = {};

      if (shadowData is List) {
        for (var p in shadowData) {
          final allDays = _safeMap(p['polasci_po_danu']);
          if (allDays.isEmpty) continue;

          final dayData = _safeMap(allDays[danDanas]);
          if (dayData.isEmpty) continue;

          for (var gradCode in ['bc', 'vs']) {
            String? vreme = dayData[gradCode]?.toString();
            if (vreme == null || vreme == 'null') continue;

            // ✅ NORMALIZUJ VREME za ML analizu
            String normTime = GradAdresaValidator.normalizeTime(vreme);
            String grad = gradCode == 'bc' ? 'Bela Crkva' : 'Vršac';

            // NOVO: Đaci se sada uvek broje u kapacitetu (i za BC),
            // jer je korisnik tražio "Mesto je Mesto" i za BC u smislu prikaza/upozorenja.

            final key = '${grad}_$normTime'; // 🎯 FIX: Grupiši po terminu, ne globalno
            demandMap.putIfAbsent(key, () => []).add(p['id'].toString());

            final String? vozac = dayData['__vozac']?.toString() ?? dayData['_vozac']?.toString();
            if (vozac != null && vozac != 'null') {
              driverMap.putIfAbsent(key, () => {}).add(vozac);
            }
          }
        }
      }

      for (var entry in demandMap.entries) {
        final key = entry.key;
        final passengers = entry.value;

        int count = passengers.length;
        int driversCount = driverMap[key]?.length ?? 1;

        // 🏙️ Odredi grad i vreme za lookup kapaciteta
        final parts = key.split('_');
        final gradIme = parts[0];
        final vremeVrednost = parts[1];
        final gradKod = GradAdresaValidator.isBelaCrkva(gradIme) ? 'BC' : 'VS';

        // 🎫 Učitaj stvarni kapacitet iz KapacitetService (sinhrono iz cache-a)
        final int baseKapacitet = KapacitetService.getKapacitetSync(gradKod, vremeVrednost);
        final int totalKapacitet = driversCount * baseKapacitet;

        if (count > totalKapacitet) {
          _currentAdvice.add(DispatchAdvice(
            title: ' 🚨 TATA, TATA! (Preopterećenje)',
            description:
                'U terminu $gradIme $vremeVrednost ima $count putnika na $driversCount van-a (kapacitet: $totalKapacitet). Kapacitet premašen!',
            priority: AdvicePriority.critical,
            action: 'Dodaj vozilo',
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Overflow error: ');
    }
  }

  String _getDanKratica() {
    final now = DateTime.now();
    const dani = ['pon', 'pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[now.weekday];
  }

  ///  SMART GROUPING (Spajanje Vans-ova)
  Future<void> _analyzeOptimalGrouping() async {
    try {
      final String danDanas = _getDanKratica();
      final dynamic shadowData =
          await _supabase.from('registrovani_putnici').select('id, polasci_po_danu, tip').neq('tip', 'posiljka');

      Map<String, List<String>> demandMap = {};

      if (shadowData is List) {
        for (var p in shadowData) {
          final allDays = _safeMap(p['polasci_po_danu']);
          if (allDays.isEmpty) continue;

          final dayData = _safeMap(allDays[danDanas]);
          if (dayData.isEmpty) continue;

          for (var gradCode in ['bc', 'vs']) {
            String? vreme = dayData[gradCode]?.toString();
            if (vreme == null || vreme == 'null') continue;
            String normTime = vreme.startsWith('0') ? vreme.substring(1) : vreme;
            String grad = gradCode == 'bc' ? 'Bela Crkva' : 'Vršac';

            final key = '${grad}_$normTime'; // 🎯 FIX: Grupiši po terminu
            demandMap.putIfAbsent(key, () => []).add(p['id'].toString());
          }
        }
      }

      List<String> sortedKeys = demandMap.keys.toList()..sort();
      for (int i = 0; i < sortedKeys.length - 1; i++) {
        String keyA = sortedKeys[i];
        String keyB = sortedKeys[i + 1];

        String gradA = keyA.split('_')[0];
        String gradB = keyB.split('_')[0];
        if (gradA != gradB) continue;

        DateTime timeA = _parseTime(keyA.split('_')[1]);
        DateTime timeB = _parseTime(keyB.split('_')[1]);

        if (timeB.difference(timeA).inMinutes <= 35) {
          int totalCount = demandMap[keyA]!.length + demandMap[keyB]!.length;
          if (totalCount <= 8) {
            _currentAdvice.add(DispatchAdvice(
              title: '💡 PRILIKA ZA SPAJANJE',
              description:
                  'Termini ${keyA.split('_')[1]} i ${keyB.split('_')[1]} ($gradA) imaju ukupno $totalCount putnika. Može jedan van.',
              priority: AdvicePriority.smart,
              action: 'Spoji rute',
              proposedChange: 'Spoji $keyA u $keyB',
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Grouping error: ');
    }
  }

  DateTime _parseTime(String t) {
    try {
      final parts = t.split(':');
      return DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    } catch (_) {
      return DateTime(2024, 1, 1, 0, 0);
    }
  }

  ///  AUTONOMNI SPLIT
  Future<void> _analyzeMultiVanSplits() async {
    try {
      final String danDanas = _getDanKratica();
      final dynamic shadowData = await _supabase.from('registrovani_putnici').select('id, putnik_ime, polasci_po_danu');

      Map<String, Set<String>> overlaps = {};

      if (shadowData is List) {
        for (var p in shadowData) {
          final allDays = _safeMap(p['polasci_po_danu']);
          if (allDays.isEmpty) continue;

          final dayData = _safeMap(allDays[danDanas]);
          if (dayData.isEmpty) continue;

          for (var gradCode in ['bc', 'vs']) {
            String? vreme = dayData[gradCode]?.toString();
            if (vreme == null || vreme == 'null') continue;
            String normTime = vreme.startsWith('0') ? vreme.substring(1) : vreme;
            String grad = gradCode == 'bc' ? 'Bela Crkva' : 'Vršac';

            final key = '${grad}_$normTime'; // 🎯 FIX: Grupiši po terminu
            final String? vozac = dayData['__vozac']?.toString() ?? dayData['_vozac']?.toString();
            if (vozac != null && vozac != 'null') {
              overlaps.putIfAbsent(key, () => {}).add(vozac);
            }
          }
        }
      }

      overlaps.forEach((key, drivers) {
        if (drivers.length >= 2) {
          final grad = key.split('_')[0];
          final vreme = key.split('_')[1];
          _currentAdvice.add(DispatchAdvice(
            title: '🚢 AUTONOMNI SPLIT ($grad $vreme)',
            description: 'Detektovano više vozača: ${drivers.join(", ")}. Optimizuj raspored.',
            priority: AdvicePriority.critical,
            action: 'Sinhronizuj',
          ));
        }
      });
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Split error: ');
    }
  }

  Future<void> _analyzeRealtimeDemand() async {
    try {
      final DateTime oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final dynamic recent =
          await _supabase.from('seat_requests').select().gt('created_at', oneHourAgo.toIso8601String());

      if (recent is List && recent.length >= 5) {
        _triggerAlert('REALTIME DEMAND', 'Nagli skok rezervacija (/h).');
      }
    } catch (e) {
      if (kDebugMode) print(' [ML Dispatch] Velocity error: ');
    }
  }

  void _triggerAlert(String title, String body) {
    _currentAdvice.add(DispatchAdvice(
      title: title,
      description: body,
      priority: AdvicePriority.smart,
      action: 'Vidi',
    ));
    notifyListeners();
  }
}

enum AdvicePriority { smart, critical }

class DispatchAdvice {
  final String title;
  final String description;
  final AdvicePriority priority;
  final String action;
  final String? originalStatus;
  final String? proposedChange;
  final DateTime timestamp;

  DispatchAdvice({
    required this.title,
    required this.description,
    required this.priority,
    required this.action,
    this.originalStatus,
    this.proposedChange,
  }) : timestamp = DateTime.now();
}
