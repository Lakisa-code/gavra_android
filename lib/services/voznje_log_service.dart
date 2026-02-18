import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/voznje_log.dart';
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';
import 'vozac_mapping_service.dart';

/// Servis za upravljanje istorijom vožnji
/// MINIMALNA tabela: putnik_id, datum, tip (voznja/otkazivanje/uplata), iznos, vozac_id
/// ✅ TRAJNO REŠENJE: Sve statistike se čitaju iz ove tabele
class VoznjeLogService {
  static StreamSubscription? _logSubscription;
  static final StreamController<List<Map<String, dynamic>>> _logController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static SupabaseClient get _supabase => supabase;

  /// 📊 STATISTIKE ZA POPIS - Broj vožnji, otkazivanja i uplata po vozaču za određeni datum
  /// Vraća mapu: {voznje: X, otkazivanja: X, uplate: X, pazar: X.X}
  static Future<Map<String, dynamic>> getStatistikePoVozacu({required String vozacIme, required DateTime datum}) async {
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

      final response = await _supabase
          .from('voznje_log')
          .select('tip, iznos')
          .eq('vozac_id', vozacUuid)
          .eq('datum', datumStr)
          .limit(100);

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

  /// 🚀 BATCH STATISTIKE ZA VIŠE VOZAČA - Optimizovano (2 queries umesto N+1)
  /// Vraća mapu: {vozacUuid: {voznje: X, otkazivanja: X, uplate: X, pazar: X.X}, ...}
  /// ✅ PERFORMANCE FIX: Koristi inFilter umesto looopa
  static Future<Map<String, Map<String, dynamic>>> getStatistikeZaViseVozaca({
    required List<String> vozacIds, // List UUID-a
    required DateTime datum,
  }) async {
    final Map<String, Map<String, dynamic>> rezultat = {};

    if (vozacIds.isEmpty) {
      return rezultat;
    }

    try {
      final datumStr = datum.toIso8601String().split('T')[0];

      // QUERY 1: Učitaj sve logove za sve vozače odjednom
      final response = await _supabase
          .from('voznje_log')
          .select('vozac_id, tip, iznos')
          .inFilter('vozac_id', vozacIds)
          .eq('datum', datumStr)
          .limit(5000); // Dovoljno veliki limit za sve vozače na jedan dan

      // Inicijalizuj rezultat za sve vozače
      for (final vozacId in vozacIds) {
        rezultat[vozacId] = {'voznje': 0, 'otkazivanja': 0, 'uplate': 0, 'mesecne': 0, 'pazar': 0.0};
      }

      // PROCESS IN MEMORY: Grupiraj po vozaču (već su u memoriji)
      for (final record in response) {
        final vozacId = record['vozac_id'] as String?;
        if (vozacId == null || !rezultat.containsKey(vozacId)) continue;

        final tip = record['tip'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        switch (tip) {
          case 'voznja':
            rezultat[vozacId]!['voznje']++;
            break;
          case 'otkazivanje':
            rezultat[vozacId]!['otkazivanja']++;
            break;
          case 'uplata':
            rezultat[vozacId]!['uplate']++;
            rezultat[vozacId]!['pazar'] = (rezultat[vozacId]!['pazar'] as double) + iznos;
            break;
          case 'uplata_dnevna':
            rezultat[vozacId]!['uplate']++;
            rezultat[vozacId]!['pazar'] = (rezultat[vozacId]!['pazar'] as double) + iznos;
            break;
          case 'uplata_mesecna':
            rezultat[vozacId]!['mesecne']++;
            rezultat[vozacId]!['pazar'] = (rezultat[vozacId]!['pazar'] as double) + iznos;
            break;
        }
      }
    } catch (e) {
      debugPrint('❌ [VoznjeLogService] Greška pri batch statistici: $e');
    }

    return rezultat;
  }

  /// 🔍 PROVERA POKUPLJENIH PUTNIKA - Vraća Set putnik_id koji su za dati datum imali 'voznja' log
  static Future<Set<String>> getPickedUpIds({required String datumStr}) async {
    try {
      final response = await _supabase.from('voznje_log').select('putnik_id').eq('datum', datumStr).eq('tip', 'voznja');

      return (response as List).map((l) => l['putnik_id'].toString()).toSet();
    } catch (e) {
      debugPrint('❌ Greška pri dobijanju pokupljenih putnika: $e');
      return {};
    }
  }

  /// 🔍 DETALJI O POKUPLJENIM PUTNICIMA (SSOT) - Vraća Map: putnik_id -> {vozac_id, created_at, meta}
  static Future<Map<String, Map<String, dynamic>>> getPickedUpLogData({required String datumStr}) async {
    try {
      final response = await _supabase
          .from('voznje_log')
          .select('putnik_id, vozac_id, created_at, meta')
          .eq('datum', datumStr)
          .eq('tip', 'voznja');

      final Map<String, Map<String, dynamic>> res = {};
      for (var l in (response as List)) {
        final pid = l['putnik_id'].toString();
        final meta = l['meta'] as Map<String, dynamic>?;
        final grad = meta?['grad']?.toString().toLowerCase();
        final vreme = meta?['vreme']?.toString();

        // Kreiramo kompozitni ključ za precizno mapiranje (putnik + grad + vreme)
        // Ako nema meta podataka (stari logovi), koristimo samo putnik_id
        String key = pid;
        if (grad != null && vreme != null) {
          // ✅ FIX: Koristi centralizovanu normalizaciju na HH:mm format
          final normVreme = GradAdresaValidator.normalizeTime(vreme);
          key = "$pid|$grad|$normVreme";
        }

        res[key] = {
          'vozac_id': l['vozac_id'],
          'created_at': l['created_at'],
          'meta': meta,
        };
      }
      return res;
    } catch (e) {
      debugPrint('❌ [VoznjeLogService] Greška pri dohvatu detalja pokupljenosti: $e');
      return {};
    }
  }

  /// 📊 DOHVATA POJEDINAČNI LOG ZA PROVERU
  static Future<Map<String, dynamic>?> getLogEntry({
    required String putnikId,
    required String datum,
    required String tip,
    String? grad,
    String? vreme,
  }) async {
    try {
      var query = _supabase.from('voznje_log').select('id').eq('putnik_id', putnikId).eq('datum', datum).eq('tip', tip);

      if (grad != null) {
        // ✅ FIX: Koristi bc/vs skraćenice
        final gradKey = (grad.toLowerCase().contains('vrsac') || grad.toLowerCase() == 'vs') ? 'vs' : 'bc';
        query = query.eq('meta->>grad', gradKey);
      }
      if (vreme != null) {
        // ✅ FIX: Koristi centralizovanu normalizaciju vremena (HH:mm)
        final normVreme = GradAdresaValidator.normalizeTime(vreme);
        query = query.eq('meta->>vreme', normVreme);
      }

      return await query.maybeSingle();
    } catch (e) {
      return null;
    }
  }

  /// 📊 STREAM STATISTIKA ZA POPIS - Realtime verzija
  static Stream<Map<String, dynamic>> streamStatistikePoVozacu({required String vozacIme, required DateTime datum}) {
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
        final log = VoznjeLog.fromJson(record);

        // Filtriraj po vozaču i datumu
        if (log.vozacId != vozacUuid) continue;
        if (log.datum?.toIso8601String().split('T')[0] != datumStr) continue;

        switch (log.tip) {
          case 'voznja':
            voznje++;
            break;
          case 'otkazivanje':
            otkazivanja++;
            break;
          case 'uplata':
          case 'uplata_dnevna':
          case 'uplata_mesecna':
          case 'placanje': // Podrška za stare logove iz PutnikService-a
            uplate++;
            pazar += log.iznos;
            break;
        }
      }

      return {'voznje': voznje, 'otkazivanja': otkazivanja, 'uplate': uplate, 'pazar': pazar};
    });
  }

  /// 📊 STREAM BROJA DUŽNIKA - Realtime verzija
  static Stream<int> streamBrojDuznikaPoVozacu({required String vozacIme, required DateTime datum}) {
    final datumStr = datum.toIso8601String().split('T')[0];
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);

    if (vozacUuid == null || vozacUuid.isEmpty) {
      return Stream.value(0);
    }

    return _supabase.from('voznje_log').stream(primaryKey: ['id']).map((records) {
      // Grupiši po putnik_id samo za ovog vozača i datum
      final Map<String, Set<String>> putnikTipovi = {};
      for (final record in records) {
        final log = VoznjeLog.fromJson(record);

        if (log.vozacId != vozacUuid) continue;
        if (log.datum?.toIso8601String().split('T')[0] != datumStr) continue;

        final putnikId = log.putnikId;
        final tip = log.tip;
        if (putnikId == null || tip == null) continue;

        putnikTipovi.putIfAbsent(putnikId, () => {});
        putnikTipovi[putnikId]!.add(tip);
      }

      // Pronađi putnike koji imaju 'voznja' ali nemaju bilo kakvu 'uplatu'
      int brojDuznika = 0;
      for (final entry in putnikTipovi.entries) {
        final tipovi = entry.value;
        final imaVoznju = tipovi.contains('voznja');
        final imaUplatu = tipovi.any((t) => t.contains('uplata') || t == 'placanje');

        if (imaVoznju && !imaUplatu) {
          brojDuznika++;
        }
      }

      return brojDuznika;
    });
  }

  /// 📊 DUŽNICI - Broj DNEVNIH putnika koji su pokupljeni ali NISU platili za dati datum
  /// Dužnik = tip='dnevni', ima 'voznja' zapis ali NEMA 'uplata' zapis za isti datum
  static Future<int> getBrojDuznikaPoVozacu({required String vozacIme, required DateTime datum}) async {
    try {
      final vozacUuid = VozacMappingService.getVozacUuidSync(vozacIme);
      if (vozacUuid == null || vozacUuid.isEmpty) return 0;

      final datumStr = datum.toIso8601String().split('T')[0];

      // Dohvati sve zapise za ovog vozača i datum
      final response = await _supabase
          .from('voznje_log')
          .select('putnik_id, tip')
          .eq('vozac_id', vozacUuid)
          .eq('datum', datumStr)
          .limit(100);

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
      final putniciResponse = await _supabase
          .from('registrovani_putnici')
          .select('id, tip')
          .inFilter('id', potencijalniDuznici)
          .limit(1000);

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
          } catch (e) {
            debugPrint('⚠️ Error parsing timestamp: $e');
          }
        }

        String? vozacIme;
        if (vozacId != null && vozacId.isNotEmpty) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
        }

        result[putnikId] = {'datum': datum, 'vozacIme': vozacIme};
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
    String tipUplate = 'uplata',
    String? tipPlacanja,
    String? status,
  }) async {
    await _supabase.from('voznje_log').insert({
      'putnik_id': putnikId,
      'datum': datum.toIso8601String().split('T')[0],
      'tip': tipUplate,
      'iznos': iznos,
      'vozac_id': vozacId,
      'placeni_mesec': placeniMesec ?? datum.month,
      'placena_godina': placenaGodina ?? datum.year,
      'tip_placanja': tipPlacanja,
      'status': status,
    });
  }

  /// ✅ TRAJNO REŠENJE: Dohvati pazar po vozačima za period
  /// Vraća mapu {vozacIme: iznos, '_ukupno': ukupno}
  static Future<Map<String, double>> getPazarPoVozacima({required DateTime from, required DateTime to}) async {
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

  /// 🚀 BATCH PAZAR ZA VIŠE VOZAČA - Optimizovano (1 query)
  /// Vraća mapu: {vozacUuid: iznos, ...}
  /// ✅ PERFORMANCE FIX: Koristi inFilter umesto N queries
  static Future<Map<String, double>> getPazarZaViseVozaca({
    required List<String> vozacIds, // List UUID-a
    required DateTime from,
    required DateTime to,
  }) async {
    final Map<String, double> pazar = {};

    if (vozacIds.isEmpty) {
      return pazar;
    }

    try {
      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      // SINGLE QUERY: Učitaj sve uplate za sve vozače u period
      final response = await _supabase
          .from('voznje_log')
          .select('vozac_id, iznos')
          .inFilter('vozac_id', vozacIds)
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .gte('datum', fromStr)
          .lte('datum', toStr)
          .limit(10000); // Dovoljno za sve vozače u periodu

      // Inicijalizuj sve vozače
      for (final vozacId in vozacIds) {
        pazar[vozacId] = 0.0;
      }

      // PROCESS IN MEMORY: Grupiraj po vozaču
      for (final record in response) {
        final vozacId = record['vozac_id'] as String?;
        final iznos = (record['iznos'] as num?)?.toDouble() ?? 0;

        if (vozacId != null && pazar.containsKey(vozacId) && iznos > 0) {
          pazar[vozacId] = (pazar[vozacId] ?? 0.0) + iznos;
        }
      }
    } catch (e) {
      debugPrint('❌ [VoznjeLogService] Greška pri batch pazaru: $e');
    }

    return pazar;
  }

  /// ✅ TRAJNO REŠENJE: Stream pazara po vozačima (realtime)
  static Stream<Map<String, double>> streamPazarPoVozacima({required DateTime from, required DateTime to}) {
    final fromStr = from.toIso8601String().split('T')[0];
    final toStr = to.toIso8601String().split('T')[0];

    // ✅ FIX: Filtriraj stream UVEK po datumu - koristi filter za range
    Stream<List<Map<String, dynamic>>> query;
    if (fromStr == toStr) {
      // Isti dan - koristi eq filter
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).eq('datum', fromStr).limit(500);
    } else {
      // Različiti dani - učitaj sve i filtriraj u kodu
      // NOTE: Supabase stream ne podržava gte/lte, trebajmo filter u map()
      query = _supabase.from('voznje_log').stream(primaryKey: ['id']).order('datum', ascending: false).limit(500);
    }

    return query.map((records) {
      final Map<String, double> pazar = {};
      double ukupno = 0;

      for (final record in records) {
        final log = VoznjeLog.fromJson(record);

        // Filtriraj po tipu i datumu
        if (log.tip != 'uplata' && log.tip != 'uplata_mesecna' && log.tip != 'uplata_dnevna' && log.tip != 'placanje') {
          continue;
        }

        final logDatumStr = log.datum?.toIso8601String().split('T')[0];
        if (logDatumStr == null) continue;
        if (logDatumStr.compareTo(fromStr) < 0 || logDatumStr.compareTo(toStr) > 0) continue;

        final vozacId = log.vozacId;
        final iznos = log.iznos;

        if (iznos <= 0) continue;

        // Konvertuj UUID u ime vozača sa fallback-om
        String vozacIme = vozacId ?? '';
        if (vozacId != null && vozacId.isNotEmpty) {
          // Prvo pokušaj iz mapiranja
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

  /// 🚀 BATCH BROJ UPLATA - Optimizovano (1 query)
  /// Vraća mapu: {vozacUuid: brojUplata, ...}
  /// ✅ PERFORMANCE FIX: Koristi inFilter umesto N queries
  static Future<Map<String, int>> getBrojUplataZaViseVozaca({
    required List<String> vozacIds, // List UUID-a
    required DateTime from,
    required DateTime to,
  }) async {
    final Map<String, int> brojUplata = {};

    if (vozacIds.isEmpty) {
      return brojUplata;
    }

    try {
      final fromStr = from.toIso8601String().split('T')[0];
      final toStr = to.toIso8601String().split('T')[0];

      // SINGLE QUERY: Učitaj sve mesečne uplate za sve vozače
      final response = await _supabase
          .from('voznje_log')
          .select('vozac_id')
          .inFilter('vozac_id', vozacIds)
          .eq('tip', 'uplata_mesecna')
          .gte('datum', fromStr)
          .lte('datum', toStr)
          .limit(10000);

      // Inicijalizuj sve vozače
      for (final vozacId in vozacIds) {
        brojUplata[vozacId] = 0;
      }

      // PROCESS IN MEMORY: Grupiraj po vozaču
      for (final record in response) {
        final vozacId = record['vozac_id'] as String?;
        if (vozacId != null && brojUplata.containsKey(vozacId)) {
          brojUplata[vozacId] = (brojUplata[vozacId] ?? 0) + 1;
        }
      }
    } catch (e) {
      debugPrint('❌ [VoznjeLogService] Greška pri batch broju uplata: $e');
    }

    return brojUplata;
  }

  /// ✅ Stream broja uplata po vozačima (realtime) - za kocku "Mesečne"
  static Stream<Map<String, int>> streamBrojUplataPoVozacima({required DateTime from, required DateTime to}) {
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
  static Stream<List<VoznjeLog>> streamRecentLogs({required String vozacIme, int limit = 10}) {
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
          final List<VoznjeLog> filtered = logs
              .where((log) {
                if (log['vozac_id'] == vozacUuid) return true;
                if (log['vozac_id'] == null) return true;
                return false;
              })
              .map((json) => VoznjeLog.fromJson(json))
              .toList();

          // Sortiraj po vremenu (created_at) silazno
          filtered.sort((a, b) {
            final DateTime dateA = a.createdAt ?? DateTime.now();
            final DateTime dateB = b.createdAt ?? DateTime.now();
            return dateB.compareTo(dateA);
          });
          return filtered.take(limit).toList();
        });
  }

  /// 🕒 GLOBALNI STREAM SVIH AKCIJA - Za Gavra Lab Admin Dnevnik
  /// ✅ ISPRAVKA: Dodat server-side order i limit za stream
  static Stream<List<VoznjeLog>> streamAllRecentLogs({int limit = 50}) {
    return _supabase
        .from('voznje_log')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((List<Map<String, dynamic>> logs) {
          // Sortiranje je već urađeno na serveru, ali Supabase stream ponekad emituje
          // nesortirane podatke pri update-u, pa je sigurnije zadržati i lokalni sort.
          final List<VoznjeLog> sorted = logs.map((json) => VoznjeLog.fromJson(json)).toList();
          sorted.sort((a, b) {
            final DateTime dateA = a.createdAt ?? DateTime.now();
            final DateTime dateB = b.createdAt ?? DateTime.now();
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
    int? satiPrePolaska,
    String? tipPlacanja,
    String? status,
    String? datum, // NOVO: Mogućnost prosleđivanja specifičnog datuma
    String? grad,
    String? vreme,
  }) async {
    try {
      final now = DateTime.now();
      final datumStr = datum ?? now.toIso8601String().split('T')[0];

      // Priprema meta podataka
      final Map<String, dynamic> finalMeta = Map.from(meta ?? {});
      if (grad != null) {
        // ✅ FIX: Koristi bc/vs skraćenice za konzistentnost sa seat_requests
        finalMeta['grad'] = (grad.toLowerCase().contains('vrsac') || grad.toLowerCase() == 'vs') ? 'vs' : 'bc';
      }
      if (vreme != null) {
        // ✅ FIX: Standardizuj na HH:mm pre upisa u log (da bi match radio kasnije)
        finalMeta['vreme'] = GradAdresaValidator.normalizeTime(vreme);
      }

      await _supabase.from('voznje_log').insert({
        'tip': tip,
        'putnik_id': putnikId,
        'vozac_id': vozacId,
        'iznos': iznos,
        'broj_mesta': brojMesta,
        'datum': datumStr,
        'detalji': detalji,
        'meta': finalMeta.isEmpty ? null : finalMeta,
        'placeni_mesec': now.month,
        'placena_godina': now.year,
        'sati_pre_polaska': satiPrePolaska,
        'tip_placanja': tipPlacanja,
        'status': status,
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
      status: status,
      meta: {'dan': dan.toLowerCase(), 'grad': grad.toLowerCase(), 'vreme': vreme},
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
      meta: {'dan': dan.toLowerCase(), 'grad': grad.toLowerCase(), 'vreme': vreme},
    );
  }

  /// ❌ LOGOVANJE GREŠKE PRI OBRADI ZAHTEVA
  static Future<void> logGreska({
    String? putnikId, // 🔧 Može biti null za nove putnike koji nisu još sačuvani
    required String greska,
    Map<String, dynamic>? meta,
  }) async {
    return logGeneric(tip: 'greska_zahteva', putnikId: putnikId, detalji: 'Greška: $greska', meta: meta);
  }

  /// Dohvata nedavne logove (poslednjih 100)
  static Future<List<Map<String, dynamic>>> getRecentLogs() async {
    try {
      final response = await _supabase.from('voznje_log').select().order('created_at', ascending: false).limit(100);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Stream nedavnih logova sa realtime osvežavanjem
  static Stream<List<Map<String, dynamic>>> streamRecentLogsRealtime() {
    if (_logSubscription == null) {
      _logSubscription = RealtimeManager.instance.subscribe('voznje_log').listen((payload) {
        _refreshLogStream();
      });
      // Inicijalno učitavanje
      _refreshLogStream();
    }
    return _logController.stream;
  }

  static void _refreshLogStream() async {
    final logs = await getRecentLogs();
    if (!_logController.isClosed) {
      _logController.add(logs);
    }
  }

  /// 🧹 Čisti realtime subscription
  static void dispose() {
    _logSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('voznje_log');
    _logSubscription = null;
    _logController.close();
  }
}
