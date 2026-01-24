import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart';
import '../models/registrovani_putnik.dart';
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';
import 'slobodna_mesta_service.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart'; // 🔄 DODATO za istoriju vožnji

/// Servis za upravljanje mesečnim putnicima (normalizovana šema)
class RegistrovaniPutnikService {
  RegistrovaniPutnikService({SupabaseClient? supabaseClient}) : _supabaseOverride = supabaseClient;
  final SupabaseClient? _supabaseOverride;

  SupabaseClient get _supabase => _supabaseOverride ?? supabase;

  // 🔧 SINGLETON PATTERN za realtime stream - koristi RealtimeManager
  static StreamController<List<RegistrovaniPutnik>>? _sharedController;
  static StreamSubscription? _sharedSubscription;
  static List<RegistrovaniPutnik>? _lastValue;

  // 🔧 SINGLETON PATTERN za "SVI PUTNICI" stream (uključujući neaktivne)
  static StreamController<List<RegistrovaniPutnik>>? _sharedSviController;
  static StreamSubscription? _sharedSviSubscription;
  static List<RegistrovaniPutnik>? _lastSviValue;

  /// Dohvata sve mesečne putnike
  Future<List<RegistrovaniPutnik>> getAllRegistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<RegistrovaniPutnik>> getAktivniregistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata putnike kojima treba račun (treba_racun = true)
  Future<List<RegistrovaniPutnik>> getPutniciZaRacun() async {
    final response = await _supabase
        .from('registrovani_putnici')
        .select('*')
        .eq('aktivan', true)
        .eq('obrisan', false)
        .eq('treba_racun', true)
        .order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata mesečnog putnika po ID-u
  Future<RegistrovaniPutnik?> getRegistrovaniPutnikById(String id) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('id', id).single();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<RegistrovaniPutnik?> getRegistrovaniPutnikByIme(String ime) async {
    try {
      final response =
          await supabase.from('registrovani_putnici').select().eq('putnik_ime', ime).eq('obrisan', false).single();

      return RegistrovaniPutnik.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// 🔧 SINGLETON STREAM za mesečne putnike - koristi RealtimeManager
  /// Svi pozivi dele isti controller
  static Stream<List<RegistrovaniPutnik>> streamAktivniRegistrovaniPutnici() {
    // Ako već postoji aktivan controller, koristi ga
    if (_sharedController != null && !_sharedController!.isClosed) {
      // NE POVEĆAVAJ listener count - broadcast stream deli istu pretplatu
      // debugPrint('📊 [RegistrovaniPutnikService] Reusing existing stream'); // Disabled - too spammy

      // Emituj poslednju vrednost novom listener-u
      if (_lastValue != null) {
        Future.microtask(() {
          if (_sharedController != null && !_sharedController!.isClosed) {
            _sharedController!.add(_lastValue!);
          }
        });
      }

      return _sharedController!.stream;
    }

    // Kreiraj novi shared controller
    _sharedController = StreamController<List<RegistrovaniPutnik>>.broadcast();

    // Učitaj inicijalne podatke
    _fetchAndEmit(supabase);

    // Kreiraj subscription preko RealtimeManager
    _setupRealtimeSubscription(supabase);

    return _sharedController!.stream;
  }

  /// 🔄 Fetch podatke i emituj u stream
  static Future<void> _fetchAndEmit(SupabaseClient supabase) async {
    try {
      final data = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('putnik_ime');

      final putnici = data.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
      _lastValue = putnici;

      if (_sharedController != null && !_sharedController!.isClosed) {
        _sharedController!.add(putnici);
      }
    } catch (_) {
      // Fetch error - silent
    }
  }

  /// 🔌 Setup realtime subscription preko RealtimeManager
  static void _setupRealtimeSubscription(SupabaseClient supabase) {
    _sharedSubscription?.cancel();

    // Koristi centralizovani RealtimeManager
    _sharedSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
      _fetchAndEmit(supabase);
    });
  }

  /// 🧹 Čisti singleton cache - pozovi kad treba resetovati sve
  static void clearRealtimeCache() {
    // Čisti Aktivni stream
    _sharedSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('registrovani_putnici');
    _sharedSubscription = null;
    _sharedController?.close();
    _sharedController = null;
    _lastValue = null;

    // Čisti Svi stream
    _sharedSviSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('registrovani_putnici_svi');
    _sharedSviSubscription = null;
    _sharedSviController?.close();
    _sharedSviController = null;
    _lastSviValue = null;
  }

  /// 📱 Normalizuje broj telefona za poređenje
  static String _normalizePhone(String telefon) {
    var cleaned = telefon.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+381')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('00381')) {
      cleaned = '0${cleaned.substring(5)}';
    }
    return cleaned;
  }

