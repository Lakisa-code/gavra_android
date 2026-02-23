import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/seat_request.dart';
import '../utils/grad_adresa_validator.dart';
import 'voznje_log_service.dart';

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
    int priority = 1,
    String? customAdresaId, // 🏠 ID custom adrese za brži geocoding
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);
      final normVreme = GradAdresaValidator.normalizeTime(vreme);
      final danKey = dan.toLowerCase();

      // Obriši postojeće aktivne zahteve za isti putnik+grad+dan (trajni ključ).
      await _supabase
          .from('seat_requests')
          .delete()
          .eq('putnik_id', putnikId)
          .eq('grad', gradKey)
          .eq('dan', danKey)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      await _supabase.from('seat_requests').insert({
        'putnik_id': putnikId,
        'grad': gradKey,
        'dan': danKey,
        'zeljeno_vreme': '$normVreme:00',
        'status': status,
        'broj_mesta': brojMesta,
        'priority': priority,
        'custom_adresa_id': customAdresaId,
      });
      debugPrint('✅ [SeatRequestService] Inserted for $gradKey $normVreme on $danKey');

      // 📝 LOG: Zablježi zakazanu vožnju u voznje_log (trajni zapis)
      final datumStr = getIsoDateForDan(danKey);
      await VoznjeLogService.logGeneric(
        tip: 'zakazano',
        putnikId: putnikId,
        datum: datumStr,
        grad: gradKey,
        vreme: normVreme,
        brojMesta: brojMesta,
        status: status,
      );
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error inserting seat request: $e');
    }
  }

  /// Dohvata aktivne zahteve
  static Future<List<SeatRequest>> getActiveRequests() async {
    try {
      final response = await _supabase.from('seat_requests').select().order('created_at', ascending: false);
      return (response as List).map((json) => SeatRequest.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error getting active requests: $e');
      return [];
    }
  }

  /// Dohvata aktivne zahteve sa statusom 'manual' za admina
  /// Vraća listu mapa jer sadrži podatke iz join-a (registrovani_putnici)
  static Future<List<Map<String, dynamic>>> getManualRequests() async {
    try {
      final response = await _supabase
          .from('seat_requests')
          .select('*, registrovani_putnici(putnik_ime, broj_telefona)')
          .eq('status', 'manual')
          .order('created_at', ascending: false);

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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'processed_at': DateTime.now().toUtc().toIso8601String(),
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'processed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ [SeatRequestService] Error rejecting request: $e');
      return false;
    }
  }

  /// Stream za manual zahteve (realtime)
  static Stream<List<SeatRequest>> streamManualRequests() {
    return _supabase
        .from('seat_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'manual')
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => SeatRequest.fromJson(json)).toList());
  }

  /// 🔢 Stream za broj manual zahteva (za bedž na Home ekranu)
  static Stream<int> streamManualRequestCount() {
    return _supabase.from('seat_requests').stream(primaryKey: ['id']).eq('status', 'manual').map((list) => list.length);
  }

  /// 🤖 POKREĆE DIGITALNOG DISPEČERA U BAZI
  static Future<int> triggerDigitalDispecer() async {
    try {
      // Poziva funkciju koja obrađuje sve 'pending' zahteve
      final response = await _supabase.rpc('obradi_sve_pending_zahteve');
      return (response as List).length;
    } catch (e) {
      // Alternativni poziv ako prva funkcija ne postoji (legacy fallback)
      try {
        final response = await _supabase.rpc('dispecer_cron_obrada');
        return (response as List).length;
      } catch (e2) {
        debugPrint('❌ [SeatRequestService] Error triggering digital dispecer: $e / $e2');
        return 0;
      }
    }
  }

  /// 🎫 Prihvata alternativni termin - ODMAH ODOBRAVA
  static Future<bool> acceptAlternative({
    String? requestId,
    required String putnikId,
    required String novoVreme,
    required String grad,
    required String dan,
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);
      final danKey = dan.toLowerCase();
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Otkaži postojeće aktivne zahteve za isti grad+dan
      await _supabase
          .from('seat_requests')
          .update({'status': 'cancelled'})
          .eq('putnik_id', putnikId)
          .eq('grad', gradKey)
          .eq('dan', danKey)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      if (requestId != null && requestId.isNotEmpty) {
        await _supabase.from('seat_requests').update({
          'zeljeno_vreme': novoVreme,
          'status': 'approved',
          'processed_at': nowStr,
        }).eq('id', requestId);
      } else {
        await _supabase.from('seat_requests').insert({
          'putnik_id': putnikId,
          'grad': gradKey,
          'dan': danKey,
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

  /// 📅 Helper: Daje ISO datum za dan u tekućoj sedmici (za voznje_log)
  static String getIsoDateForDan(String danKratica) {
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danKratica.toLowerCase()] ?? 1;
    final now = DateTime.now();
    int daysToAdd = targetWeekday - now.weekday;
    if (daysToAdd < 0) daysToAdd += 7;
    return now.add(Duration(days: daysToAdd)).toIso8601String().split('T')[0];
  }

  /// 📅 Helper: Ostaje zbog backward-compat poziva izvana
  static DateTime getNextDateForDay(DateTime fromDate, String danKratica) {
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danKratica.toLowerCase()] ?? 1;
    final currentWeekday = fromDate.weekday;
    int daysToAdd = targetWeekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;
    return fromDate.add(Duration(days: daysToAdd));
  }
}
