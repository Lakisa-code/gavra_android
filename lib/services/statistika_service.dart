import 'realtime_hub_service.dart';
import 'vozac_mapping_service.dart';

/// Servis za statistiku - koristi SAMO registrovani_putnici tabelu
/// Sve statistike se čuvaju u JSONB kolonama: statistics, action_log
/// 🚀 OPTIMIZOVANO: Koristi centralni RealtimeHubService (Postgres Changes)
class StatistikaService {
  /// Stream pazara za sve vozače - SIMPLIFIKOVANO
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  /// 🚀 OPTIMIZOVANO: Koristi RealtimeHubService (raw data za action_log pristup)
  static Stream<Map<String, double>> streamPazarZaSveVozace({
    required DateTime from,
    required DateTime to,
  }) {
    // Koristi centralni RealtimeHubService - raw data za action_log
    return RealtimeHubService.instance.putnikStream.map((putnici) {
      final Map<String, double> pazar = {};
      double ukupno = 0;

      for (final putnik in putnici) {
        // Proveri da li je plaćeno u datom periodu
        final datumPlacanja = putnik.datumPlacanja;
        if (datumPlacanja == null) continue;

        try {
          if (datumPlacanja.isAfter(from) && datumPlacanja.isBefore(to.add(const Duration(days: 1)))) {
            final cena = putnik.cena ?? 0;

            // Pronađi vozača koji je naplatio iz actionLog (List<dynamic>)
            String vozacIme = 'Nepoznat';
            final actionLog = putnik.actionLog;

            if (actionLog.isNotEmpty) {
              // Pronađi poslednju 'paid' akciju
              for (final action in actionLog.reversed) {
                if (action is Map && (action['action'] == 'paid' || action['type'] == 'paid')) {
                  vozacIme = action['by']?.toString() ?? action['vozac_id']?.toString() ?? 'Nepoznat';
                  break;
                }
              }
            }

            pazar[vozacIme] = (pazar[vozacIme] ?? 0) + cena;
            ukupno += cena;
          }
        } catch (_) {}
      }

      pazar['_ukupno'] = ukupno;
      return pazar;
    });
  }

  /// Singleton instance for compatibility
  static final StatistikaService instance = StatistikaService._internal();
  StatistikaService._internal();

  /// Stream pazara za određenog vozača
  static Stream<double> streamPazarZaVozaca({
    required String vozac,
    required DateTime from,
    required DateTime to,
  }) {
    return streamPazarZaSveVozace(from: from, to: to).map((pazar) {
      return pazar[vozac] ?? 0.0;
    });
  }

  /// Stream broja mesečnih karata koje je vozač naplatio DANAS
  /// 🚀 OPTIMIZOVANO: Koristi RealtimeHubService
  static Stream<int> streamBrojRegistrovanihZaVozaca({required String vozac}) {
    final now = DateTime.now();
    final danPocetak = DateTime(now.year, now.month, now.day);
    final danKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Dohvati UUID vozača za poređenje
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozac);

    return RealtimeHubService.instance.putnikStream.map((putnici) {
      int count = 0;
      for (final putnik in putnici) {
        // Proveri da li je mesečni putnik (ucenik ili radnik, ne dnevni)
        if (putnik.tip == 'dnevni') continue;

        // Proveri da li je plaćeno danas
        final vremePlacanja = putnik.vremePlacanja;
        if (vremePlacanja == null) continue;

        try {
          if (vremePlacanja.isAfter(danPocetak) && vremePlacanja.isBefore(danKraj)) {
            // Pronađi vozača koji je naplatio iz action_log (List<dynamic>)
            final actionLog = putnik.actionLog;
            for (final action in actionLog.reversed) {
              if (action is Map && (action['action'] == 'paid' || action['type'] == 'paid')) {
                final paidBy = action['by']?.toString() ?? action['vozac_id']?.toString() ?? '';
                if (paidBy == vozac || paidBy == vozacUuid || paidBy.contains(vozac)) {
                  count++;
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }
      return count;
    });
  }

  /// Stream broja dužnika za vozača
  /// 🚀 OPTIMIZOVANO: Koristi RealtimeHubService
  static Stream<int> streamBrojDuznikaZaVozaca({required String vozac}) {
    return RealtimeHubService.instance.putnikStream.map((putnici) {
      return putnici.where((p) => p.aktivan && p.placeno != true).length;
    });
  }

  /// Detaljne statistike po vozačima
  Future<Map<String, Map<String, dynamic>>> detaljneStatistikePoVozacima(
    List<dynamic> putnici,
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    final Map<String, Map<String, dynamic>> stats = {};

    for (final putnik in putnici) {
      if (putnik is! Map) continue;
      final vozacId = putnik['vozac_id']?.toString() ?? 'nepoznat';

      stats.putIfAbsent(
          vozacId,
          () => {
                'putnika': 0,
                'pazar': 0.0,
              });

      stats[vozacId]!['putnika'] = (stats[vozacId]!['putnika'] as int) + 1;
      final cena = (putnik['cena'] as num?)?.toDouble() ?? 0;
      stats[vozacId]!['pazar'] = (stats[vozacId]!['pazar'] as double) + cena;
    }

    return stats;
  }

  /// Dohvati kilometražu za vozača
  Future<double> getKilometrazu(String vozac, DateTime from, DateTime to) async {
    // Placeholder - kilometraža se ne prati trenutno
    return 0.0;
  }
}
