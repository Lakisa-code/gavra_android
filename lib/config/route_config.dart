/// 🎯 CENTRALIZOVANA KONFIGURACIJA ZA RUTIRANJE
/// Sve konstante vezane za gradove, koordinate, timeout-ove i retry parametre
///
/// Koristi se u: OsrmService, SmartNavigationService, GeocodingService,
/// OfflineMapService, AdresaSupabaseService

import 'package:latlong2/latlong.dart';

/// Glavna konfiguracija za rutiranje
class RouteConfig {
  RouteConfig._();

  // ═══════════════════════════════════════════════════════════════════════
  // 🏙️ DOZVOLJENI GRADOVI
  // ═══════════════════════════════════════════════════════════════════════

  /// Glavni gradovi za navigaciju (koriste se za filtriranje)
  static const List<String> glavniGradovi = ['Bela Crkva', 'Vršac'];

  /// Sva naselja u Vršac opštini (lowercase za poređenje)
  static const List<String> vrsacOpstinaNaselja = [
    'vrsac',
    'vršac',
    'straza',
    'straža',
    'vojvodinci',
    'potporanj',
    'oresac',
    'orešac',
    'pavlis',
    'pavliš',
    'veliko srediste',
    'veliko središte',
    'malo srediste',
    'malo središte',
    'zagajica',
    'zagajica',
    'mesic',
    'mesić',
    'jablanka',
    'gudurica',
    'ritisevo',
    'ritiševo',
    'uljma',
    'sočica',
    'socica',
    'markovac',
    'kuštilj',
    'kustilj',
  ];

  /// Sva naselja u Bela Crkva opštini (lowercase za poređenje)
  static const List<String> belaCrkvaOpstinaNaselja = [
    'bela crkva',
    'vracev gaj',
    'vraćev gaj',
    'dupljaja',
    'jasenovo',
    'kruscica',
    'kruščica',
    'kusic',
    'kusić',
    'crvena crkva',
    'kaludjerovo',
    'kaluđerovo',
    'banatska palanka',
    'dobricevo',
    'dobričevo',
    'grebenac',
    'kajtasovo',
    'kruscica',
    'kruščica',
  ];

  /// Sva dozvoljena naselja (kombinovano)
  static List<String> get svaDozvoljenaGradovi => [...vrsacOpstinaNaselja, ...belaCrkvaOpstinaNaselja];

  /// Proveri da li je grad/naselje dozvoljeno
  static bool isGradDozvoljen(String grad) {
    final normalized = _normalizeGrad(grad);
    return svaDozvoljenaGradovi.any(
      (allowed) => normalized.contains(allowed) || allowed.contains(normalized),
    );
  }

