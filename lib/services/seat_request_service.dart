import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';

/// Servis za upravljanje aktivnim zahtevima za sedišta (seat_requests tabela)
class SeatRequestService {
  static SupabaseClient get _supabase => supabase;

  /// 📥 INSERT U SEAT_REQUESTS TABELU ZA BACKEND OBRADU
  static Future<void> insertSeatRequest({
    required String putnikId,
    required String dan,
    required String vreme,
    required String grad,
    int brojMesta = 1,
  }) async {
    try {
      final datum = getNextDateForDay(DateTime.now(), dan);

      await _supabase.from('seat_requests').insert({
        'putnik_id': putnikId,
        'grad': grad.toUpperCase(),
        'datum': datum.toIso8601String().split('T')[0],
        'zeljeno_vreme': vreme,
        'status': 'pending',
        'broj_mesta': brojMesta,
      });
      debugPrint(
          '✅ [SeatRequestService] Inserted for $grad $vreme on $dan (Datum: ${datum.toIso8601String().split('T')[0]})');
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error inserting seat request: $e');
    }
  }

  /// 🗑️ BRISANJE ZAHTEVA NAKON POTVRDE/OBRADE
  static Future<void> deleteProcessedRequest({
    required String putnikId,
    required String dan,
    required String grad,
  }) async {
    try {
      final datum = getNextDateForDay(DateTime.now(), dan);
      final datumStr = datum.toIso8601String().split('T')[0];

      await _supabase.from('seat_requests').delete().match({
        'putnik_id': putnikId,
        'grad': grad.toUpperCase(),
        'datum': datumStr,
      });
      debugPrint('🧹 [SeatRequestService] Deleted processed request for $grad on $datumStr');
    } catch (e) {
      debugPrint('⚠️ [SeatRequestService] Error deleting processed request: $e');
    }
  }

  /// 🕒 STREAM SVIH AKTIVNIH ZAHTEVA - Za admin monitoring
  static Stream<List<Map<String, dynamic>>> streamActiveRequests() {
    return _supabase.from('seat_requests').stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  /// 📅 Helper: Računa sledeći datum za dati dan u nedelji
  static DateTime getNextDateForDay(DateTime fromDate, String danKratica) {
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danKratica.toLowerCase()] ?? 1;
    final currentWeekday = fromDate.weekday;

    int daysToAdd = targetWeekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;

    return fromDate.add(Duration(days: daysToAdd));
  }
}
