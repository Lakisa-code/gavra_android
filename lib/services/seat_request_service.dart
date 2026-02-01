import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'realtime/realtime_manager.dart';

/// Servis za upravljanje aktivnim zahtevima za sedišta (seat_requests tabela)
class SeatRequestService {
  static SupabaseClient get _supabase => supabase;

  static StreamSubscription? _requestsSubscription;
  static final StreamController<List<Map<String, dynamic>>> _requestsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

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

  /// Dohvata aktivne zahteve
  static Future<List<Map<String, dynamic>>> getActiveRequests() async {
    try {
      final response = await _supabase.from('seat_requests').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// 🕒 STREAM SVIH AKTIVNIH ZAHTEVA - Za admin monitoring
  static Stream<List<Map<String, dynamic>>> streamActiveRequests() {
    if (_requestsSubscription == null) {
      _requestsSubscription = RealtimeManager.instance.subscribe('seat_requests').listen((payload) {
        _refreshRequestsStream();
      });
      // Inicijalno učitavanje
      _refreshRequestsStream();
    }
    return _requestsController.stream;
  }

  static void _refreshRequestsStream() async {
    final requests = await getActiveRequests();
    if (!_requestsController.isClosed) {
      _requestsController.add(requests);
    }
  }

  /// 🧹 Čisti realtime subscription
  static void dispose() {
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _requestsController.close();
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
