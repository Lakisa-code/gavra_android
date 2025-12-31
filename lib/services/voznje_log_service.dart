import 'package:supabase_flutter/supabase_flutter.dart';

import 'vozac_mapping_service.dart';

/// Servis za upravljanje istorijom vožnji
/// MINIMALNA tabela: putnik_id, datum, tip (voznja/otkazivanje/uplata), iznos, vozac_id
/// ✅ TRAJNO REŠENJE: Sve statistike se čitaju iz ove tabele
class VoznjeLogService {
  static final _supabase = Supabase.instance.client;

  /// 🆕 Dohvati poslednje otkazivanje za sve putnike
  /// Vraća mapu {putnikId: {datum: DateTime, vozacIme: String}}
  static Future<Map<String, Map<String, dynamic>>> getOtkazivanjaZaSvePutnike() async {
    final Map<String, Map<String, dynamic>> result = {};

    try {
      final response = await _supabase
          .from('voznje_log')
          .select('putnik_id, created_at, vozac_id')
          .eq('tip', 'otkazivanje')
          .order('created_at', ascending: false);

      for (final record in response) {
        final putnikId = record['putnik_id'] as String?;
        if (putnikId == null) continue;

        // Uzmi samo poslednje otkazivanje za svakog putnika
        if (result.containsKey(putnikId)) continue;

        final createdAt = record['created_at'] as String?;
        final vozacId = record['vozac_id'] as String?;

        DateTime? datum;
        if (createdAt != null) {
          try {
            datum = DateTime.parse(createdAt).toLocal();
          } catch (_) {}
        }

        String? vozacIme;
        if (vozacId != null && vozacId.isNotEmpty) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
        }

        result[putnikId] = {
          'datum': datum,
          'vozacIme': vozacIme,
        };
      }
    } catch (e) {
      // Greška - vrati praznu mapu
    }

    return result;
  }

  /// Dodaj uplatu za putnika
  static Future<void> dodajUplatu({
    required String putnikId,
    required DateTime datum,
    required double iznos,
    String? vozacId,
    int? placeniMesec,
    int? placenaGodina,
  }) async {
    await _supabase.from('voznje_log').insert({
      'putnik_id': putnikId,
      'datum': datum.toIso8601String().split('T')[0],
      'tip': 'uplata',
      'iznos': iznos,
      'vozac_id': vozacId,
      'placeni_mesec': placeniMesec ?? datum.month,
      'placena_godina': placenaGodina ?? datum.year,
    });
  }

  /// ✅ TRAJNO REŠENJE: Dohvati pazar po vozačima za period
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  static Future<Map<String, double>> getPazarPoVozacima({
    required DateTime from,
    required DateTime to,
  }) async {
    final Map<String, double> pazar = {};
    double ukupno = 0;

    try {
      final response = await _supabase
          .from('voznje_log')
          .select('vozac_id, iznos')
          .eq('tip', 'uplata')
          .gte('datum', from.toIso8601String().split('T')[0])
          .lte('datum', to.toIso8601String().split('T')[0]);

      for (final record in response) {
        final vozacId = record['vozac_id'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        if (iznos <= 0) continue;

        // Konvertuj UUID u ime vozača
        String vozacIme = vozacId ?? '';
        if (vozacId != null && vozacId.isNotEmpty) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? vozacId;
        }
        if (vozacIme.isEmpty) continue;

        pazar[vozacIme] = (pazar[vozacIme] ?? 0) + iznos;
        ukupno += iznos;
      }
    } catch (e) {
      // Greška pri čitanju - vrati praznu mapu
    }

    pazar['_ukupno'] = ukupno;
    return pazar;
  }

  /// ✅ TRAJNO REŠENJE: Stream pazara po vozačima (realtime)
  static Stream<Map<String, double>> streamPazarPoVozacima({
    required DateTime from,
    required DateTime to,
  }) {
    return _supabase.from('voznje_log').stream(primaryKey: ['id']).map((records) {
      final Map<String, double> pazar = {};
      double ukupno = 0;

      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      for (final record in records) {
        // Filtriraj po tipu i datumu
        if (record['tip'] != 'uplata') continue;
        final datum = record['datum'] as String?;
        if (datum == null) continue;
        if (datum.compareTo(fromStr) < 0 || datum.compareTo(toStr) > 0) continue;

        final vozacId = record['vozac_id'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        if (iznos <= 0) continue;

        // Konvertuj UUID u ime vozača
        String vozacIme = vozacId ?? '';
        if (vozacId != null && vozacId.isNotEmpty) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? vozacId;
        }
        if (vozacIme.isEmpty) continue;

        pazar[vozacIme] = (pazar[vozacIme] ?? 0) + iznos;
        ukupno += iznos;
      }

      pazar['_ukupno'] = ukupno;
      return pazar;
    });
  }

  /// ✅ TRAJNO REŠENJE: Broj uplata za vozača u periodu
  static Future<int> getBrojUplataZaVozaca({
    required String vozacImeIliUuid,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Dohvati UUID ako je prosleđeno ime
      String? vozacUuid = vozacImeIliUuid;
      if (!vozacImeIliUuid.contains('-')) {
        vozacUuid = VozacMappingService.getVozacUuidSync(vozacImeIliUuid);
      }

      final response = await _supabase
          .from('voznje_log')
          .select('id')
          .eq('tip', 'uplata')
          .eq('vozac_id', vozacUuid ?? vozacImeIliUuid)
          .gte('datum', from.toIso8601String().split('T')[0])
          .lte('datum', to.toIso8601String().split('T')[0]);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// ✅ Stream broja uplata po vozačima (realtime) - za kocku "Mesečne"
  static Stream<Map<String, int>> streamBrojUplataPoVozacima({
    required DateTime from,
    required DateTime to,
  }) {
    return _supabase.from('voznje_log').stream(primaryKey: ['id']).map((records) {
      final Map<String, int> brojUplata = {};
      int ukupno = 0;

      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      for (final record in records) {
        // Filtriraj po tipu i datumu
        if (record['tip'] != 'uplata') continue;
        final datum = record['datum'] as String?;
        if (datum == null) continue;
        if (datum.compareTo(fromStr) < 0 || datum.compareTo(toStr) > 0) continue;

        final vozacId = record['vozac_id'] as String?;

        // Konvertuj UUID u ime vozača
        String vozacIme = vozacId ?? '';
        if (vozacId != null && vozacId.isNotEmpty) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId) ?? vozacId;
        }
        if (vozacIme.isEmpty) continue;

        brojUplata[vozacIme] = (brojUplata[vozacIme] ?? 0) + 1;
        ukupno++;
      }

      brojUplata['_ukupno'] = ukupno;
      return brojUplata;
    });
  }
}
