import '../globals.dart';
import 'voznje_log_service.dart';

/// Servis za statistiku
/// ✅ TRAJNO REŠENJE: Koristi VoznjeLogService kao source of truth
class StatistikaService {
  /// Singleton instance for compatibility
  static final StatistikaService instance = StatistikaService._internal();
  StatistikaService._internal();

  /// Stream pazara za sve vozače
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  /// ✅ DELEGIRA na VoznjeLogService
  static Stream<Map<String, double>> streamPazarZaSveVozace({
    required DateTime from,
    required DateTime to,
  }) {
    return VoznjeLogService.streamPazarPoVozacima(from: from, to: to);
  }

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
  /// ✅ ISPRAVKA: Broji stvaran broj uplata, ne aproksimaciju
  static Stream<int> streamBrojRegistrovanihZaVozaca({required String vozac}) {
    final now = DateTime.now();
    final danPocetak = DateTime(now.year, now.month, now.day);
    final danKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return VoznjeLogService.streamBrojUplataPoVozacima(from: danPocetak, to: danKraj).map((brojUplata) {
      return brojUplata[vozac] ?? 0;
    });
  }

  /// Stream broja dužnika
  static Stream<int> streamBrojDuznikaZaVozaca({required String vozac}) {
    return VoznjeLogService.streamBrojDuznikaPoVozacu(
      vozacIme: vozac,
      datum: DateTime.now(),
    );
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
      final vozacId = putnik['vozac_id']?.toString();
      if (vozacId == null || vozacId.isEmpty) continue;

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
    try {
      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      final response = await supabase
          .from('daily_reports')
          .select('kilometraza')
          .eq('vozac', vozac)
          .gte('datum', fromStr)
          .lte('datum', toStr);

      if (response.isEmpty) return 0.0;

      double total = 0;
      for (var row in response) {
        total += (row['kilometraza'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      return 0.0;
    }
  }
}
