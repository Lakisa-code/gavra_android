import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import 'vozac_mapping_service.dart';

/// Servis za upravljanje istorijom vožnji
/// MINIMALNA tabela: putnik_id, datum, tip (voznja/otkazivanje/uplata), iznos, vozac_id
/// ✅ TRAJNO REŠENJE: Sve statistike se čitaju iz ove tabele
class VoznjeLogService {
  static SupabaseClient get _supabase => supabase;

  /// 📊 STATISTIKE ZA POPIS - Broj vožnji, otkazivanja i uplata po vozaču za određeni datum
  /// Vraća mapu: {voznje: X, otkazivanja: X, uplate: X, pazar: X.X}
  static Future<Map<String, dynamic>> getStatistikePoVozacu({
    required String vozacIme,
    required DateTime datum,
  }) async {
    int voznje = 0;
    int otkazivanja = 0;
    int naplaceniDnevni = 0;
    int naplaceniMesecni = 0;
    double pazar = 0.0;

    try {
      // Dohvati UUID vozača
      final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);
      if (vozacUuid == null || vozacUuid.isEmpty) {
        return {'voznje': 0, 'otkazivanja': 0, 'uplate': 0, 'mesecne': 0, 'pazar': 0.0};
      }

      final datumStr = datum.toIso8601String().split('T')[0];

      final response =
          await _supabase.from('voznje_log').select('tip, iznos').eq('vozac_id', vozacUuid).eq('datum', datumStr);

      for (final record in response) {
        final tip = record['tip'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        switch (tip) {
          case 'voznja':
            voznje++;
            break;
          case 'otkazivanje':
            otkazivanja++;
            break;
          case 'uplata':
            // STARI TIP PRE MIGRACIJE (sada više ne bi trebao da postoji, ali za svaki slučaj)
            // Pretpostavljamo da je 'uplata' bila dnevna ako je iznos manji od np. 2000?
            // Ili ga brojimo u dnevne.
            naplaceniDnevni++;
            pazar += iznos;
            break;
          case 'uplata_dnevna':
            naplaceniDnevni++;
            pazar += iznos;
            break;
          case 'uplata_mesecna':
            naplaceniMesecni++;
            pazar += iznos;
            break;
        }
      }
    } catch (e) {
      // Greška - vrati prazne statistike
    }

    return {
      'voznje': voznje,
      'otkazivanja': otkazivanja,
      'uplate': naplaceniDnevni, // Dnevne naplate
      'mesecne': naplaceniMesecni, // Mesečne naplate
      'pazar': pazar,
    };
  }

  /// 📊 STREAM STATISTIKA ZA POPIS - Realtime verzija
  static Stream<Map<String, dynamic>> streamStatistikePoVozacu({
    required String vozacIme,
    required DateTime datum,
  }) {
    final datumStr = datum.toIso8601String().split('T')[0];
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);

    if (vozacUuid == null || vozacUuid.isEmpty) {
      return Stream.value({'voznje': 0, 'otkazivanja': 0, 'uplate': 0, 'pazar': 0.0});
    }

    return _supabase.from('voznje_log').stream(primaryKey: ['id']).map((records) {
      int voznje = 0;
      int otkazivanja = 0;
      int uplate = 0;
      double pazar = 0.0;

      for (final record in records) {
        // Filtriraj po vozaču i datumu
        if (record['vozac_id'] != vozacUuid) continue;
        if (record['datum'] != datumStr) continue;

        final tip = record['tip'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        switch (tip) {
          case 'voznja':
            voznje++;
            break;
          case 'otkazivanje':
            otkazivanja++;
            break;
          case 'uplata':
            uplate++;
            pazar += iznos;
            break;
        }
      }

      return {
        'voznje': voznje,
        'otkazivanja': otkazivanja,
        'uplate': uplate,
        'pazar': pazar,
      };
    });
  }

  /// 📊 DUŽNICI - Broj DNEVNIH putnika koji su pokupljeni ali NISU platili za dati datum
  /// Dužnik = tip='dnevni', ima 'voznja' zapis ali NEMA 'uplata' zapis za isti datum
  static Future<int> getBrojDuznikaPoVozacu({
    required String vozacIme,
    required DateTime datum,
  }) async {
    try {
      final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);
      if (vozacUuid == null || vozacUuid.isEmpty) return 0;

      final datumStr = datum.toIso8601String().split('T')[0];

      // Dohvati sve zapise za ovog vozača i datum
      final response =
          await _supabase.from('voznje_log').select('putnik_id, tip').eq('vozac_id', vozacUuid).eq('datum', datumStr);

      // Grupiši po putnik_id
      final Map<String, Set<String>> putnikTipovi = {};
      for (final record in response) {
        final putnikId = record['putnik_id'] as String?;
        final tip = record['tip'] as String?;
        if (putnikId == null || tip == null) continue;

        putnikTipovi.putIfAbsent(putnikId, () => {});
        putnikTipovi[putnikId]!.add(tip);
      }

      // Pronađi potencijalne dužnike (ima 'voznja' ali NEMA 'uplata')
      final potencijalniDuznici = <String>[];
      for (final entry in putnikTipovi.entries) {
        if (entry.value.contains('voznja') && !entry.value.contains('uplata')) {
          potencijalniDuznici.add(entry.key);
        }
      }

      if (potencijalniDuznici.isEmpty) return 0;

      // Proveri koji od njih su DNEVNI putnici (tip = 'dnevni')
      final putniciResponse =
          await _supabase.from('registrovani_putnici').select('id, tip').inFilter('id', potencijalniDuznici);

      int brojDuznika = 0;
      for (final putnik in putniciResponse) {
        final tipPutnika = putnik['tip'] as String?;
        if (tipPutnika == 'dnevni') {
          brojDuznika++;
        }
      }

      return brojDuznika;
    } catch (e) {
      return 0;
    }
  }

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
    String tipUplate = 'uplata', // Default na 'uplata' za backward compatibility
  }) async {
    await _supabase.from('voznje_log').insert({
      'putnik_id': putnikId,
      'datum': datum.toIso8601String().split('T')[0],
      'tip': tipUplate,
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
          .select('vozac_id, iznos, tip')
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
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
        final tip = record['tip'] as String?;
        if (tip == null || (tip != 'uplata' && tip != 'uplata_mesecna' && tip != 'uplata_dnevna')) continue;

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
          .eq('tip', 'uplata_mesecna')
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
        // Filtriraj po tipu ('uplata_mesecna' samo) i datumu
        if (record['tip'] != 'uplata_mesecna') continue;
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
