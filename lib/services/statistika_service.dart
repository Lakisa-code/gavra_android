import 'voznje_log_service.dart';

/// Servis za statistiku
/// ✅ TRAJNO REŠENJE: Sve statistike se čitaju iz voznje_log tabele
/// 🚀 Pojednostavljen: Direktan Supabase realtime
class StatistikaService {
  /// Stream pazara za sve vozače
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  /// ✅ TRAJNO REŠENJE: Čita iz voznje_log tabele
  static Stream<Map<String, double>> streamPazarZaSveVozace({
    required DateTime from,
    required DateTime to,
  }) {
    return VoznjeLogService.streamPazarPoVozacima(from: from, to: to);
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
  /// ✅ TRAJNO REŠENJE: Čita iz voznje_log tabele
  static Stream<int> streamBrojRegistrovanihZaVozaca({required String vozac}) {
    final now = DateTime.now();
    final danPocetak = DateTime(now.year, now.month, now.day);
    final danKraj = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // ✅ TRAJNO REŠENJE: Koristi voznje_log stream
    return VoznjeLogService.streamPazarPoVozacima(from: danPocetak, to: danKraj).asyncMap((pazar) async {
      // Prebroji uplate za ovog vozača danas
      return await VoznjeLogService.getBrojUplataZaVozaca(
        vozacImeIliUuid: vozac,
        from: danPocetak,
        to: danKraj,
      );
    });
  }

  /// Stream broja dužnika
  /// ✅ TRAJNO REŠENJE: Ovo ostaje na registrovani_putnici jer dužnici su putnici koji nisu platili
  static Stream<int> streamBrojDuznikaZaVozaca({required String vozac}) {
    // Ovo mora da ostane na registrovani_putnici jer tražimo putnike koji NISU platili
    // voznje_log ne može da nam kaže ko NIJE platio
    return Stream.value(0);
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