  /// Normalizuj naziv grada za poređenje
  static String _normalizeGrad(String grad) {
    return grad
        .toLowerCase()
        .trim()
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 📍 KOORDINATE CENTARA GRADOVA
  // ═══════════════════════════════════════════════════════════════════════

  /// Koordinate centra Bele Crkve
  static const double belaCrkvaLat = 44.9013448;
  static const double belaCrkvaLng = 21.4240519;
  static const LatLng belaCrkvaCenter = LatLng(belaCrkvaLat, belaCrkvaLng);

  /// Koordinate centra Vršca
  static const double vrsacLat = 45.1167;
  static const double vrsacLng = 21.3;
  static const LatLng vrsacCenter = LatLng(vrsacLat, vrsacLng);

  /// Mapa centara gradova
  static const Map<String, List<double>> centriGradova = {
    'Bela Crkva': [belaCrkvaLat, belaCrkvaLng],
    'Vršac': [vrsacLat, vrsacLng],
  };

  /// Dobij centar grada po imenu
  static LatLng? getCenterForGrad(String grad) {
    final normalized = grad.toLowerCase().trim();
    if (normalized.contains('bela') || normalized.contains('bc')) {
      return belaCrkvaCenter;
    }
    if (normalized.contains('vrsac') || normalized.contains('vršac') || normalized.contains('vs')) {
      return vrsacCenter;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🗺️ GRANICE REGIONA (za offline mapu)
  // ═══════════════════════════════════════════════════════════════════════

  /// Južna granica regiona
  static const double regionMinLat = 44.7;

  /// Severna granica regiona
  static const double regionMaxLat = 45.2;

  /// Zapadna granica regiona
  static const double regionMinLng = 20.8;

  /// Istočna granica regiona
  static const double regionMaxLng = 21.5;

  /// Proveri da li su koordinate unutar servisnog regiona
  static bool isWithinServiceRegion(double lat, double lng) {
    return lat >= regionMinLat && lat <= regionMaxLat && lng >= regionMinLng && lng <= regionMaxLng;
  }

  /// Proveri da li su koordinate validne za Srbiju (šira provera)
  static bool isValidSerbiaCoordinate(double lat, double lng) {
    return lat >= 42.0 && lat <= 46.5 && lng >= 18.0 && lng <= 23.0;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ⏱️ TIMEOUT I RETRY PARAMETRI
  // ═══════════════════════════════════════════════════════════════════════

  /// Timeout za OSRM API pozive
  static const Duration osrmTimeout = Duration(seconds: 10);

  /// Timeout za Nominatim geocoding
  static const Duration nominatimTimeout = Duration(seconds: 10);

  /// Timeout za Supabase operacije
  static const Duration supabaseTimeout = Duration(seconds: 10);

  /// Maksimalan broj retry pokušaja za OSRM
  static const int osrmMaxRetries = 1;

  /// Maksimalan broj retry pokušaja za Nominatim
  static const int nominatimMaxRetries = 3;

  /// Bazni delay za exponential backoff (ms)
  static const int baseRetryDelayMs = 500;

  /// Multiplier za exponential backoff
  static const double retryBackoffMultiplier = 2.0;

  /// Izračunaj delay za N-ti retry pokušaj
  static Duration getRetryDelay(int attemptNumber) {
    final delayMs = baseRetryDelayMs * (retryBackoffMultiplier * (attemptNumber - 1)).toInt().clamp(1, 8);
    return Duration(milliseconds: delayMs);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🔧 OPTIMIZACIJA PARAMETRI
  // ═══════════════════════════════════════════════════════════════════════

  /// Maksimalan broj waypointa za HERE WeGo navigaciju
  static const int hereWeGoMaxWaypoints = 10;

  /// Prag za brute force vs nearest neighbor (broj putnika)
  static const int bruteForceThreshold = 8;

  /// Maksimalan broj paralelnih geocoding zahteva
  /// ⚠️ ZA NOMINATIM FREE API MORA BITI 1
  static const int maxParallelGeocoding = 1;

  /// Batch size za Nominatim rate limiting
  static const int nominatimBatchSize = 1;

  /// Delay između Nominatim batch-eva
  /// ⚠️ ZA NOMINATIM FREE API MORA BITI MIN 1 SEKUNDA
  static const Duration nominatimBatchDelay = Duration(seconds: 1);

  // ═══════════════════════════════════════════════════════════════════════
  // 📊 CACHE PARAMETRI
  // ═══════════════════════════════════════════════════════════════════════

  /// Trajanje memory cache-a za geocoding
  static const Duration geocodingMemoryCacheDuration = Duration(hours: 6);

  /// Trajanje disk cache-a za geocoding
  static const Duration geocodingDiskCacheDuration = Duration(days: 7);

  /// Trajanje cache-a za adrese iz baze
  static const Duration adresaCacheDuration = Duration(minutes: 10);

  /// Trajanje cache-a za rutu
  static const Duration routeCacheDuration = Duration(seconds: 30);

  // ═══════════════════════════════════════════════════════════════════════
  // 🌐 API URLS
  // ═══════════════════════════════════════════════════════════════════════

  /// OSRM server URL (javni, besplatni)
  static const String osrmBaseUrl = 'https://router.project-osrm.org';

  /// Nominatim server URL
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org/search';

  /// OpenStreetMap tile URL
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ═══════════════════════════════════════════════════════════════════════
  // 🏥 KRITIČNE ADRESE (za preload)
  // ═══════════════════════════════════════════════════════════════════════

  /// Kritične adrese koje treba unapred učitati
  static const List<Map<String, dynamic>> kriticneAdrese = [
    {'grad': 'Vršac', 'adresa': 'Trg pobede 1', 'lat': 45.1167, 'lng': 21.3000},
    {
      'grad': 'Bela Crkva',
      'adresa': 'Trg oslobođenja 1',
      'lat': 44.8975,
      'lng': 21.4178,
    },
    {'grad': 'Straža', 'adresa': 'Centar', 'lat': 44.974348, 'lng': 21.299610},
    {
      'grad': 'Vršac',
      'adresa': 'Železnička stanica',
      'lat': 45.1150,
      'lng': 21.3100,
    },
    {
      'grad': 'Bela Crkva',
      'adresa': 'Autobuska stanica',
      'lat': 44.8980,
      'lng': 21.4180,
    },
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 🕐 VREMENA POLAZAKA (RED VOŽNJE)
  // ═══════════════════════════════════════════════════════════════════════

  /// Zimski red vožnje - Bela Crkva polasci
  static const List<String> bcVremenaZimski = [
    '05:00',
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  /// Zimski red vožnje - Vršac polasci
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
    '17:00',
    '19:00',
  ];

  /// Letnji red vožnje - Bela Crkva polasci
  static const List<String> bcVremenaLetnji = [
    '05:00',
    '06:00',
    '08:00',
    '10:00',
    '12:00',
    '13:00',
    '14:00',
    '15:30',
    '18:00',
  ];

  /// Letnji red vožnje - Vršac polasci
  static const List<String> vsVremenaLetnji = [
    '06:00',
    '07:00',
    '09:00',
    '11:00',
    '13:00',
    '14:00',
    '15:30',
    '16:15',
    '19:00',
  ];

  /// Praznici/Specijalni red vožnje - Bela Crkva polasci
  static const List<String> bcVremenaPraznici = [
    '5:00',
    '6:00',
    '12:00',
    '13:00',
    '15:00',
  ];

  /// Praznici/Specijalni red vožnje - Vršac polasci
  static const List<String> vsVremenaPraznici = [
    '6:00',
    '7:00',
    '13:00',
    '14:00',
    '15:30',
  ];

  /// Dobij vremena polazaka za grad i sezonu
  static List<String> getVremenaPolazaka({
    required String grad,
    required bool letnji,
  }) {
    final isBelaCrkva = grad.toLowerCase().contains('bela') || grad.toLowerCase() == 'bc';

    if (isBelaCrkva) {
      return letnji ? bcVremenaLetnji : bcVremenaZimski;
    } else {
      return letnji ? vsVremenaLetnji : vsVremenaZimski;
    }
  }

  /// Sva vremena za oba grada (za validaciju)
  static List<String> get svaVremena => {
        ...bcVremenaZimski,
        ...vsVremenaZimski,
        ...bcVremenaLetnji,
        ...vsVremenaLetnji,
      }.toList()
        ..sort();
}

/// 🚦 Rush hour konfiguracija za vreme penalizaciju
class RushHourConfig {
  RushHourConfig._();

  /// Jutarnji rush hour početak
  static const int morningRushStart = 7;

  /// Jutarnji rush hour kraj
  static const int morningRushEnd = 9;

  /// Popodnevni rush hour početak
  static const int eveningRushStart = 17;

  /// Popodnevni rush hour kraj
  static const int eveningRushEnd = 19;

  /// Noćni sati početak (manje saobraćaja)
  static const int nightStart = 22;

  /// Noćni sati kraj
  static const int nightEnd = 6;

  /// Penalizacija za rush hour (30% duže)
  static const double rushHourPenalty = 1.3;

  /// Bonus za noćnu vožnju (20% brže)
  static const double nightBonus = 0.8;

  /// Dobij time penalty za trenutni sat
  static double getTimePenalty(int hour) {
    // Rush hour penalty
    if ((hour >= morningRushStart && hour <= morningRushEnd) || (hour >= eveningRushStart && hour <= eveningRushEnd)) {
      return rushHourPenalty;
    }
    // Night bonus
    if (hour >= nightStart || hour <= nightEnd) {
      return nightBonus;
    }
    // Normal time
    return 1.0;
  }
}