  /// 🔍 Proveri da li već postoji putnik sa istim brojem telefona
  Future<RegistrovaniPutnik?> findByPhone(String telefon) async {
    if (telefon.isEmpty) return null;

    final normalizedInput = _normalizePhone(telefon);

    // Dohvati sve putnike i uporedi normalizovane brojeve
    final allPutnici = await _supabase.from('registrovani_putnici').select().eq('obrisan', false);

    for (final p in allPutnici) {
      final storedPhone = p['broj_telefona'] as String? ?? '';
      if (storedPhone.isNotEmpty && _normalizePhone(storedPhone) == normalizedInput) {
        return RegistrovaniPutnik.fromMap(p);
      }
    }
    return null;
  }

  /// Kreira novog mesečnog putnika
  /// Baca grešku ako već postoji putnik sa istim brojem telefona
  /// Baca grešku ako je kapacitet popunjen za bilo koji termin (osim ako je skipKapacitetCheck=true)
  Future<RegistrovaniPutnik> createRegistrovaniPutnik(
    RegistrovaniPutnik putnik, {
    bool skipKapacitetCheck = false,
  }) async {
    // 🔍 PROVERA DUPLIKATA - pre insert-a proveri da li već postoji
    final telefon = putnik.brojTelefona;
    if (telefon != null && telefon.isNotEmpty) {
      final existing = await findByPhone(telefon);
      if (existing != null) {
        throw Exception('Putnik sa ovim brojem telefona već postoji: ${existing.putnikIme}. '
            'Možete ga pronaći u listi putnika.');
      }
    }

    // 🚫 PROVERA KAPACITETA - Da li ima slobodnih mesta za sve termine?
    // Preskači ako admin uređuje (skipKapacitetCheck=true)
    final putnikMap = putnik.toMap();
    if (!skipKapacitetCheck) {
      final rawPolasci = putnikMap['polasci_po_danu'] as Map<String, dynamic>?;
      if (rawPolasci != null) {
        await _validateKapacitetForRawPolasci(rawPolasci, brojMesta: putnik.brojMesta, tipPutnika: putnik.tip);
      }
    }

    final response = await _supabase.from('registrovani_putnici').insert(putnikMap).select('''
          *
        ''').single();

    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// 🚫 Validira da ima slobodnih mesta za sve termine putnika
  /// Prima raw polasci_po_danu map iz baze (format: { "pon": { "bc": "8:00", "vs": null }, ... })
  Future<void> _validateKapacitetForRawPolasci(Map<String, dynamic> polasciPoDanu,
      {int brojMesta = 1, String? tipPutnika}) async {
    if (polasciPoDanu.isEmpty) return;

    final danas = DateTime.now();
    final daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];

    // Proveri svaki dan koji putnik ima definisan
    for (final danKratica in daniKratice) {
      final danData = polasciPoDanu[danKratica];
      if (danData == null || danData is! Map) continue;

      // Proveri BC polazak - PAŽNJA: null.toString() = "null", ne prazan string!
      final bcValue = danData['bc'];
      final bcVreme = (bcValue != null && bcValue.toString().isNotEmpty && bcValue.toString() != 'null')
          ? bcValue.toString()
          : null;

      if (bcVreme != null) {
        // Izračunaj datum za ovaj dan u narednih 7 dana
        final targetDate = _getNextDateForDay(danas, danKratica);
        final datumStr = targetDate.toIso8601String().split('T')[0];

        final normalizedVreme = GradAdresaValidator.normalizeTime(bcVreme);
        final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta('BC', normalizedVreme,
            datum: datumStr, tipPutnika: tipPutnika, brojMesta: brojMesta);
        if (!imaMesta) {
          final danPunoIme = _getDanPunoIme(danKratica);
          throw Exception(
            'NEMA SLOBODNIH MESTA!\n\n'
            'Termin: $danPunoIme u $bcVreme (Bela Crkva)\n'
            'Kapacitet je popunjen.\n\n'
            'Izaberite drugi termin ili kontaktirajte admina.',
          );
        }
      }

      // Proveri VS polazak - PAŽNJA: null.toString() = "null", ne prazan string!
      final vsValue = danData['vs'];
      final vsVreme = (vsValue != null && vsValue.toString().isNotEmpty && vsValue.toString() != 'null')
          ? vsValue.toString()
          : null;

      if (vsVreme != null) {
        final targetDate = _getNextDateForDay(danas, danKratica);
        final datumStr = targetDate.toIso8601String().split('T')[0];

        final normalizedVreme = GradAdresaValidator.normalizeTime(vsVreme);
        final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta('VS', normalizedVreme,
            datum: datumStr, tipPutnika: tipPutnika, brojMesta: brojMesta);
        if (!imaMesta) {
          final danPunoIme = _getDanPunoIme(danKratica);
          throw Exception(
            'NEMA SLOBODNIH MESTA!\n\n'
            'Termin: $danPunoIme u $vsVreme (Vršac)\n'
            'Kapacitet je popunjen.\n\n'
            'Izaberite drugi termin ili kontaktirajte admina.',
          );
        }
      }
    }
  }

