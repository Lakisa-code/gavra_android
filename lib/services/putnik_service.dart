import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart' as globals_file;
import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/vozac_cache.dart';
import 'realtime/realtime_manager.dart';
import 'seat_request_service.dart';
import 'voznje_log_service.dart';
import 'vreme_vozac_service.dart';

class _StreamParams {
  _StreamParams({this.isoDate, this.grad, this.vreme});
  final String? isoDate;
  final String? grad;
  final String? vreme;
}

class PutnikService {
  SupabaseClient get supabase => globals_file.supabase;

  static const String registrovaniFields = '*, '
      'adresa_bc:adresa_bela_crkva_id(naziv), '
      'adresa_vs:adresa_vrsac_id(naziv)';

  // Obuhvata i join ka adrese tabeli za custom_adresa_id -> naziv
  static const String seatRequestSelectFields =
      '*, registrovani_putnici!inner($registrovaniFields), adrese:custom_adresa_id(naziv)';

  static final Map<String, StreamController<List<Putnik>>> _streams = {};
  static final Map<String, List<Putnik>> _lastValues = {};
  static final Map<String, _StreamParams> _streamParams = {};

  // 🌐 GLOBALNI SHARED LISTENER-I (jedan po tabeli, ne po stream key-u)
  static StreamSubscription? _globalSeatRequestsListener;
  static StreamSubscription? _globalVoznjeLogListener;
  static StreamSubscription? _globalRegistrovaniListener;
  static StreamSubscription? _globalVremeVozacListener;

  static void closeStream({String? isoDate, String? grad, String? vreme}) {
    final key = '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
    final controller = _streams[key];
    if (controller != null && !controller.isClosed) controller.close();
    _streams.remove(key);
    _lastValues.remove(key);
    _streamParams.remove(key);

    // ✅ Zatvori globalne listener-e ako nema više aktivnih streamova
    if (_streams.isEmpty) {
      _globalSeatRequestsListener?.cancel();
      _globalVoznjeLogListener?.cancel();
      _globalRegistrovaniListener?.cancel();
      _globalVremeVozacListener?.cancel();
      _globalSeatRequestsListener = null;
      _globalVoznjeLogListener = null;
      _globalRegistrovaniListener = null;
      _globalVremeVozacListener = null;
      debugPrint('🛑 [PutnikService] Svi streamovi zatvoreni - globalni listener-i otkazani');
    }
  }

