import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';
import 'geocoding_stats_service.dart';
import 'package:logger/logger.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';
  static const String _cachePrefix = 'geocoding_';
  static final Logger _logger = Logger();

  // Pronađi koordinate za adresu - SA CACHE OPTIMIZACIJOM
  static Future<String?> getKoordinateZaAdresu(
    String grad,
    String adresa,
  ) async {
    // 🚫 PROVERI DA LI JE GRAD DOZVOLJEN (samo Bela Crkva i Vršac)
    if (_isCityBlocked(grad)) {
      _logger
          .w('🚫 Geocoding blokiran za grad: $grad (samo BC/Vršac dozvoljeni)');
      return null;
    }

    final cacheKey = CacheKeys.geocoding('${grad}_$adresa');

    // 1. Prvo proveri memory cache (najbrži)
    final memoryCached = CacheService.getFromMemory<String>(
      cacheKey,
      maxAge: const Duration(hours: 6), // Koordinate se retko menjaju
    );
    if (memoryCached != null) {
      await GeocodingStatsService.incrementCacheHits();
      await GeocodingStatsService.addPopularLocation('${grad}_$adresa');
      _logger
          .d('✅ Koordinate iz memory cache: $grad, $adresa -> $memoryCached');
      return memoryCached;
    }

    // 2. Proveri disk cache
    final diskCached = await CacheService.getFromDisk<String>(
      cacheKey,
      maxAge: const Duration(days: 7), // Koordinate su stabilne
    );
    if (diskCached != null) {
      // Sacuvaj u memory za sledeći put
      CacheService.saveToMemory(cacheKey, diskCached);
      await GeocodingStatsService.incrementCacheHits();
      await GeocodingStatsService.addPopularLocation('${grad}_$adresa');
      _logger.d('✅ Koordinate iz disk cache: $grad, $adresa -> $diskCached');
      return diskCached;
    }

    // 3. Pozovi API samo ako nema cache
    try {
      await GeocodingStatsService.incrementApiCalls();
      final coords = await _fetchFromNominatim(grad, adresa);
      if (coords != null) {
        // Sacuvaj u oba cache-a
        CacheService.saveToMemory(cacheKey, coords);
        await CacheService.saveToDisk(cacheKey, coords);
        await GeocodingStatsService.addPopularLocation('${grad}_$adresa');
        _logger.i('✅ Koordinate sa API: $grad, $adresa -> $coords');
        return coords;
      }
    } catch (e) {
      _logger.e('❌ Greška geocoding: $e');
    }

    return null;
  }

  // Pozovi Nominatim API sa retry logikom
  static Future<String?> _fetchFromNominatim(String grad, String adresa) async {
    const int maxRetries = 3;
    const Duration timeout = Duration(seconds: 10);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final query = '$adresa, $grad, Serbia';
        final encodedQuery = Uri.encodeComponent(query);
        final url =
            '$_baseUrl?q=$encodedQuery&format=json&limit=1&countrycodes=rs';

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'GavraAndroidApp/1.0 (transport app)',
          },
        ).timeout(timeout);

        if (response.statusCode == 200) {
          final List<dynamic> results =
              json.decode(response.body) as List<dynamic>;

          if (results.isNotEmpty) {
            final result = results[0];
            final lat = result['lat'];
            final lon = result['lon'];
            final coords = '$lat,$lon';

            return coords;
          } else {}
        } else {}
      } catch (e) {
        if (attempt < maxRetries) {
          // Kratka pauza pre sledećeg pokušaja
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    return null;
  }

  // Obriši cache (za admin)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      _logger.e('❌ Greška brisanja cache: $e');
    }
  }

  /// 🧹 CACHE MANAGEMENT - OPTIMIZOVANO

  /// Očisti geocoding cache stariji od određenog vremena
  static Future<void> clearOldCache({
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cachePrefix));

      for (final key in keys) {
        // Jednostavno obriši sve stare geocoding cache - koordinate se retko menjaju
        await prefs.remove(key);
      }

      _logger.i('🧹 Cleared old geocoding cache');
    } catch (e) {
      _logger.e('❌ Error clearing geocoding cache: $e');
    }
  }

  /// Prebroji cache entries
  static Future<int> getCacheCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .where((key) => key.startsWith(_cachePrefix))
          .length;
    } catch (e) {
      return 0;
    }
  }

  /// 🚫 PROVERI DA LI JE GRAD VAN DOZVOLJENE RELACIJE
  static bool _isCityBlocked(String grad) {
    final normalizedGrad = grad.toLowerCase().trim();

    // ✅ DOZVOLJENI GRADOVI: SAMO Bela Crkva i Vršac opštine
    final allowedCities = [
      // VRŠAC OPŠTINA
      'vrsac', 'vršac', 'straza', 'straža', 'vojvodinci', 'potporanj', 'oresac',
      'orešac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kruščica', 'kusic', 'kusić', 'crvena crkva',
    ];
    return !allowedCities.any(
      (allowed) =>
          normalizedGrad.contains(allowed) || allowed.contains(normalizedGrad),
    );
  }
}
