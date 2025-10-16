import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dnevni_putnik.dart';
import '../models/mesecni_putnik.dart';
import '../utils/logging.dart';
import 'database_optimizer.dart';
import 'query_performance_monitor.dart';

/// 🚀 OPTIMIZED PUTNIK SERVICE
/// Zamena za PutnikService sa optimizovanim query-jima
class OptimizedPutnikService {
  static final _supabase = Supabase.instance.client;

  /// 📊 Dobija sve putnike sa optimizovanim query-jem (rešava N+1 problem)
  static Future<List<Map<String, dynamic>>> getPutniciOptimized({
    String? datum,
    String? grad,
    String? vozac,
    bool includeMesecni = true,
  }) async {
    return await QueryPerformanceMonitor.trackQuery(
      'get_putnici_optimized',
      () async {
        return await DatabaseOptimizer.getOptimizedPutnici(
          datum: datum,
          grad: grad,
          includeMesecni: includeMesecni,
        );
      },
      metadata: {
        'datum': datum,
        'grad': grad,
        'vozac': vozac,
        'includeMesecni': includeMesecni,
      },
    );
  }

  /// 🔍 Optimizovana pretraga putnika
  static Future<Map<String, dynamic>> searchPutnici({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? tables,
  }) async {
    return await QueryPerformanceMonitor.trackQuery(
      'search_putnici_optimized',
      () async {
        return await DatabaseOptimizer.searchPutnici(
          query: query,
          limit: limit,
          offset: offset,
          tables: tables,
        );
      },
      metadata: {
        'query': query,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  /// ⚡ Bulk update putnika (mnogo brži od individual updates)
  static Future<bool> bulkUpdatePutnici({
    required List<String> ids,
    required Map<String, dynamic> updates,
    required String tabela,
  }) async {
    if (ids.isEmpty) return true;

    return await QueryPerformanceMonitor.trackQuery(
      'bulk_update_putnici',
      () async {
        return await DatabaseOptimizer.bulkUpdatePutnici(ids, updates, tabela);
      },
      metadata: {
        'count': ids.length,
        'tabela': tabela,
        'updates': updates.keys.toList(),
      },
    );
  }

  /// 📈 Optimizovane statistike
  static Future<Map<String, dynamic>> getStatistics({
    String? vozac,
    DateTime? odDatuma,
    DateTime? doDatuma,
  }) async {
    return await QueryPerformanceMonitor.trackQuery(
      'get_optimized_statistics',
      () async {
        return await DatabaseOptimizer.getOptimizedStatistics(
          vozac: vozac,
          odDatuma: odDatuma,
          doDatuma: doDatuma,
        );
      },
      metadata: {
        'vozac': vozac,
        'period_days': odDatuma != null && doDatuma != null ? doDatuma.difference(odDatuma).inDays : null,
      },
    );
  }

  /// 🎯 PERFORMANCE OPTIMIZED METHODS

  /// Dobija dnevne putnike sa cached rezultatima
  static Future<List<DnevniPutnik>> getDnevniPutniciZaDatum(DateTime datum) async {
    return await QueryPerformanceMonitor.trackQuery(
      'get_dnevni_putnici_za_datum',
      () async {
        final datumString = datum.toIso8601String().split('T')[0];

        // Koristi optimizovani query sa JOIN-om
        final results = await _supabase.from('dnevni_putnici').select('''
              *,
              adrese:adresa_id(id, naziv, grad),
              rute:ruta_id(id, naziv, cena)
            ''').eq('datum', datumString).eq('obrisan', false).order('polazak');

        return results.map((json) {
          // Flatter related data za lakše korišćenje
          if (json['adrese'] != null) {
            final adresa = json['adrese'] as Map<String, dynamic>;
            json['adresa_naziv'] = adresa['naziv'];
            json['grad'] = adresa['grad'];
          }

          if (json['rute'] != null) {
            final ruta = json['rute'] as Map<String, dynamic>;
            json['ruta_naziv'] = ruta['naziv'];
            json['cena'] = ruta['cena'];
          }

          return DnevniPutnik.fromMap(json);
        }).toList();
      },
      metadata: {'datum': datum.toIso8601String()},
    );
  }

  /// Dobija mesečne putnike sa cached rezultatima
  static Future<List<MesecniPutnik>> getMesecniPutniciAktivni() async {
    return await QueryPerformanceMonitor.trackQuery(
      'get_mesecni_putnici_aktivni',
      () async {
        // Koristi optimizovani query sa JOIN-om
        final results = await _supabase.from('mesecni_putnici').select('''
              *,
              adrese:adresa_id(id, naziv, grad),
              rute:ruta_id(id, naziv, cena)
            ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

        return results.map((json) {
          // Flatter related data
          if (json['adrese'] != null) {
            final adresa = json['adrese'] as Map<String, dynamic>;
            json['adresa_naziv'] = adresa['naziv'];
            json['grad'] = adresa['grad'];
          }

          if (json['rute'] != null) {
            final ruta = json['rute'] as Map<String, dynamic>;
            json['ruta_naziv'] = ruta['naziv'];
            json['cena'] = ruta['cena'];
          }

          return MesecniPutnik.fromMap(json);
        }).toList();
      },
    );
  }

  /// Batch operacije za putovanja_istorija
  static Future<bool> batchInsertPutovanjaIstorija(List<Map<String, dynamic>> putovanja) async {
    if (putovanja.isEmpty) return true;

    return await QueryPerformanceMonitor.trackQuery(
      'batch_insert_putovanja_istorija',
      () async {
        try {
          // Chunk the data into smaller batches (max 100 per batch)
          const batchSize = 100;
          for (int i = 0; i < putovanja.length; i += batchSize) {
            final chunk = putovanja.skip(i).take(batchSize).toList();
            await _supabase.from('putovanja_istorija').insert(chunk);
          }

          return true;
        } catch (e) {
          dlog('❌ [OPTIMIZED PUTNIK SERVICE] Batch insert failed: $e');
          return false;
        }
      },
      metadata: {'count': putovanja.length},
    );
  }

  /// Optimizovan update pojedinačnog putnika
  static Future<bool> updatePutnik({
    required String id,
    required Map<String, dynamic> updates,
    required String tabela,
  }) async {
    return await QueryPerformanceMonitor.trackQuery(
      'update_putnik_optimized',
      () async {
        try {
          // Add timestamp automatically
          updates['updated_at'] = DateTime.now().toIso8601String();

          await _supabase.from(tabela).update(updates).eq('id', id);

          // Clear relevant cache
          DatabaseOptimizer.clearCache(tabela);

          return true;
        } catch (e) {
          dlog('❌ [OPTIMIZED PUTNIK SERVICE] Update failed: $e');
          return false;
        }
      },
      metadata: {
        'tabela': tabela,
        'updates': updates.keys.toList(),
      },
    );
  }

  /// Optimizovan delete (soft delete)
  static Future<bool> softDeletePutnik(String id, String tabela) async {
    return await updatePutnik(
      id: id,
      updates: {'obrisan': true},
      tabela: tabela,
    );
  }

  /// 📊 Performance monitoring methods

  /// Dobija performance statistike
  static Map<String, QueryStats> getPerformanceStats() {
    return QueryPerformanceMonitor.getAllStats();
  }

  /// Generiše performance report
  static String generatePerformanceReport() {
    return QueryPerformanceMonitor.generatePerformanceReport();
  }

  /// Reset performance statistike
  static void resetPerformanceStats() {
    QueryPerformanceMonitor.resetStats();
  }

  /// Dobija spore query-jeve
  static List<QueryStats> getSlowQueries({int limit = 10}) {
    return QueryPerformanceMonitor.getTopSlowQueries(limit: limit);
  }

  /// 🧹 Cache management

  /// Očisti cache za specifičnu tabelu ili sve
  static void clearCache([String? pattern]) {
    DatabaseOptimizer.clearCache(pattern);
  }

  /// 🔧 Database maintenance

  /// Analiziraj query performance i daj preporuke
  static Future<List<String>> analyzePerformance() async {
    return await DatabaseOptimizer.analyzeQueryPerformance();
  }

  /// Optimizuj connection pool
  static Future<void> optimizeDatabase() async {
    await DatabaseOptimizer.optimizeConnectionPool();
  }
}
