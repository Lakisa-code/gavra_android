import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚐 Servis za učitavanje satnih redoslijeda iz baze
/// Dinamički učitava vremena polazaka iz `voznje_po_sezoni` tabele
class RouteService {
  static final RouteService _instance = RouteService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Cachirana vremena
  static final Map<String, List<String>> _vremenaCache = {};
  static final Map<String, DateTime> _cachetime = {};
  static const Duration _cacheDuration = Duration(hours: 1);

  RouteService._internal();

  factory RouteService() {
    return _instance;
  }

  /// 🚐 Dobija vremena polazaka za grad i sezonu (sa cachingom)
  static Future<List<String>> getVremenaPolazaka({
    required String grad,
    required String sezona,
  }) async {
    final cacheKey = '${grad}_$sezona';

    // Provjeri cache
    if (_vremenaCache.containsKey(cacheKey)) {
      final lastTime = _cachetime[cacheKey] ?? DateTime.now();
      if (DateTime.now().difference(lastTime) < _cacheDuration) {
        debugPrint('✅ [RouteService] Cache hit: $cacheKey');
        return _vremenaCache[cacheKey]!;
      }
    }

    try {
      final response = await _supabase
          .from('voznje_po_sezoni')
          .select('vremena')
          .eq('sezona', sezona)
          .eq('grad', grad)
          .eq('aktivan', true)
          .limit(1)
          .single();

      final vremena = List<String>.from(response['vremena'] ?? []);

      // Cachira rezultat
      _vremenaCache[cacheKey] = vremena;
      _cachetime[cacheKey] = DateTime.now();

      debugPrint('📡 [RouteService] Učitan redoslijed ($sezona/$grad): $vremena');
      return vremena;
    } catch (e) {
      debugPrint('❌ [RouteService] Greška pri učitavanju ($sezona/$grad): $e');
      // Fallback na prazne satne redoslijede
      return [];
    }
  }

  /// 🔄 Osveži cache (poziva se na app startup)
  static Future<void> refreshCache() async {
    try {
      final response = await _supabase.from('voznje_po_sezoni').select('sezona, grad, vremena').eq('aktivan', true);

      for (final row in response) {
        final cacheKey = '${row['grad']}_${row['sezona']}';
        _vremenaCache[cacheKey] = List<String>.from(row['vremena'] ?? []);
        _cachetime[cacheKey] = DateTime.now();
      }

      debugPrint('✨ [RouteService] Cache osveži uspešan');
    } catch (e) {
      debugPrint('❌ [RouteService] Greška pri osvežavanju cache-a: $e');
    }
  }

  /// 🔔 Setup realtime listener za izmjene redoslijeda
  static Future<void> setupRealtimeListener() async {
    try {
      _supabase
          .channel('voznje_po_sezoni')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'voznje_po_sezoni',
            callback: (payload) {
              debugPrint('🔔 [RouteService] Izmjena redoslijeda u bazi!');
              // Očisti cache
              _vremenaCache.clear();
              _cachetime.clear();
            },
          )
          .subscribe();

      debugPrint('📡 [RouteService] Realtime listener aktiviran');
    } catch (e) {
      debugPrint('❌ [RouteService] Greška pri setupu realtime listenera: $e');
    }
  }

  /// 🗑️ Očisti cache
  static void clearCache() {
    _vremenaCache.clear();
    _cachetime.clear();
    debugPrint('🗑️ [RouteService] Cache očišćen');
  }

  /// 🔍 Dobija keširovana vremena (bez učitavanja iz baze)
  static List<String> getCachedVremena(String sezona, String grad) {
    final cacheKey = '${grad}_$sezona';
    return _vremenaCache[cacheKey] ?? [];
  }
}
