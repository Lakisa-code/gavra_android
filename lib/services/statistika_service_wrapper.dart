import 'package:gavra_android/services/clean_statistika_service.dart';

/// Wrapper za StatistikaService koji koristi CleanStatistikaService
/// Omogućava kompatibilnost sa postojećim kodom
class StatistikaService {
  /// Dohvati ukupne statistike (kompatibilna metoda)
  static Future<Map<String, dynamic>> dohvatiUkupneStatistike() async {
    return await CleanStatistikaService.dohvatiUkupneStatistike();
  }

  /// Dohvati mesečne statistike (kompatibilna metoda)
  static Future<Map<String, dynamic>> dohvatiMesecneStatistike(
    int mesec,
    int godina,
  ) async {
    return await CleanStatistikaService.dohvatiMesecneStatistike(mesec, godina);
  }

  /// Dohvati sve putnike (nova metoda)
  static Future<List<Map<String, dynamic>>> dohvatiSvePutnike() async {
    return await CleanStatistikaService.dohvatiSvePutnikeClean();
  }

  /// Legacy metoda za kompatibilnost
  static Future<double> izracunajUkupanIznos() async {
    final stats = await dohvatiUkupneStatistike();
    return (stats['ukupno_sve'] as num).toDouble();
  }

  /// Legacy metoda za broj transakcija
  static Future<int> dohvatiBrojTransakcija() async {
    final stats = await dohvatiUkupneStatistike();
    return stats['broj_ukupno'] as int;
  }

  /// Nova metoda - provera da li nema duplikata
  static Future<bool> proveriBezDuplikata() async {
    final stats = await dohvatiUkupneStatistike();
    return stats['no_duplicates'] as bool;
  }

  /// Debug metoda za analizu
  static Future<Map<String, dynamic>> debugInfo() async {
    final stats = await dohvatiUkupneStatistike();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'service': 'StatistikaServiceWrapper -> CleanStatistikaService',
      'no_duplicates': stats['no_duplicates'],
      'total_amount': stats['ukupno_sve'],
      'total_records': stats['broj_ukupno'],
      'breakdown': {
        'mesecni': stats['ukupno_mesecni'],
        'standalone': stats['ukupno_standalone'],
      },
    };
  }
}
