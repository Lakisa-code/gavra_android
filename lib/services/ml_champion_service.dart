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

/// 🏆 ML CHAMPION SERVICE - "Šampion"
///
/// Četvrti član AI porodice (uz Mehaničara, Fizičara i Dispečera).
/// Zadužen za ljude, komunikaciju i "vaspitanje" putnika.
class MLChampionService extends ChangeNotifier {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME
  RealtimeChannel? _tripsStream;

  // Interna keš memorija za statistiku
  final Map<String, PassengerStats> _statsMap = <String, PassengerStats>{};

  // 💬 PREDLOŽENE PORUKE (Šta bi beba poslala)
  final List<ProposedMessage> _proposedMessages = [];

  // 🧠 DINAMIČKE TEŽINE I STATISTIKA (Šampion ih sam uči)
  double _successWeight = 0.05;
  double _cancellationPenalty = 0.3;
  double _systemAvgCancelRate = 0.1;

  // UNUPERVISED METRICS
  double _globalMeanScore = 4.5;
  double _globalStdDev = 0.2;
  double _avgTripsPerPassenger = 0.0;

  static final MLChampionService _instance = MLChampionService._internal();
  factory MLChampionService() => _instance;
  MLChampionService._internal();

  List<ProposedMessage> get proposedMessages => List.unmodifiable(_proposedMessages);

  double get systemAvgCancelRate => _systemAvgCancelRate;
  double get currentPenalty => _cancellationPenalty;
  double get currentWeight => _successWeight;
  double get globalMeanScore => _globalMeanScore;
  double get globalStdDev => _globalStdDev;
  double get avgTrips => _avgTripsPerPassenger;

  /// 🚀 POKRENI ŠAMPIONA
  Future<void> start() async {
    await analyzeAll();
    _subscribeToTrips();
  }

  /// 🛑 ZAUSTAVI
  void stop() {
    _tripsStream?.unsubscribe();
  }

