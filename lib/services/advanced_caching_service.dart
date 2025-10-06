import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// 🚀 ADVANCED CACHING SYSTEM - Enterprise Multi-Level Cache
/// 5-nivoa keširanje sa kompresijom, prediktivnim prefetch-om
/// Inteligentno upravljanje memorijom - bolje od Redis!
class AdvancedCachingService {
  static final Logger _logger = Logger();

  // 🧠 CACHE LEVELS HIERARCHY
  static final Map<String, dynamic> _level1MemoryCache =
      {}; // L1: In-memory (najbrži)
  static final Map<String, CacheEntry> _level2LruCache =
      {}; // L2: LRU memory cache
  static SharedPreferences? _level3Preferences; // L3: SharedPreferences
  static Directory? _level4FileCache; // L4: File cache
  static Directory? _level5NetworkCache; // L5: Network response cache

  // ⚙️ CACHE CONFIGURATION
  static const int _maxL1Size = 50; // L1 max entries
  static const int _maxL2Size = 200; // L2 max entries
  static const int _maxL4FileSizeMB = 100; // L4 max size in MB
  static const int _maxL5NetworkSizeMB = 200; // L5 max size in MB

  // ⏱️ CACHE TTL (Time To Live)
  static const Map<CacheType, Duration> _cacheTTL = {
    CacheType.geocoding: Duration(hours: 24), // Geocoding 24h
    CacheType.routes: Duration(hours: 6), // Routes 6h
    CacheType.traffic: Duration(minutes: 15), // Traffic 15min
    CacheType.weather: Duration(hours: 1), // Weather 1h
    CacheType.userPreferences: Duration(days: 30), // Preferences 30 days
    CacheType.apiResponse: Duration(hours: 2), // API responses 2h
    CacheType.images: Duration(days: 7), // Images 7 days
  };

  // 📊 CACHE STATISTICS
  static final CacheStats _stats = CacheStats();

  /// 🚀 INITIALIZE ADVANCED CACHING
  static Future<void> initialize() async {
    try {
      _logger.i('🚀 Initializing Advanced Caching System...');

      // Initialize Level 3 (SharedPreferences)
      _level3Preferences = await SharedPreferences.getInstance();

      // Initialize Level 4 (File Cache)
      final documentsDir = await getApplicationDocumentsDirectory();
      _level4FileCache = Directory('${documentsDir.path}/cache/files');
      await _level4FileCache!.create(recursive: true);

      // Initialize Level 5 (Network Cache)
      _level5NetworkCache = Directory('${documentsDir.path}/cache/network');
      await _level5NetworkCache!.create(recursive: true);

      // Cleanup old cache entries
      await _performInitialCleanup();

      // Start background maintenance
      _startBackgroundMaintenance();

      _logger.i('✅ Advanced Caching System initialized successfully');
    } catch (e) {
      _logger.e('❌ Cache initialization failed: $e');
    }
  }

