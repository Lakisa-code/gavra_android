import 'dart:async';

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
    String status = 'pending',
    String? fixedDate, // 📅 Opciono: Tačan datum ako nije potreban proračun sutrašnjice
  }) async {
    try {
      final datum = fixedDate != null ? DateTime.parse(fixedDate) : getNextDateForDay(DateTime.now(), dan);
      final datumStr = datum.toIso8601String().split('T')[0];

      // 🛡️ PROVERA: Da li već postoji aktivan zahtev za OVAJ GRAD i DATUM?
      // Ako postoji bilo šta (pending, manual, approved), otkaži to jer šaljemo NOVU verziju
      await _supabase
          .from('seat_requests')
          .update({'status': 'cancelled'})
          .eq('putnik_id', putnikId)
          .eq('grad', grad.toUpperCase())
          .eq('datum', datumStr)
          .inFilter('status', ['pending', 'manual', 'approved']);

      await _supabase.from('seat_requests').insert({
        'putnik_id': putnikId,
        'grad': grad.toUpperCase(),
        'datum': datumStr,
        'zeljeno_vreme': vreme,
        'status': status,
        'broj_mesta': brojMesta,
      });
      debugPrint('✅ [SeatRequestService] Inserted for $grad $vreme on $dan (Datum: $datumStr)');
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error inserting seat request: $e');
    }
  }

  /// Dohvata aktivne zahteve
  static Future<List<Map<String, dynamic>>> getActiveRequests() async {
    try {
      final response = await _supabase.from('seat_requests').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Dohvata aktivne zahteve sa statusom 'manual' za admina
  static Future<List<Map<String, dynamic>>> getManualRequests() async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime, broj_telefona)')
          .eq('status', 'manual');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error getting manual requests: $e');
      return [];
    }
  }

  /// Odobrava zahtev
  static Future<bool> approveRequest(String id) async {
    try {
      await _supabase.from('seat_requests').update({
        'status': 'approved',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error approving request: $e');
      return false;
    }
  }

  /// Odbija zahtev
  static Future<bool> rejectRequest(String id) async {
    try {
      await _supabase.from('seat_requests').update({
        'status': 'rejected',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error rejecting request: $e');
      return false;
    }
  }

  /// Stream za manual zahteve (realtime)
  static Stream<List<Map<String, dynamic>>> streamManualRequests() {
    return _supabase
        .from('seat_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'manual')
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  /// 🔢 Stream za broj manual zahteva (za bedž na Home ekranu)
  static Stream<int> streamManualRequestCount() {
    return streamManualRequests().map((list) => list.length);
  }

  /// 🤖 POKREĆE DIGITALNOG DISPEČERA U BAZI
  static Future<int> triggerDigitalDispecer() async {
    try {
      final List<dynamic> response = await _supabase.rpc('dispecer_cron_obrada');
      return response.length;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error triggering digital dispecer: $e');
      return 0;
    }
  }

  /// 🎫 Prihvata alternativni termin - ODMAH ODOBRAVA
  static Future<bool> acceptAlternative({
    String? requestId,
    required String putnikId,
    required String novoVreme,
    required String grad,
    required String datum,
  }) async {
    try {
      final gradUpper = grad.toUpperCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      if (requestId != null && requestId.isNotEmpty) {
        await _supabase.from('seat_requests').update({
          'zeljeno_vreme': novoVreme,
          'status': 'approved',
          'processed_at': nowStr,
        }).eq('id', requestId);
      } else {
        await _supabase.from('seat_requests').insert({
          'putnik_id': putnikId,
          'grad': gradUpper,
          'datum': datum,
          'zeljeno_vreme': novoVreme,
          'status': 'approved',
          'processed_at': nowStr,
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error accepting alternative: $e');
      return false;
    }
  }

  /// Pomoćna funkcija za dobijanje skraćenice dana
  static String getDanKratica(DateTime date) {
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[date.weekday - 1];
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
