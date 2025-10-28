/// 🚀 PERFORMANCE CACHE SERVICE
/// Jednostavan cache servis za optimizaciju performansi

class PerformanceCacheService {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration defaultTtl = Duration(minutes: 5);

  /// Čuva vrednost u cache-u
  static void set(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now().add(ttl ?? defaultTtl);
  }

  /// Dobija vrednost iz cache-a
  static T? get<T>(String key) {
    if (!_cache.containsKey(key)) return null;

    final timestamp = _cacheTimestamps[key];
    if (timestamp == null || DateTime.now().isAfter(timestamp)) {
      // Cache je expired
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }

    return _cache[key] as T?;
  }

  /// Briše cache
  static void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Briše expired cache entries
  static void cleanExpired() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.isAfter(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Da li postoji u cache-u
  static bool contains(String key) {
    return get<dynamic>(key) != null;
  }

  // LEGACY METHODS - za kompatibilnost sa starim kodom
  static String generateRouteKey(dynamic params) {
    return params.toString().hashCode.toString();
  }

  static T? getCachedRoute<T>(String key) {
    return get<T>(key);
  }

  static void cacheRoute(String key, dynamic route) {
    set(key, route);
  }

  static T? getCachedCoordinates<T>(String key) {
    return get<T>(key);
  }

  static void cacheCoordinates(String key, dynamic coordinates) {
    set(key, coordinates);
  }

  static Future<void> loadFromPersistentStorage() async {
    // No-op za sada - možda dodati SharedPreferences kasnije
  }
}