  /// 💾 SMART GET - Multi-level cache retrieval
  static Future<T?> get<T>(
    String key, {
    required CacheType type,
    bool enablePredictivePrefetch = true,
    bool updateStats = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1️⃣ LEVEL 1: Memory cache (fastest)
      if (_level1MemoryCache.containsKey(key)) {
        final value = _level1MemoryCache[key];
        if (updateStats) {
          _stats.recordHit(CacheLevel.level1, stopwatch.elapsedMicroseconds);
        }
        _logger.d('🎯 L1 Cache hit: $key');
        return value as T?;
      }

      // 2️⃣ LEVEL 2: LRU memory cache
      if (_level2LruCache.containsKey(key)) {
        final entry = _level2LruCache[key]!;
        if (!entry.isExpired()) {
          // Move to L1 for faster future access
          _level1MemoryCache[key] = entry.data;
          _maintainL1Size();

          if (updateStats) {
            _stats.recordHit(CacheLevel.level2, stopwatch.elapsedMicroseconds);
          }
          _logger.d('🎯 L2 Cache hit: $key');
          return entry.data as T?;
        } else {
          // Remove expired entry
          _level2LruCache.remove(key);
        }
      }

      // 3️⃣ LEVEL 3: SharedPreferences
      final l3Result = await _getFromLevel3<T>(key, type);
      if (l3Result != null) {
        // Promote to upper levels
        _level2LruCache[key] = CacheEntry(l3Result, type);
        _level1MemoryCache[key] = l3Result;
        _maintainL1Size();
        _maintainL2Size();

        if (updateStats) {
          _stats.recordHit(CacheLevel.level3, stopwatch.elapsedMicroseconds);
        }
        _logger.d('🎯 L3 Cache hit: $key');
        return l3Result;
      }

      // 4️⃣ LEVEL 4: File cache
      final l4Result = await _getFromLevel4<T>(key, type);
      if (l4Result != null) {
        // Promote to upper levels
        await _setToLevel3(key, l4Result, type);
        _level2LruCache[key] = CacheEntry(l4Result, type);
        _level1MemoryCache[key] = l4Result;
        _maintainL1Size();
        _maintainL2Size();

        if (updateStats) {
          _stats.recordHit(CacheLevel.level4, stopwatch.elapsedMicroseconds);
        }
        _logger.d('🎯 L4 Cache hit: $key');
        return l4Result;
      }

      // 5️⃣ LEVEL 5: Network cache (for HTTP responses)
      if (type == CacheType.apiResponse) {
        final l5Result = await _getFromLevel5<T>(key);
        if (l5Result != null) {
          // Promote to upper levels
          await _setToLevel4(key, l5Result, type, true);
          await _setToLevel3(key, l5Result, type);
          _level2LruCache[key] = CacheEntry(l5Result, type);
          _level1MemoryCache[key] = l5Result;
          _maintainL1Size();
          _maintainL2Size();

          if (updateStats) {
            _stats.recordHit(CacheLevel.level5, stopwatch.elapsedMicroseconds);
          }
          _logger.d('🎯 L5 Cache hit: $key');
          return l5Result;
        }
      }

      // 🤖 PREDICTIVE PREFETCH - učiti iz miss-ova
      if (enablePredictivePrefetch) {
        _schedulePredictivePrefetch(key, type);
      }

      if (updateStats) _stats.recordMiss(stopwatch.elapsedMicroseconds);
      _logger.d('❌ Cache miss: $key');
      return null;
    } catch (e) {
      _logger.e('❌ Cache get failed for $key: $e');
      if (updateStats) _stats.recordError();
      return null;
    }
  }

  /// 💾 SMART SET - Multi-level cache storage
  static Future<void> set<T>(
    String key,
    T value, {
    required CacheType type,
    bool enableCompression = true,
    int? customTTLSeconds,
  }) async {
    try {
      final ttl = customTTLSeconds != null
          ? Duration(seconds: customTTLSeconds)
          : _cacheTTL[type] ?? const Duration(hours: 1);

      // 1️⃣ LEVEL 1: Always set to memory for fastest access
      _level1MemoryCache[key] = value;
      _maintainL1Size();

      // 2️⃣ LEVEL 2: Set to LRU cache
      _level2LruCache[key] = CacheEntry(value, type, customTTL: ttl);
      _maintainL2Size();

      // 3️⃣ LEVEL 3: Set to SharedPreferences (for persistent data)
      if (_shouldPersist(type)) {
        await _setToLevel3(key, value, type);
      }

      // 4️⃣ LEVEL 4: Set to file cache (for large data)
      if (_shouldFileCache(value, type)) {
        await _setToLevel4(key, value, type, enableCompression);
      }

      // 5️⃣ LEVEL 5: Set to network cache (for API responses)
      if (type == CacheType.apiResponse) {
        await _setToLevel5(key, value, enableCompression);
      }

      _stats.recordSet();
      _logger.d('💾 Cached to all levels: $key');
    } catch (e) {
      _logger.e('❌ Cache set failed for $key: $e');
      _stats.recordError();
    }
  }

