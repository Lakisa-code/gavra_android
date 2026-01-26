import 'package:flutter/foundation.dart';
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

  /// 📊 STREAM BROJA DUŽNIKA - Realtime verzija
  static Stream<int> streamBrojDuznikaPoVozacu({
    required String vozacIme,
    required DateTime datum,
  }) {
    final datumStr = datum.toIso8601String().split('T')[0];
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);

    if (vozacUuid == null || vozacUuid.isEmpty) {
      return Stream.value(0);
    }

    return _supabase.from('voznje_log').stream(primaryKey: ['id']).map((records) {
      // Grupiši po putnik_id samo za ovog vozača i datum
      final Map<String, Set<String>> putnikTipovi = {};
      for (final record in records) {
        if (record['vozac_id'] != vozacUuid) continue;
        if (record['datum'] != datumStr) continue;

        final putnikId = record['putnik_id'] as String?;
        final tip = record['tip'] as String?;
        if (putnikId == null || tip == null) continue;

        putnikTipovi.putIfAbsent(putnikId, () => {});
        putnikTipovi[putnikId]!.add(tip);
      }

      // Pronađi putnike koji imaju 'voznja' ali nemaju bilo kakvu 'uplatu'
      int brojDuznika = 0;
      for (final entry in putnikTipovi.entries) {
        final tipovi = entry.value;
        final imaVoznju = tipovi.contains('voznja');
        final imaUplatu = tipovi.any((t) => t.contains('uplata'));

        if (imaVoznju && !imaUplatu) {
          // Ovde bi idealno trebali proveriti i tip='dnevni' u registrovani_putnici,
          // ali to je teško uraditi sinhrono u stream map-u.
          // Za potrebe realtime brojača na ekranu, voznja bez uplate je dovoljna indikacija.
          brojDuznika++;
        }
      }

      return brojDuznika;
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

      // Pronađi potencijalne dužnike (ima 'voznja' ali NEMA bilo kakvu 'uplatu')
      final potencijalniDuznici = <String>[];
      for (final entry in putnikTipovi.entries) {
        final tipovi = entry.value;
        final imaVoznju = tipovi.contains('voznja');
        final imaUplatu = tipovi.any((t) => t.contains('uplata'));

        if (imaVoznju && !imaUplatu) {
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
        if (tipPutnika == 'dnevni' || tipPutnika == 'posiljka') {
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
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // ✅ FIX: Filtriraj stream direktno da ne probijemo limit od 100 redova
    Stream<List<Map<String, dynamic>>> query;
    if (fromStr == toStr) {
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).eq('datum', fromStr).limit(500);
    } else {
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(500);
    }

    return query.map((records) {
      final Map<String, double> pazar = {};
      double ukupno = 0;

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
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // ✅ FIX: Eksplicitni tip Stream<List<...>> da podrži i filter i no-filter
    Stream<List<Map<String, dynamic>>> query;

    if (fromStr == toStr) {
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).eq('datum', fromStr).limit(500);
    } else {
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(500);
    }

    return query.map((records) {
      final Map<String, int> brojUplata = {};
      int ukupno = 0;

      for (final record in records) {
        // Dodatna provera datuma (za svaki slučaj)
        final datum = record['datum'] as String?;
        if (datum == null) continue;

        // Dodatna prover range-a (ako upit nije filtrirao)
        if (fromStr != toStr) {
          if (datum.compareTo(fromStr) < 0 || datum.compareTo(toStr) > 0) continue;
        }

        final tip = record['tip'] as String?;
        if (tip != 'uplata_mesecna') continue;

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

  /// 🕒 STREAM POSLEDNJIH AKCIJA - Za Dnevnik vozača
  /// ✅ ISPRAVKA: Uključuje i akcije putnika (gde je vozac_id NULL) ako su povezani sa ovim vozačem
  static Stream<List<Map<String, dynamic>>> streamRecentLogs({
    required String vozacIme,
    int limit = 10,
  }) {
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);
    if (vozacUuid == null || vozacUuid.isEmpty) {
      return Stream.value([]);
    }

    // 🔥 FIX: Koristimo server-side order za stream da bismo dobili NAJNOVIJE logove
    // Bez ovoga, stream vraća prvih 1000 redova (najstarijih) iz baze
    return _supabase
        .from('voznje_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit * 5) // Uzimamo malo više pa ćemo filtrirati lokalno
        .map((List<Map<String, dynamic>> logs) {
          final List<Map<String, dynamic>> filtered = logs.where((log) {
            if (log['vozac_id'] == vozacUuid) return true;
            if (log['vozac_id'] == null) return true;
            return false;
          }).toList();

          // Sortiraj po vremenu (created_at) silazno
          filtered.sort((a, b) {
            final DateTime dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
            final DateTime dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
            return dateB.compareTo(dateA);
          });
          return filtered.take(limit).toList();
        });
  }

  /// 🕒 GLOBALNI STREAM SVIH AKCIJA - Za Gavra Lab Admin Dnevnik
  /// ✅ ISPRAVKA: Dodat server-side order i limit za stream
  static Stream<List<Map<String, dynamic>>> streamAllRecentLogs({int limit = 50}) {
    return _supabase
        .from('voznje_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((List<Map<String, dynamic>> logs) {
          // Sortiranje je već urađeno na serveru, ali Supabase stream ponekad emituje
          // nesortirane podatke pri update-u, pa je sigurnije zadržati i lokalni sort.
          final List<Map<String, dynamic>> sorted = List.from(logs);
          sorted.sort((a, b) {
            final DateTime dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
            final DateTime dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
            return dateB.compareTo(dateA);
          });
          return sorted;
        });
  }

  /// 📝 LOGOVANJE GENERIČKE AKCIJE
  static Future<void> logGeneric({
    required String tip,
    String? putnikId,
    String? vozacId,
    double iznos = 0,
    int brojMesta = 1,
    String? detalji,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final datumStr = DateTime.now().toIso8601String().split('T')[0];
      await _supabase.from('voznje_log').insert({
        'tip': tip,
        'putnik_id': putnikId,
        'vozac_id': vozacId,
        'iznos': iznos,
        'broj_mesta': brojMesta,
        'datum': datumStr,
        'detalji': detalji,
        'meta': meta, // 🆕 Dodato meta polje za dodatne podatke (npr. grad, vreme)
        'placeni_mesec': DateTime.now().month,
        'placena_godina': DateTime.now().year,
      });
    } catch (e) {
      debugPrint('❌ Greška pri logovanju akcije ($tip): $e');
    }
  }

  /// 📝 LOGOVANJE ZAHTEVA PUTNIKA (Specijalizovana metoda)
  static Future<void> logZahtev({
    required String putnikId,
    required String dan,
    required String vreme,
    required String grad,
    required String tipPutnika,
    String status = 'Novi zahtev',
  }) async {
    return logGeneric(
      tip: 'zakazivanje_putnika',
      putnikId: putnikId,
      detalji: '$status ($tipPutnika): $dan u $vreme ($grad)',
    );
  }

  /// 📝 LOGOVANJE POTVRDE ZAHTEVA (Kada sistem ili admin potvrdi pending zahtev)
  static Future<void> logPotvrda({
    required String putnikId,
    required String dan,
    required String vreme,
    required String grad,
    String? tipPutnika,
    String detalji = 'Zahtev potvrđen',
  }) async {
    final typeStr = tipPutnika != null ? ' ($tipPutnika)' : '';
    return logGeneric(
      tip: 'potvrda_zakazivanja',
      putnikId: putnikId,
      detalji: '$detalji$typeStr: $dan u $vreme ($grad)',
    );
  }

  /// ❌ LOGOVANJE GREŠKE PRI OBRADI ZAHTEVA
  static Future<void> logGreska({
    String? putnikId, // 🔧 Može biti null za nove putnike koji nisu još sačuvani
    required String greska,
    Map<String, dynamic>? meta,
  }) async {
    return logGeneric(
      tip: 'greska_zahteva',
      putnikId: putnikId,
      detalji: 'Greška: $greska',
      meta: meta,
    );
  }
}
