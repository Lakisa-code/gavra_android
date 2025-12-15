import 'package:supabase_flutter/supabase_flutter.dart';

/// Servis za upravljanje istorijom vožnji
/// MINIMALNA tabela: putnik_id, datum, tip (voznja/otkazivanje/uplata), iznos, vozac_id
class VoznjeLogService {
  static final _supabase = Supabase.instance.client;

  /// Dodaj uplatu za putnika
  static Future<void> dodajUplatu({
    required String putnikId,
    required DateTime datum,
    required double iznos,
    String? vozacId,
  }) async {
    await _supabase.from('voznje_log').insert({
      'putnik_id': putnikId,
      'datum': datum.toIso8601String().split('T')[0],
      'tip': 'uplata',
      'iznos': iznos,
      'vozac_id': vozacId,
    });
  }
}
