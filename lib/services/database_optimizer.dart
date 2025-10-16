import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logging.dart';

/// 🚀 DATABASE QUERY OPTIMIZER
/// Optimizuje Supabase query-jeve za bolju performance
class DatabaseOptimizer {
  static final _supabase = Supabase.instance.client;
  static final Map<String, dynamic> _queryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// 🔄 OPTIMIZED PASSENGER QUERIES
  /// Rešava N+1 problem kombinovanjem query-jeva

  /// Dobija sve putnike sa related data u jednom query-ju
  static Future<List<Map<String, dynamic>>> getOptimizedPutnici({
    String? datum,
    String? grad,
    bool includeMesecni = true,
  }) async {
    final cacheKey = 'putnici_${datum ?? 'all'}_${grad ?? 'all'}_$includeMesecni';

    // Proveri cache prvo
    if (_isCacheValid(cacheKey)) {
      dlog('🎯 [DB OPTIMIZER] Cache hit za $cacheKey');
      final cached = _queryCache[cacheKey];
      if (cached is List) {
        return cached.cast<Map<String, dynamic>>();
      }
      return <Map<String, dynamic>>[];
    }

    try {
      final List<Map<String, dynamic>> allResults = [];

      // 1. DNEVNI PUTNICI sa JOIN-ovima za adrese i rute
      if (datum != null) {
        final dnevniQuery = _supabase.from('dnevni_putnici').select('''
              *,
              adrese:adresa_id(id, naziv, grad),
              rute:ruta_id(id, naziv, cena)
            ''').eq('datum', datum).eq('obrisan', false);

        final dnevniResults = await dnevniQuery;
        for (final result in dnevniResults) {
          result['tip_putnika'] = 'dnevni';
          allResults.add(result);
        }
      }

      // 2. MESEČNI PUTNICI sa JOIN-ovima (ako je potreban)
      if (includeMesecni) {
        final mesecniQuery = _supabase.from('mesecni_putnici').select('''
              *,
              adrese:adresa_id(id, naziv, grad),
              rute:ruta_id(id, naziv, cena)
            ''').eq('aktivan', true).eq('obrisan', false);

        final mesecniResults = await mesecniQuery;
        for (final result in mesecniResults) {
          result['tip_putnika'] = 'mesecni';
          allResults.add(result);
        }
      }

      // Cache rezultate
      _queryCache[cacheKey] = allResults;
      _cacheTimestamps[cacheKey] = DateTime.now();

      dlog('✅ [DB OPTIMIZER] Optimized putnici query: ${allResults.length} rezultata');
      return allResults;
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Greška u optimized putnici query: $e');
      return [];
    }
  }

  /// 🚀 BULK OPERATIONS - za batch update-ove
  static Future<bool> bulkUpdatePutnici(
    List<String> ids,
    Map<String, dynamic> updates,
    String tabela,
  ) async {
    if (ids.isEmpty) return true;

    try {
      // Korist RPC funkciju za bulk update
      await _supabase.rpc<void>(
        'bulk_update_putnici',
        params: {
          'putnik_ids': ids,
          'update_data': updates,
          'target_table': tabela,
        },
      );

      dlog('✅ [DB OPTIMIZER] Bulk update uspešan: ${ids.length} putnika');
      _clearCacheForTable(tabela);
      return true;
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Greška u bulk update: $e');

      // Fallback na individual updates
      return await _fallbackIndividualUpdates(ids, updates, tabela);
    }
  }

  /// 📊 OPTIMIZED STATISTICS QUERIES
  static Future<Map<String, dynamic>> getOptimizedStatistics({
    String? vozac,
    DateTime? odDatuma,
    DateTime? doDatuma,
  }) async {
    final cacheKey =
        'stats_${vozac ?? 'all'}_${odDatuma?.toIso8601String() ?? 'all'}_${doDatuma?.toIso8601String() ?? 'all'}';

    if (_isCacheValid(cacheKey)) {
      final cached = _queryCache[cacheKey];
      return cached is Map<String, dynamic> ? cached : <String, dynamic>{};
    }

    try {
      // Jedan query sa agregacija umesto više manjih
      final results = await _supabase.rpc<Map<String, dynamic>>(
        'get_optimized_stats',
        params: {
          'vozac_filter': vozac,
          'od_datum': odDatuma?.toIso8601String(),
          'do_datum': doDatuma?.toIso8601String(),
        },
      );

      _queryCache[cacheKey] = results;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return results;
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Greška u optimized statistics: $e');
      return {};
    }
  }

