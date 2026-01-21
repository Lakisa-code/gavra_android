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
class MLChampionService {
  static SupabaseClient get _supabase => supabase;

  // 📡 REALTIME
  RealtimeChannel? _tripsStream;

  // Interna keš memorija za statistiku
  final Map<String, PassengerStats> _statsMap = <String, PassengerStats>{};

  // 💬 PREDLOŽENE PORUKE (Šta bi beba poslala)
  final List<ProposedMessage> _proposedMessages = [];

  static final MLChampionService _instance = MLChampionService._internal();
  factory MLChampionService() => _instance;
  MLChampionService._internal();

  List<ProposedMessage> get proposedMessages => List.unmodifiable(_proposedMessages);

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
            callback: (payload) {
              if (kDebugMode) print('🏆 [ML Champion] Neko je upisao vožnju! Rejting se menja...');

              // Ako imamo passenger ID u payloadu, osveži samo njega
              final newRecord = payload.newRecord;
              if (newRecord.containsKey('putnik_id')) {
                final String pid = newRecord['putnik_id'].toString();
                // Treba nam ime - probamo iz cache-a ili fetch
                final String name = _statsMap[pid]?.name ?? 'Putnik';
                analyzePassenger(pid, name);
              } else {
                analyzeAll(); // Fallback, osveži sve
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška stream-a: $e');
    }
  }

  /// 📊 ANALIZIRAJ SVE PUTNIKE
  /// Beba skenira celu istoriju i uči ko je kakav.
  Future<void> analyzeAll() async {
    try {
      if (kDebugMode) print('🏆 [ML Champion] Šampion češlja istoriju vožnji...');

      // 1. Dobavi sve putnike
      final dynamic putniciData =
          await _supabase.from('registrovani_putnici').select('id, putnik_ime').eq('obrisan', false);

      if (putniciData is! List) return;

      // 2. Za svakog putnika pročešljaj logove
      for (final dynamic p in putniciData) {
        if (p is! Map) continue;
        final String id = p['id']?.toString() ?? '';
        final String name = p['putnik_ime']?.toString() ?? 'Nepoznat';

        await analyzePassenger(id, name);
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška u masovnoj analizi: $e');
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
      double score = 4.5; // Startno poverenje
      score += (combinedTrips * 0.05);
      score -= (cancellations * 0.3);

      _statsMap[userId] = PassengerStats(
        id: userId,
        name: name,
        score: score.clamp(0.0, 5.0),
        totalTrips: combinedTrips,
        cancellations: cancellations,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ [ML Champion] Greška pri analizi putnika $name: $e');
    }
  }

  List<PassengerStats> get topLegends {
    final List<PassengerStats> list = _statsMap.values.toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list.take(5).toList();
  }

  List<PassengerStats> get problematicOnes {
    final List<PassengerStats> list = _statsMap.values.toList();
    list.sort((a, b) => a.score.compareTo(b.score));
    return list.where((p) => p.score < 4.0).take(5).toList();
  }

  /// 💬 GENERIŠI "VASPITNU" PORUKU
  String generateMessage(String userId, String context) {
    final double score = _statsMap[userId]?.score ?? 5.0;
    final String name = _statsMap[userId]?.name ?? 'Putnik';
    String message = 'Rezervacija potvrđena.';

    if (context == 'LATE_BOOKING') {
      if (score < 3.5) {
        message =
            'Slušaj lafčino, opet zakazuješ u minut do 12? Skor ti je pao na ${score.toStringAsFixed(1)}. Gledaj da sledeći put budeš brži ako hoćeš mesto! 😉';
      } else {
        message =
            'E legendo, vidim da si u gužvi. Ubacio sam te sad jer si redovan, ali javi se ranije sledeći put! 🤝';
      }
    }

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