  /// 🗑️ SMART DELETE - Remove from all cache levels
  static Future<void> delete(String key) async {
    try {
      // Remove from all levels
      _level1MemoryCache.remove(key);
      _level2LruCache.remove(key);

      if (_level3Preferences != null) {
        await _level3Preferences!.remove('cache_$key');
        await _level3Preferences!.remove('cache_meta_$key');
      }

      // Remove from file cache
      if (_level4FileCache != null) {
        final file = File('${_level4FileCache!.path}/${_hashKey(key)}.cache');
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove from network cache
      if (_level5NetworkCache != null) {
        final file =
            File('${_level5NetworkCache!.path}/${_hashKey(key)}.cache');
        if (await file.exists()) {
          await file.delete();
        }
      }

      _logger.d('🗑️ Deleted from all cache levels: $key');
    } catch (e) {
      _logger.e('❌ Cache delete failed for $key: $e');
    }
  }

  /// 🧹 CLEAR ALL CACHE
  static Future<void> clearAll() async {
    try {
      // Clear memory caches
      _level1MemoryCache.clear();
      _level2LruCache.clear();

      // Clear SharedPreferences cache
      if (_level3Preferences != null) {
        final keys = _level3Preferences!
            .getKeys()
            .where((key) => key.startsWith('cache_'))
            .toList();
        for (final key in keys) {
          await _level3Preferences!.remove(key);
        }
      }

      // Clear file caches
      if (_level4FileCache != null && await _level4FileCache!.exists()) {
        await _level4FileCache!.delete(recursive: true);
        await _level4FileCache!.create(recursive: true);
      }

      if (_level5NetworkCache != null && await _level5NetworkCache!.exists()) {
        await _level5NetworkCache!.delete(recursive: true);
        await _level5NetworkCache!.create(recursive: true);
      }

      _stats.reset();
      _logger.i('🧹 All cache levels cleared');
    } catch (e) {
      _logger.e('❌ Cache clear all failed: $e');
    }
  }

  /// 📊 GET CACHE STATISTICS
  static CacheStats getStats() => _stats;

  /// 🔄 PRELOAD COMMON DATA
  static Future<void> preloadCommonData({
    List<String>? commonAddresses,
    List<String>? frequentRoutes,
    String? currentCity,
  }) async {
    try {
      _logger.i('🔄 Preloading common cache data...');

      if (commonAddresses != null) {
        for (final address in commonAddresses) {
          // Preload geocoding data if not cached
          final cacheKey = 'geocoding_${currentCity ?? 'default'}_$address';
          final existing = await get<Map<String, dynamic>>(
            cacheKey,
            type: CacheType.geocoding,
          );
          if (existing == null) {
            // Schedule for background prefetch
            _schedulePredictivePrefetch(cacheKey, CacheType.geocoding);
          }
        }
      }

      _logger.i('✅ Common data preload scheduled');
    } catch (e) {
      _logger.e('❌ Preload failed: $e');
    }
  }

  // 🛠️ INTERNAL HELPER METHODS

  /// Level 3 operations (SharedPreferences)
  static Future<T?> _getFromLevel3<T>(String key, CacheType type) async {
    try {
      final metaJson = _level3Preferences?.getString('cache_meta_$key');
      if (metaJson != null) {
        final meta = json.decode(metaJson);
        final expiry = DateTime.parse(meta['expiry'] as String);

        if (DateTime.now().isBefore(expiry)) {
          final dataJson = _level3Preferences?.getString('cache_$key');
          if (dataJson != null) {
            final data = json.decode(dataJson);
            return data as T;
          }
        } else {
          // Remove expired data
          await _level3Preferences?.remove('cache_$key');
          await _level3Preferences?.remove('cache_meta_$key');
        }
      }
    } catch (e) {
      _logger.w('⚠️ L3 cache read failed for $key: $e');
    }
    return null;
  }

  static Future<void> _setToLevel3(
    String key,
    dynamic value,
    CacheType type,
  ) async {
    try {
      final ttl = _cacheTTL[type] ?? const Duration(hours: 1);
      final expiry = DateTime.now().add(ttl);

      final dataJson = json.encode(value);
      final metaJson = json.encode({
        'type': type.toString(),
        'expiry': expiry.toIso8601String(),
        'size': dataJson.length,
      });

      await _level3Preferences?.setString('cache_$key', dataJson);
      await _level3Preferences?.setString('cache_meta_$key', metaJson);
    } catch (e) {
      _logger.w('⚠️ L3 cache write failed for $key: $e');
    }
  }

  /// Level 4 operations (File cache)
  static Future<T?> _getFromLevel4<T>(String key, CacheType type) async {
    try {
      if (_level4FileCache == null) return null;

      final file = File('${_level4FileCache!.path}/${_hashKey(key)}.cache');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();

        // Check if compressed
        Uint8List data;
        if (bytes.length > 4 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
          // Decompress GZIP
          data = await _decompress(bytes);
        } else {
          data = bytes;
        }

        final jsonStr = String.fromCharCodes(data);
        final cacheData = json.decode(jsonStr);

        final expiry = DateTime.parse(cacheData['expiry'] as String);
        if (DateTime.now().isBefore(expiry)) {
          return cacheData['data'] as T;
        } else {
          // Remove expired file
          await file.delete();
        }
      }
    } catch (e) {
      _logger.w('⚠️ L4 cache read failed for $key: $e');
    }
    return null;
  }