  /// 🔍 OPTIMIZED SEARCH sa paginacijom
  static Future<Map<String, dynamic>> searchPutnici({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? tables,
  }) async {
    try {
      final searchTables = tables ?? ['dnevni_putnici', 'mesecni_putnici'];
      final results = await _supabase.rpc<List<dynamic>>(
        'search_putnici_optimized',
        params: {
          'search_query': query,
          'search_tables': searchTables,
          'result_limit': limit,
          'result_offset': offset,
        },
      );

      return {
        'results': results,
        'hasMore': results.length == limit,
        'totalCount': await _getSearchCount(query, searchTables),
      };
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Greška u optimized search: $e');
      return {'results': <dynamic>[], 'hasMore': false, 'totalCount': 0};
    }
  }

  /// 🎯 INDEX OPTIMIZATION RECOMMENDATIONS
  static Future<List<String>> analyzeQueryPerformance() async {
    final recommendations = <String>[];

    try {
      // Analiziraj slow query log
      final slowQueries = await _supabase.rpc<List<dynamic>>('analyze_slow_queries');

      for (final query in slowQueries) {
        final table = query['table_name'] as String?;
        final duration = query['avg_duration'] as num?;

        if (duration != null && duration > 1000) {
          // > 1s
          recommendations.add('🐌 Spora query na tabeli $table: ${duration.toInt()}ms');

          // Predloži index
          if (table == 'dnevni_putnici') {
            recommendations.add(
              '💡 Predlog: CREATE INDEX idx_dnevni_putnici_datum ON dnevni_putnici(datum) WHERE obrisan = false;',
            );
          }
          if (table == 'mesecni_putnici') {
            recommendations
                .add('💡 Predlog: CREATE INDEX idx_mesecni_putnici_aktivan ON mesecni_putnici(aktivan, obrisan);');
          }
        }
      }
    } catch (e) {
      recommendations.add('❌ Greška u analizi performance: $e');
    }

    return recommendations;
  }

  /// 🧹 CACHE MANAGEMENT
  static void clearCache([String? pattern]) {
    if (pattern != null) {
      final keysToRemove = _queryCache.keys.where((key) => key.contains(pattern)).toList();
      for (final key in keysToRemove) {
        _queryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    } else {
      _queryCache.clear();
      _cacheTimestamps.clear();
    }
    dlog('🧹 [DB OPTIMIZER] Cache cleared: ${pattern ?? 'all'}');
  }

  /// 📈 CONNECTION POOL OPTIMIZATION
  static Future<void> optimizeConnectionPool() async {
    try {
      // Warm up connection pool - komentarisan jer metoda ne postoji
      // await SupabaseManager.warmUpConnections();

      // Set optimal connection limits
      await _supabase.rpc<void>(
        'optimize_connection_settings',
        params: {
          'max_connections': 20,
          'connection_timeout': 30,
          'idle_timeout': 300,
        },
      );

      dlog('✅ [DB OPTIMIZER] Connection pool optimized');
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Greška u connection pool optimization: $e');
    }
  }

  /// PRIVATE HELPER METHODS

  static bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    final isValid = DateTime.now().difference(timestamp) < _cacheExpiration;
    if (!isValid) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    return isValid;
  }

  static void _clearCacheForTable(String table) {
    final keysToRemove = _queryCache.keys.where((key) => key.contains(table)).toList();
    for (final key in keysToRemove) {
      _queryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  static Future<bool> _fallbackIndividualUpdates(
    List<String> ids,
    Map<String, dynamic> updates,
    String tabela,
  ) async {
    try {
      for (final id in ids) {
        await _supabase.from(tabela).update(updates).eq('id', id);
      }
      return true;
    } catch (e) {
      dlog('❌ [DB OPTIMIZER] Fallback individual updates failed: $e');
      return false;
    }
  }

  static Future<int> _getSearchCount(String query, List<String> tables) async {
    try {
      final result = await _supabase.rpc<int>(
        'count_search_results',
        params: {
          'search_query': query,
          'search_tables': tables,
        },
      );
      return result;
    } catch (e) {
      return 0;
    }
  }
}
