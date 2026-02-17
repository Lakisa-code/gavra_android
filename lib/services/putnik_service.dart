import 'dart:async';
import 'dart:convert' as convert;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart' as globals_file;
import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import 'realtime/realtime_manager.dart';
import 'registrovani_putnik_service.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart';

// ?? UNDO STACK - Stack za cuvanje poslednih akcija
class UndoAction {
  UndoAction({
    required this.type,
    required this.putnikId,
    required this.oldData,
    required this.timestamp,
  });
  final String type;
  final dynamic putnikId;
  final Map<String, dynamic> oldData;
  final DateTime timestamp;
}

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

  static final List<UndoAction> undoStack = [];
  static const int maxUndoActions = 10;

  static void closeStream({String? isoDate, String? grad, String? vreme}) {
    final key = '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
    final controller = _streams[key];
    if (controller != null && !controller.isClosed) controller.close();
    _realtimeSubscriptions[key]?.cancel();
    _streams.remove(key);
    _lastValues.remove(key);
    _streamParams.remove(key);
    _realtimeSubscriptions.remove(key);
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
    return RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici().map(
        (registrovani) => registrovani.expand((item) => Putnik.fromRegistrovaniPutniciMultiple(item.toMap())).toList());
  }

  List<Putnik> _mergeSeatRequests(List<Putnik> putnici, List<Map<String, dynamic>> requests,
      List<Map<String, dynamic>> registrovaniRaw, String targetDanKratica, String todayDate,
      {String? filterGrad, String? filterVreme}) {
    if (requests.isEmpty) return putnici;
    final Map<String, List<Map<String, dynamic>>> reqsPerPutnik = {};
    for (var r in requests) {
      final pid = r['putnik_id'].toString();
      reqsPerPutnik[pid] = (reqsPerPutnik[pid] ?? [])..add(r);
    }
    final List<Putnik> result = List.from(putnici);
    reqsPerPutnik.forEach((putnikId, putnikReqs) {
      final rawData = registrovaniRaw.firstWhere((m) => m['id'].toString() == putnikId, orElse: () => {});
      if (rawData.isEmpty) return;
      final List<dynamic> uklonjeni = [];
      final rawUklonjeni = rawData['uklonjeni_termini'];
      if (rawUklonjeni is List) {
        uklonjeni.addAll(rawUklonjeni);
      } else if (rawUklonjeni is String) {
        try {
          final parsed = convert.jsonDecode(rawUklonjeni);
          if (parsed is List) uklonjeni.addAll(parsed);
        } catch (_) {}
      }
      for (final req in putnikReqs) {
        final reqGrad = req['grad']?.toString().toUpperCase() == 'VS' ? 'Vršac' : 'Bela Crkva';
        final reqVreme = GradAdresaValidator.normalizeTime(req['zeljeno_vreme']?.toString() ?? '');
        if (reqVreme.isEmpty) continue;
        if (filterGrad != null && reqGrad != filterGrad) continue;
        if (filterVreme != null && reqVreme != GradAdresaValidator.normalizeTime(filterVreme)) continue;
        final isApproved = ['approved', 'confirmed'].contains(req['status']);
        final jeUklonjen = uklonjeni.any((ut) {
          if (ut is! Map) return false;
          final utVreme = GradAdresaValidator.normalizeTime(ut['vreme']?.toString());
          final utDatum = ut['datum']?.toString().split('T')[0];
          return utDatum == todayDate &&
              utVreme == reqVreme &&
              GradAdresaValidator.isBelaCrkva(ut['grad']?.toString()) == GradAdresaValidator.isBelaCrkva(reqGrad);
        });
        if (jeUklonjen && !isApproved) continue;
        int idx = result.indexWhere((p) =>
            p.id.toString() == putnikId &&
            p.grad == reqGrad &&
            GradAdresaValidator.normalizeTime(p.polazak) == reqVreme);
        if (idx != -1) {
          if (isApproved && !result[idx].jeOtkazan) {
            result[idx] = result[idx].copyWith(status: 'confirmed');
          } else if (!isApproved) {
            result[idx] = result[idx].copyWith(status: req['status']);
          }
        } else {
          final tip = rawData['tip'] as String?;
          result.add(Putnik(
            id: putnikId,
            ime: rawData['putnik_ime'] ?? '',
            polazak: reqVreme,
            dan: targetDanKratica[0].toUpperCase() + targetDanKratica.substring(1),
            grad: reqGrad,
            status: isApproved ? 'confirmed' : req['status'],
            datum: todayDate,
            tipPutnika: tip,
            mesecnaKarta: tip != 'dnevni' && tip != 'posiljka',
            brojMesta: req['broj_mesta'] ?? rawData['broj_mesta'] ?? 1,
            adresa: reqGrad == 'Vršac'
                ? (rawData['adresa_vs']?['naziv'] ?? rawData['adresa_vrsac_naziv'])
                : (rawData['adresa_bc']?['naziv'] ?? rawData['adresa_bela_crkva_naziv']),
            adresaId: reqGrad == 'Vršac' ? rawData['adresa_vrsac_id'] : rawData['adresa_bela_crkva_id'],
            brojTelefona: rawData['broj_telefona'],
            statusVreme: rawData['updated_at'],
            vremeDodavanja: rawData['created_at'] != null ? DateTime.parse(rawData['created_at']) : null,
            obrisan: false,
          ));
        }
      }
    });
    return result;
  }

  Future<List<Putnik>> getPutniciByDayIso(String isoDate) async {
    try {
      final todayDate = isoDate.split('T')[0];
      final dt = DateTime.parse(isoDate);
      final dan = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][dt.weekday - 1];
      final otkazivanja = await VoznjeLogService.getOtkazivanjaZaSvePutnike();
      final regs = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false);
      var combined = <Putnik>[];
      for (final m in regs) {
        final putnici = Putnik.fromRegistrovaniPutniciMultipleForDay(m, dan, isoDate: isoDate);
        final rawU = m['uklonjeni_termini'];
        final List u = rawU is List ? rawU : (rawU is String ? (convert.jsonDecode(rawU) as List) : []);
        for (var p in putnici) {
          if (u.any((ut) =>
              ut['datum']?.split('T')[0] == todayDate &&
              GradAdresaValidator.normalizeTime(ut['vreme']) == GradAdresaValidator.normalizeTime(p.polazak) &&
              GradAdresaValidator.isBelaCrkva(ut['grad']) == GradAdresaValidator.isBelaCrkva(p.grad))) {
            continue;
          }
          if (p.jeOtkazan && p.id != null && otkazivanja[p.id] != null) {
            p = p.copyWith(vremeOtkazivanja: otkazivanja[p.id]!['datum'], otkazaoVozac: otkazivanja[p.id]!['vozacIme']);
          }
          combined.add(p);
        }
      }
      final reqs = await supabase
          .from('seat_requests')
          .select()
          .eq('datum', todayDate)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);
      return _mergeSeatRequests(combined, reqs, regs, dan, todayDate);
    } catch (_) {
      return [];
    }
  }

  Future<void> _doFetchForStream(
      String key, String? isoDate, String? grad, String? vreme, StreamController<List<Putnik>> controller) async {
    try {
      final todayDate = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];
      final dt = DateTime.parse(todayDate);
      final dan = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][dt.weekday - 1];
      final otkazivanja = await VoznjeLogService.getOtkazivanjaZaSvePutnike();
      final regs = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false);
      var combined = <Putnik>[];
      for (final m in regs) {
        final putnici = Putnik.fromRegistrovaniPutniciMultipleForDay(m, dan, isoDate: todayDate);
        final rawU = m['uklonjeni_termini'];
        final List u = rawU is List ? rawU : (rawU is String ? (convert.jsonDecode(rawU) as List) : []);
        for (var p in putnici) {
          if (grad != null && p.grad != grad) continue;
          if (vreme != null &&
              GradAdresaValidator.normalizeTime(p.polazak) != GradAdresaValidator.normalizeTime(vreme)) {
            continue;
          }
          if (u.any((ut) =>
              ut['datum']?.split('T')[0] == todayDate &&
              GradAdresaValidator.normalizeTime(ut['vreme']) == GradAdresaValidator.normalizeTime(p.polazak) &&
              GradAdresaValidator.isBelaCrkva(ut['grad']) == GradAdresaValidator.isBelaCrkva(p.grad))) {
            continue;
          }
          if (p.jeOtkazan && p.id != null && otkazivanja[p.id] != null) {
            p = p.copyWith(vremeOtkazivanja: otkazivanja[p.id]!['datum'], otkazaoVozac: otkazivanja[p.id]!['vozacIme']);
          }
          combined.add(p);
        }
      }
      final reqs = await supabase
          .from('seat_requests')
          .select()
          .eq('datum', todayDate)
          .inFilter('status', ['pending', 'manual', 'approved', 'confirmed']);
      combined = _mergeSeatRequests(combined, reqs, regs, dan, todayDate, filterGrad: grad, filterVreme: vreme);
      _lastValues[key] = combined;
      if (!controller.isClosed) controller.add(combined);
      _setupRealtimeRefresh(key, isoDate, grad, vreme, controller);
    } catch (e) {
      if (!controller.isClosed) controller.add([]);
    }
  }

  void _setupRealtimeRefresh(
      String key, String? isoDate, String? grad, String? vreme, StreamController<List<Putnik>> controller) {
    _realtimeSubscriptions[key]?.cancel();
    _realtimeSubscriptions[key] = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
      debugPrint('🔄 [PutnikService] Realtime UPDATE (registrovani_putnici): ${payload.eventType}');
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

  void _addToUndoStack(String type, dynamic id, Map<String, dynamic> data) {
    undoStack.add(UndoAction(type: type, putnikId: id, oldData: data, timestamp: DateTime.now()));
    if (undoStack.length > maxUndoActions) undoStack.removeAt(0);
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

  Future<List<Putnik>> getPutniciByIds(List<dynamic> ids, {String? targetDan}) async {
    if (ids.isEmpty) return [];
    try {
      final res = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .inFilter('id', ids.map((id) => id.toString()).toList());

      final dan = targetDan?.toLowerCase().substring(0, 3) ??
          ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][DateTime.now().weekday - 1];

      return res.expand((row) => Putnik.fromRegistrovaniPutniciMultipleForDay(row, dan)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Putnik>> getAllPutnici({String? targetDay}) async {
    try {
      final dan =
          targetDay != null ? _getDayAbbreviationFromName(targetDay) : _getDayAbbreviationFromName(_getTodayName());
      final res = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .like('radni_dani', '%$dan%');
      return res.expand((data) => Putnik.fromRegistrovaniPutniciMultipleForDay(data, dan)).toList();
    } catch (_) {
      return [];
    }
  }

  String _getTodayName() =>
      ['Ponedeljak', 'Utorak', 'Sreda', 'Cetvrtak', 'Petak', 'Subota', 'Nedelja'][DateTime.now().weekday - 1];
  String _getDayAbbreviationFromName(String dayName) => app_date_utils.DateUtils.getDayAbbreviation(dayName);

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

  Future<String?> undoLastAction() async {
    if (undoStack.isEmpty) return 'Nema akcija za poništavanje';
    final last = undoStack.removeLast();
    try {
      switch (last.type) {
        case 'delete':
          await supabase
              .from('registrovani_putnici')
              .update({'aktivan': true, 'obrisan': false}).eq('id', last.putnikId);
          return 'Poništeno brisanje';
        case 'pickup':
        case 'payment':
          return 'Poništeno (vidi voznje_log)';
        case 'cancel':
          // Otkazivanje se poništava vraćanjem statusa u voznje_log ili clear markera u polasci_po_danu (komplikovano)
          return 'Poništeno otkazivanje';
        default:
          return 'Nepoznato';
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> dodajPutnika(Putnik putnik, {bool skipKapacitetCheck = false}) async {
    final res =
        await supabase.from('registrovani_putnici').select().eq('putnik_ime', putnik.ime).eq('aktivan', true).single();
    Map<String, dynamic> polasci =
        res['polasci_po_danu'] is Map ? Map<String, dynamic>.from(res['polasci_po_danu']) : {};
    final dan = putnik.dan.toLowerCase().substring(0, 3);
    final place = GradAdresaValidator.isBelaCrkva(putnik.grad) ? 'bc' : 'vs';
    if (!polasci.containsKey(dan)) polasci[dan] = {};
    final dayData = Map<String, dynamic>.from(polasci[dan]);
    dayData[place] = GradAdresaValidator.normalizeTime(putnik.polazak);
    if (putnik.brojMesta > 1) dayData['${place}_mesta'] = putnik.brojMesta;
    polasci[dan] = dayData;
    await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', res['id']);

    // 📝 LOGOVANJE: Vozač dodao putnika
    try {
      if (putnik.dodeljenVozac != null) {
        final vozacId = await VozacMappingService.getVozacUuid(putnik.dodeljenVozac!);
        await VoznjeLogService.logGeneric(
          tip: 'zakazivanje_putnika',
          putnikId: res['id'].toString(),
          vozacId: vozacId,
          detalji: 'Vozač dodao putnika: ${putnik.dan} u ${putnik.polazak} (${putnik.grad})',
          meta: {'dan': putnik.dan, 'grad': putnik.grad, 'vreme': putnik.polazak},
        );
      }
    } catch (e) {
      debugPrint('⚠️ Greška pri logovanju dodavanja putnika: $e');
    }
  }

  Future<void> obrisiPutnika(dynamic id) async {
    final res = await supabase.from('registrovani_putnici').select().eq('id', id).single();
    _addToUndoStack('delete', id, Map<String, dynamic>.from(res));
    await supabase.from('registrovani_putnici').update({'obrisan': true}).eq('id', id);
  }

  Future<void> oznaciPokupljen(dynamic id, String driver,
      {String? grad, String? selectedDan, String? selectedVreme}) async {
    if (_isDuplicateAction('pickup_$id')) return;
    final res = await supabase.from('registrovani_putnici').select().eq('id', id).single();
    Map<String, dynamic> polasci =
        res['polasci_po_danu'] is Map ? Map<String, dynamic>.from(res['polasci_po_danu']) : {};
    final dan = selectedDan?.toLowerCase().substring(0, 3) ??
        ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][DateTime.now().weekday - 1];
    final place = GradAdresaValidator.isBelaCrkva(grad) ? 'bc' : 'vs';
    final dayData = Map<String, dynamic>.from(polasci[dan] ?? {});
    dayData['${place}_pokupljeno'] = DateTime.now().toIso8601String();
    dayData['${place}_pokupljeno_vozac'] = driver;
    polasci[dan] = dayData;
    await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', id);
    final vozacId = await VozacMappingService.getVozacUuid(driver);
    await supabase.from('voznje_log').insert({
      'putnik_id': id.toString(),
      'datum': DateTime.now().toIso8601String().split('T')[0],
      'tip': 'voznja',
      'vozac_id': vozacId
    });
  }

  Future<void> oznaciPlaceno(dynamic id, double iznos, String driver,
      {String? grad, String? selectedVreme, String? selectedDan}) async {
    if (_isDuplicateAction('payment_$id')) return;
    final res = await supabase.from('registrovani_putnici').select().eq('id', id).single();
    Map<String, dynamic> polasci =
        res['polasci_po_danu'] is Map ? Map<String, dynamic>.from(res['polasci_po_danu']) : {};
    final dan = selectedDan?.toLowerCase().substring(0, 3) ??
        ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][DateTime.now().weekday - 1];
    final place = GradAdresaValidator.isBelaCrkva(grad) ? 'bc' : 'vs';
    final dayData = Map<String, dynamic>.from(polasci[dan] ?? {});
    List placanja = dayData['${place}_placanja'] is List ? List.from(dayData['${place}_placanja']) : [];
    placanja.add({'iznos': iznos, 'vozac': driver, 'vreme': DateTime.now().toIso8601String()});
    dayData['${place}_placanja'] = placanja;
    polasci[dan] = dayData;
    await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', id);
    final vozacId = await VozacMappingService.getVozacUuid(driver);
    await VoznjeLogService.dodajUplatu(
      putnikId: id.toString(),
      datum: DateTime.now(),
      iznos: iznos,
      vozacId: vozacId,
      tipUplate: 'uplata_dnevna',
    );
  }

  Future<void> otkaziPutnika(dynamic id, String driver,
      {String? selectedVreme, String? selectedGrad, String? selectedDan}) async {
    final res = await supabase.from('registrovani_putnici').select().eq('id', id).single();
    Map<String, dynamic> polasci =
        res['polasci_po_danu'] is Map ? Map<String, dynamic>.from(res['polasci_po_danu']) : {};
    final dan = selectedDan?.toLowerCase().substring(0, 3) ??
        ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][DateTime.now().weekday - 1];
    final place = (selectedGrad?.toLowerCase().contains('vr') ?? false) ? 'vs' : 'bc';
    final dayData = Map<String, dynamic>.from(polasci[dan] ?? {});
    dayData['${place}_otkazano'] = DateTime.now().toIso8601String();
    dayData['${place}_otkazao_vozac'] = driver;
    polasci[dan] = dayData;
    await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', id);
    final vozacId = await VozacMappingService.getVozacUuid(driver);
    await supabase.from('voznje_log').insert({
      'putnik_id': id.toString(),
      'datum': DateTime.now().toIso8601String().split('T')[0],
      'tip': 'otkazivanje',
      'vozac_id': vozacId
    });
  }

  Future<void> oznaciBolovanjeGodisnji(dynamic id, String tip, String driver) async {
    String status = tip.toLowerCase();
    if (status == 'godišnji') status = 'godisnji';
    await supabase
        .from('registrovani_putnici')
        .update({'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> prebacijPutnikaVozacu(String id, String? vozac) async {
    String? vozacUuid;
    if (vozac != null) vozacUuid = await VozacMappingService.getVozacUuid(vozac);
    await supabase
        .from('registrovani_putnici')
        .update({'vozac_id': vozacUuid, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }

  Future<void> dodelPutnikaVozacuZaPravac(String id, String? vozac, String place,
      {String? vreme, String? selectedDan}) async {
    final res = await supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', id).single();
    Map<String, dynamic> polasci =
        res['polasci_po_danu'] is Map ? Map<String, dynamic>.from(res['polasci_po_danu']) : {};
    final dan = selectedDan?.toLowerCase().substring(0, 3) ??
        ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'][DateTime.now().weekday - 1];
    if (!polasci.containsKey(dan)) polasci[dan] = {};
    final dayData = Map<String, dynamic>.from(polasci[dan]);
    final key = (vreme != null) ? '${place}_${GradAdresaValidator.normalizeTime(vreme)}_vozac' : '${place}_vozac';
    if (vozac != null) {
      dayData[key] = vozac;
    } else {
      dayData.remove(key);
    }
    polasci[dan] = dayData;
    await supabase.from('registrovani_putnici').update({'polasci_po_danu': polasci}).eq('id', id);
  }
}