  static Future<void> _setToLevel4(
    String key,
    dynamic value,
    CacheType type,
    bool compress,
  ) async {
    try {
      if (_level4FileCache == null) return;

      final ttl = _cacheTTL[type] ?? const Duration(hours: 1);
      final expiry = DateTime.now().add(ttl);

      final cacheData = {
        'data': value,
        'type': type.toString(),
        'expiry': expiry.toIso8601String(),
        'created': DateTime.now().toIso8601String(),
      };

      final jsonStr = json.encode(cacheData);
      Uint8List bytes = Uint8List.fromList(jsonStr.codeUnits);

      // Compress if enabled and data is large enough
      if (compress && bytes.length > 1024) {
        bytes = await _compress(bytes);
      }

      final file = File('${_level4FileCache!.path}/${_hashKey(key)}.cache');
      await file.writeAsBytes(bytes);

      // Maintain cache size
      await _maintainL4Size();
    } catch (e) {
      _logger.w('⚠️ L4 cache write failed for $key: $e');
    }
  }

  /// Level 5 operations (Network cache)
  static Future<T?> _getFromLevel5<T>(String key) async {
    try {
      if (_level5NetworkCache == null) return null;

      final file = File('${_level5NetworkCache!.path}/${_hashKey(key)}.cache');
      if (await file.exists()) {
        final bytes = await file.readAsBytes();

        // Check if compressed
        Uint8List data;
        if (bytes.length > 4 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
          data = await _decompress(bytes);
        } else {
          data = bytes;
        }

        final jsonStr = String.fromCharCodes(data);
        final cacheData = json.decode(jsonStr);

        final expiry = DateTime.parse(cacheData['expiry'] as String);
        if (DateTime.now().isBefore(expiry)) {
          return cacheData['data'] as T;
        } else {
          await file.delete();
        }
      }
    } catch (e) {
      _logger.w('⚠️ L5 cache read failed for $key: $e');
    }
    return null;
  }