  String _streamKey({String? isoDate, String? grad, String? vreme}) => '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';

  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({String? isoDate, String? grad, String? vreme}) {
    final key = _streamKey(isoDate: isoDate, grad: grad, vreme: vreme);
    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      final controller = _streams[key]!;
      if (_lastValues.containsKey(key)) {
        Future.microtask(() {
          if (!controller.isClosed) controller.add(_lastValues[key]!);
        });
      } else {
        _doFetchForStream(key, isoDate, grad, vreme, controller);
      }
      return controller.stream;
    }
    final controller = StreamController<List<Putnik>>.broadcast();
    _streams[key] = controller;
    _streamParams[key] = _StreamParams(isoDate: isoDate, grad: grad, vreme: vreme);
    _doFetchForStream(key, isoDate, grad, vreme, controller);
    controller.onCancel = () {
      _streams.remove(key);
      _lastValues.remove(key);
      _streamParams.remove(key);

      // ✅ Zatvori globalne listener-e ako nema više aktivnih streamova
      if (_streams.isEmpty) {
        _globalSeatRequestsListener?.cancel();
        _globalVoznjeLogListener?.cancel();
        _globalRegistrovaniListener?.cancel();
        _globalVremeVozacListener?.cancel();
        _globalSeatRequestsListener = null;
        _globalVoznjeLogListener = null;
        _globalRegistrovaniListener = null;
        _globalVremeVozacListener = null;
        debugPrint('🛑 [PutnikService] Svi streamovi zatvoreni - globalni listener-i otkazani');
      }
    };
    return controller.stream;
  }

  Stream<List<Putnik>> streamPutnici() {
    // 🆕 REDIREKCIJA NA IZVOR ISTINE (seat_requests)
    // Vikendom (subota/nedelja) koristi naredni ponedeljak
    final today = DateTime.now();
    final DateTime workingDate;
    if (today.weekday == DateTime.saturday) {
      workingDate = today.add(const Duration(days: 2));
    } else if (today.weekday == DateTime.sunday) {
      workingDate = today.add(const Duration(days: 1));
    } else {
      workingDate = today;
    }
    final todayDate = workingDate.toIso8601String().split('T')[0];
    return streamKombinovaniPutniciFiltered(isoDate: todayDate);
  }

  // UKLONJENO: _mergeSeatRequests - kolona polasci_po_danu više ne postoji

  Future<List<Putnik>> getPutniciByDayIso(String isoDate) async {
    try {
      final todayDate = isoDate.split('T')[0];

      final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {'p_datum': todayDate});

      final putnikIds = (reqs as List).map((r) => r['putnik_id'].toString()).toSet().toList();
      final registrovani = putnikIds.isNotEmpty
          ? await supabase.from('registrovani_putnici').select(registrovaniFields).inFilter('id', putnikIds)
          : [];
      final registrovaniMap = {for (var r in registrovani) r['id'].toString(): r};

      return reqs
          .map((r) {
            final map = _rpcToPutnikMap(r as Map<String, dynamic>);
            final rp = registrovaniMap[r['putnik_id']?.toString()];
            if (rp != null) map['registrovani_putnici'] = rp;
            return map;
          })
          .map((r) => Putnik.fromSeatRequest(r))
          .where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled')
          .toList();
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Error fetching by day: $e');
      return [];
    }
  }

  /// Konvertuje RPC rezultat u format koji Putnik.fromSeatRequest() razumije
  Map<String, dynamic> _rpcToPutnikMap(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    // seat_requests je izvor istine za operativno stanje
    // je_pokupljen i je_otkazan_iz_loga sada dolaze direktno iz seat_requests.status (via RPC)
    map['pokupljen_iz_loga'] = row['je_pokupljen'] == true;
    map['otkazano_iz_loga'] = row['je_otkazan_iz_loga'] == true;
    map['placeno_iz_loga'] = row['je_placen'] == true;
    if (row['iznos_placanja'] != null) {
      final raw = row['iznos_placanja'];
      map['cena'] = raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0;
    }
    if (row['pokupioVozac'] != null) map['pokupioVozac'] = row['pokupioVozac'];
    if (row['naplatioVozac'] != null) map['naplatioVozac'] = row['naplatioVozac'];
    if (row['otkazaoVozac'] != null) map['otkazaoVozac'] = row['otkazaoVozac'];
    if (row['log_created_at'] != null) {
      map['processed_at'] ??= row['log_created_at'];
    }
    // 'cancelled' normalizuj na 'otkazano' za konzistentnost u Flutter modelu
    if (map['status'] == 'cancelled') {
      map['status'] = 'otkazano';
    }
    return map;
  }

  Future<void> _doFetchForStream(
      String key, String? isoDate, String? grad, String? vreme, StreamController<List<Putnik>> controller) async {
    try {
      final todayDate = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];

      final gradNorm = grad == null ? null : GradAdresaValidator.normalizeGrad(grad).toLowerCase();
      final vremeNorm = vreme != null ? '${GradAdresaValidator.normalizeTime(vreme)}:00' : null;

      final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {
        'p_datum': todayDate,
        if (gradNorm != null) 'p_grad': gradNorm,
        if (vremeNorm != null) 'p_vreme': vremeNorm,
      });

      // Dohvati registrovani_putnici join podatke
      final putnikIds = (reqs as List).map((r) => r['putnik_id'].toString()).toSet().toList();
      final registrovani = putnikIds.isNotEmpty
          ? await supabase.from('registrovani_putnici').select(registrovaniFields).inFilter('id', putnikIds)
          : [];
      final registrovaniMap = {for (var r in registrovani) r['id'].toString(): r};

      final enriched = (reqs).map((r) {
        final map = _rpcToPutnikMap(r as Map<String, dynamic>);
        final rp = registrovaniMap[r['putnik_id']?.toString()];
        if (rp != null) map['registrovani_putnici'] = rp;
        return map;
      }).toList();

      final allMapped = enriched.map((r) => Putnik.fromSeatRequest(r)).toList();

      // 🐛 DEBUG: Prikaži placeno/je_placen za sve putnike
      for (final r in enriched) {
        final p = allMapped.firstWhere(
          (p) => p.requestId == r['id']?.toString(),
          orElse: () => allMapped.isNotEmpty ? allMapped.first : Putnik(ime: '?', grad: '?', polazak: '?', dan: '?'),
        );
        debugPrint(
          '💰 [DEBUG] ime=${r['registrovani_putnici']?['putnik_ime'] ?? '?'} '
          'status=${r['status']} je_placen=${r['je_placen']} '
          'iznos=${r['iznos_placanja']} cena=${r['cena']} '
          'placeno=${p.placeno} dan=${p.dan}',
        );
      }

      final results =
          allMapped.where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled').toList();

      debugPrint(
          '🔍 [_doFetchForStream] Stream key=$key, datum=$todayDate, grad=$grad, vreme=$vreme → ${results.length} putnika');

      _lastValues[key] = results;
      if (!controller.isClosed) controller.add(results);
      _setupRealtimeRefresh(key, isoDate, grad, vreme, controller);
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Error in stream fetch: $e');
      if (!controller.isClosed) controller.add([]);
    }
  }

  void _setupRealtimeRefresh(
      String key, String? isoDate, String? grad, String? vreme, StreamController<List<Putnik>> controller) {
    // 🌐 SETUP GLOBALNIH SHARED LISTENER-A (samo ako već nisu kreirani)

    // Listener za seat_requests - refreshuje SVE aktivne streamove
    if (_globalSeatRequestsListener == null) {
      _globalSeatRequestsListener = RealtimeManager.instance.subscribe('seat_requests').listen((payload) {
        debugPrint('🔄 [PutnikService] GLOBAL realtime UPDATE (seat_requests): ${payload.eventType}');
        _refreshAllActiveStreams();
      });
      debugPrint('✅ [PutnikService] Globalni seat_requests listener kreiran');
    }

    // Listener za voznje_log
    if (_globalVoznjeLogListener == null) {
      _globalVoznjeLogListener = RealtimeManager.instance.subscribe('voznje_log').listen((payload) async {
        debugPrint('🔄 [PutnikService] GLOBAL realtime UPDATE (voznje_log): ${payload.eventType}');
        // ✅ FIX: Dodaj mali delay da se eventual consistency resolvira
        await Future.delayed(const Duration(milliseconds: 500));
        _refreshAllActiveStreams();
      });
      debugPrint('✅ [PutnikService] Globalni voznje_log listener kreiran');
    }

    // Listener za registrovani_putnici
    if (_globalRegistrovaniListener == null) {
      _globalRegistrovaniListener = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
        debugPrint('🔄 [PutnikService] GLOBAL realtime UPDATE (registrovani_putnici): ${payload.eventType}');
        _refreshAllActiveStreams();
      });
      debugPrint('✅ [PutnikService] Globalni registrovani_putnici listener kreiran');
    }

    // Listener za vreme_vozac (individualne i termin dodele vozača)
    if (_globalVremeVozacListener == null) {
      _globalVremeVozacListener = RealtimeManager.instance.subscribe('vreme_vozac').listen((payload) async {
        debugPrint('🔄 [PutnikService] GLOBAL realtime UPDATE (vreme_vozac): ${payload.eventType}');
        // Refresh cache pa onda streamove da dodeljenVozac bude ažuran
        await VremeVozacService().refreshCacheFromDatabase();
        _refreshAllActiveStreams();
      });
      debugPrint('✅ [PutnikService] Globalni vreme_vozac listener kreiran');
    }
  }

  /// 🔄 Refreshuje SVE aktivne streamove
  void _refreshAllActiveStreams() {
    debugPrint('🔄 [PutnikService] _refreshAllActiveStreams: ${_streams.length} aktivnih streamova');
    for (final entry in _streams.entries) {
      final key = entry.key;
      final controller = entry.value;
      final params = _streamParams[key];
      if (params != null && !controller.isClosed) {
        debugPrint(
            '🔄 [PutnikService] Refreshujem stream: isoDate=${params.isoDate}, grad=${params.grad}, vreme=${params.vreme}');
        _doFetchForStream(key, params.isoDate, params.grad, params.vreme, controller);
      }
    }
  }

  /// 🔄 PUBLIC metoda za eksplicitno refresh-ovanje streamova (npr. posle dodavanja putnika)
  void refreshAllActiveStreams() {
    debugPrint('🔄 [PutnikService] Eksplicitan refresh svih aktivnih streamova');
    _refreshAllActiveStreams();
  }

  static final Map<String, DateTime> _lastActionTime = {};
  static bool _isDuplicateAction(String key) {
    final now = DateTime.now();
    if (_lastActionTime.containsKey(key) && now.difference(_lastActionTime[key]!) < const Duration(milliseconds: 500)) {
      return true;
    }
    _lastActionTime[key] = now;
    return false;
  }

  Future<Putnik?> getPutnikByName(String ime, {String? grad}) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {'p_datum': todayStr});
    // Filtriraj po imenu kroz registrovani_putnici join
    // Dohvati putnik_id po imenu
    final rpRes = await supabase.from('registrovani_putnici').select('id').eq('putnik_ime', ime).maybeSingle();
    if (rpRes == null) return null;
    final putnikId = rpRes['id'].toString();

    final match =
        (reqs as List).cast<Map<String, dynamic>>().where((r) => r['putnik_id']?.toString() == putnikId).firstOrNull;
    if (match != null) {
      final rp =
          await supabase.from('registrovani_putnici').select(registrovaniFields).eq('id', putnikId).maybeSingle();
      final map = _rpcToPutnikMap(match);
      if (rp != null) map['registrovani_putnici'] = rp;
      return Putnik.fromSeatRequest(map);
    }

    // Fallback na profil ako nema današnjeg zahteva
    final res =
        await supabase.from('registrovani_putnici').select(registrovaniFields).eq('putnik_ime', ime).maybeSingle();
    if (res == null) return null;
    return Putnik.fromRegistrovaniPutnici(res);
  }

  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {'p_datum': todayStr});
      final match = (reqs as List)
          .cast<Map<String, dynamic>>()
          .where((r) => r['putnik_id']?.toString() == id.toString())
          .firstOrNull;

      if (match != null) {
        final rp = await supabase.from('registrovani_putnici').select(registrovaniFields).eq('id', id).maybeSingle();
        final map = _rpcToPutnikMap(match);
        if (rp != null) map['registrovani_putnici'] = rp;
        return Putnik.fromSeatRequest(map);
      }

      final res = await supabase.from('registrovani_putnici').select(registrovaniFields).eq('id', id).limit(1);
      return res.isNotEmpty ? Putnik.fromRegistrovaniPutnici(res.first) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Putnik>> getPutniciByIds(List<dynamic> ids, {String? targetDan, String? isoDate}) async {
    if (ids.isEmpty) return [];
    try {
      final String danasStr = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];

      final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {'p_datum': danasStr});

      final idStrings = ids.map((id) => id.toString()).toSet();
      final filtered = (reqs as List).where((r) => idStrings.contains(r['putnik_id']?.toString())).toList();

      final putnikIds = filtered.map((r) => r['putnik_id'].toString()).toSet().toList();
      final registrovani = putnikIds.isNotEmpty
          ? await supabase.from('registrovani_putnici').select(registrovaniFields).inFilter('id', putnikIds)
          : [];
      final registrovaniMap = {for (var r in registrovani) r['id'].toString(): r};

      return filtered
          .map((r) {
            final map = _rpcToPutnikMap(r as Map<String, dynamic>);
            final rp = registrovaniMap[r['putnik_id']?.toString()];
            if (rp != null) map['registrovani_putnici'] = rp;
            return map;
          })
          .map((r) => Putnik.fromSeatRequest(r))
          .where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled')
          .toList();
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Error in getPutniciByIds: $e');
      return [];
    }
  }

  Future<List<Putnik>> getAllPutnici({String? targetDay, String? isoDate}) async {
    try {
      final String danasStr = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];

      final reqs = await supabase.rpc('get_putnoci_sa_statusom', params: {'p_datum': danasStr});

      final putnikIds = (reqs as List).map((r) => r['putnik_id'].toString()).toSet().toList();
      final registrovani = putnikIds.isNotEmpty
          ? await supabase.from('registrovani_putnici').select(registrovaniFields).inFilter('id', putnikIds)
          : [];
      final registrovaniMap = {for (var r in registrovani) r['id'].toString(): r};

      return reqs
          .map((r) {
            final map = _rpcToPutnikMap(r as Map<String, dynamic>);
            final rp = registrovaniMap[r['putnik_id']?.toString()];
            if (rp != null) map['registrovani_putnici'] = rp;
            return map;
          })
          .map((r) => Putnik.fromSeatRequest(r))
          .where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled')
          .toList();
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Error in getAllPutnici: $e');
      return [];
    }
  }

  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      final data = putnik.toRegistrovaniPutniciMap();
      if (putnik.id != null) {
        await supabase.from('registrovani_putnici').update(data).eq('id', putnik.id!);
      } else {
        await supabase.from('registrovani_putnici').insert(data);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dodajPutnika(Putnik putnik, {bool skipKapacitetCheck = false}) async {
    debugPrint('🔍 [PutnikService] dodajPutnika: ime="${putnik.ime}"');

    final res = await supabase
        .from('registrovani_putnici')
        .select('id, tip')
        .eq('putnik_ime', putnik.ime)
        .eq('aktivan', true)
        .eq('obrisan', false)
        .maybeSingle();

    debugPrint('🔍 [PutnikService] Query result: ${res != null ? "FOUND id=${res['id']}" : "NOT FOUND"}');

    if (res == null) {
      throw Exception('Putnik "${putnik.ime}" nije pronađen u bazi ili nije aktivan');
    }
    final putnikId = res['id'];

    await SeatRequestService.insertSeatRequest(
      putnikId: putnikId.toString(),
      dan: putnik.dan,
      vreme: putnik.polazak,
      grad: putnik.grad,
      brojMesta: putnik.brojMesta,
      status: 'confirmed', // Vozač ga je dodao ručno
      customAdresaId: putnik.adresaId,
    );
  }

  Future<void> obrisiPutnika(dynamic id) async {
    // Soft delete profile
    await supabase.from('registrovani_putnici').update({'obrisan': true}).eq('id', id);
  }

  Future<void> oznaciPokupljen(dynamic id, bool value,
      {String? grad, String? vreme, String? driver, String? datum, String? requestId}) async {
    if (_isDuplicateAction('pickup_$id')) return;
    if (!value) {
      return; // 🚫 "Undo" funkcija uklonjena - ne dozvoljavamo poništavanje pokupljenja
    }

    final targetDatum = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // ✅ DIREKTAN QUERY: Dohvati vozac_id iz baze umesto VozacMappingService
    String? vozacId;
    if (driver != null) {
      try {
        final vozacData = await supabase.from('vozaci').select('id').eq('ime', driver).maybeSingle();
        vozacId = vozacData?['id'] as String?;
      } catch (e) {
        debugPrint('⚠️ [oznaciPokupljen] Greška pri dohvatanju vozača "$driver": $e');
      }
    }

    // 1. Označi status='pokupljen' u seat_requests (operativno stanje)
    try {
      if (requestId != null && requestId.isNotEmpty) {
        await supabase.from('seat_requests').update({
          'status': 'pokupljen',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'processed_at': DateTime.now().toUtc().toIso8601String(),
          if (driver != null) 'pokupljeno_by': driver,
        }).eq('id', requestId);
        debugPrint('✅ [oznaciPokupljen] seat_requests status=pokupljen (requestId=$requestId)');
      } else {
        // Fallback: match po putnik_id + datum + grad + vreme (PRAVILO: DAN+GRAD+VREME)
        final gradKey = grad != null ? GradAdresaValidator.normalizeGrad(grad) : null;
        final vremeKey = vreme != null ? '${GradAdresaValidator.normalizeTime(vreme)}:00' : null;
        if (gradKey == null || vremeKey == null) {
          debugPrint('⛔ [oznaciPokupljen] Nedostaje grad ili vreme — ne mogu da označim pokupljenim bez DAN+GRAD+VREME!');
        } else {
          await supabase
              .from('seat_requests')
              .update({
                'status': 'pokupljen',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
                'processed_at': DateTime.now().toUtc().toIso8601String(),
                if (driver != null) 'pokupljeno_by': driver,
              })
              .eq('putnik_id', id.toString())
              .eq('datum', targetDatum)
              .eq('grad', gradKey)
              .eq('zeljeno_vreme', vremeKey);
          debugPrint('✅ [oznaciPokupljen] seat_requests status=pokupljen (datum=$targetDatum, grad=$gradKey, vreme=$vremeKey)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [oznaciPokupljen] Greška pri update seat_requests: $e');
    }

    // 2. Upiši u voznje_log (TRAJNI ZAPIS ZA STATISTIKU - nikad se ne briše)
    final existing = await VoznjeLogService.getLogEntry(
      putnikId: id.toString(),
      datum: targetDatum,
      tip: 'voznja',
      grad: grad,
      vreme: vreme,
    );

    if (existing == null) {
      await VoznjeLogService.logGeneric(
        tip: 'voznja',
        putnikId: id.toString(),
        vozacId: vozacId,
        vozacImeOverride: vozacId == null ? driver : null,
        datum: targetDatum,
        grad: grad,
        vreme: vreme,
      );
    }
  }

  /// 🏖️ POSTAVLJA PUTNIKA NA BOLOVANJE ILI GODIŠNJI
  /// Takođe otkazuje njegove vožnje u seat_requests za taj dan ili period
  Future<void> oznaciBolovanjeGodisnji(String putnikId, String status, String actor) async {
    try {
      // 1. Ažuriraj status putnika
      await supabase.from('registrovani_putnici').update({
        'status': status,
        'updated_at': nowToString(),
      }).eq('id', putnikId);

      // 2. Ako je na bolovanju/godišnjem, otkaži sve pending seat_requests za DANAS i SUTRA
      if (status == 'bolovanje' || status == 'godisnji') {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final sutra = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

        await supabase
            .from('seat_requests')
            .update({'status': 'cancelled', 'updated_at': nowToString()})
            .eq('putnik_id', putnikId)
            .inFilter('datum', [danas, sutra])
            .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

        debugPrint('🏖️ [PutnikService] Otkazane vožnje za putnika $putnikId (status: $status)');
      }
    } catch (e) {
      debugPrint('❌ [PutnikService] Error setting bolovanje/godisnji: $e');
      rethrow;
    }
  }

  String nowToString() => DateTime.now().toUtc().toIso8601String();

  Future<void> ukloniPolazak(
    dynamic id, {
    String? grad,
    String? vreme,
    String? selectedDan,
    String? selectedVreme,
    String? selectedGrad,
    String? datum,
    String? requestId,
  }) async {
    debugPrint('🗑️ [PutnikService] ukloniPolazak: id=$id, requestId=$requestId');

    // 1. PRIORITET: Match po requestId
    if (requestId != null && requestId.isNotEmpty) {
      try {
        final res = await supabase
            .from('seat_requests')
            .update({
              'status': 'bez_polaska',
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', requestId)
            .select();

        if (res.isNotEmpty) {
          debugPrint('🗑️ [PutnikService] ukloniPolazak SUCCESS (by requestId)');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [PutnikService] Error matching by requestId in ukloniPolazak: $e');
      }
    }

    // FALLBACK na stare parametre
    final finalDan = selectedDan;
    final finalVreme = selectedVreme ?? vreme;
    final finalGrad = selectedGrad ?? grad;

    final dateStr = datum ??
        (finalDan != null
            ? app_date_utils.DateUtils.getIsoDateForDay(finalDan)
            : DateTime.now().toIso8601String().split('T')[0]);

    final gradKey = GradAdresaValidator.normalizeGrad(finalGrad);
    final normalizedTime = GradAdresaValidator.normalizeTime(finalVreme);
    debugPrint('🗑️ [PutnikService] ukloniPolazak (fallback): dateStr=$dateStr, grad=$gradKey, time=$normalizedTime');

    try {
      if (normalizedTime.isNotEmpty) {
        // Pokušaj sa zeljeno_vreme
        var res = await supabase
            .from('seat_requests')
            .update({
              'status': 'bez_polaska',
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .eq('grad', gradKey)
            .eq('zeljeno_vreme', '$normalizedTime:00')
            .select();

        if (res.isNotEmpty) {
          debugPrint('🗑️ [PutnikService] ukloniPolazak SUCCESS (zeljeno_vreme): ${res.length} rows');
          return;
        }

        // Pokušaj sa dodeljeno_vreme
        res = await supabase
            .from('seat_requests')
            .update({
              'status': 'bez_polaska',
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .eq('grad', gradKey)
            .eq('dodeljeno_vreme', '$normalizedTime:00')
            .select();

        if (res.isNotEmpty) {
          debugPrint('🗑️ [PutnikService] ukloniPolazak SUCCESS (dodeljeno_vreme): ${res.length} rows');
          return;
        }
      }

      // Zadnji fallback: match bez vremena
      final res = await supabase
          .from('seat_requests')
          .update({
            'status': 'bez_polaska',
            'processed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .match({
            'putnik_id': id.toString(),
            'datum': dateStr,
          })
          .eq('grad', gradKey)
          .select();

      debugPrint('🗑️ [PutnikService] ukloniPolazak (fallback): updated ${res.length} rows');
    } catch (e) {
      debugPrint('❌ [PutnikService] ukloniPolazak ERROR: $e');
      rethrow;
    }
  }

  Future<void> otkaziPutnika(
    dynamic id,
    String? driver, {
    String? grad,
    String? vreme,
    String? selectedDan,
    String? selectedVreme,
    String? selectedGrad,
    String? datum,
    String? requestId,
    String status = 'otkazano',
  }) async {
    debugPrint('🛑 [PutnikService] otkaziPutnika: id=$id, requestId=$requestId, status=$status');

    // ✅ LOGOVANJE AKCIJE (sa gradom i vremenom za preciznost)
    try {
      String? vozacUuid;
      if (driver != null) {
        vozacUuid = VozacCache.getUuidByIme(driver);
      }

      await VoznjeLogService.logGeneric(
        tip: 'otkazivanje',
        putnikId: id.toString(),
        vozacId: vozacUuid,
        vozacImeOverride: vozacUuid == null ? driver : null, // 'Putnik', 'Admin', itd.
        grad: selectedGrad ?? grad,
        vreme: selectedVreme ?? vreme,
        datum: datum,
      );
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Greška pri logovanju otkazivanja: $e');
    }

    // 1. PRIORITET: Match po requestId
    if (requestId != null && requestId.isNotEmpty) {
      try {
        final res = await supabase
            .from('seat_requests')
            .update({
              'status': status,
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              if (driver != null) 'cancelled_by': driver,
            })
            .eq('id', requestId)
            .select();

        if (res.isNotEmpty) {
          debugPrint('🛑 [PutnikService] otkaziPutnika SUCCESS (by requestId)');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ [PutnikService] Error matching by requestId in otkaziPutnika: $e');
      }
    }

    final finalDan = selectedDan;
    final finalVreme = selectedVreme ?? vreme;
    final finalGrad = selectedGrad ?? grad;

    final dateStr = datum ??
        (finalDan != null
            ? app_date_utils.DateUtils.getIsoDateForDay(finalDan)
            : DateTime.now().toIso8601String().split('T')[0]);

    final gradKey = GradAdresaValidator.normalizeGrad(finalGrad);
    final normalizedTime = GradAdresaValidator.normalizeTime(finalVreme);
    debugPrint('🛑 [PutnikService] otkaziPutnika (fallback): dateStr=$dateStr, grad=$gradKey, time=$normalizedTime');

    try {
      if (normalizedTime.isNotEmpty) {
        // Pokušaj sa zeljeno_vreme
        var res = await supabase
            .from('seat_requests')
            .update({
              'status': status,
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              if (driver != null) 'cancelled_by': driver,
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .eq('grad', gradKey)
            .eq('zeljeno_vreme', '$normalizedTime:00')
            .select();

        if (res.isNotEmpty) {
          debugPrint('🛑 [PutnikService] otkaziPutnika SUCCESS (zeljeno_vreme)');
          return;
        }

        // Pokušaj sa dodeljeno_vreme
        res = await supabase
            .from('seat_requests')
            .update({
              'status': status,
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              if (driver != null) 'cancelled_by': driver,
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .eq('grad', gradKey)
            .eq('dodeljeno_vreme', '$normalizedTime:00')
            .select();

        if (res.isNotEmpty) {
          debugPrint('🛑 [PutnikService] otkaziPutnika SUCCESS (dodeljeno_vreme)');
          return;
        }
      }

      // ⛔ ZABRANJENO: fallback bez vremena narušava DAN+GRAD+VREME pravilo
      // Ako nije pronađen termin po zeljeno_vreme ni dodeljeno_vreme — logujemo grešku, NE diramo ništa
      debugPrint('⛔ [PutnikService] otkaziPutnika: nije pronađen termin za datum=$dateStr, grad=$gradKey, vreme=$normalizedTime — NE diram druge termine!');
    } catch (e) {
      debugPrint('❌ [PutnikService] otkaziPutnika ERROR: $e');
      rethrow;
    }
  }

  Future<void> oznaciPlaceno(
    dynamic id,
    num iznos,
    String? driver, {
    String? grad,
    String? selectedVreme,
    String? selectedDan,
    String? requestId, // 🆕 Dodato
  }) async {
    final danasStr = DateTime.now().toIso8601String().split('T')[0];
    final dateStr = selectedDan != null ? app_date_utils.DateUtils.getIsoDateForDay(selectedDan) : danasStr;

    // ✅ DIREKTAN QUERY: Dohvati vozac_id iz baze umesto VozacMappingService
    String? vozacId;
    if (driver != null) {
      try {
        final vozacData = await supabase.from('vozaci').select('id').eq('ime', driver).maybeSingle();
        vozacId = vozacData?['id'] as String?;
        debugPrint('💰 [oznaciPlaceno] driver="$driver" → vozacId=$vozacId');
      } catch (e) {
        debugPrint('⚠️ [oznaciPlaceno] Greška pri dohvatanju vozača "$driver": $e');
      }
    } else {
      debugPrint('⚠️ [oznaciPlaceno] driver je NULL!');
    }

    // 💰 Plaćanje se evidentira SAMO u voznje_log (izvor istine za finansije)
    // seat_requests.status se NE mijenja - 'pokupljen' ostaje 'pokupljen', 'confirmed' ostaje 'confirmed'
    // Dodaj u voznje_log preko servisa (sa gradom i vremenom za preciznost)
    await VoznjeLogService.dodajUplatu(
      putnikId: id.toString(),
      datum: DateTime.parse(dateStr),
      iznos: iznos.toDouble(),
      vozacId: vozacId,
      grad: grad,
      vreme: selectedVreme,
    );
  }

  Future<void> prebacijPutnikaVozacu(String id, String? vozac) async {
    String? vozacUuid;
    if (vozac != null) {
      vozacUuid = VozacCache.getUuidByIme(vozac);
    }
    await supabase
        .from('registrovani_putnici')
        .update({'vozac_id': vozacUuid, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  /// 🚫 GLOBALNO UKLONI POLAZAK: Postavlja 'bez_polaska' status za sve putnike u datom terminu
  Future<int> globalniBezPolaska({
    required String datum,
    required String grad,
    required String vreme,
  }) async {
    try {
      final gradKey = GradAdresaValidator.normalizeGrad(grad);

      var query = supabase.from('seat_requests').update({
        'status': 'bez_polaska',
        'processed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).match({
        'datum': datum,
      }).eq('grad', gradKey);

      if (vreme.isNotEmpty) {
        query = query.eq('zeljeno_vreme', '${GradAdresaValidator.normalizeTime(vreme)}:00');
      }

      final res = await query.select();
      debugPrint('🚫 [PutnikService] globalniBezPolaska: updated ${res.length} rows');
      return res.length;
    } catch (e) {
      debugPrint('❌ [PutnikService] globalniBezPolaska ERROR: $e');
      return 0;
    }
  }
}
