import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart' as globals_file;
import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';
import 'seat_request_service.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart';

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

  static final Map<String, StreamController<List<Putnik>>> _streams = {};
  static final Map<String, List<Putnik>> _lastValues = {};
  static final Map<String, _StreamParams> _streamParams = {};

  // 🌐 GLOBALNI SHARED LISTENER-I (jedan po tabeli, ne po stream key-u)
  static StreamSubscription? _globalSeatRequestsListener;
  static StreamSubscription? _globalVoznjeLogListener;
  static StreamSubscription? _globalRegistrovaniListener;

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
      _globalSeatRequestsListener = null;
      _globalVoznjeLogListener = null;
      _globalRegistrovaniListener = null;
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
        _globalSeatRequestsListener = null;
        _globalVoznjeLogListener = null;
        _globalRegistrovaniListener = null;
        debugPrint('🛑 [PutnikService] Svi streamovi zatvoreni - globalni listener-i otkazani');
      }
    };
    return controller.stream;
  }

  Stream<List<Putnik>> streamPutnici() {
    // 🆕 REDIREKCIJA NA IZVOR ISTINE (seat_requests)
    // Koristi samo datum (YYYY-MM-DD) za ključ, ne puni ISO sa vremenom
    final todayDate = DateTime.now().toIso8601String().split('T')[0];
    return streamKombinovaniPutniciFiltered(isoDate: todayDate);
  }

  // UKLONJENO: _mergeSeatRequests - kolona polasci_po_danu više ne postoji

  Future<List<Putnik>> getPutniciByDayIso(String isoDate) async {
    try {
      final todayDate = isoDate.split('T')[0];

      final reqs = await supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .eq('datum', todayDate)
          .inFilter('status',
              ['pending', 'manual', 'approved', 'confirmed', 'otkazano', 'cancelled', 'bez_polaska', 'hidden']);

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logData = await VoznjeLogService.getPickedUpLogData(datumStr: todayDate);
      _enrichWithLogData(reqs as List, logData);

      return (reqs as List)
          .map((r) => Putnik.fromSeatRequest(r as Map<String, dynamic>))
          .where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled')
          .toList();
    } catch (e) {
      debugPrint('⚠️ [PutnikService] Error fetching by day: $e');
      return [];
    }
  }

  Future<void> _doFetchForStream(
      String key, String? isoDate, String? grad, String? vreme, StreamController<List<Putnik>> controller) async {
    try {
      final todayDate = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];

      var query = supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .eq('datum', todayDate)
          .inFilter('status',
              ['pending', 'manual', 'approved', 'confirmed', 'otkazano', 'cancelled', 'bez_polaska', 'hidden']);

      if (grad != null) {
        query = query.ilike('grad', grad.toLowerCase() == 'vrsac' || grad.toLowerCase() == 'vršac' ? 'vs' : 'bc');
      }

      if (vreme != null) {
        query = query.eq('zeljeno_vreme', '${GradAdresaValidator.normalizeTime(vreme)}:00');
      }

      final reqs = await query;

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logData = await VoznjeLogService.getPickedUpLogData(datumStr: todayDate);
      _enrichWithLogData(reqs as List, logData);

      final results = (reqs as List)
          .map((r) => Putnik.fromSeatRequest(r as Map<String, dynamic>))
          .where((p) => p.status != 'bez_polaska' && p.status != 'hidden' && p.status != 'cancelled')
          .toList();

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

    // 🆕 SSOT: Prvo proveri u seat_requests za danas
    final seatReq = await supabase
        .from('seat_requests')
        .select('*, registrovani_putnici!inner($registrovaniFields)')
        .eq('registrovani_putnici.putnik_ime', ime)
        .eq('datum', todayStr)
        .maybeSingle();

    if (seatReq != null) {
      final todayDate = DateTime.now().toIso8601String().split('T')[0];
      final logData = await VoznjeLogService.getPickedUpLogData(datumStr: todayDate);
      final data = Map<String, dynamic>.from(seatReq as Map);
      _enrichWithLogData([data], logData);
      return Putnik.fromSeatRequest(data);
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

      // 🆕 SSOT: Prvo proveri u seat_requests za danas
      final seatReq = await supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .eq('putnik_id', id)
          .eq('datum', todayStr)
          .maybeSingle();

      if (seatReq != null) {
        final logData = await VoznjeLogService.getPickedUpLogData(datumStr: todayStr);
        final data = Map<String, dynamic>.from(seatReq);
        _enrichWithLogData([data], logData);
        return Putnik.fromSeatRequest(data);
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

      // 🔄 RELACIONALNI FETCH: Dohvati iz seat_requests za ove putnike i datum
      final res = await supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .inFilter('putnik_id', ids.map((id) => id.toString()).toList())
          .eq('datum', danasStr)
          .inFilter('status',
              ['pending', 'manual', 'approved', 'confirmed', 'otkazano', 'cancelled', 'bez_polaska', 'hidden']);

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logData = await VoznjeLogService.getPickedUpLogData(datumStr: danasStr);
      _enrichWithLogData(res as List, logData);

      return (res as List)
          .map((row) => Putnik.fromSeatRequest(row as Map<String, dynamic>))
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

      // 🔄 RELACIONALNI FETCH: Dohvati SVE aktivne zahteve za datum
      final res = await supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .eq('datum', danasStr)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed', 'otkazano', 'cancelled']);

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logDataAll = await VoznjeLogService.getPickedUpLogData(datumStr: danasStr);
      _enrichWithLogData(res as List, logDataAll);

      return (res as List)
          .map((row) => Putnik.fromSeatRequest(row as Map<String, dynamic>))
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
      customAdresa: putnik.adresa,
      customAdresaId: putnik.adresaId,
    );
  }

  Future<void> obrisiPutnika(dynamic id) async {
    // Soft delete profile
    await supabase.from('registrovani_putnici').update({'obrisan': true}).eq('id', id);
  }

  Future<void> oznaciPokupljen(dynamic id, bool value,
      {String? grad, String? vreme, String? driver, String? datum}) async {
    if (_isDuplicateAction('pickup_$id')) return;
    if (!value) {
      return; // 🚫 "Undo" funkcija uklonjena - ne dozvoljavamo poništavanje pokupljenja
    }

    final targetDatum = datum ?? DateTime.now().toIso8601String().split('T')[0];

    // Ažuriraj seat_requests - postavi status confirmed/approved
    String? vozacId;
    if (driver != null) {
      vozacId = await VozacMappingService.getVozacUuid(driver);
    }

    // ✅ OZNAČI KAO POKUPLJEN (Samo u vozač_log, po zahtevu korisnika)
    // Proveri da li već postoji unos za ovog putnika za ovaj datum/grad/vreme
    final existing = await VoznjeLogService.getLogEntry(
      putnikId: id.toString(),
      datum: targetDatum,
      tip: 'voznja',
      grad: grad,
      vreme: vreme,
    );

    if (existing == null) {
      // Nema postojećeg unosa, upiši novi preko servisa
      await VoznjeLogService.logGeneric(
        tip: 'voznja',
        putnikId: id.toString(),
        vozacId: vozacId,
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

    final isVrsac = (finalGrad?.toLowerCase().contains('vr') ?? false) || (finalGrad?.toLowerCase() == 'vs');
    final gradVariants = isVrsac ? ['vs', 'VS', 'Vršac', 'Vrsac', 'VRŠAC'] : ['bc', 'BC', 'Bela Crkva', 'BELA CRKVA'];

    final normalizedTime = GradAdresaValidator.normalizeTime(finalVreme);
    debugPrint(
        '🗑️ [PutnikService] ukloniPolazak (fallback): dateStr=$dateStr, gradVariants=$gradVariants, time=$normalizedTime');

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
            .inFilter('grad', gradVariants)
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
            .inFilter('grad', gradVariants)
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
          .inFilter('grad', gradVariants)
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
        vozacUuid = await VozacMappingService.getVozacUuid(driver);
      }

      await VoznjeLogService.logGeneric(
        tip: 'otkazivanje',
        putnikId: id.toString(),
        vozacId: vozacUuid,
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

    final isVrsac = (finalGrad?.toLowerCase().contains('vr') ?? false) || (finalGrad?.toLowerCase() == 'vs');
    final gradVariants = isVrsac ? ['vs', 'VS', 'Vršac', 'Vrsac', 'VRŠAC'] : ['bc', 'BC', 'Bela Crkva', 'BELA CRKVA'];

    final normalizedTime = GradAdresaValidator.normalizeTime(finalVreme);
    debugPrint(
        '🛑 [PutnikService] otkaziPutnika (fallback): dateStr=$dateStr, gradVariants=$gradVariants, time=$normalizedTime');

    try {
      if (normalizedTime.isNotEmpty) {
        // Pokušaj sa zeljeno_vreme
        var res = await supabase
            .from('seat_requests')
            .update({
              'status': status,
              'processed_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .inFilter('grad', gradVariants)
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
            })
            .match({
              'putnik_id': id.toString(),
              'datum': dateStr,
            })
            .inFilter('grad', gradVariants)
            .eq('dodeljeno_vreme', '$normalizedTime:00')
            .select();

        if (res.isNotEmpty) {
          debugPrint('🛑 [PutnikService] otkaziPutnika SUCCESS (dodeljeno_vreme)');
          return;
        }
      }

      // Zadnji fallback: bez vremena
      final withoutTime = await supabase
          .from('seat_requests')
          .update({
            'status': status,
            'processed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .match({
            'putnik_id': id.toString(),
            'datum': dateStr,
          })
          .inFilter('grad', gradVariants)
          .select();

      debugPrint('🛑 [PutnikService] otkaziPutnika SUCCESS (fallback): ${withoutTime.length} rows');
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

    final isVrsac = (grad?.toLowerCase().contains('vr') ?? false) || (grad?.toLowerCase() == 'vs');
    final gradVariants = isVrsac ? ['vs', 'VS', 'Vršac', 'Vrsac', 'VRŠAC'] : ['bc', 'BC', 'Bela Crkva', 'BELA CRKVA'];

    String? vozacId;
    if (driver != null) {
      vozacId = await VozacMappingService.getVozacUuid(driver);
    }

    // Ažuriraj seat_requests
    var query = supabase.from('seat_requests').update({
      'status': 'confirmed',
      'processed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'vozac_id': vozacId,
    });

    if (requestId != null && requestId.isNotEmpty) {
      query = query.eq('id', requestId);
    } else {
      query = query.match({
        'putnik_id': id,
        'datum': dateStr,
      }).inFilter('grad', gradVariants);
    }

    await query;

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

  Future<void> dodelPutnikaVozacuZaPravac(
    String id,
    String? vozac,
    String? pravac, {
    String? vreme,
    String? selectedDan,
    String? requestId, // 🆕 Dodato za precizno mapiranje
  }) async {
    // 1. Get driver UUID
    String? vozacUuid;
    if (vozac != null && vozac != '_NONE_') {
      vozacUuid = await VozacMappingService.getVozacUuid(vozac);
    }

    // 2. Determine the date
    final dateStr = app_date_utils.DateUtils.getIsoDateForDay(selectedDan ?? 'Ponedeljak');

    // 3. Normalize grad
    final isVrsac = (pravac?.toLowerCase().contains('vr') ?? false) || (pravac?.toLowerCase() == 'vs');
    final gradKey = isVrsac ? 'vs' : 'bc';
    final gradVariants = isVrsac ? ['vs', 'VS', 'Vršac', 'Vrsac', 'VRŠAC'] : ['bc', 'BC', 'Bela Crkva', 'BELA CRKVA'];

    // 4. Update query
    var query = supabase.from('seat_requests').update({
      'vozac_id': vozacUuid,
      'status': 'confirmed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    // PRIORITET 1: Ako imamo requestId, to je najsigurnije
    if (requestId != null && requestId.isNotEmpty) {
      query = query.eq('id', requestId);
    } else {
      // PRIORITET 2: Match po setu parametara
      query = query.match({
        'putnik_id': id,
        'datum': dateStr,
      }).inFilter('grad', gradVariants);

      // Ako je prosleđeno vreme, filtriraj i po njemu
      if (vreme != null && vreme.isNotEmpty) {
        final normVreme = GradAdresaValidator.normalizeTime(vreme);
        query = query.eq('zeljeno_vreme', '$normVreme:00');
      }
    }

    final result = await query.select();

    if (result.isEmpty && requestId == null) {
      // Fallback: pokusaj bez vremena i bez gornje-donje crte (pokušaj samo putnik+datum+grad)
      final fallbackResult = await supabase
          .from('seat_requests')
          .update({
            'vozac_id': vozacUuid,
            'status': 'confirmed',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .match({
            'putnik_id': id,
            'datum': dateStr,
          })
          .inFilter('grad', gradVariants)
          .select();

      if (fallbackResult.isEmpty) {
        throw Exception(
            'Putnik nije pronađen u seat_requests tabeli za datum $dateStr, grad $gradKey ${vreme != null ? "i vreme $vreme" : ""}');
      }
    }
  }

  Future<void> prebacijPutnikaVozacu(String id, String? vozac) async {
    String? vozacUuid;
    if (vozac != null) {
      vozacUuid = await VozacMappingService.getVozacUuid(vozac);
    }
    await supabase
        .from('registrovani_putnici')
        .update({'vozac_id': vozacUuid, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  /// 🔄 POMOĆNA METODA: Obogaćuje podatke iz seat_requests informacijama iz voznje_log
  void _enrichWithLogData(List<dynamic> reqs, Map<String, Map<String, dynamic>> logData) {
    for (var r in reqs) {
      final data = r as Map<String, dynamic>;
      final putnikId = data['putnik_id']?.toString();
      if (putnikId == null) continue;

      final gradRaw = data['grad']?.toString();
      // ✅ FIX: Normalizuj grad na 'vs'/'bc' skraćenice za konzistentan match sa logData
      final grad = GradAdresaValidator.isVrsac(gradRaw)
          ? 'vs'
          : GradAdresaValidator.isBelaCrkva(gradRaw)
              ? 'bc'
              : gradRaw?.toLowerCase();

      final vremeRaw = (data['dodeljeno_vreme'] ?? data['zeljeno_vreme'])?.toString();

      // ✅ FIX: Koristi centralizovanu normalizaciju vremena (HH:mm format)
      final normVreme = GradAdresaValidator.normalizeTime(vremeRaw);

      // Pokušavamo da nađemo precizan match (putnik + grad + vreme)
      String compositeKey = "$putnikId|$grad|$normVreme";
      Map<String, dynamic>? match;

      if (logData.containsKey(compositeKey)) {
        match = logData[compositeKey];
      }

      if (match != null) {
        final List tipovi = match['tipovi'] ?? [match['tip']];

        if (tipovi.contains('voznja')) {
          data['pokupljen_iz_loga'] = true;
          debugPrint('✅ [_enrichWithLogData] Putnik $putnikId - pokupljen_iz_loga = true');
        }
        if (tipovi.contains('otkazivanje')) {
          data['status'] = 'otkazano';
          data['otkazano_iz_loga'] = true;
          debugPrint('✅ [_enrichWithLogData] Putnik $putnikId - otkazano_iz_loga = true');
        }
        if (tipovi.contains('uplata') || tipovi.contains('uplata_dnevna')) {
          data['placeno_iz_loga'] = true;
          // ✅ NOVO: Popuni iznos i vozač ime za prikaz u kartici putnika
          data['cena'] = match['iznos'];
          data['naplatioVozac'] = match['vozac_ime'];
          debugPrint(
              '✅ [_enrichWithLogData] Putnik $putnikId - placeno_iz_loga = true, cena=${match['iznos']}, naplatioVozac=${match['vozac_ime']}');
        }

        // Ako vozač nije definisan u seat_request, uzmi ga iz loga
        if (data['vozac_id'] == null) {
          data['vozac_id'] = match['vozac_id'];
        }
        // Vreme akcije iz loga ima prioritet
        data['processed_at'] = match['created_at'] ?? data['processed_at'];
      } else {
        data['pokupljen_iz_loga'] = false;
        data['otkazano_iz_loga'] = false;
        data['placeno_iz_loga'] = false;
      }
    }
  }

  /// 🚫 GLOBALNO UKLONI POLAZAK: Postavlja 'bez_polaska' status za sve putnike u datom terminu
  Future<int> globalniBezPolaska({
    required String datum,
    required String grad,
    required String vreme,
  }) async {
    try {
      final isVrsac = (grad.toLowerCase().contains('vr')) || (grad.toLowerCase() == 'vs');
      final gradVariants = isVrsac ? ['vs', 'VS', 'Vršac', 'Vrsac', 'VRŠAC'] : ['bc', 'BC', 'Bela Crkva', 'BELA CRKVA'];

      var query = supabase.from('seat_requests').update({
        'status': 'bez_polaska',
        'processed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).match({
        'datum': datum,
      }).inFilter('grad', gradVariants);

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
