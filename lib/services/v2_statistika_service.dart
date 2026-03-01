import 'dart:async';

import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../utils/v2_vozac_cache.dart';
import 'realtime/v2_master_realtime_manager.dart';

/// Servis za statistiku
/// ✅ TRAJNO REŠENJE: Koristi VoznjeLogService kao source of truth
class StatistikaService {
  /// Singleton instance for compatibility
  static final StatistikaService instance = StatistikaService._internal();
  StatistikaService._internal();

  /// Stream pazara direktno iz master cache-a (0 DB upita za današnji dan).
  /// Za ostale datume radi jednokratni DB fetch.
  /// Re-emituje kad v2_statistika_istorija dobije WebSocket event.
  ///
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  static Stream<Map<String, double>> streamPazarIzCachea({
    required String isoDate, // npr. '2026-03-01'
  }) {
    final rm = V2MasterRealtimeManager.instance;
    final controller = StreamController<Map<String, double>>.broadcast();

    Map<String, double> _izracunajIzCache() {
      final Map<String, double> pazar = {};
      double ukupno = 0;
      for (final row in rm.statistikaCache.values) {
        final tip = row['tip'] as String?;
        if (tip != 'uplata' && tip != 'uplata_dnevna' && tip != 'uplata_mesecna' && tip != 'placanje') continue;
        final iznos = (row['iznos'] as num?)?.toDouble() ?? 0;
        if (iznos <= 0) continue;
        String vozacIme = (row['vozac_ime'] as String?) ?? '';
        if (vozacIme.isEmpty) {
          final vozacId = row['vozac_id']?.toString() ?? '';
          if (vozacId.isNotEmpty) vozacIme = VozacCache.getImeByUuid(vozacId) ?? vozacId;
        }
        if (vozacIme.isEmpty) continue;
        pazar[vozacIme] = (pazar[vozacIme] ?? 0) + iznos;
        ukupno += iznos;
      }
      pazar['_ukupno'] = ukupno;
      return pazar;
    }

    Future<Map<String, double>> _fetchIzBaze() async {
      try {
        final rows = await supabase
            .from('v2_statistika_istorija')
            .select('tip, iznos, vozac_id, vozac_ime')
            .eq('datum', isoDate)
            .limit(500);
        final Map<String, double> pazar = {};
        double ukupno = 0;
        for (final row in rows) {
          final tip = row['tip'] as String?;
          if (tip != 'uplata' && tip != 'uplata_dnevna' && tip != 'uplata_mesecna' && tip != 'placanje') continue;
          final iznos = (row['iznos'] as num?)?.toDouble() ?? 0;
          if (iznos <= 0) continue;
          String vozacIme = (row['vozac_ime'] as String?) ?? '';
          if (vozacIme.isEmpty) {
            final vozacId = row['vozac_id']?.toString() ?? '';
            if (vozacId.isNotEmpty) vozacIme = VozacCache.getImeByUuid(vozacId) ?? vozacId;
          }
          if (vozacIme.isEmpty) continue;
          pazar[vozacIme] = (pazar[vozacIme] ?? 0) + iznos;
          ukupno += iznos;
        }
        pazar['_ukupno'] = ukupno;
        return pazar;
      } catch (e) {
        debugPrint('❌ [StatistikaService] _fetchIzBaze: $e');
        return {'_ukupno': 0};
      }
    }

    void emit() async {
      if (controller.isClosed) return;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final result = (isoDate == today && rm.isInitialized) ? _izracunajIzCache() : await _fetchIzBaze();
      if (!controller.isClosed) controller.add(result);
    }

    Future.microtask(emit);
    final sub = rm.subscribe('v2_statistika_istorija').listen((_) => emit());
    controller.onCancel = () {
      sub.cancel();
      rm.unsubscribe('v2_statistika_istorija');
    };
    return controller.stream;
  }
}
