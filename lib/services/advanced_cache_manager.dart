import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'memory_management_service.dart';
import 'performance_optimizer_service.dart';

/// 🚀 ADVANCED CACHE MANAGER
/// Napredni sistem keširanje sa automatskim cleanup-om i optimizacijom
class AdvancedCacheManager {
  factory AdvancedCacheManager() => _instance;
  AdvancedCacheManager._internal();
  static final AdvancedCacheManager _instance = AdvancedCacheManager._internal();

  // 💾 MEMORY CACHE
  final Map<String, _CacheEntry> _memoryCache = {};
  final Queue<String> _accessOrder = Queue<String>();

  // 📊 CACHE STATISTICS
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  // ⚡ CONFIGURATION
  static const int _maxMemoryEntries = 500;
  static const Duration _defaultMaxAge = Duration(hours: 1);
  static const Duration _cleanupInterval = Duration(minutes: 10);

  Timer? _cleanupTimer;
  bool _initialized = false;

  /// Initialize cache manager
  Future<void> initialize() async {
    if (_initialized) return;

    _startPeriodicCleanup();
    _initialized = true;
  }

  /// 🔍 Get from cache (memory first, then disk)
  Future<T?> get<T>(
    String key, {
    Duration? maxAge,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Check memory cache first
      final memoryResult = _getFromMemory<T>(key, maxAge: maxAge);
      if (memoryResult != null) {
        _hitCount++;
        _updateAccessOrder(key);
        return memoryResult;
      }

      // 2. Check disk cache
      final diskResult = await _getFromDisk<T>(key, maxAge: maxAge, fromJson: fromJson);
      if (diskResult != null) {
        _hitCount++;
        // Store in memory for next time
        _setInMemory(key, diskResult, maxAge: maxAge);
        return diskResult;
      }

      _missCount++;
      return null;
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'cache_get_$key',
        stopwatch.elapsed,
      );
    }
  }

  /// 💾 Set in cache (both memory and disk)
  Future<void> set<T>(
    String key,
    T value, {
    Duration? maxAge,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Store in memory cache
      _setInMemory(key, value, maxAge: maxAge);

      // Store in disk cache
      await _setOnDisk(key, value, maxAge: maxAge, toJson: toJson);
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'cache_set_$key',
        stopwatch.elapsed,
      );
    }
  }

  /// 🔍 Get from memory cache only
  T? _getFromMemory<T>(String key, {Duration? maxAge}) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    final age = maxAge ?? _defaultMaxAge;
    if (DateTime.now().difference(entry.timestamp) > age) {
      _memoryCache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    return entry.value as T?;
  }

  /// 💾 Set in memory cache
  void _setInMemory<T>(String key, T value, {Duration? maxAge}) {
    // Remove if already exists to update access order
    if (_memoryCache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // Add new entry
    _memoryCache[key] = _CacheEntry(value, DateTime.now());
    _accessOrder.add(key);

    // Evict oldest entries if cache is full
    while (_memoryCache.length > _maxMemoryEntries) {
      final oldestKey = _accessOrder.removeFirst();
      _memoryCache.remove(oldestKey);
      _evictionCount++;
    }
  }

  /// 🔍 Get from disk cache
  Future<T?> _getFromDisk<T>(
    String key, {
    Duration? maxAge,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cache_$key');
      if (data == null) return null;

      final Map<String, dynamic> cached = Map<String, dynamic>.from(json.decode(data) as Map);
      final timestamp = DateTime.parse(cached['timestamp'] as String);
      final age = maxAge ?? _defaultMaxAge;

      if (DateTime.now().difference(timestamp) > age) {
        await prefs.remove('cache_$key');
        return null;
      }

      final value = cached['value'];

      // Handle different data types
      if (T == String) {
        return value as T;
      } else if (T == int) {
        return value as T;
      } else if (T == double) {
        return value as T;
      } else if (T == bool) {
        return value as T;
      } else if (T == List) {
        return (value as List).cast<dynamic>() as T;
      } else if (T == Map) {
        return (value as Map).cast<String, dynamic>() as T;
      } else if (fromJson != null && value is Map<String, dynamic>) {
        return fromJson(value);
      }

      return value as T?;
    } catch (e) {
      return null;
    }
  }

  /// 💾 Set on disk cache
  Future<void> _setOnDisk<T>(
    String key,
    T value, {
    Duration? maxAge,
    Map<String, dynamic> Function(T)? toJson,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      dynamic serializable = value;

      // Handle complex objects
      if (toJson != null) {
        serializable = toJson(value);
      } else if (value is! String &&
          value is! int &&
          value is! double &&
          value is! bool &&
          value is! List &&
          value is! Map) {
        // Skip serialization for unsupported types
        return;
      }

      final cacheData = {
        'value': serializable,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString('cache_$key', json.encode(cacheData));
    } catch (e) {
      // Fail silently - cache is not critical
    }
  }

  /// 🔄 Update access order for LRU
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// 🗑️ Remove from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _accessOrder.remove(key);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
    } catch (e) {
      // Fail silently
    }
  }

  /// 🧹 Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    _accessOrder.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Fail silently
    }
  }

  /// 🧹 Start periodic cleanup
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performCleanup();
    });

    // Register timer for memory management
    MemoryManagementService().registerTimer('cache_cleanup', _cleanupTimer!);
  }

  /// 🧹 Perform cleanup of expired entries
  void _performCleanup() {
    final stopwatch = Stopwatch()..start();
    int cleanedCount = 0;

    try {
      // Clean memory cache
      final now = DateTime.now();
      final keysToRemove = <String>[];

      for (final entry in _memoryCache.entries) {
        if (now.difference(entry.value.timestamp) > _defaultMaxAge) {
          keysToRemove.add(entry.key);
        }
      }

      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _accessOrder.remove(key);
        cleanedCount++;
      }

      // Clean disk cache asynchronously
      _cleanDiskCache();
    } finally {
      stopwatch.stop();
      PerformanceOptimizerService().trackOperation(
        'cache_cleanup_$cleanedCount',
        stopwatch.elapsed,
      );
    }
  }

  /// 🧹 Clean disk cache
  Future<void> _cleanDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      final now = DateTime.now();

      for (final key in keys) {
        try {
          final data = prefs.getString(key);
          if (data == null) continue;

          final Map<String, dynamic> cached = Map<String, dynamic>.from(json.decode(data) as Map);
          final timestamp = DateTime.parse(cached['timestamp'] as String);

          if (now.difference(timestamp) > _defaultMaxAge) {
            await prefs.remove(key);
          }
        } catch (e) {
          // Remove corrupted entries
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  /// 📊 Get cache statistics
  Map<String, dynamic> getStatistics() {
    final total = _hitCount + _missCount;
    final hitRate = total > 0 ? (_hitCount / total * 100).toStringAsFixed(2) : '0.00';

    return {
      'memory_entries': _memoryCache.length,
      'max_memory_entries': _maxMemoryEntries,
      'memory_usage_percent': (_memoryCache.length / _maxMemoryEntries * 100).toStringAsFixed(2),
      'hit_count': _hitCount,
      'miss_count': _missCount,
      'eviction_count': _evictionCount,
      'hit_rate_percent': hitRate,
      'cleanup_interval_minutes': _cleanupInterval.inMinutes,
      'default_max_age_hours': _defaultMaxAge.inHours,
    };
  }

  /// 🔍 Check if key exists in cache
  bool containsKey(String key) {
    return _memoryCache.containsKey(key);
  }

  /// 📏 Get cache size
  int get size => _memoryCache.length;

  /// 🚫 Dispose cache manager
  void dispose() {
    _cleanupTimer?.cancel();
    MemoryManagementService().unregisterTimer('cache_cleanup');

    _memoryCache.clear();
    _accessOrder.clear();
    _initialized = false;
  }
}

/// Cache entry model
class _CacheEntry {
  _CacheEntry(this.value, this.timestamp);
  final dynamic value;
  final DateTime timestamp;
}

/// 🚀 CACHE MIXIN FOR EASY USAGE
mixin CacheMixin {
  final AdvancedCacheManager _cache = AdvancedCacheManager();

  Future<T?> getCached<T>(
    String key, {
    Duration? maxAge,
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    return _cache.get<T>(key, maxAge: maxAge, fromJson: fromJson);
  }

  Future<void> setCached<T>(
    String key,
    T value, {
    Duration? maxAge,
    Map<String, dynamic> Function(T)? toJson,
  }) {
    return _cache.set<T>(key, value, maxAge: maxAge, toJson: toJson);
  }

  Future<void> removeCached(String key) {
    return _cache.remove(key);
  }
}