  /// Vraća sledeći datum za dati dan u nedelji
  DateTime _getNextDateForDay(DateTime fromDate, String danKratica) {
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final targetWeekday = daniMap[danKratica] ?? 1;
    final currentWeekday = fromDate.weekday;

    int daysToAdd = targetWeekday - currentWeekday;
    if (daysToAdd < 0) daysToAdd += 7;

    return fromDate.add(Duration(days: daysToAdd));
  }

  /// Vraća puno ime dana
  String _getDanPunoIme(String kratica) {
    const map = {
      'pon': 'Ponedeljak',
      'uto': 'Utorak',
      'sre': 'Sreda',
      'cet': 'Četvrtak',
      'pet': 'Petak',
      'sub': 'Subota',
      'ned': 'Nedelja',
    };
    return map[kratica] ?? kratica;
  }

  /// Ažurira mesečnog putnika
  /// Proverava kapacitet ako se menjaju termini (polasci_po_danu)
  Future<RegistrovaniPutnik> updateRegistrovaniPutnik(
    String id,
    Map<String, dynamic> updates, {
    bool skipKapacitetCheck = false,
  }) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    // 🛡️ MERGE SA POSTOJEĆIM MARKERIMA U BAZI (bc_pokupljeno, bc_placeno, itd.)
    if (updates.containsKey('polasci_po_danu')) {
      final noviPolasci = updates['polasci_po_danu'];
      if (noviPolasci != null && noviPolasci is Map) {
        // Čitaj trenutno stanje iz baze
        final trenutnoStanje =
            await _supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', id).single();

        final trenutniPolasci = trenutnoStanje['polasci_po_danu'] as Map<String, dynamic>?;

        if (trenutniPolasci != null) {
          // Merge novi polasci sa postojećim markerima
          final mergedPolasci = <String, dynamic>{};

          // Kopiraj sve dane iz novih podataka
          noviPolasci.forEach((dan, noviPodaci) {
            if (noviPodaci is Map) {
              mergedPolasci[dan] = Map<String, dynamic>.from(noviPodaci);
            } else {
              mergedPolasci[dan] = noviPodaci;
            }
          });

          // Sačuvaj postojeće markere (pokupljeno, placeno, vozac) iz baze
          trenutniPolasci.forEach((dan, stariPodaci) {
            if (stariPodaci is Map && mergedPolasci.containsKey(dan)) {
              final danPolasci = mergedPolasci[dan] as Map<String, dynamic>;
              final stariDanPolasci = stariPodaci as Map<String, dynamic>;

              // Čuvaj vozačeve markere
              if (stariDanPolasci.containsKey('bc_pokupljeno')) {
                danPolasci['bc_pokupljeno'] = stariDanPolasci['bc_pokupljeno'];
              }
              if (stariDanPolasci.containsKey('bc_placeno')) {
                danPolasci['bc_placeno'] = stariDanPolasci['bc_placeno'];
              }
              if (stariDanPolasci.containsKey('vs_pokupljeno')) {
                danPolasci['vs_pokupljeno'] = stariDanPolasci['vs_pokupljeno'];
              }
              if (stariDanPolasci.containsKey('vs_placeno')) {
                danPolasci['vs_placeno'] = stariDanPolasci['vs_placeno'];
              }
              if (stariDanPolasci.containsKey('bc_pokupljeno_vozac')) {
                danPolasci['bc_pokupljeno_vozac'] = stariDanPolasci['bc_pokupljeno_vozac'];
              }
              if (stariDanPolasci.containsKey('vs_pokupljeno_vozac')) {
                danPolasci['vs_pokupljeno_vozac'] = stariDanPolasci['vs_pokupljeno_vozac'];
              }
            }
          });

          updates['polasci_po_danu'] = mergedPolasci;
        }
      }
    }

