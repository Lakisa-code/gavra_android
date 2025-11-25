// 🛡️ SUPABASE CONNECTION MANAGER
// ✅ КОРИСТИ СЕ У АПЛИКАЦИЈИ - НЕ БРИСАТИ!
//
// Овај сервис ограничава број истовремених конекција на Supabase
// и спречава преоптерећење cloud база података.
// Користи се у: simplified_kusur_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

/// SINGLETON MANAGER ZA SUPABASE KONEKCIJE
/// Kontroliše broj istovremenih konekcija i optimizuje performanse
class SupabaseManager {
  // Ograniči na 5 istovremenih konekcija

  SupabaseManager._internal();
  static SupabaseManager? _instance;
  static SupabaseClient? _client;

  // Connection tracking
  static int _activeConnections = 0;
  static const int _maxConnections = 5;

  /// Singleton pristup
  static SupabaseManager get instance {
    _instance ??= SupabaseManager._internal();
    return _instance!;
  }

  /// Dobij optimizovani Supabase klijent
  static SupabaseClient get client {
    _client ??= Supabase.instance.client;
    return _client!;
  }

  /// Izvrši operaciju sa kontrolom konekcija
  static Future<T> executeWithConnectionLimit<T>(
    Future<T> Function(SupabaseClient) operation,
  ) async {
    // Čekaj da se oslobodi konekcija ako je dostignut limit
    while (_activeConnections >= _maxConnections) {
      // Debug logging removed for production
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    _activeConnections++;
    // Debug logging removed for production
    try {
      final result = await operation(client);
      return result;
    } finally {
      _activeConnections--;
      // Debug logging removed for production
    }
  }

  /// Optimizovano čitanje sa timeout-om
  static Future<List<Map<String, dynamic>>> safeSelect(
    String table, {
    String? columns,
    Map<String, dynamic>? filters,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return executeWithConnectionLimit<List<Map<String, dynamic>>>(
        (client) async {
      var queryBuilder = client.from(table);
      var query = columns != null
          ? queryBuilder.select(columns)
          : queryBuilder.select();

      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value.toString());
        }
      }
      final response = await query.timeout(timeout);
      return List<Map<String, dynamic>>.from(response as List);
    });
  }

  /// Optimizovano ažuriranje sa timeout-om
  static Future<bool> safeUpdate(
    String table,
    Map<String, dynamic> data,
    Map<String, dynamic> filters, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return executeWithConnectionLimit<bool>((client) async {
      try {
        var query = client.from(table).update(data);

        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value.toString());
        }

        await query.timeout(timeout);
        return true;
      } catch (e) {
        // Debug logging removed for production
        return false;
      }
    });
  }

  /// Optimizovano ažuriranje koje vraća podatke
  static Future<List<Map<String, dynamic>>> safeUpdateWithReturn(
    String table,
    Map<String, dynamic> data,
    Map<String, dynamic> filters, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return executeWithConnectionLimit<List<Map<String, dynamic>>>(
        (client) async {
      try {
        var query = client.from(table).update(data);

        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value.toString());
        }

        final response = await query.select().timeout(timeout);
        return List<Map<String, dynamic>>.from(response as List);
      } catch (e) {
        // Debug logging removed for production
        return [];
      }
    });
  }

  /// Optimizovano umetanje sa timeout-om
  static Future<Map<String, dynamic>?> safeInsert(
    String table,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return executeWithConnectionLimit<Map<String, dynamic>?>((client) async {
      try {
        final response = await client
            .from(table)
            .insert(data)
            .select()
            .single()
            .timeout(timeout);
        return response;
      } catch (e) {
        // Debug logging removed for production
        return null;
      }
    });
  }

  /// Statistike konekcija
  static Map<String, dynamic> getConnectionStats() {
    return {
      'activeConnections': _activeConnections,
      'maxConnections': _maxConnections,
      'utilizationPercent':
          (_activeConnections / _maxConnections * 100).round(),
    };
  }

  /// Resetuj connection pool (za testiranje)
  static void resetConnectionPool() {
    _activeConnections = 0;
    // Debug logging removed for production
  }
}