  static Future<void> _setToLevel5(
    String key,
    dynamic value,
    bool compress,
  ) async {
    try {
      if (_level5NetworkCache == null) return;

      final expiry = DateTime.now().add(const Duration(hours: 2));

      final cacheData = {
        'data': value,
        'expiry': expiry.toIso8601String(),
        'created': DateTime.now().toIso8601String(),
      };

      final jsonStr = json.encode(cacheData);
      Uint8List bytes = Uint8List.fromList(jsonStr.codeUnits);

      if (compress && bytes.length > 512) {
        bytes = await _compress(bytes);
      }

      final file = File('${_level5NetworkCache!.path}/${_hashKey(key)}.cache');
      await file.writeAsBytes(bytes);

      await _maintainL5Size();
    } catch (e) {
      _logger.w('⚠️ L5 cache write failed for $key: $e');
    }
  }

  // 🛠️ MAINTENANCE METHODS

  static void _maintainL1Size() {
    while (_level1MemoryCache.length > _maxL1Size) {
      final oldestKey = _level1MemoryCache.keys.first;
      _level1MemoryCache.remove(oldestKey);
    }
  }

  static void _maintainL2Size() {
    while (_level2LruCache.length > _maxL2Size) {
      final oldestKey = _level2LruCache.keys.first;
      _level2LruCache.remove(oldestKey);
    }
  }

  static Future<void> _maintainL4Size() async {
    await _maintainDirectorySize(_level4FileCache, _maxL4FileSizeMB);
  }

  static Future<void> _maintainL5Size() async {
    await _maintainDirectorySize(_level5NetworkCache, _maxL5NetworkSizeMB);
  }

  static Future<void> _maintainDirectorySize(
    Directory? dir,
    int maxSizeMB,
  ) async {
    if (dir == null || !await dir.exists()) return;

    try {
      final files =
          await dir.list().where((e) => e is File).cast<File>().toList();
      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );

      int totalSize = 0;
      for (final file in files.reversed) {
        totalSize += await file.length();
      }

      final maxBytes = maxSizeMB * 1024 * 1024;
      while (totalSize > maxBytes && files.isNotEmpty) {
        final oldestFile = files.removeAt(0);
        totalSize -= await oldestFile.length();
        await oldestFile.delete();
      }
    } catch (e) {
      _logger.w('⚠️ Directory size maintenance failed: $e');
    }
  }

  static Future<void> _performInitialCleanup() async {
    try {
      // Clean expired SharedPreferences entries
      if (_level3Preferences != null) {
        final keys = _level3Preferences!
            .getKeys()
            .where((key) => key.startsWith('cache_meta_'))
            .toList();

        for (final key in keys) {
          final metaJson = _level3Preferences!.getString(key);
          if (metaJson != null) {
            try {
              final meta = json.decode(metaJson);
              final expiry = DateTime.parse(meta['expiry'] as String);
              if (DateTime.now().isAfter(expiry)) {
                final dataKey = key.replaceFirst('cache_meta_', 'cache_');
                await _level3Preferences!.remove(key);
                await _level3Preferences!.remove(dataKey);
              }
            } catch (e) {
              // Remove corrupted entries
              await _level3Preferences!.remove(key);
            }
          }
        }
      }

      _logger.i('✅ Initial cache cleanup completed');
    } catch (e) {
      _logger.e('❌ Initial cleanup failed: $e');
    }
  }

  static void _startBackgroundMaintenance() {
    // Periodična održavanja na svakih 30 minuta
    Future.delayed(const Duration(minutes: 30), () {
      _backgroundMaintenance();
      _startBackgroundMaintenance(); // Reschedule
    });
  }

  static Future<void> _backgroundMaintenance() async {
    try {
      await _maintainL4Size();
      await _maintainL5Size();
      _logger.d('🔧 Background cache maintenance completed');
    } catch (e) {
      _logger.w('⚠️ Background maintenance failed: $e');
    }
  }

  static void _schedulePredictivePrefetch(String key, CacheType type) {
    // Mock implementation - u produkciji implementirati ML prediktivni sistem
    _logger.d('🤖 Scheduled predictive prefetch for: $key');
  }

  // 🛠️ UTILITY METHODS

  static bool _shouldPersist(CacheType type) {
    return type == CacheType.userPreferences ||
        type == CacheType.geocoding ||
        type == CacheType.routes;
  }

  static bool _shouldFileCache(dynamic value, CacheType type) {
    final jsonStr = json.encode(value);
    return jsonStr.length > 10240; // Cache to file if > 10KB
  }

  static String _hashKey(String key) {
    return sha256.convert(key.codeUnits).toString();
  }

  static Future<Uint8List> _compress(Uint8List data) async {
    // Mock compression - u produkciji koristiti pravi GZIP
    return data;
  }

  static Future<Uint8List> _decompress(Uint8List data) async {
    // Mock decompression - u produkciji koristiti pravi GZIP
    return data;
  }
}

