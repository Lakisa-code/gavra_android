// NOVI StatistikaService koji koristi clean podatke
// Ovaj fajl zamenjuje stari StatistikaService

// Re-export za kompatibilnost
import 'package:gavra_android/services/statistika_service_wrapper.dart' as wrapper;

export 'statistika_service_wrapper.dart';

class StatistikaService {
  static Future<Map<String, dynamic>> dohvatiUkupneStatistike() => wrapper.StatistikaService.dohvatiUkupneStatistike();

  static Future<Map<String, dynamic>> dohvatiMesecneStatistike(
    int mesec,
    int godina,
  ) =>
      wrapper.StatistikaService.dohvatiMesecneStatistike(mesec, godina);

  static Future<List<Map<String, dynamic>>> dohvatiSvePutnike() => wrapper.StatistikaService.dohvatiSvePutnike();

  static Future<double> izracunajUkupanIznos() => wrapper.StatistikaService.izracunajUkupanIznos();

  static Future<int> dohvatiBrojTransakcija() => wrapper.StatistikaService.dohvatiBrojTransakcija();

  static Future<bool> proveriBezDuplikata() => wrapper.StatistikaService.proveriBezDuplikata();

  // Debug info removed
}



