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
    } catch (e) {
      // 🔇 Ignore
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

    if (timestamp != null) {
      _memoryCache.remove(key);
      _cacheTimestamp.remove(key);
    }

    _cacheMissCounter++;
    return null;
  }

  /// 💾 POSTAVI U MEMORY CACHE sa optional duration
  static void setMemory<T>(String key, T value, {Duration? duration}) {
    _memoryCache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
  }

  /// 💾 Sacuvaj u memory cache
  static void saveToMemory<T>(String key, T value) {
    _memoryCache[key] = value;
    _cacheTimestamp[key] = DateTime.now();
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
          await clearFromDisk(key);
          return null;
        }
      }

      final cachedData = _prefs!.getString(key);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData);
        return decoded as T;
      }
    } catch (e) {
      // 🔇 Ignore
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
    } catch (e) {
      // 🔇 Ignore
    }
  }

  /// 🗑️ Ukloni iz cache-a
  static Future<void> clearFromDisk(String key) async {
    if (_prefs == null) return;

    final timestampKey = '${key}_timestamp';
    await _prefs!.remove(key);
    await _prefs!.remove(timestampKey);
  }

  /// 🕐 Automatski cleanup - poziva se periodično
  static void performAutomaticCleanup() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp) > const Duration(minutes: 10)) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _cacheTimestamp.remove(key);
    }
  }

  /// 🧹 Očisti sav cache
  static Future<void> clearAll() async {
    _memoryCache.clear();
    _cacheTimestamp.clear();

    if (_prefs != null) {
      await _prefs!.clear();
    }
  }

  /// 📊 Cache statistike
  static Map<String, dynamic> getStats() {
    final now = DateTime.now();
    int expiredCount = 0;

    _cacheTimestamp.forEach((key, timestamp) {
      if (now.difference(timestamp) > const Duration(minutes: 10)) {
        expiredCount++;
      }
    });

    return {
      'memory_cache_size': _memoryCache.length,
      'expired_entries': expiredCount,
      'cache_hit_ratio': _cacheHitCounter > 0
          ? (_cacheHitCounter / (_cacheHitCounter + _cacheMissCounter)).toStringAsFixed(2)
          : '0.00',
      'oldest_memory_cache': _cacheTimestamp.values.isNotEmpty
          ? _cacheTimestamp.values.reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
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
}
