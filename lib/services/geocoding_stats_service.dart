import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'cache_service.dart';
import 'geocoding_service.dart';

class GeocodingStatsService {
  static final Logger _logger = Logger();
  static const String _statsPrefix = 'geocoding_stats_';
  static const String _apiCallsKey = 'geocoding_api_calls';
  static const String _cacheHitsKey = 'geocoding_cache_hits';
  static const String _lastResetKey = 'geocoding_last_reset';
  static const String _popularLocationsKey = 'geocoding_popular_locations';

  /// Povećava brojač API poziva
  static Future<void> incrementApiCalls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCalls = prefs.getInt(_apiCallsKey) ?? 0;
      await prefs.setInt(_apiCallsKey, currentCalls + 1);
      _logger.d('📊 API pozivi: ${currentCalls + 1}');
    } catch (e) {
      _logger.e('❌ Greška incrementing API calls: $e');
    }
  }

  /// Povećava brojač cache hit-ova
  static Future<void> incrementCacheHits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentHits = prefs.getInt(_cacheHitsKey) ?? 0;
      await prefs.setInt(_cacheHitsKey, currentHits + 1);
      _logger.d('📊 Cache hits: ${currentHits + 1}');
    } catch (e) {
      _logger.e('❌ Greška incrementing cache hits: $e');
    }
  }

  /// Dodaje lokaciju u popularne lokacije
  static Future<void> addPopularLocation(String location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList(_popularLocationsKey) ?? [];

      // Dodaj ili povećaj brojač za lokaciju
      final existingIndex =
          locations.indexWhere((loc) => loc.startsWith('$location:'));

      if (existingIndex != -1) {
        // Povećaj brojač
        final parts = locations[existingIndex].split(':');
        final count = int.tryParse(parts[1]) ?? 1;
        locations[existingIndex] = '$location:${count + 1}';
      } else {
        // Dodaj novu lokaciju
        locations.add('$location:1');
      }

      await prefs.setStringList(_popularLocationsKey, locations);
    } catch (e) {
      _logger.e('❌ Greška adding popular location: $e');
    }
  }

  /// Dobija statistike geocoding servisa
  static Future<Map<String, dynamic>> getGeocodingStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final apiCalls = prefs.getInt(_apiCallsKey) ?? 0;
      final cacheHits = prefs.getInt(_cacheHitsKey) ?? 0;
      final lastReset = prefs.getString(_lastResetKey);

      // Izračunaj cache hit rate
      final total = apiCalls + cacheHits;
      final cacheHitRate = total > 0 ? (cacheHits / total * 100) : 0.0;

      // Dobij cache info
      final cacheCount = await GeocodingService.getCacheCount();

      return {
        'api_calls': apiCalls,
        'cache_hits': cacheHits,
        'total_requests': total,
        'cache_hit_rate': cacheHitRate.toStringAsFixed(1),
        'cache_entries': cacheCount,
        'last_reset': lastReset ?? 'Nikad',
        'cache_size_estimate':
            '${(cacheCount * 0.5).toStringAsFixed(1)} KB', // Aproksimacija
      };
    } catch (e) {
      _logger.e('❌ Greška getting geocoding stats: $e');
      return {};
    }
  }

  /// Dobija popularne lokacije sa brojem pretrage
  static Future<List<Map<String, dynamic>>> getPopularLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locations = prefs.getStringList(_popularLocationsKey) ?? [];

      final popularList = <Map<String, dynamic>>[];

      for (final location in locations) {
        final parts = location.split(':');
        if (parts.length == 2) {
          popularList.add({
            'location': parts[0],
            'count': int.tryParse(parts[1]) ?? 1,
          });
        }
      }

      // Sortiraj po broju pretrage (opadajuće)
      popularList
          .sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return popularList.take(10).toList(); // Top 10
    } catch (e) {
      _logger.e('❌ Greška getting popular locations: $e');
      return [];
    }
  }

  /// Reset-uje sve geocoding statistike
  static Future<void> resetStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_apiCallsKey);
      await prefs.remove(_cacheHitsKey);
      await prefs.remove(_popularLocationsKey);
      await prefs.setString(_lastResetKey, DateTime.now().toIso8601String());

      _logger.i('🔄 Geocoding statistike resetovane');
    } catch (e) {
      _logger.e('❌ Greška resetting stats: $e');
    }
  }

  /// Briše geocoding cache
  static Future<void> clearGeocodingCache() async {
    try {
      await GeocodingService.clearCache();
      _logger.i('🧹 Geocoding cache obrisan');
    } catch (e) {
      _logger.e('❌ Greška clearing cache: $e');
    }
  }

  /// Dobija detaljne informacije o cache-u
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('geocoding_'));

      int totalEntries = 0;
      int coordinateEntries = 0;
      int statsEntries = 0;

      for (final key in keys) {
        totalEntries++;
        if (key.contains('geocoding_') &&
            !key.contains('stats') &&
            !key.contains('popular') &&
            !key.contains('reset')) {
          coordinateEntries++;
        } else {
          statsEntries++;
        }
      }

      return {
        'total_entries': totalEntries,
        'coordinate_entries': coordinateEntries,
        'stats_entries': statsEntries,
        'keys': keys.take(20).toList(), // Prikaži prvih 20 ključeva
      };
    } catch (e) {
      _logger.e('❌ Greška getting cache info: $e');
      return {};
    }
  }
}
