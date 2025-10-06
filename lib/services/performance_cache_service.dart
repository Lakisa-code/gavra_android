import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/putnik.dart';

/// 🚀 PERFORMANCE CACHE SERVIS za GPS optimizaciju
/// Implementira multi-level cache za brže optimizacije
class PerformanceCacheService {
  // Memory cache za trenutnu sesiju
  static final Map<String, List<Putnik>> _memoryRouteCache = {};
  static final Map<String, DateTime> _memoryCacheTimestamps = {};
  static final Map<String, Position> _memoryCoordinateCache = {};

  // Cache constants
  static const int _maxMemoryCacheSize = 50;
  static const int _routeCacheValidityMinutes = 30;
  static const int _coordinateCacheValidityHours = 24;

  /// 🏎️ Dobij optimizovanu rutu iz cache-a
  static List<Putnik>? getCachedRoute(String cacheKey) {
    // Proveri memory cache prvo
    final cachedRoute = _memoryRouteCache[cacheKey];
    final timestamp = _memoryCacheTimestamps[cacheKey];

    if (cachedRoute != null && timestamp != null) {
      final isValid = DateTime.now().difference(timestamp).inMinutes <
          _routeCacheValidityMinutes;
      if (isValid) {
        return List.from(cachedRoute);
      } else {
        // Obriši stari cache
        _memoryRouteCache.remove(cacheKey);
        _memoryCacheTimestamps.remove(cacheKey);
      }
    }

    return null;
  }

  /// 💾 Sačuvaj optimizovanu rutu u cache
  static void cacheRoute(String cacheKey, List<Putnik> route) {
    // Cleanup if cache je prevelik
    if (_memoryRouteCache.length >= _maxMemoryCacheSize) {
      _cleanupOldestCacheEntries();
    }

    _memoryRouteCache[cacheKey] = List.from(route);
    _memoryCacheTimestamps[cacheKey] = DateTime.now();
  }

  /// 📍 Dobij koordinate iz cache-a
  static Position? getCachedCoordinates(String address) {
    final cached = _memoryCoordinateCache[address];
    if (cached != null) {
      return cached;
    }
    return null;
  }

  /// 📍 Sačuvaj koordinate u cache
  static void cacheCoordinates(String address, Position position) {
    _memoryCoordinateCache[address] = position;

    // Persistent storage za koordinate
    _saveToPersistentStorage(address, position);
  }

  /// 🧹 Očisti stare cache unose
  static void _cleanupOldestCacheEntries() {
    if (_memoryCacheTimestamps.isEmpty) return;

    // Pronađi najstariji unos
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _memoryCacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _memoryRouteCache.remove(oldestKey);
      _memoryCacheTimestamps.remove(oldestKey);
    }
  }

  /// 💾 Sačuvaj koordinate trajno (SharedPreferences)
  static Future<void> _saveToPersistentStorage(
      String address, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coordData = {
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('coord_$address', jsonEncode(coordData));
    } catch (e) {
      // Greška u čuvanju koordinata u trajno skladište
    }
  }

  /// 📖 Učitaj koordinate iz trajnog skladišta
  static Future<Position?> loadFromPersistentStorage(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final coordJson = prefs.getString('coord_$address');

      if (coordJson != null) {
        final coordData = jsonDecode(coordJson);
        final timestamp =
            DateTime.fromMillisecondsSinceEpoch(coordData['timestamp'] as int);

        // Proveri da li je cache još uvek valjan (24 sata)
        if (DateTime.now().difference(timestamp).inHours <
            _coordinateCacheValidityHours) {
          final position = Position(
            latitude: (coordData['lat'] as num).toDouble(),
            longitude: (coordData['lng'] as num).toDouble(),
            timestamp: timestamp,
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

          // Dodaj u memory cache takođe
          _memoryCoordinateCache[address] = position;
          return position;
        } else {
          // Obriši stari cache
          await prefs.remove('coord_$address');
        }
      }
    } catch (e) {
      // Greška u učitavanju iz trajnog skladišta
    }

    return null;
  }

  /// 🧮 Generiši cache key za rutu
  static String generateRouteKey(List<Putnik> putnici,
      {Position? driverPosition}) {
    // Sortiraj putničke ID-jeve za konzistentan key
    final sortedIds = putnici.map((p) => p.id.toString()).toList()..sort();
    final putniciKey = sortedIds.join(',');

    // Dodaj driver poziciju ako je dostupna
    String positionKey = 'no_pos';
    if (driverPosition != null) {
      positionKey =
          '${driverPosition.latitude.toStringAsFixed(3)}_${driverPosition.longitude.toStringAsFixed(3)}';
    }

    return 'route_${putniciKey}_$positionKey';
  }

  /// 📊 Cache statistike
  static Map<String, dynamic> getCacheStats() {
    final memoryRoutes = _memoryRouteCache.length;
    final memoryCoords = _memoryCoordinateCache.length;

    // Izračunaj hit rate (simplified)
    final totalRequests = memoryRoutes + memoryCoords;
    final hitRate =
        totalRequests > 0 ? (memoryRoutes / totalRequests * 100) : 0.0;

    return {
      'memoryRoutes': memoryRoutes,
      'memoryCoordinates': memoryCoords,
      'hitRate': hitRate.toStringAsFixed(1),
      'maxCacheSize': _maxMemoryCacheSize,
    };
  }

  /// 🧹 Očisti sav cache
  static Future<void> clearAllCache() async {
    _memoryRouteCache.clear();
    _memoryCacheTimestamps.clear();
    _memoryCoordinateCache.clear();

    // Očisti i persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('coord_')).toList();

      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Greška u brisanju trajnog cache-a
    }
  }

  /// 🔧 Preload popularne adrese u cache
  static Future<void> preloadPopularAddresses(List<String> addresses) async {
    for (final address in addresses) {
      final cached = await loadFromPersistentStorage(address);
      if (cached != null) {
        // Successfully preloaded from persistent storage
      }
    }
  }

  /// 🎯 Smart cache warmup na osnovu istorije
  static Future<void> warmupCacheFromHistory(List<Putnik> recentPutnici) async {
    final uniqueAddresses = recentPutnici
        .where((p) => p.adresa != null && p.adresa!.isNotEmpty)
        .map((p) => p.adresa!)
        .toSet()
        .toList();

    await preloadPopularAddresses(uniqueAddresses);
  }
}
