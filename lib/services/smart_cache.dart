// 💾 SMART CACHE SYSTEM
// Dual-layer cache with TTL strategy and automatic invalidation
// L1: Memory Cache (fast, volatile)
// L2: SharedPreferences (persistent)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartCache {
  // Singleton instance
  static SmartCache? _instance;
  static SmartCache get instance => _instance ??= SmartCache._();

  SmartCache._();

  // L1: Memory cache (fast, volatile)
  final Map<String, CachedValue> _memoryCache = {};

  // L2: SharedPreferences key prefix
  static const String _prefs = 'global_app_cache';

  // =====================================================
  // CACHE TTL CONFIGURATION
  // =====================================================

  /// Cache Time-To-Live durations by entity type
  /// - Vozaci: 1 hour (rarely changes)
  /// - Kusur: 5 minutes (changes frequently)
  /// - Pazar: 10 minutes (recalculated often)
  /// - Putnici: 2 minutes (real-time updates needed)
  /// - GPS: 30 seconds (high frequency updates)
  /// - Statistika: 1 hour (slow-changing aggregates)
  static const Duration ttlVozaci = Duration(hours: 1);
  static const Duration ttlKusur = Duration(minutes: 5);
  static const Duration ttlPazar = Duration(minutes: 10);
  static const Duration ttlPutnici = Duration(minutes: 2);
  static const Duration ttlGps = Duration(seconds: 30);
  static const Duration ttlStatistika = Duration(hours: 1);
  static const Duration ttlDefault = Duration(minutes: 15);

  // =====================================================
  // GET WITH FALLBACK
  // =====================================================

  /// Get value from cache with automatic fallback to fetch function
  ///
  /// Search order:
  /// 1. L1 (Memory) - instant if available and fresh
  /// 2. L2 (SharedPreferences) - fast if available and fresh
  /// 3. Fetch function - slow but always fresh
  ///
  /// [key] - Unique cache key
  /// [fetchFn] - Async function to fetch fresh data on cache miss
  /// [ttl] - Time-to-live duration for this cache entry
  /// [forceRefresh] - Skip cache and force fresh fetch
  Future<T?> get<T>({
    required String key,
    required Future<T> Function() fetchFn,
    required Duration ttl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      // Try L1 (Memory)
      if (_memoryCache.containsKey(key)) {
        final cached = _memoryCache[key] as CachedValue<T>?;
        if (cached != null && !cached.isExpired) {
          debugPrint('✅ Cache HIT (L1): $key');
          return cached.value;
        } else {
          debugPrint('⏰ Cache EXPIRED (L1): $key');
          _memoryCache.remove(key);
        }
      }

      // Try L2 (SharedPreferences)
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('${_prefs}_$key');

        if (cachedJson != null) {
          final data = jsonDecode(cachedJson) as Map<String, dynamic>;
          final cachedAt = DateTime.parse(data['cachedAt'] as String);

          if (DateTime.now().difference(cachedAt) < ttl) {
            final value = _deserialize<T>(data['value']);
            if (value != null) {
              // Restore to L1
              _memoryCache[key] = CachedValue(value, ttl);
              debugPrint('✅ Cache HIT (L2): $key');
              return value;
            }
          } else {
            debugPrint('⏰ Cache EXPIRED (L2): $key');
          }
        }
      } catch (e) {
        debugPrint('❌ Cache L2 deserialization error for $key: $e');
      }
    }

    // Cache MISS - fetch fresh data
    debugPrint('❌ Cache MISS: $key - Fetching fresh data...');
    final freshValue = await fetchFn();
    await set(key, freshValue, ttl);
    return freshValue;
  }

  // =====================================================
  // SET (Both Layers)
  // =====================================================

  /// Set cache value at both L1 and L2 layers
  Future<void> set<T>(String key, T value, Duration ttl) async {
    try {
      // L1: Memory
      _memoryCache[key] = CachedValue(value, ttl);

      // L2: SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'value': _serialize(value),
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('${_prefs}_$key', jsonEncode(cacheData));

      debugPrint('💾 Cache SET: $key (TTL: ${ttl.inMinutes}m)');
    } catch (e) {
      debugPrint('❌ Cache SET error for $key: $e');
    }
  }

  // =====================================================
  // INVALIDATE
  // =====================================================

  /// Invalidate (remove) cache entry from both layers
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_prefs}_$key');

    debugPrint('🗑️ Cache INVALIDATED: $key');
  }

  /// Invalidate multiple keys matching a pattern
  Future<void> invalidatePattern(String pattern) async {
    // L1: Remove matching keys
    final keysToRemove = _memoryCache.keys.where((k) => k.contains(pattern)).toList();

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // L2: Remove matching keys
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final matchingKeys = allKeys.where((k) => k.startsWith(_prefs) && k.contains(pattern));

    for (final key in matchingKeys) {
      await prefs.remove(key);
    }

    debugPrint('🗑️ Cache INVALIDATED (pattern): $pattern (${keysToRemove.length} keys)');
  }

  // =====================================================
  // CLEAR ALL
  // =====================================================

  /// Clear entire cache (both layers)
  Future<void> clearAll() async {
    _memoryCache.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefs));

    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint('🗑️ Cache CLEARED: All entries removed');
  }

  // =====================================================
  // CACHE STATISTICS
  // =====================================================

  /// Get cache statistics for monitoring
  Future<CacheStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final l2Keys = prefs.getKeys().where((k) => k.startsWith(_prefs)).length;

    return CacheStats(
      l1Entries: _memoryCache.length,
      l2Entries: l2Keys,
      l1ExpiredEntries: _memoryCache.values.where((v) => v.isExpired).length,
    );
  }

  // =====================================================
  // HELPER: Vozac-specific cache keys
  // =====================================================

  String keyVozac(String vozacIme) => 'vozac_$vozacIme';
  String keyKusur(String vozacIme) => 'kusur_$vozacIme';
  String keyPazar(String vozacIme, DateTime datum) => 'pazar_${vozacIme}_${_formatDate(datum)}';
  String keyStatistika(String vozacIme, DateTime mesec) => 'statistika_${vozacIme}_${_formatDate(mesec)}';
  String keyGps(String vozacId) => 'gps_$vozacId';
  String keyPutnici(DateTime datum) => 'putnici_${_formatDate(datum)}';

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // =====================================================
  // SERIALIZATION HELPERS
  // =====================================================

  dynamic _serialize<T>(T value) {
    if (value is Map || value is List || value is String || value is num || value is bool) {
      return value;
    }

    // For custom objects with toJson()
    try {
      if ((value as dynamic).toJson != null) {
        return (value as dynamic).toJson();
      }
    } catch (_) {}

    return value.toString();
  }

  T? _deserialize<T>(dynamic value) {
    if (value == null) return null;

    // Direct primitive types
    if (T == String || T == int || T == double || T == bool) {
      return value as T?;
    }

    // Maps and Lists - check runtime type, not generic type equality
    if (value is Map) {
      return value as T?;
    }

    if (value is List) {
      return value as T?;
    }

    return value as T?;
  }
}

// =====================================================
// CACHED VALUE WRAPPER
// =====================================================

class CachedValue<T> {
  final T value;
  final DateTime cachedAt;
  final Duration ttl;

  CachedValue(this.value, this.ttl) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;

  Duration get timeUntilExpiry => ttl - DateTime.now().difference(cachedAt);
}

// =====================================================
// CACHE STATISTICS
// =====================================================

class CacheStats {
  final int l1Entries;
  final int l2Entries;
  final int l1ExpiredEntries;

  CacheStats({
    required this.l1Entries,
    required this.l2Entries,
    required this.l1ExpiredEntries,
  });

  int get totalEntries => l1Entries + l2Entries;
  int get l1ActiveEntries => l1Entries - l1ExpiredEntries;
  double get l1HitRate => l1Entries > 0 ? l1ActiveEntries / l1Entries : 0.0;

  @override
  String toString() => '''
Cache Statistics:
  L1 (Memory): $l1Entries entries ($l1ActiveEntries active, $l1ExpiredEntries expired)
  L2 (Persistent): $l2Entries entries
  Total: $totalEntries entries
  L1 Hit Rate: ${(l1HitRate * 100).toStringAsFixed(1)}%
  ''';
}
