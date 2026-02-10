import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🚐 Servis za učitavanje satnih redoslijeda iz baze
/// Dinamički učitava vremena polazaka iz `voznje_po_sezoni` tabele
class RouteService {
  static final RouteService _instance = RouteService._internal();
  static final SupabaseClient _supabase = Supabase.instance.client;

  RouteService._internal();

  factory RouteService() {
    return _instance;
  }

  /// 🚐 Dobija vremena polazaka za grad i sezonu (sa cachingom)
  static Future<List<String>> getVremenaPolazaka({
    required String grad,
    required String sezona,
  }) async {
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

      debugPrint('📡 [RouteService] Učitan redoslijed ($sezona/$grad): $vremena');
      return vremena;
    } catch (e) {
      debugPrint('❌ [RouteService] Greška pri učitavanju ($sezona/$grad): $e');
      // Fallback na prazne satne redoslijede
      return [];
    }
  }
}