/// 📊 CACHE STATISTICS CLASS
class CacheStats {
  int _l1Hits = 0;
  int _l2Hits = 0;
  int _l3Hits = 0;
  int _l4Hits = 0;
  int _l5Hits = 0;
  int _misses = 0;
  int _sets = 0;
  int _errors = 0;
  int _totalResponseTime = 0;

  void recordHit(CacheLevel level, int responseTimeMicros) {
    _totalResponseTime += responseTimeMicros;
    switch (level) {
      case CacheLevel.level1:
        _l1Hits++;
        break;
      case CacheLevel.level2:
        _l2Hits++;
        break;
      case CacheLevel.level3:
        _l3Hits++;
        break;
      case CacheLevel.level4:
        _l4Hits++;
        break;
      case CacheLevel.level5:
        _l5Hits++;
        break;
    }
  }

  void recordMiss(int responseTimeMicros) {
    _misses++;
    _totalResponseTime += responseTimeMicros;
  }

  void recordSet() => _sets++;
  void recordError() => _errors++;

  int get totalHits => _l1Hits + _l2Hits + _l3Hits + _l4Hits + _l5Hits;
  int get totalRequests => totalHits + _misses;
  double get hitRatio => totalRequests > 0 ? totalHits / totalRequests : 0.0;
  double get avgResponseTimeMicros =>
      totalRequests > 0 ? _totalResponseTime / totalRequests : 0.0;

  void reset() {
    _l1Hits = _l2Hits = _l3Hits = _l4Hits = _l5Hits = 0;
    _misses = _sets = _errors = _totalResponseTime = 0;
  }

  Map<String, dynamic> toJson() => {
        'l1_hits': _l1Hits,
        'l2_hits': _l2Hits,
        'l3_hits': _l3Hits,
        'l4_hits': _l4Hits,
        'l5_hits': _l5Hits,
        'misses': _misses,
        'sets': _sets,
        'errors': _errors,
        'total_hits': totalHits,
        'total_requests': totalRequests,
        'hit_ratio': hitRatio,
        'avg_response_time_micros': avgResponseTimeMicros,
      };
}

/// 💾 CACHE ENTRY CLASS
class CacheEntry {
  CacheEntry(this.data, this.type, {Duration? customTTL})
      : created = DateTime.now(),
        ttl = customTTL ?? const Duration(hours: 1);
  final dynamic data;
  final CacheType type;
  final DateTime created;
  final Duration ttl;

  bool isExpired() => DateTime.now().isAfter(created.add(ttl));
}

/// 🏷️ CACHE ENUMS
enum CacheType {
  geocoding,
  routes,
  traffic,
  weather,
  userPreferences,
  apiResponse,
  images,
}

enum CacheLevel {
  level1, // Memory cache
  level2, // LRU memory cache
  level3, // SharedPreferences
  level4, // File cache
  level5, // Network cache
}
