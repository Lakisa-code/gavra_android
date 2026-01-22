import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// 👨‍✈️ BEBA DISPEČER (ML Dispatch Autonomous Service)
///
/// 100% AUTONOMNA: Ne veruje u fiksne sektore ili "human" kategorije.
/// Uči isključivo iz protoka podataka i istorijskih afiniteta putnika.

class MLDispatchAutonomousService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME
  RealtimeChannel? _bookingStream;

  // Interna memorija bebe (100% Unsupervised)
  final Map<String, double> _recurrentFactors = {};
  final Map<String, String> _passengerAffinity = {}; // putnik_id -> vozac_ime (Naučeno)
  double _avgHourlyBookings = 0.5;

  bool _isActive = false;
  Timer? _velocityTimer;

  // Rezultati analize za UI
  final List<DispatchAdvice> _currentAdvice = <DispatchAdvice>[];

  // Singleton
  static final MLDispatchAutonomousService _instance = MLDispatchAutonomousService._internal();
  factory MLDispatchAutonomousService() => _instance;
  MLDispatchAutonomousService._internal();

  List<DispatchAdvice> get activeAdvice => List<DispatchAdvice>.unmodifiable(_currentAdvice);

  /// Broj putnika za koje je sistem naučio afinitet iz istorije (Pure Data)
  double get learnedAffinityCount => _passengerAffinity.length.toDouble();

  /// 🎓 LEARN FLOW (Unsupervised Affinity Learning)
  Future<void> _learnFromHistory() async {
    try {
      if (kDebugMode) print('🎓 [ML Dispatch] Beba uči afinitete iz istorije...');

      // 1. Nauči ko s kim najčešće putuje (80% Overlap Pattern)
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

      // 2. Nauči Booking Velocity
      final List<dynamic> recentRequests =
          await _supabase.from('seat_requests').select('created_at').order('created_at', ascending: false).limit(100);

      if (recentRequests.length > 10) {
        _avgHourlyBookings = recentRequests.length / 48.0;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Greška pri učenju: $e');
    } finally {
      notifyListeners();
    }
  }

  /// 🚀 POKRENI DISPEČERA
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
      if (kDebugMode) print('⚠️ [ML Dispatch] Stream error: $e');
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
      await _analyzeMultiVanSplits();
    });
  }

  String _getDanKratica() {
    final now = DateTime.now();
    const dani = ['pon', 'pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[now.weekday];
  }

  /// 🚐 AUTONOMNI SPLIT (Shadow Matrix)
  Future<void> _analyzeMultiVanSplits() async {
    try {
      final String danDanas = _getDanKratica();
      final dynamic shadowData = await _supabase.from('registrovani_putnici').select('id, putnik_ime, polasci_po_danu');

      Map<String, Set<String>> overlaps = {};

      if (shadowData is List) {
        for (var p in shadowData) {
          // Bezbedno izvlačenje JSON podataka (izbegavamo cast greške ako je u bazi String)
          dynamic rawAllDays = p['polasci_po_danu'];
          if (rawAllDays == null || rawAllDays is! Map) continue;
          final allDays = Map<String, dynamic>.from(rawAllDays);

          dynamic rawDayData = allDays[danDanas];
          if (rawDayData == null || rawDayData is! Map) continue;
          final dayData = Map<String, dynamic>.from(rawDayData);

          for (var gradCode in ['bc', 'vs']) {
            String? vreme = dayData[gradCode]?.toString();
            if (vreme == null || vreme == 'null') continue;

            String normTime = vreme.startsWith('0') ? vreme.substring(1) : vreme;
            String fullGrad = gradCode == 'bc' ? 'Bela Crkva' : 'Vršac';

            final String? vozac =
                dayData['${gradCode}_${normTime}_vozac']?.toString() ?? dayData['${gradCode}_vozac']?.toString();

            if (vozac != null && vozac != 'null') {
              final key = '${fullGrad}_$normTime';
              overlaps.putIfAbsent(key, () => {}).add(vozac);
            }
          }
        }
      }

      for (var entry in overlaps.entries) {
        if (entry.value.length >= 2) {
          final grad = entry.key.split('_')[0];
          final vreme = entry.key.split('_')[1];
          final drivers = entry.value.toList();

          int countA = 0;
          int countB = 0;

          for (var p in shadowData as List) {
            final pId = p['id']?.toString();
            final affinity = _passengerAffinity[pId];
            if (affinity != null) {
              if (affinity.contains(drivers[0])) {
                countA++;
              } else if (affinity.contains(drivers[1])) {
                countB++;
              }
            }
          }

          _currentAdvice.add(DispatchAdvice(
            title: 'AUTONOMNI SPLIT ($vreme)',
            description:
                'Beba detektovala duo: ${drivers.join(' & ')}. \nAfinitet: ${drivers[0]} ($countA), ${drivers[1]} ($countB).',
            priority: AdvicePriority.critical,
            action: 'Sinhronizuj listu',
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Split error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _analyzeRealtimeDemand() async {
    try {
      final DateTime oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final dynamic recent =
          await _supabase.from('seat_requests').select().gt('created_at', oneHourAgo.toIso8601String());

      if (recent is List && recent.length >= 5) {
        _triggerAlert('REALTIME DEMAND', 'Nagli skok rezervacija (${recent.length}/h).');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Dispatch] Velocity error: $e');
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