    // 🚫 PROVERA KAPACITETA - ako se menjaju termini
    if (!skipKapacitetCheck && updates.containsKey('polasci_po_danu')) {
      final polasciPoDanu = updates['polasci_po_danu'];
      if (polasciPoDanu != null && polasciPoDanu is Map) {
        // Dohvati broj_mesta i tip za proveru kapaciteta
        final currentData =
            await _supabase.from('registrovani_putnici').select('broj_mesta, tip').eq('id', id).single();
        final bm = updates['broj_mesta'] ?? currentData['broj_mesta'] ?? 1;
        final t = updates['tip'] ?? currentData['tip'];

        // Direktno koristi raw polasci_po_danu map za validaciju
        await _validateKapacitetForRawPolasci(Map<String, dynamic>.from(polasciPoDanu),
            brojMesta: bm is num ? bm.toInt() : 1, tipPutnika: t?.toString().toLowerCase());
      }
    }

    final response = await _supabase.from('registrovani_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    clearCache();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Ažurira mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik?> azurirajMesecnogPutnika(RegistrovaniPutnik putnik) async {
    try {
      final result = await updateRegistrovaniPutnik(putnik.id, putnik.toMap());
      return result;
    } catch (e) {
      rethrow; // Prebaci grešku da caller može da je uhvati
    }
  }

  /// Dodaje novog mesečnog putnika (legacy metoda name)
  Future<RegistrovaniPutnik> dodajMesecnogPutnika(
    RegistrovaniPutnik putnik, {
    bool skipKapacitetCheck = false,
  }) async {
    return await createRegistrovaniPutnik(putnik, skipKapacitetCheck: skipKapacitetCheck);
  }

  /// Ažurira plaćanje za mesec (vozacId je UUID)
  /// Koristi voznje_log za praćenje vožnji
  Future<bool> azurirajPlacanjeZaMesec(
    String putnikId,
    double iznos,
    String vozacIme, // 🔧 FIX: Sada prima IME vozača, ne UUID
    DateTime pocetakMeseca,
    DateTime krajMeseca,
  ) async {
    String? validVozacId;

    try {
      // Konvertuj ime vozača u UUID za foreign key kolonu
      if (vozacIme.isNotEmpty) {
        if (_isValidUuid(vozacIme)) {
          // Ako je već UUID, koristi ga
          validVozacId = vozacIme;
        } else {
          // Konvertuj ime u UUID
          try {
            await VozacMappingService.initialize();
            var converted = VozacMappingService.getVozacUuidSync(vozacIme);
            converted ??= await VozacMappingService.getVozacUuid(vozacIme);
            if (converted != null && _isValidUuid(converted)) {
              validVozacId = converted;
            }
          } catch (e) {
            debugPrint('❌ azurirajPlacanjeZaMesec: Greška pri VozacMapping za "$vozacIme": $e');
          }
        }
      }

      if (validVozacId == null) {
        debugPrint(
            '⚠️ azurirajPlacanjeZaMesec: vozacId je NULL za vozača "$vozacIme" - uplata neće biti u statistici!');
      }

      await VoznjeLogService.dodajUplatu(
        putnikId: putnikId,
        datum: DateTime.now(),
        iznos: iznos,
        vozacId: validVozacId,
        placeniMesec: pocetakMeseca.month,
        placenaGodina: pocetakMeseca.year,
        tipUplate: 'uplata_mesecna',
      );

      final now = DateTime.now();

      // ✅ Dohvati polasci_po_danu da bismo dodali plaćanje po danu
      final currentData =
          await _supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).single();

      // Odredi dan
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final danKratica = daniKratice[now.weekday - 1];

      // Parsiraj postojeći polasci_po_danu
      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasci = currentData['polasci_po_danu'];
      if (rawPolasci != null) {
        if (rawPolasci is String) {
          try {
            polasciPoDanu = Map<String, dynamic>.from(jsonDecode(rawPolasci));
          } catch (_) {}
        } else if (rawPolasci is Map) {
          polasciPoDanu = Map<String, dynamic>.from(rawPolasci);
        }
      }

      // Ažuriraj dan sa plaćanjem - jednostavno polje placeno_vozac (važi za ceo mesec)
      final dayData = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map? ?? {});
      dayData['placeno'] = now.toIso8601String();
      dayData['placeno_vozac'] = vozacIme; // Jedno polje za vozača
      dayData['placeno_iznos'] = iznos;
      polasciPoDanu[danKratica] = dayData;

