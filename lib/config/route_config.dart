/// 🚐 Route Configuration
///
/// Vremena polazaka za različite rute i sezone.
/// Koristi se u kapacitet servisu i navigacionim bar-ovima.

class RouteConfig {
  // 🏙️ BELA CRKVA - Zimski raspored (oktobar-mart)
  static const List<String> bcVremenaZimski = [
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  // 🏙️ BELA CRKVA - Letnji raspored (april-septembar)
  static const List<String> bcVremenaLetnji = [
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  // 🏙️ BELA CRKVA - Praznični raspored
  static const List<String> bcVremenaPraznici = [
    '05:00',
    '06:00',
    '12:00',
    '13:00',
    '15:00',
  ];

  // 🌆 VRŠAC - Zimski raspored (oktobar-mart)
  static const List<String> vsVremenaZimski = [
    '06:00',
    '07:00',
    '08:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  // 🌆 VRŠAC - Letnji raspored (april-septembar)
  static const List<String> vsVremenaLetnji = [
    '06:00',
    '07:00',
    '08:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  // 🌆 VRŠAC - Praznični raspored
  static const List<String> vsVremenaPraznici = [
    '06:00',
    '07:00',
    '13:00',
    '14:00',
    '15:30',
  ];

  // 🗺️ GEOGRAFSKE KOORDINATE
  static const double belaCrkvaLat = 44.8989;
  static const double belaCrkvaLng = 21.4181;
  static const double vrsacLat = 45.1167;
  static const double vrsacLng = 21.3036;

  // 🛣️ OSRM (OpenStreetMap Routing Machine) KONFIGURACIJA
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const int osrmMaxRetries = 3;
  static const Duration osrmTimeout = Duration(seconds: 30);

  // 🏠 GEOCODING KONFIGURACIJA
  static const Duration nominatimBatchDelay = Duration(milliseconds: 1000);
  static const Duration geocodingMemoryCacheDuration = Duration(hours: 1);
  static const Duration geocodingDiskCacheDuration = Duration(days: 7);

  /// 🚐 Dobija vremena polazaka za određeni grad i sezonu
  static List<String> getVremenaPolazaka({
    required String grad,
    required bool letnji,
  }) {
    final isBc = grad.toLowerCase().contains('bela') || grad.toLowerCase().contains('bc');
    final isVs = grad.toLowerCase().contains('vrs') || grad.toLowerCase().contains('vrš');

    if (isBc) {
      return letnji ? bcVremenaLetnji : bcVremenaZimski;
    } else if (isVs) {
      return letnji ? vsVremenaLetnji : vsVremenaZimski;
    } else {
      // Default na BC
      return letnji ? bcVremenaLetnji : bcVremenaZimski;
    }
  }

  /// ⏱️ Dobija delay za retry pokušaj (exponential backoff)
  static Duration getRetryDelay(int attempt) {
    // 1s, 2s, 4s, 8s...
    return Duration(seconds: 1 << (attempt - 1));
  }
}
