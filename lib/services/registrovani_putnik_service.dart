import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/day_constants.dart';
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
  static RealtimeChannel? _realtimeChannel;
  static List<RegistrovaniPutnik>? _lastValue;

  // 🔧 SINGLETON PATTERN za "SVI PUTNICI" stream (uključujući neaktivne)
  static StreamController<List<RegistrovaniPutnik>>? _sharedSviController;
  static StreamSubscription? _sharedSviSubscription;
  static List<RegistrovaniPutnik>? _lastSviValue;

  /// Dohvata sve mesečne putnike
  Future<List<RegistrovaniPutnik>> getAllRegistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('obrisan', false).eq('is_duplicate', false).order('putnik_ime');

    return response.map((json) => RegistrovaniPutnik.fromMap(json)).toList();
  }

  /// Dohvata aktivne mesečne putnike
  Future<List<RegistrovaniPutnik>> getAktivniregistrovaniPutnici() async {
    final response = await _supabase.from('registrovani_putnici').select('''
          *
        ''').eq('aktivan', true).eq('obrisan', false).eq('is_duplicate', false).order('putnik_ime');

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
        .eq('is_duplicate', false)
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

  /// Dohvata sve zahteve za sedište (seat_requests) za putnika u narednih 7 dana
  Future<List<Map<String, dynamic>>> getWeeklySeatRequests(String putnikId) async {
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];
    final nextWeekStr = now.add(const Duration(days: 7)).toIso8601String().split('T')[0];

    try {
      final response = await _supabase
          .from('seat_requests')
          .select()
          .eq('putnik_id', putnikId)
          .gte('datum', todayStr)
          .lte('datum', nextWeekStr);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ [RegistrovaniPutnikService] Greška pri dohvatanju nedeljnih zahteva: $e');
      return [];
    }
  }

  /// Dohvata mesečnog putnika po imenu (legacy compatibility)
  static Future<RegistrovaniPutnik?> getRegistrovaniPutnikByIme(String ime) async {
    try {
      final response = await supabase
          .from('registrovani_putnici')
          .select()
          .eq('putnik_ime', ime)
          .eq('obrisan', false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

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
      debugPrint('📊 [RegistrovaniPutnik] Osvežavanje liste putnika iz baze...');

      // 🔧 QUERY BEZ FOREIGN KEY LOOKUP - privremeno rešenje dok se ne doda FK u bazu
      final data = await supabase.from('registrovani_putnici').select(
            '*', // Bez join-a sa adresama - fetch-ovaćemo ih posebno ako treba
          );

      // Filtriraj lokalno umesto preko Supabase
      final putnici = data
          .where((json) {
            final aktivan = json['aktivan'] as bool? ?? false;
            final obrisan = json['obrisan'] as bool? ?? false; // 🛡️ FIX: Default je false (nije obrisan)
            final isDuplicate = json['is_duplicate'] as bool? ?? false;
            return aktivan && !obrisan && !isDuplicate;
          })
          .map((json) => RegistrovaniPutnik.fromMap(json))
          .toList()
        ..sort((a, b) => a.putnikIme.compareTo(b.putnikIme));

      debugPrint('✅ [RegistrovaniPutnik] Učitano ${putnici.length} putnika (nakon filtriranja)');

      _lastValue = putnici;

      if (_sharedController != null && !_sharedController!.isClosed) {
        _sharedController!.add(putnici);
        debugPrint('🔊 [RegistrovaniPutnik] Stream emitovao listu sa ${putnici.length} putnika');
      } else {
        debugPrint('⚠️ [RegistrovaniPutnik] Controller nije dostupan ili je zatvoren');
      }
    } catch (e) {
      debugPrint('🔴 [RegistrovaniPutnik] Error fetching passengers: $e');
    }
  }

  /// 🔌 Setup realtime subscription - Koristi payload za partial updates
  static void _setupRealtimeSubscription(SupabaseClient supabase) {
    _sharedSubscription?.cancel();

    debugPrint('🔗 [RegistrovaniPutnik] Setup realtime subscription...');
    // Koristi centralizovani RealtimeManager
    _sharedSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
      debugPrint('🔄 [RegistrovaniPutnik] Payload primljen: ${payload.eventType}');
      unawaited(_handleRealtimeUpdate(payload));
    }, onError: (error) {
      debugPrint('❌ [RegistrovaniPutnik] Stream error: $error');
    });
    debugPrint('✅ [RegistrovaniPutnik] Realtime subscription postavljena');
  }

  /// 🔄 Handle realtime update koristeći payload umesto full refetch
  static Future<void> _handleRealtimeUpdate(PostgresChangePayload payload) async {
    if (_lastValue == null) {
      debugPrint('⚠️ [RegistrovaniPutnik] Nema inicijalne vrednosti, preskačem update');
      return;
    }

    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        await _handleInsert(newRecord);
        break;
      case PostgresChangeEvent.update:
        await _handleUpdate(newRecord, oldRecord);
        break;
      default:
        debugPrint('⚠️ [RegistrovaniPutnik] Nepoznat event type: ${payload.eventType}');
        break;
    }
  }

  /// ➕ Handle INSERT event
  static Future<void> _handleInsert(Map<String, dynamic> newRecord) async {
    try {
      final putnikId = newRecord['id'] as String?;
      if (putnikId == null) return;

      // Proveri da li zadovoljava filter kriterijume (aktivan, nije obrisan, nije duplikat)
      final aktivan = newRecord['aktivan'] as bool? ?? false;
      final obrisan = newRecord['obrisan'] as bool? ?? false; // 🛡️ FIX: Default je false
      final isDuplicate = newRecord['is_duplicate'] as bool? ?? false;

      if (!aktivan || obrisan || isDuplicate) {
        debugPrint('🔄 [RegistrovaniPutnik] INSERT ignorisan (ne zadovoljava filter)');
        return;
      }

      // Dohvati potpune podatke BEZ JOIN-a (privremeno)
      final fullData = await supabase
          .from('registrovani_putnici')
          .select('*') // Bez foreign key lookup
          .eq('id', putnikId)
          .single();

      final putnik = RegistrovaniPutnik.fromMap(fullData);

      // Dodaj u listu i sortiraj
      _lastValue!.add(putnik);
      _lastValue!.sort((a, b) => a.putnikIme.compareTo(b.putnikIme));

      debugPrint('✅ [RegistrovaniPutnik] INSERT: Dodan ${putnik.putnikIme}');
      _emitUpdate();
    } catch (e) {
      debugPrint('❌ [RegistrovaniPutnik] INSERT error: $e');
    }
  }

  /// 🔄 Handle UPDATE event
  static Future<void> _handleUpdate(Map<String, dynamic> newRecord, Map<String, dynamic>? oldRecord) async {
    try {
      final putnikId = newRecord['id'] as String?;
      if (putnikId == null) return;

      final index = _lastValue!.indexWhere((p) => p.id == putnikId);

      // Proveri da li sada zadovoljava filter kriterijume
      final aktivan = newRecord['aktivan'] as bool? ?? false;
      final obrisan = newRecord['obrisan'] as bool? ?? false; // 🛡️ FIX: Default je false
      final isDuplicate = newRecord['is_duplicate'] as bool? ?? false;
      final shouldBeIncluded = aktivan && !obrisan && !isDuplicate;

      if (shouldBeIncluded) {
        // Dohvati potpune podatke sa JOIN-om
        final fullData = await supabase
            .from('registrovani_putnici')
            .select('*') // Bez foreign key lookup
            .eq('id', putnikId)
            .single();

        final updatedPutnik = RegistrovaniPutnik.fromMap(fullData);

        if (index == -1) {
          // Možda je bio neaktivan, a sada je aktivan - dodaj
          _lastValue!.add(updatedPutnik);
          debugPrint('✅ [RegistrovaniPutnik] UPDATE: Dodan ${updatedPutnik.putnikIme} (sada aktivan)');
        } else {
          // Update postojeći
          _lastValue![index] = updatedPutnik;
          debugPrint('✅ [RegistrovaniPutnik] UPDATE: Ažuriran ${updatedPutnik.putnikIme}');
        }
        _lastValue!.sort((a, b) => a.putnikIme.compareTo(b.putnikIme));
      } else {
        // Ukloni iz liste ako postoji
        if (index != -1) {
          final putnik = _lastValue![index];
          _lastValue!.removeAt(index);
          debugPrint('✅ [RegistrovaniPutnik] UPDATE: Uklonjen ${putnik.putnikIme} (više ne zadovoljava filter)');
        }
      }

      _emitUpdate();
    } catch (e) {
      debugPrint('❌ [RegistrovaniPutnik] UPDATE error: $e');
    }
  }

  /// 🔊 Emit update u stream
  static void _emitUpdate() {
    if (_sharedController != null && !_sharedController!.isClosed) {
      _sharedController!.add(List.from(_lastValue!));
      debugPrint('🔊 [RegistrovaniPutnik] Stream emitovao update sa ${_lastValue!.length} putnika');
    }
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
  /// ✅ FIX: Ignoriši duplikate i obrisane putnike
  Future<RegistrovaniPutnik?> findByPhone(String telefon) async {
    if (telefon.isEmpty) return null;

    final normalizedInput = _normalizePhone(telefon);

    // Dohvati samo ORIGINALNE (ne-duplicirane) putnike koji nisu obrisani
    final allPutnici =
        await _supabase.from('registrovani_putnici').select().eq('obrisan', false).eq('is_duplicate', false);

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
      final rawPolasci = putnikMap['polasci_po_danu'];
      Map<String, dynamic>? polasci;
      if (rawPolasci is Map) {
        polasci = Map<String, dynamic>.from(rawPolasci);
      }

      if (polasci != null) {
        await _validateKapacitetForRawPolasci(polasci, brojMesta: putnik.brojMesta, tipPutnika: putnik.tip);
      }
    }

    final response = await _supabase.from('registrovani_putnici').insert(putnikMap).select('''
          *
        ''').single();

    return RegistrovaniPutnik.fromMap(response);
  }

  /// 🚫 Validira da ima slobodnih mesta za sve termine putnika
  /// Prima raw polasci_po_danu map iz baze (format: { "pon": { "bc": "8:00", "vs": null }, ... })
  Future<void> _validateKapacitetForRawPolasci(Map<String, dynamic> polasciPoDanu,
      {int brojMesta = 1, String? tipPutnika, String? excludeId}) async {
    if (polasciPoDanu.isEmpty) return;

    final danas = DateTime.now();
    final currentWeekday = danas.weekday;
    const daniMap = {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7};
    final daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];

    // Proveri svaki dan koji putnik ima definisan
    for (final danKratica in daniKratice) {
      final danData = polasciPoDanu[danKratica];
      if (danData == null || danData is! Map) continue;

      final targetWeekday = daniMap[danKratica] ?? 1;

      // 🚫 PRESKOČI PROVERU ZA PRETHODNE DANE U NEDELJI (FIX korisničkog zahteva)
      // Ako je danas utorak, ne proveravaj ponedeljak jer je taj polazak već prošao
      // i admin ne želi da bude blokiran ako je juče bio pun bus.
      if (targetWeekday < currentWeekday) {
        continue;
      }

      // Proveri BC polazak
      final bcVreme = _getVremeFromDanData(danData, 'bc');
      if (bcVreme != null) {
        await _checkKapacitet(danKratica, 'BC', bcVreme, danas, tipPutnika, brojMesta, excludeId);
      }

      // Proveri BC2 (Zimski) polazak
      final bc2Vreme = _getVremeFromDanData(danData, 'bc2');
      if (bc2Vreme != null) {
        await _checkKapacitet(danKratica, 'BC', bc2Vreme, danas, tipPutnika, brojMesta, excludeId, labels: '(Zimski)');
      }

      // Proveri VS polazak
      final vsVreme = _getVremeFromDanData(danData, 'vs');
      if (vsVreme != null) {
        await _checkKapacitet(danKratica, 'VS', vsVreme, danas, tipPutnika, brojMesta, excludeId);
      }

      // Proveri VS2 (Zimski) polazak
      final vs2Vreme = _getVremeFromDanData(danData, 'vs2');
      if (vs2Vreme != null) {
        await _checkKapacitet(danKratica, 'VS', vs2Vreme, danas, tipPutnika, brojMesta, excludeId, labels: '(Zimski)');
      }
    }
  }

  String? _getVremeFromDanData(Map<dynamic, dynamic> danData, String key) {
    final value = danData[key];
    if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
      return value.toString();
    }
    return null;
  }

  Future<void> _checkKapacitet(String danKratica, String grad, String vreme, DateTime danas, String? tipPutnika,
      int brojMesta, String? excludeId,
      {String labels = ''}) async {
    final targetDate = _getNextDateForDay(danas, danKratica);
    final datumStr = targetDate.toIso8601String().split('T')[0];
    final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);

    final imaMesta = await SlobodnaMestaService.imaSlobodnihMesta(grad, normalizedVreme,
        datum: datumStr, tipPutnika: tipPutnika, brojMesta: brojMesta, excludeId: excludeId);

    if (!imaMesta) {
      final danPunoIme = _getDanPunoIme(danKratica);
      throw Exception(
        'NEMA SLOBODNIH MESTA!\n\n'
        'Termin: $danPunoIme u $vreme $labels ($grad)\n'
        'Kapacitet je popunjen.\n\n'
        'Izaberite drugi termin ili kontaktirajte admina.',
      );
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
    final index = DayConstants.dayAbbreviations.indexOf(kratica.toLowerCase());
    if (index >= 0) {
      return DayConstants.dayNamesInternal[index];
    }
    return kratica;
  }

  /// Ažurira mesečnog putnika
  /// Proverava kapacitet ako se menjaju termini (polasci_po_danu)
  Future<RegistrovaniPutnik> updateRegistrovaniPutnik(
    String id,
    Map<String, dynamic> updates, {
    bool skipKapacitetCheck = false,
  }) async {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    // 🛡️ MERGE SA POSTOJEĆIM MARKERIMA U BAZI (bc_pokupljeno, bc_placeno, itd.)
    if (updates.containsKey('polasci_po_danu')) {
      final noviPolasci = updates['polasci_po_danu'];
      if (noviPolasci != null && noviPolasci is Map) {
        // Čitaj trenutno stanje iz baze
        final trenutnoStanje =
            await _supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', id).limit(1).maybeSingle();

        if (trenutnoStanje == null) {
          debugPrint('🔴 [RegistrovaniPutnikService] Passenger not found: $id');
          throw Exception('Putnik sa ID-om $id nije pronađen');
        }

        final rawPolasciDB = trenutnoStanje['polasci_po_danu'];
        Map<String, dynamic>? trenutniPolasci;

        if (rawPolasciDB is Map) {
          trenutniPolasci = Map<String, dynamic>.from(rawPolasciDB);
        }

        if (trenutniPolasci != null) {
          // Merge novi polasci sa postojećim markerima
          final mergedPolasci = <String, dynamic>{};

          // 1. Prvo kopiraj SVE što je trenutno u bazi (da ne bismo izgubili npr. subotu/nedelju)
          trenutniPolasci.forEach((dan, stariPodaci) {
            if (stariPodaci is Map) {
              mergedPolasci[dan] = Map<String, dynamic>.from(stariPodaci);
            } else {
              mergedPolasci[dan] = stariPodaci;
            }
          });

          // 2. Preklopi sa novim podacima iz dijaloga
          noviPolasci.forEach((dan, noviPodaci) {
            if (noviPodaci is Map) {
              final postojeciPodaciZaDan = mergedPolasci[dan] is Map
                  ? Map<String, dynamic>.from(mergedPolasci[dan] as Map)
                  : <String, dynamic>{};

              final Map<String, dynamic> noviPodaciMap = Map<String, dynamic>.from(noviPodaci);

              // Ažuriraj samo polaske, zadrži markere ako su postojali
              postojeciPodaciZaDan['bc'] = noviPodaciMap['bc'];
              postojeciPodaciZaDan['vs'] = noviPodaciMap['vs'];
              postojeciPodaciZaDan['bc2'] = noviPodaciMap['bc2'];
              postojeciPodaciZaDan['vs2'] = noviPodaciMap['vs2'];

              // Ako je polazak obrisan (null), obriši i markere vezane za taj polazak
              if (noviPodaciMap['bc'] == null) {
                postojeciPodaciZaDan.remove('bc_pokupljeno');
                postojeciPodaciZaDan.remove('bc_pokupljeno_vozac');
                postojeciPodaciZaDan.remove('bc_status');
              }
              if (noviPodaciMap['bc2'] == null) {
                postojeciPodaciZaDan.remove('bc2_pokupljeno');
                postojeciPodaciZaDan.remove('bc2_status');
              }
              if (noviPodaciMap['vs'] == null) {
                postojeciPodaciZaDan.remove('vs_pokupljeno');
                postojeciPodaciZaDan.remove('vs_pokupljeno_vozac');
                postojeciPodaciZaDan.remove('vs_status');
              }
              if (noviPodaciMap['vs2'] == null) {
                postojeciPodaciZaDan.remove('vs2_pokupljeno');
                postojeciPodaciZaDan.remove('vs2_status');
              }

              mergedPolasci[dan] = postojeciPodaciZaDan;
            } else {
              mergedPolasci[dan] = noviPodaci;
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
            await _supabase.from('registrovani_putnici').select('broj_mesta, tip').eq('id', id).limit(1).maybeSingle();

        if (currentData == null) {
          debugPrint('🔴 [RegistrovaniPutnikService] Passenger not found for capacity check: $id');
          throw Exception('Putnik sa ID-om $id nije pronađen za proveru kapaciteta');
        }
        final bm = updates['broj_mesta'] ?? currentData['broj_mesta'] ?? 1;
        final t = updates['tip'] ?? currentData['tip'];

        // Direktno koristi raw polasci_po_danu map za validaciju
        await _validateKapacitetForRawPolasci(Map<String, dynamic>.from(polasciPoDanu),
            brojMesta: bm is num ? bm.toInt() : 1, tipPutnika: t?.toString().toLowerCase(), excludeId: id);
      }
    }

    final response = await _supabase.from('registrovani_putnici').update(updates).eq('id', id).select('''
          *
        ''').single();

    // 🆕 SINHRONIZACIJA SA SEAT_REQUESTS (Single Source of Truth)
    // Ako admin menja vremena u šablonu, moramo ažurirati i aktivne zahteve za tu nedelju
    if (updates.containsKey('polasci_po_danu')) {
      try {
        await _syncSeatRequestsWithTemplate(id, Map<String, dynamic>.from(updates['polasci_po_danu']));
      } catch (e) {
        debugPrint('⚠️ [RegistrovaniPutnikService] Greška pri sinhronizaciji seat_requests: $e');
      }
    }

    return RegistrovaniPutnik.fromMap(response);
  }

  /// 🔄 Sinhronizuje aktivne seat_requests sa novim stanjem šablona
  /// Ovo osigurava da Adminove promene u dijalogu odmah vidi i putnik.
  /// 🆕 PROŠIRENO: Ažurira sve buduće zahteve, ne samo za narednih 7 dana.
  Future<void> _syncSeatRequestsWithTemplate(String putnikId, Map<String, dynamic> noviPolasci) async {
    final now = DateTime.now();
    // Počni od danas (da ne menjamo istoriju)
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

    // 1. Dohvati SVE buduće aktivne zahteve (ne samo sledećih 7 dana)
    // Ovo rešava problem kada admin testira za buduće mesece (npr. februar 2026)
    final requests = await _supabase
        .from('seat_requests')
        .select()
        .eq('putnik_id', putnikId)
        .gte('datum', todayStr)
        .filter('status', 'in', '("pending", "manual", "approved", "confirmed", "rejected")');

    for (final req in requests) {
      final datumStr = req['datum'] as String;
      final grad = (req['grad'] ?? '').toString().toLowerCase(); // 'bc' ili 'vs'
      final region = (grad == 'bc' || grad == 'bela crkva') ? 'bc' : 'vs';

      final datum = DateTime.parse(datumStr);
      final daniNedelje = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final dan = daniNedelje[datum.weekday - 1];

      final noviPodaciZaDan = noviPolasci[dan];
      if (noviPodaciZaDan != null && noviPodaciZaDan is Map) {
        final novoVremeStr = noviPodaciZaDan[region]?.toString();

        if (novoVremeStr != null && novoVremeStr.isNotEmpty && novoVremeStr != 'null') {
          // Ažuriraj vreme u seat_requests da se poklapa sa onim što je Admin postavio
          // I postavi status na 'confirmed'
          await _supabase.from('seat_requests').update({
            'zeljeno_vreme': '$novoVremeStr:00',
            'status': 'confirmed',
            'processed_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', req['id']);
        } else {
          // Ako je Admin obrisao vreme u dijalogu (null ili empty), otkaži seat_request
          await _supabase.from('seat_requests').update({
            'status': 'otkazano',
            'processed_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', req['id']);
        }
      }
    }
  }

  /// Toggle aktivnost mesečnog putnika
  Future<bool> toggleAktivnost(String id, bool aktivnost) async {
    try {
      await _supabase.from('registrovani_putnici').update({
        'aktivan': aktivnost,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

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
      final currentData = await _supabase
          .from('registrovani_putnici')
          .select('polasci_po_danu')
          .eq('id', putnikId)
          .limit(1)
          .maybeSingle();

      if (currentData == null) {
        debugPrint('🔴 [RegistrovaniPutnikService] Passenger not found for logging: $putnikId');
        return false;
      }

      // Odredi dan
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final danKratica = daniKratice[now.weekday - 1];

      // Parsiraj postojeći polasci_po_danu
      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasci = currentData['polasci_po_danu'];
      if (rawPolasci != null) {
        if (rawPolasci is Map) {
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

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
      final response = await _supabase.from('vozaci').select('ime').eq('id', vozacUuid).limit(1).maybeSingle();
      if (response == null) {
        return VozacMappingService.getVozacIme(vozacUuid);
      }
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
    } catch (e) {
      debugPrint('⚠️ Error yielding vozac info: $e');
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
    } catch (e) {
      debugPrint('⚠️ Error calculating total payment: $e');
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