      // ✅ FIX: NE MENJAJ vozac_id pri plaćanju!
      // Naplata i dodeljivanje putnika vozaču su dve RAZLIČITE stvari.
      // vozac_id se menja SAMO kroz DodeliPutnike ekran.

      // 💰 PLAĆANJE: Direktan UPDATE bez provere kapaciteta
      // Plaćanje ne menja termine, samo dodaje informaciju o uplati u polasci_po_danu JSON
      await _supabase.from('registrovani_putnici').update({
        'polasci_po_danu': polasciPoDanu,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);

      return true;
    } catch (e) {
      // 🔧 FIX: Baci exception sa pravom greškom da korisnik vidi šta je problem
      rethrow;
    }
  }

  /// Helper funkcija za validaciju UUID formata
  bool _isValidUuid(String str) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(str);
  }

  /// Briše mesečnog putnika (soft delete)
  Future<bool> obrisiRegistrovaniPutnik(String id) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'obrisan': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      clearCache();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Traži mesečne putnike po imenu, prezimenu ili broju telefona
  Future<List<RegistrovaniPutnik>> searchregistrovaniPutnici(String query) async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).or('putnik_ime.ilike.%$query%,broj_telefona.ilike.%$query%').order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata sva plaćanja za mesečnog putnika
  /// 🔄 POJEDNOSTAVLJENO: Koristi voznje_log + registrovani_putnici
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      List<Map<String, dynamic>> svaPlacanja = [];

      final putnik =
          await _supabase.from('registrovani_putnici').select('id, vozac_id').eq('putnik_ime', putnikIme).maybeSingle();

      if (putnik == null) return [];

      final placanjaIzLoga = await _supabase.from('voznje_log').select().eq('putnik_id', putnik['id']).inFilter(
          'tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna']).order('datum', ascending: false) as List<dynamic>;

      for (var placanje in placanjaIzLoga) {
        svaPlacanja.add({
          'cena': placanje['iznos'],
          'created_at': placanje['created_at'],
          'vozac_ime': await _getVozacImeByUuid(placanje['vozac_id'] as String?),
          'putnik_ime': putnikIme,
          'datum': placanje['datum'],
          'placeniMesec': placanje['placeni_mesec'],
          'placenaGodina': placanje['placena_godina'],
        });
      }

      return svaPlacanja;
    } catch (e) {
      return [];
    }
  }

  /// Dohvata sva plaćanja za mesečnog putnika po ID-u
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnikaById(String putnikId) async {
    try {
      final placanjaIzLoga = await _supabase.from('voznje_log').select().eq('putnik_id', putnikId).inFilter(
          'tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna']).order('datum', ascending: false) as List<dynamic>;

      List<Map<String, dynamic>> results = [];
      for (var placanje in placanjaIzLoga) {
        results.add({
          'cena': placanje['iznos'],
          'created_at': placanje['created_at'],
          // 'vozac_ime': await _getVozacImeByUuid(placanje['vozac_id'] as String?), // Preskočimo vozača za performanse ako nije potreban
          'datum': placanje['datum'],
          'placeniMesec': placanje['placeni_mesec'],
          'placenaGodina': placanje['placena_godina'],
        });
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Helper funkcija za dobijanje imena vozača iz UUID-a
  Future<String?> _getVozacImeByUuid(String? vozacUuid) async {
    if (vozacUuid == null || vozacUuid.isEmpty) return null;

    try {
      final response = await _supabase.from('vozaci').select('ime').eq('id', vozacUuid).single();
      return response['ime'] as String?;
    } catch (e) {
      return VozacMappingService.getVozacIme(vozacUuid);
    }
  }

  /// Dohvata zakupljene putnike za današnji dan
  /// 🔄 POJEDNOSTAVLJENO: Koristi registrovani_putnici direktno
  static Future<List<Map<String, dynamic>>> getZakupljenoDanas() async {
    try {
      final response = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('status', 'zakupljeno')
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('putnik_ime');

      return response.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream za realtime ažuriranja mesečnih putnika
  /// Koristi direktan Supabase Realtime
  Stream<List<RegistrovaniPutnik>> get registrovaniPutniciStream {
    return streamAktivniRegistrovaniPutnici();
  }

  /// Izračunava broj putovanja iz voznje_log
  static Future<int> izracunajBrojPutovanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'voznja');

      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  /// Izračunava broj otkazivanja iz voznje_log
  static Future<int> izracunajBrojOtkazivanjaIzIstorije(
    String mesecniPutnikId,
  ) async {
    try {
      final response =
          await supabase.from('voznje_log').select('datum').eq('putnik_id', mesecniPutnikId).eq('tip', 'otkazivanje');

      final jedinstveniDatumi = <String>{};
      for (final red in response) {
        if (red['datum'] != null) {
          jedinstveniDatumi.add(red['datum'] as String);
        }
      }

      return jedinstveniDatumi.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== ENHANCED CAPABILITIES ====================

  static final Map<String, dynamic> _cache = {};

  static void clearCache() {
    _cache.clear();
  }

  /// 🔍 Dobija vozača iz poslednjeg plaćanja za mesečnog putnika
  /// Koristi direktan Supabase stream
  static Stream<String?> streamVozacPoslednjegPlacanja(String putnikId) {
    return streamAktivniRegistrovaniPutnici().map((putnici) {
      try {
        final putnik = putnici.where((p) => p.id == putnikId).firstOrNull;
        if (putnik == null) return null;
        final vozacId = putnik.vozacId;
        if (vozacId != null && vozacId.isNotEmpty) {
          return VozacMappingService.getVozacImeWithFallbackSync(vozacId);
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }

  /// 🔥 Stream poslednjeg plaćanja za putnika (iz voznje_log)
  /// Vraća Map sa 'vozac_ime', 'datum' i 'iznos'
  static Stream<Map<String, dynamic>?> streamPoslednjePlacanje(String putnikId) async* {
    try {
      final response = await supabase
          .from('voznje_log')
          .select('datum, vozac_id, iznos')
          .eq('putnik_id', putnikId)
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna'])
          .order('datum', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        yield null;
        return;
      }

      final vozacId = response['vozac_id'] as String?;
      final datum = response['datum'] as String?;
      final iznos = (response['iznos'] as num?)?.toDouble() ?? 0.0;
      String? vozacIme;
      if (vozacId != null && vozacId.isNotEmpty) {
        vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacId);
      }

      yield {
        'vozac_ime': vozacIme,
        'datum': datum,
        'iznos': iznos,
      };
    } catch (_) {
      yield null;
    }
  }

  /// 💰 Dohvati UKUPNO plaćeno za putnika (svi uplate)
  static Future<double> dohvatiUkupnoPlaceno(String putnikId) async {
    try {
      final response = await supabase
          .from('voznje_log')
          .select('iznos')
          .eq('putnik_id', putnikId)
          .inFilter('tip', ['uplata', 'uplata_mesecna', 'uplata_dnevna']);

      double ukupno = 0.0;
      for (final row in response) {
        ukupno += (row['iznos'] as num?)?.toDouble() ?? 0.0;
      }
      return ukupno;
    } catch (_) {
      return 0.0;
    }
  }

  /// 🔧 SINGLETON STREAM za SVE mesečne putnike (uključujući neaktivne)
  static Stream<List<RegistrovaniPutnik>> streamSviRegistrovaniPutnici() {
    if (_sharedSviController != null && !_sharedSviController!.isClosed) {
      if (_lastSviValue != null) {
        Future.microtask(() {
          if (_sharedSviController != null && !_sharedSviController!.isClosed) {
            _sharedSviController!.add(_lastSviValue!);
          }
        });
      }
      return _sharedSviController!.stream;
    }

    _sharedSviController = StreamController<List<RegistrovaniPutnik>>.broadcast();

    _fetchAndEmitSvi(supabase);
    _setupRealtimeSubscriptionSvi(supabase);

    return _sharedSviController!.stream;
  }

  static Future<void> _fetchAndEmitSvi(SupabaseClient supabase) async {
    try {
      final data = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('obrisan', false) // Samo ovo je razlika - ne filtriramo po 'aktivan'
          .order('putnik_ime');

      final putnici = data.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
      _lastSviValue = putnici;

      if (_sharedSviController != null && !_sharedSviController!.isClosed) {
        _sharedSviController!.add(putnici);
      }
    } catch (_) {}
  }

  static void _setupRealtimeSubscriptionSvi(SupabaseClient supabase) {
    _sharedSviSubscription?.cancel();
    _sharedSviSubscription = RealtimeManager.instance.subscribe('registrovani_putnici_svi').listen((payload) {
      _fetchAndEmitSvi(supabase);
    });
  }
}