  // 📡 SLUŠANJE VOŽNJI (Realtime Reputation Error)
  void _subscribeToTrips() {
    try {
      _tripsStream = _supabase
          .channel('public:voznje_log')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'voznje_log',
            callback: (payload) async {
              if (kDebugMode) print('🏆 [ML Champion] Neko je upisao vožnju! Rejting se menja...');

              // Ako imamo passenger ID u payloadu, osveži samo njega
              final newRecord = payload.newRecord;
              if (newRecord.containsKey('putnik_id')) {
                final String pid = newRecord['putnik_id'].toString();
                // Treba nam ime - probamo iz cache-a ili fetch
                final String name = _statsMap[pid]?.name ?? 'Putnik';
                await analyzePassenger(pid, name);
              } else {
                await analyzeAll(); // Fallback, osveži sve
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška stream-a: $e');
    }
  }

  /// 📊 ANALIZIRAJ SVE PUTNIKE (100% Unsupervised Learning)
  /// Optimizovano skeniranje sa dinamičkim učenjem "šta je normalno".
  Future<void> analyzeAll() async {
    try {
      if (kDebugMode) print('🏆 [ML Champion] Šampion započinje Unsupervised Learning ciklus...');

      // 1. Dobavi sve putnike
      final List<dynamic> putniciData =
          await _supabase.from('registrovani_putnici').select('id, putnik_ime').eq('obrisan', false);

      if (putniciData.isEmpty) return;

      // 2. Dobavi kompletan statistički uzorak
      final List<dynamic> logovi =
          await _supabase.from('voznje_log').select('putnik_id, tip').not('putnik_id', 'is', null);

      // Mapiranje podataka
      final Map<String, int> tripsCount = {};
      final Map<String, int> cancellationsCount = {};
      int totalSystemTrips = 0;
      int totalSystemCancels = 0;

      for (var log in logovi) {
        final pid = log['putnik_id']?.toString() ?? '';
        final tip = log['tip']?.toString() ?? '';

        if (tip == 'voznja') {
          tripsCount[pid] = (tripsCount[pid] ?? 0) + 1;
          totalSystemTrips++;
        } else if (tip == 'storno' || tip == 'otkazano') {
          cancellationsCount[pid] = (cancellationsCount[pid] ?? 0) + 1;
          totalSystemCancels++;
        }
      }

      // 🧠 DINAMIČKA KALIBRACIJA TEŽINA (PHASE 1: ENVIRONMENT)
      if (totalSystemTrips > 0) {
        _systemAvgCancelRate = totalSystemCancels / (totalSystemTrips + totalSystemCancels);
        _avgTripsPerPassenger = totalSystemTrips / putniciData.length;

        // Kazna je manja ako SVI otkazuju (npr. oluja), ali veća ako je sistem stabilan
        _cancellationPenalty = 0.2 + (0.4 * (1.0 - _systemAvgCancelRate.clamp(0.0, 1.0)));

        // Težina uspeha zavisi od proseka - ako svi imaju malo vožnji, svaka vredi više
        _successWeight = (_avgTripsPerPassenger < 5) ? 0.15 : 0.05;

        if (kDebugMode) {
          print('🏆 [ML Champion] Learned Penalty: -${_cancellationPenalty.toStringAsFixed(2)}');
          print('🏆 [ML Champion] Learned Weight: +${_successWeight.toStringAsFixed(2)}');
        }
      }

      // 3. Spoji podatke i ažuriraj cache + Računaj globalni mean
      _statsMap.clear();
      double sumScores = 0;
      final List<double> allScores = [];

      for (final p in putniciData) {
        final String id = p['id']?.toString() ?? '';
        final String name = p['putnik_ime']?.toString() ?? 'Nepoznat';

        final int combinedTrips = tripsCount[id] ?? 0;
        final int cancellations = cancellationsCount[id] ?? 0;

        // 🧠 FORMULA KOJU ŠAMPION SAM IZVODI
        double score = 4.5;
        score += (combinedTrips * _successWeight);
        score -= (cancellations * _cancellationPenalty);
        score = score.clamp(0.0, 5.0);

        _statsMap[id] = PassengerStats(
          id: id,
          name: name,
          score: score,
          totalTrips: combinedTrips,
          cancellations: cancellations,
        );

        sumScores += score;
        allScores.add(score);
      }

      // 📊 PHASE 2: STATISTICAL NORMALCY (Unsupervised Thresholds)
      if (allScores.isNotEmpty) {
        _globalMeanScore = sumScores / allScores.length;

        // Računanje Standardne Devijacije (StdDev)
        double variance = 0;
        for (var s in allScores) {
          variance += (s - _globalMeanScore) * (s - _globalMeanScore);
        }
        _globalStdDev = (variance / allScores.length > 0) ? (variance / allScores.length) : 0.2;

        if (kDebugMode) {
          print(
              '🏆 [ML Champion] Normalcy: Mean=${_globalMeanScore.toStringAsFixed(2)}, StdDev=${_globalStdDev.toStringAsFixed(2)}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška u učenju: $e');
    } finally {
      notifyListeners();
    }
  }

  /// 📊 ANALIZIRAJ SPECIFIČNOG PUTNIKA
  Future<void> analyzePassenger(String userId, String name) async {
    try {
      // Optimizacija: Koristimo count() umesto fetch-ovanja cele istorije
      // 1. Broj uspešnih vožnji
      final int combinedTrips =
          await _supabase.from('voznje_log').count(CountOption.exact).eq('putnik_id', userId).eq('tip', 'voznja');

      // 2. Broj otkazivanja (storno ili otkazano)
      final int cancellations = await _supabase
          .from('voznje_log')
          .count(CountOption.exact)
          .eq('putnik_id', userId)
          .inFilter('tip', ['storno', 'otkazano']);

      // Računanje skora
      double score = 4.5;
      score += (combinedTrips * _successWeight);
      score -= (cancellations * _cancellationPenalty);

      _statsMap[userId] = PassengerStats(
        id: userId,
        name: name,
        score: score.clamp(0.0, 5.0),
        totalTrips: combinedTrips,
        cancellations: cancellations,
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška pri analizi putnika $name: $e');
    }
  }

  List<PassengerStats> get topLegends {
    final List<PassengerStats> list = _statsMap.values.toList();
    // 🧠 ADAPTIVE THRESHOLD: Mean + 1.5 * StdDev
    final threshold = _globalMeanScore + (1.5 * _globalStdDev);
    return list.where((p) => p.score >= threshold).toList()..sort((a, b) => b.score.compareTo(a.score));
  }

  List<PassengerStats> get problematicOnes {
    final List<PassengerStats> list = _statsMap.values.toList();
    // 🧠 ADAPTIVE THRESHOLD: Mean - 1.5 * StdDev
    // Ako je sistem u haosu, prag za "problematične" se spušta
    final threshold = _globalMeanScore - (1.5 * _globalStdDev);
    return list.where((p) => p.score <= threshold).toList()..sort((a, b) => a.score.compareTo(b.score));
  }

  List<PassengerStats> get anomalies {
    final List<PassengerStats> list = _statsMap.values.toList();
    // 🧠 ANOMALY: Passenger whose cancel rate is 3x the system average
    return list.where((p) {
      final rate = p.cancellations / (p.totalTrips + p.cancellations + 0.1);
      return rate > (_systemAvgCancelRate * 3) && p.totalTrips > 2;
    }).toList();
  }

  /// 💬 GENERIŠI "VASPITNU" PORUKU (Koristi naučene parametre)
  String generateMessage(String userId, String context) {
    final stats = _statsMap[userId];
    final double score = stats?.score ?? 5.0;
    final String name = stats?.name ?? 'Putnik';

    // Prilagodi prag za poruku na osnovu Mean/StdDev
    final isCritical = score < (_globalMeanScore - _globalStdDev);

    String message = 'Rezervacija potvrđena.';

    // 📝 NE ŠALJI AUTOMATSKI, SAMO DODAJ U PREDLOGE
    _proposedMessages.add(ProposedMessage(
      userId: userId,
      userName: name,
      message: message,
      context: context,
    ));

    // 🔔 OBAVESTI TATU DA IMA NOVA PORUKA ZA ODOBRENJE
    try {
      LocalNotificationService.showRealtimeNotification(
        title: 'Šampion: Predlog poruke',
        body: 'Imam jednu vaspitnu za putnika $name. Pogledaj u Lab-u.',
        payload: 'ml_lab',
      );
    } catch (_) {}

    return message;
  }

  /// 🔓 AUTO-OPEN SLOTS
  Future<bool> shouldOpenGeneralBooking(String datum, String vreme) async {
    final DateTime now = DateTime.now();
    // Ako je sreda posle 20h, otvaramo kapije za "dnevne"
    if (now.weekday == DateTime.wednesday && now.hour >= 20) return true;
    return false;
  }
}

class ProposedMessage {
  final String userId;
  final String userName;
  final String message;
  final String context;
  final DateTime timestamp;

  ProposedMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.context,
  }) : timestamp = DateTime.now();
}
