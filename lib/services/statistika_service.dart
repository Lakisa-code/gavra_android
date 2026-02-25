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
}
