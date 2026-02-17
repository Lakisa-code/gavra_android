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
  static final Map<String, StreamSubscription<dynamic>> _realtimeSubscriptions = {};

  static void closeStream({String? isoDate, String? grad, String? vreme}) {
    final key = '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
    final controller = _streams[key];
    if (controller != null && !controller.isClosed) controller.close();
    _realtimeSubscriptions[key]?.cancel();
    _realtimeSubscriptions['$key:log']?.cancel(); // Nova pretplata na logove
    _streams.remove(key);
    _lastValues.remove(key);
    _streamParams.remove(key);
    _realtimeSubscriptions.remove(key);
    _realtimeSubscriptions.remove('$key:log');
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
      _realtimeSubscriptions[key]?.cancel();
      _realtimeSubscriptions.remove(key);
    };
    return controller.stream;
  }

  Stream<List<Putnik>> streamPutnici() {
    // 🆕 REDIREKCIJA NA IZVOR ISTINE (seat_requests)
    // Ovo osigurava da Admin i Vozač vide potpuno isto kao i početni ekran
    final isoDate = DateTime.now().toIso8601String();
    return streamKombinovaniPutniciFiltered(isoDate: isoDate);
  }

  // UKLONJENO: _mergeSeatRequests - kolona polasci_po_danu više ne postoji

  Future<List<Putnik>> getPutniciByDayIso(String isoDate) async {
    try {
      final todayDate = isoDate.split('T')[0];

      final reqs = await supabase
          .from('seat_requests')
          .select('*, registrovani_putnici!inner($registrovaniFields)')
          .eq('datum', todayDate)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logs = await supabase.from('voznje_log').select('putnik_id').eq('datum', todayDate).eq('tip', 'voznja');
      final pickedUpIds = (logs as List).map((l) => l['putnik_id'].toString()).toSet();

      return (reqs as List).map((r) {
        final data = r as Map<String, dynamic>;
        data['pokupljen_iz_loga'] = pickedUpIds.contains(data['putnik_id']?.toString());
        return Putnik.fromSeatRequest(data);
      }).toList();
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
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      if (grad != null) {
        query = query.ilike('grad', grad.toLowerCase() == 'vrsac' || grad.toLowerCase() == 'vršac' ? 'vs' : 'bc');
      }

      if (vreme != null) {
        query = query.eq('zeljeno_vreme', '${GradAdresaValidator.normalizeTime(vreme)}:00');
      }

      final reqs = await query;

      // 🔄 DOHVATI STATUSE IZ VOZNJE_LOG (Nova arhitektura)
      final logs = await supabase.from('voznje_log').select('putnik_id').eq('datum', todayDate).eq('tip', 'voznja');
      final pickedUpIds = (logs as List).map((l) => l['putnik_id'].toString()).toSet();

      final results = (reqs as List).map((r) {
        final data = r as Map<String, dynamic>;
        data['pokupljen_iz_loga'] = pickedUpIds.contains(data['putnik_id']?.toString());
        return Putnik.fromSeatRequest(data);
      }).toList();

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
    _realtimeSubscriptions[key]?.cancel();
    _realtimeSubscriptions['$key:log']?.cancel();

    // Refresh when seat_requests change for the target date
    _realtimeSubscriptions[key] = RealtimeManager.instance.subscribe('seat_requests').listen((payload) {
      debugPrint('🔄 [PutnikService] Realtime UPDATE (seat_requests): ${payload.eventType}');
      _doFetchForStream(key, isoDate, grad, vreme, controller);
    });

    // Refresh when voznje_log change (pokupljanja, naplate)
    _realtimeSubscriptions['$key:log'] = RealtimeManager.instance.subscribe('voznje_log').listen((payload) {
      debugPrint('🔄 [PutnikService] Realtime UPDATE (voznje_log): ${payload.eventType}');
      _doFetchForStream(key, isoDate, grad, vreme, controller);
    });
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
    final res =
        await supabase.from('registrovani_putnici').select(registrovaniFields).eq('putnik_ime', ime).maybeSingle();
    if (res == null) return null;
    return Putnik.fromRegistrovaniPutnici(res);
  }

  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    try {
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
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      return (res as List).map((row) => Putnik.fromSeatRequest(row)).toList();
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
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);

      return (res as List).map((row) => Putnik.fromSeatRequest(row)).toList();
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
    final res = await supabase
        .from('registrovani_putnici')
        .select('id, tip')
        .eq('putnik_ime', putnik.ime)
        .eq('aktivan', true)
        .maybeSingle();

    if (res == null) return;
    final putnikId = res['id'];

    await SeatRequestService.insertSeatRequest(
      putnikId: putnikId.toString(),
      dan: putnik.dan,
      vreme: putnik.polazak,
      grad: putnik.grad,
      brojMesta: putnik.brojMesta,
      status: 'confirmed', // Vozač ga je dodao ručno
    );
  }

  Future<void> obrisiPutnika(dynamic id) async {
    // Soft delete profile
    await supabase.from('registrovani_putnici').update({'obrisan': true}).eq('id', id);
  }

  Future<void> oznaciPokupljen(dynamic id, bool value, {String? grad, String? vreme, String? driver}) async {
    if (_isDuplicateAction('pickup_$id')) return;
    if (!value) return; // 🚫 "Undo" funkcija uklonjena - ne dozvoljavamo poništavanje pokupljenja

    final danasStr = DateTime.now().toIso8601String().split('T')[0];

    // Ažuriraj seat_requests - postavi status confirmed/approved
    String? vozacId;
    if (driver != null) {
      vozacId = await VozacMappingService.getVozacUuid(driver);
    }

    // ✅ OZNAČI KAO POKUPLJEN (Samo u voznje_log, po zahtevu korisnika)
    await supabase
        .from('voznje_log')
        .insert({'putnik_id': id.toString(), 'datum': danasStr, 'tip': 'voznja', 'vozac_id': vozacId});
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

  Future<void> otkaziPutnika(
    dynamic id,
    String? driver, {
    String? grad,
    String? vreme,
    String? selectedDan,
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    final finalDan = selectedDan;
    final finalVreme = selectedVreme ?? vreme;
    final finalGrad = selectedGrad ?? grad;

    final dateStr = finalDan != null
        ? app_date_utils.DateUtils.getIsoDateForDay(finalDan)
        : DateTime.now().toIso8601String().split('T')[0];
    final gradKey =
        (finalGrad?.toLowerCase().contains('vr') ?? false || finalGrad?.toLowerCase() == 'vs') ? 'VS' : 'BC';

    await supabase
        .from('seat_requests')
        .update({
          'status': 'otkazano',
          'processed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('putnik_id', id)
        .eq('datum', dateStr)
        .eq('grad', gradKey);
  }

  Future<void> oznaciPlaceno(
    dynamic id,
    num iznos,
    String? driver, {
    String? grad,
    String? selectedVreme,
    String? selectedDan,
  }) async {
    final danasStr = DateTime.now().toIso8601String().split('T')[0];
    final dateStr = selectedDan != null ? app_date_utils.DateUtils.getIsoDateForDay(selectedDan) : danasStr;
    final gradKey = (grad?.toLowerCase().contains('vr') ?? false || grad?.toLowerCase() == 'vs') ? 'VS' : 'BC';

    String? vozacId;
    if (driver != null) {
      vozacId = await VozacMappingService.getVozacUuid(driver);
    }

    // Ažuriraj seat_requests: postavi status confirmed i processed_at
    await supabase.from('seat_requests').update({
      'status': 'confirmed',
      'processed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'vozac_id': vozacId,
    }).match({
      'putnik_id': id,
      'datum': dateStr,
      'grad': gradKey,
    });

    // Dodaj u voznje_log
    await supabase.from('voznje_log').insert({
      'putnik_id': id.toString(),
      'datum': dateStr,
      'tip': 'placanje',
      'iznos': iznos,
      'vozac_id': vozacId,
    });
  }

  Future<void> dodelPutnikaVozacuZaPravac(
    String id,
    String? vozac,
    String? pravac, {
    String? vreme,
    String? selectedDan,
  }) async {
    // 1. Get driver UUID
    String? vozacUuid;
    if (vozac != null && vozac != '_NONE_') {
      vozacUuid = await VozacMappingService.getVozacUuid(vozac);
    }

    // 2. Determine the date (since seat_requests works on date, not day of week)
    final dateStr = app_date_utils.DateUtils.getIsoDateForDay(selectedDan ?? 'Ponedeljak');

    // 3. Update seat_requests
    final gradKey = (pravac?.toLowerCase().contains('vr') ?? false || pravac?.toLowerCase() == 'vs') ? 'VS' : 'BC';

    await supabase.from('seat_requests').update({
      'vozac_id': vozacUuid,
      'status': 'confirmed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).match({
      'putnik_id': id,
      'datum': dateStr,
      'grad': gradKey,
    });
  }

  Future<void> prebacijPutnikaVozacu(String id, String? vozac) async {
    String? vozacUuid;
    if (vozac != null) vozacUuid = await VozacMappingService.getVozacUuid(vozac);
    await supabase
        .from('registrovani_putnici')
        .update({'vozac_id': vozacUuid, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }
}
