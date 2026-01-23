import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'local_notification_service.dart';

/// 🏆 MODEL ZA REPUTACIJU PUTNIKA
class PassengerStats {
  final String id;
  final String name;
  final double score;
  final int totalTrips;
  final int cancellations;

  PassengerStats({
    required this.id,
    required this.name,
    required this.score,
    required this.totalTrips,
    required this.cancellations,
  });
}

/// 🧠 ML CHAMPION SERVICE - "Šampion"
class MLChampionService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME
  RealtimeChannel? _tripsStream;

  // Interna keš memorija
  final Map<String, PassengerStats> _statsMap = <String, PassengerStats>{};
  final List<ProposedMessage> _proposedMessages = [];

  bool _isAutopilotEnabled = false;

  // 📈 STATISTIKE
  double _globalMeanScore = 0.0;
  final double _globalStdDev = 0.0;

  // ⚙️ DINAMIČKE TEŽINE
  final double _successWeight = 0.05;
  final double _cancellationPenalty = 0.3;

  static final MLChampionService _instance = MLChampionService._internal();
  factory MLChampionService() => _instance;
  MLChampionService._internal();

  List<ProposedMessage> get proposedMessages => List.unmodifiable(_proposedMessages);
  bool get isAutopilotEnabled => _isAutopilotEnabled;

  double get globalMeanScore => _globalMeanScore;
  double get globalStdDev => _globalStdDev;

  // 👑 FILTERI ZA UI
  List<PassengerStats> get topLegends => _statsMap.values.where((p) => p.score > 8.0 && p.totalTrips > 10).toList();
  List<PassengerStats> get problematicOnes => _statsMap.values.where((p) => p.score < 4.0).toList();
  List<PassengerStats> get anomalies => _statsMap.values.where((p) {
        if (p.totalTrips < 5) return false;
        double cancelRate = p.cancellations / p.totalTrips;
        return cancelRate > 0.4; // Više od 40% otkazivanja je anomalija
      }).toList();

  void toggleAutopilot(bool value) {
    _isAutopilotEnabled = value;
    if (kDebugMode) print('🏆 [ML Champion] Autopilot: ${value ? 'ON' : 'OFF'}');
    notifyListeners();
  }

  /// 🚀 POKRENI
  Future<void> start() async {
    await analyzeAll();
    _subscribeToTrips();
  }

  void stop() {
    _tripsStream?.unsubscribe();
  }

  void _subscribeToTrips() {
    _tripsStream = _supabase
        .channel('public:voznje_log')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'voznje_log',
          callback: (payload) async {
            await analyzeAll();
          },
        )
        .subscribe();
  }

  Future<void> analyzeAll() async {
    try {
      final List<dynamic> passengers = await _supabase.from('registrovani_putnici').select('id, putnik_ime');
      for (var p in passengers) {
        await analyzePassenger(p['id'].toString(), p['putnik_ime'].toString());
      }
      _calculateGlobalStats();
    } catch (e) {
      if (kDebugMode) print('❌ [ML Champion] Greška u analyzeAll: $e');
    }
    notifyListeners();
  }

  void _calculateGlobalStats() {
    if (_statsMap.isEmpty) return;
    final scores = _statsMap.values.map((p) => p.score).toList();
    _globalMeanScore = scores.reduce((a, b) => a + b) / scores.length;
    // Poverenje/Devijacija
  }

  Future<void> analyzePassenger(String id, String name) async {
    try {
      final List<dynamic> logs = await _supabase.from('voznje_log').select().eq('putnik_id', id);

      int total = logs.length;
      int cancels = logs.where((l) => l['tip'] == 'otkazivanje').length;

      double score = 5.0 + (total * _successWeight) - (cancels * _cancellationPenalty);
      if (score > 10) score = 10;
      if (score < 0) score = 0;

      _statsMap[id] = PassengerStats(
        id: id,
        name: name,
        score: score,
        totalTrips: total,
        cancellations: cancels,
      );

      // PROVERA ZA AUTOPILOT ILI SAVET
      if (score < 3.0 && !_isAlreadyProposed(id)) {
        _proposeAction(id, name, 'Kritično loša reputacija. Potrebna opomena.', true);
      } else if (score > 9.0 && total > 20 && !_isAlreadyProposed(id)) {
        _proposeAction(id, name, 'Izvanredan putnik! Zaslužuje vaučer.', false);
      }
    } catch (_) {}
  }

  bool _isAlreadyProposed(String id) => _proposedMessages.any((m) => m.passengerId == id);

  void _proposeAction(String pid, String name, String reason, bool isUrgent) {
    final message = ProposedMessage(
      passengerId: pid,
      passengerName: name,
      message: isUrgent
          ? 'Poštovani $name, primećujemo učestala otkazivanja. Molimo vas za razumevanje.'
          : 'Hvala ti $name što putuješ sa nama! Beba Šampion te nagrađuje!',
      reason: reason,
      isUrgent: isUrgent,
    );
    _proposedMessages.add(message);

    if (_isAutopilotEnabled) {
      _executeAutonomousMessage(message);
    }
  }

  Future<void> _executeAutonomousMessage(ProposedMessage msg) async {
    // 🤖 AKCIJA
    try {
      await _supabase.from('admin_audit_logs').insert({
        'action_type': 'CHAMPION_AUTOPILOT',
        'details': 'Slanje poruke putniku ${msg.passengerName}: ${msg.reason}',
        'metadata': {'score': _statsMap[msg.passengerId]?.score},
      });

      LocalNotificationService.showNotification(
        title: '🤖 CHAMPION AUTOPILOT',
        body: 'Poslata poruka: ${msg.passengerName}',
      );
    } catch (e) {
      if (kDebugMode) print('❌ [Autopilot] Greška: $e');
    }
  }
}

class ProposedMessage {
  final String passengerId;
  final String passengerName;
  final String message;
  final String reason;
  final bool isUrgent;
  final DateTime timestamp;

  // Getters for UI compatibility
  String get userName => passengerName;
  String get context => reason;

  ProposedMessage({
    required this.passengerId,
    required this.passengerName,
    required this.message,
    required this.reason,
    required this.isUrgent,
  }) : timestamp = DateTime.now();
}
