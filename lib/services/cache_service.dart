import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 🚀 CACHE SERVICE - Centralizovano cache-ovanje za performanse
class CacheService {
  static SharedPreferences? _prefs;
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};

  // 📊 Cache statistike
  static int _cacheHitCounter = 0;
  static int _cacheMissCounter = 0;

  /// Inicijalizuj cache servis
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 📝 MEMORY CACHE - Za brz pristup u runtime-u
  static T? getFromMemory<T>(
    String key, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    final timestamp = _cacheTimestamp[key];
    if (timestamp != null && DateTime.now().difference(timestamp) < maxAge) {
      _cacheHitCounter++;
      return _memoryCache[key] as T?;
    }

    // Ukloni expired cache
    if (timestamp != null) {
      _memoryCache.remove(key);
      _cacheTimestamp.remove(key);
    }

    _cacheMissCounter++;
    return null;
  }

  /// 🔍 PROVERI DA LI POSTOJI U CACHE
  static bool hasInMemory(String key) {
    final timestamp = _cacheTimestamp[key];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) < const Duration(minutes: 10)) {
      return _memoryCache.containsKey(key);
    }
    return false;
  }

  /// 💾 POSTAVI U MEMORY CACHE sa optional duration
  static void setMemory<T>(String key, T value, {Duration? duration}) {
    _memoryCache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
    // Logger removed
  }

  /// 💾 Sacuvaj u memory cache
  static void saveToMemory<T>(String key, T value) {
    _memoryCache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
    // Logger removed
  }

  /// 🗂️ PERSISTENT CACHE - Za dugoročno čuvanje
  static Future<T?> getFromDisk<T>(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    if (_prefs == null) return null;

    try {
      final timestampKey = '${key}_timestamp';
      final timestamp = _prefs!.getInt(timestampKey);

      if (timestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cacheTime) > maxAge) {
          // Expired - ukloni
          await clearFromDisk(key);
          return null;
        }
      }

      final cachedData = _prefs!.getString(key);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData);
        // Logger removed
        return decoded as T;
      }
    } catch (e) {
      // Logger removed
    }

    return null;
  }

  /// 💾 Sacuvaj na disk
  static Future<void> saveToDisk<T>(String key, T value) async {
    if (_prefs == null) return;

    try {
      final timestampKey = '${key}_timestamp';
      final encoded = jsonEncode(value);

      await _prefs!.setString(key, encoded);
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      // Logger removed
    } catch (e) {
      // Logger removed
    }
  }

  /// 🗑️ Ukloni iz cache-a
  static Future<void> clearFromDisk(String key) async {
    if (_prefs == null) return;

    final timestampKey = '${key}_timestamp';
    await _prefs!.remove(key);
    await _prefs!.remove(timestampKey);
  }

  /// 🧹 Očisti specifičan key iz memory cache
  static void clearFromMemory(String key) {
    _memoryCache.remove(key);
    _cacheTimestamp.remove(key);
  }

  /// 🕐 Automatski cleanup - poziva se periodično
  static void performAutomaticCleanup() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    // Pronađi expired entries
    _cacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp) > const Duration(minutes: 10)) {
        expiredKeys.add(key);
      }
    });

    // Ukloni expired entries
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamp.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      // Logger removed - cleanup completed
    }
  }

  /// 🧹 Očisti sav cache
  static Future<void> clearAll() async {
    _memoryCache.clear();
    _cacheTimestamp.clear();

    if (_prefs != null) {
      await _prefs!.clear();
    }

    // Logger removed
  }

  /// 📊 Cache statistike
  static Map<String, dynamic> getStats() {
    final now = DateTime.now();
    int expiredCount = 0;

    // Broji expired entries
    _cacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp) > const Duration(minutes: 10)) {
        expiredCount++;
      }
    });

    return {
      'memory_cache_size': _memoryCache.length,
      'expired_entries': expiredCount,
      'cache_hit_ratio': _cacheHitCounter > 0
          ? (_cacheHitCounter / (_cacheHitCounter + _cacheMissCounter))
              .toStringAsFixed(2)
          : '0.00',
      'oldest_memory_cache': _cacheTimestamp.values.isNotEmpty
          ? _cacheTimestamp.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : 'N/A',
      'disk_cache_available': _prefs != null,
    };
  }

  /// 🔄 Dispose - oslobađa resurse
  static void dispose() {
    _memoryCache.clear();
    _cacheTimestamp.clear();
    _cacheHitCounter = 0;
    _cacheMissCounter = 0;
  }
}

/// 🏷️ CACHE KEYS - Centralizovane konstante
class CacheKeys {
  // Geocoding cache
  static String geocoding(String address) => 'geocoding_$address';

  // Putnici cache
  static const String putnici = 'putnici_list';
  static String putniksByDay(String day) => 'putnici_$day';

  // Statistike cache
  static String statistikeVozac(String vozac, String period) =>
      'stats_${vozac}_$period';
  static String ukupneStatistike(String period) => 'total_stats_$period';

  // Adrese cache
  static String adrese(String grad) => 'adrese_$grad';

  // GPS cache
  static String gpsLokacije(String vozac) => 'gps_$vozac';

  // Mesečne karte cache
  static String mesecneKarte(String mesec) => 'mesecne_karte_$mesec';
}
