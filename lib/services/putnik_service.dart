import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/vozac_boja.dart';
import 'driver_location_service.dart';
import 'realtime/realtime_manager.dart';
import 'realtime_notification_service.dart';
import 'registrovani_putnik_service.dart';
import 'vozac_mapping_service.dart';

// ?? UNDO STACK - Stack za cuvanje poslednih akcija
class UndoAction {
  UndoAction({
    required this.type,
    required this.putnikId, // ? dynamic umesto int
    required this.oldData,
    required this.timestamp,
  });
  final String type; // 'delete', 'pickup', 'payment', 'cancel', 'odsustvo', 'reset'
  final dynamic putnikId; // ? dynamic umesto int
  final Map<String, dynamic> oldData;
  final DateTime timestamp;
}

/// Parametri streama za refresh
class _StreamParams {
  _StreamParams({this.isoDate, this.grad, this.vreme});
  final String? isoDate;
  final String? grad;
  final String? vreme;
}

class PutnikService {
  final supabase = Supabase.instance.client;

  static final Map<String, StreamController<List<Putnik>>> _streams = {};
  static final Map<String, List<Putnik>> _lastValues = {};
  static final Map<String, _StreamParams> _streamParams = {};

  static StreamSubscription? _globalSubscription;
  static bool _isSubscribed = false;

  static void clearCache() {
    for (final controller in _streams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streams.clear();
    _lastValues.clear();
    _streamParams.clear();
    // Ugasi globalni subscription
    _globalSubscription?.cancel();
    RealtimeManager.instance.unsubscribe('registrovani_putnici');
    _globalSubscription = null;
    _isSubscribed = false;
  }

  String _streamKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// Inicijalizuje globalni subscription JEDNOM - koristi RealtimeManager
  void _ensureGlobalChannel() {
    if (_isSubscribed && _globalSubscription != null) return;

    // Koristi centralizovani RealtimeManager
    _globalSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
      debugPrint('🔄 [PutnikService] Postgres change: ${payload.eventType}');

      // 🔧 FIX: UVEK radi full refresh jer partial update ne može pravilno rekonstruisati
      // polasci_po_danu JSON koji sadrži vremePokupljenja, otkazanZaPolazak itd.
      // Partial update je previše kompleksan i error-prone za ovaj use case.
      debugPrint('🔄 [PutnikService] Full refresh triggered');
      _refreshAllStreams();
    });
    _isSubscribed = true;
    debugPrint('✅ [PutnikService] Global subscription created via RealtimeManager');
  }

  /// Osvežava SVE aktivne streamove (full refresh)
  void _refreshAllStreams() {
    for (final entry in _streamParams.entries) {
      final key = entry.key;
      final params = entry.value;
      final controller = _streams[key];
      if (controller != null && !controller.isClosed) {
        _doFetchForStream(key, params.isoDate, params.grad, params.vreme, controller);
      }
    }
  }

  /// 🚀 PAYLOAD FILTERING: Primenjuje promene iz payload-a direktno na lokalni cache
  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    final key = _streamKey(isoDate: isoDate, grad: grad, vreme: vreme);

    // Osiguraj globalni channel
    _ensureGlobalChannel();

    // Ako stream već postoji, vrati ga
    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      final controller = _streams[key]!;
      if (_lastValues.containsKey(key)) {
        Future.microtask(() {
          if (!controller.isClosed) {
            controller.add(_lastValues[key]!);
          }
        });
      }
      _doFetchForStream(key, isoDate, grad, vreme, controller);
      return controller.stream;
    }

    final controller = StreamController<List<Putnik>>.broadcast();
    _streams[key] = controller;
    _streamParams[key] = _StreamParams(isoDate: isoDate, grad: grad, vreme: vreme);

    _doFetchForStream(key, isoDate, grad, vreme, controller);

    controller.onCancel = () {
      debugPrint('🧹 Stream $key cleanup');
      _streams.remove(key);
      _lastValues.remove(key);
      _streamParams.remove(key);
    };

    return controller.stream;
  }

  /// ?? Helper metoda za fetch podataka za stream
  Future<void> _doFetchForStream(
    String key,
    String? isoDate,
    String? grad,
    String? vreme,
    StreamController<List<Putnik>> controller,
  ) async {
    try {
      final combined = <Putnik>[];

      // Fetch monthly rows for the relevant day (if isoDate provided, convert)
      String? danKratica;
      if (isoDate != null) {
        try {
          final dt = DateTime.parse(isoDate);
          const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
          danKratica = dani[dt.weekday - 1];
        } catch (_) {
          // Invalid date format - use default
        }
      }
      danKratica ??= _getDayAbbreviationFromName(_getTodayName());

      final todayDate = isoDate ?? DateTime.now().toIso8601String().split('T')[0];

      final registrovani = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false);

      for (final m in registrovani) {
        // ? ISPRAVKA: Kreiraj putnike SAMO za ciljani dan
        final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(m, danKratica);

        // ?? Dohvati uklonjene termine za ovog putnika
        final uklonjeniTermini = m['uklonjeni_termini'] as List<dynamic>? ?? [];

        for (final p in putniciZaDan) {
          final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
          final normVremeFilter = vreme != null ? GradAdresaValidator.normalizeTime(vreme) : null;

          if (grad != null && p.grad != grad) {
            continue;
          }
          if (normVremeFilter != null && normVreme != normVremeFilter) {
            continue;
          }

          // ?? Proveri da li je putnik uklonjen iz ovog termina
          final jeUklonjen = uklonjeniTermini.any((ut) {
            final utMap = ut as Map<String, dynamic>;
            // Normalizuj vreme za poređenje
            final utVreme = GradAdresaValidator.normalizeTime(utMap['vreme']?.toString());
            final pVreme = GradAdresaValidator.normalizeTime(p.polazak);
            // Datum može biti ISO format ili kraći format
            final utDatum = utMap['datum']?.toString().split('T')[0];
            return utDatum == todayDate && utVreme == pVreme && utMap['grad'] == p.grad;
          });
          if (jeUklonjen) {
            continue;
          }

          combined.add(p);
        }
      }

      _lastValues[key] = combined;
      if (!controller.isClosed) {
        controller.add(combined);
      }
    } catch (e) {
      _lastValues[key] = [];
      if (!controller.isClosed) {
        controller.add([]);
      }
    }
  }

  // ? DODATO: JOIN sa adrese tabelom za obe adrese
  static const String registrovaniFields = '*,'
      'polasci_po_danu,'
      'adresa_bc:adresa_bela_crkva_id(id,naziv,ulica,broj,grad,koordinate),'
      'adresa_vs:adresa_vrsac_id(id,naziv,ulica,broj,grad,koordinate)';

  // ?? UNDO STACK - Cuva poslednje akcije (max 10)
  static final List<UndoAction> _undoStack = [];
  static const int maxUndoActions = 10;

  // ?? DUPLICATE PREVENTION - Cuva poslednje akcije po putnik ID
  static final Map<String, DateTime> _lastActionTime = {};
  static const Duration _duplicatePreventionDelay = Duration(milliseconds: 500);

  /// ?? DUPLICATE PREVENTION HELPER
  static bool _isDuplicateAction(String actionKey) {
    final now = DateTime.now();
    final lastAction = _lastActionTime[actionKey];

    if (lastAction != null) {
      final timeDifference = now.difference(lastAction);
      if (timeDifference < _duplicatePreventionDelay) {
        return true;
      }
    }

    _lastActionTime[actionKey] = now;
    return false;
  }

  // ?? DODAJ U UNDO STACK
  void _addToUndoStack(
    String type,
    dynamic putnikId,
    Map<String, dynamic> oldData,
  ) {
    _undoStack.add(
      UndoAction(
        type: type,
        putnikId: putnikId,
        oldData: oldData,
        timestamp: DateTime.now(),
      ),
    );

    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  // ?? HELPER - Odredi tabelu na osnovu putnika
  // ?? POJEDNOSTAVLJENO: Sada postoji samo registrovani_putnici tabela
  Future<String> _getTableForPutnik(dynamic id) async {
    return 'registrovani_putnici';
  }

  // ?? UCITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  // ?? POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  // 🆕 DODATO: Opcioni parametar grad za precizniji rezultat
  Future<Putnik?> getPutnikByName(String imePutnika, {String? grad}) async {
    try {
      final registrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (registrovaniResponse != null) {
        // 🆕 Ako je grad specificiran, vrati putnika za taj grad
        if (grad != null) {
          final weekday = DateTime.now().weekday;
          const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
          final danKratica = daniKratice[weekday - 1];

          final putnici = Putnik.fromRegistrovaniPutniciMultipleForDay(registrovaniResponse, danKratica);
          final matching = putnici.where((p) => p.grad == grad).toList();
          if (matching.isNotEmpty) {
            return matching.first;
          }
        }

        return Putnik.fromRegistrovaniPutnici(registrovaniResponse);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ?? UCITAJ PUTNIKA IZ BILO KOJE TABELE (po ID)
  // ?? POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    try {
      final registrovaniResponse =
          await supabase.from('registrovani_putnici').select(registrovaniFields).eq('id', id as String).limit(1);

      if (registrovaniResponse.isNotEmpty) {
        return Putnik.fromRegistrovaniPutnici(registrovaniResponse.first);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ?? BATCH UCITAVANJE PUTNIKA IZ BILO KOJE TABELE (po listi ID-eva)
  // ?? POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  Future<List<Putnik>> getPutniciByIds(List<dynamic> ids) async {
    if (ids.isEmpty) return [];

    final results = <Putnik>[];
    final stringIds = ids.map((id) => id.toString()).toList();

    try {
      final registrovaniResponse =
          await supabase.from('registrovani_putnici').select(registrovaniFields).inFilter('id', stringIds);

      for (final row in registrovaniResponse) {
        results.add(Putnik.fromRegistrovaniPutnici(row));
      }

      return results;
    } catch (e) {
      // Fallback na pojedinacne pozive ako batch ne uspe
      for (final id in ids) {
        final putnik = await getPutnikFromAnyTable(id);
        if (putnik != null) results.add(putnik);
      }
      return results;
    }
  }

  /// Učitaj sve putnike iz registrovani_putnici tabele
  Future<List<Putnik>> getAllPutnici({String? targetDay}) async {
    List<Putnik> allPutnici = [];

    try {
      final targetDate = targetDay ?? _getTodayName();

      // ??? CILJANI DAN: Ucitaj putnike iz registrovani_putnici za selektovani dan
      final danKratica = _getDayAbbreviationFromName(targetDate);

      // Explicitly request polasci_po_danu and common per-day columns
      const registrovaniFields = '*,'
          'polasci_po_danu';

      // ? OPTIMIZOVANO: Prvo ucitaj sve aktivne, zatim filtriraj po danu u Dart kodu (sigurniji pristup)
      final allregistrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      // Filtriraj rezultate sa tacnim matchovanjem dana
      final registrovaniResponse = <Map<String, dynamic>>[];
      for (final row in allregistrovaniResponse) {
        final radniDani = row['radni_dani'] as String?;
        if (radniDani != null && radniDani.split(',').map((d) => d.trim()).contains(danKratica)) {
          registrovaniResponse.add(Map<String, dynamic>.from(row));
        }
      }

      for (final data in registrovaniResponse) {
        // KORISTI fromRegistrovaniPutniciMultipleForDay da kreira putnike samo za selektovani dan
        final registrovaniPutnici = Putnik.fromRegistrovaniPutniciMultipleForDay(data, danKratica);

        // ? VALIDACIJA: Prika�i samo putnike sa validnim vremenima polazaka
        final validPutnici = registrovaniPutnici.where((putnik) {
          final polazak = putnik.polazak.trim();
          // Pobolj�ana validacija vremena
          if (polazak.isEmpty) return false;

          final cleaned = polazak.toLowerCase();
          final invalidValues = ['00:00:00', '00:00', 'null', 'undefined'];
          if (invalidValues.contains(cleaned)) return false;

          // Proveri format vremena (HH:MM ili HH:MM:SS)
          final timeRegex = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');
          return timeRegex.hasMatch(polazak);
        }).toList();

        allPutnici.addAll(validPutnici);
      }

      return allPutnici;
    } catch (e) {
      return [];
    }
  }

  String _getTodayName() {
    final danas = DateTime.now();
    const daniNazivi = [
      'Ponedeljak',
      'Utorak',
      'Sreda',
      'Cetvrtak',
      'Petak',
      'Subota',
      'Nedelja',
    ];
    return daniNazivi[danas.weekday - 1];
  }

  String _getDayAbbreviationFromName(String dayName) {
    return app_date_utils.DateUtils.getDayAbbreviation(dayName);
  }

  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      final data = putnik.toRegistrovaniPutniciMap();

      if (putnik.id != null) {
        await supabase.from('registrovani_putnici').update(data).eq('id', putnik.id! as String);
      } else {
        await supabase.from('registrovani_putnici').insert(data);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ?? UNDO POSLEDNJU AKCIJU
  Future<String?> undoLastAction() async {
    if (_undoStack.isEmpty) {
      return 'Nema akcija za poni�tavanje';
    }

    final lastAction = _undoStack.removeLast();

    try {
      final tabela = await _getTableForPutnik(lastAction.putnikId);

      switch (lastAction.type) {
        case 'delete':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
            'aktivan': true,
          }).eq('id', lastAction.putnikId as String);
          return 'Poni�teno brisanje putnika';

        case 'pickup':
          await supabase.from(tabela).update({
            'broj_putovanja': lastAction.oldData['broj_putovanja'],
            'vreme_pokupljenja_bc': null,
            'vreme_pokupljenja_vs': null,
          }).eq('id', lastAction.putnikId as String);
          return 'Poni�teno pokupljanje';

        case 'payment':
          await supabase.from(tabela).update({
            'cena': null,
            'vreme_placanja': null,
            'vozac_id': null,
          }).eq('id', lastAction.putnikId as String);
          return 'Poni�teno placanje';

        case 'cancel':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
          }).eq('id', lastAction.putnikId as String);
          return 'Poni�teno otkazivanje';

        default:
          return 'Nepoznata akcija za poni�tavanje';
      }
    } catch (e) {
      return null;
    }
  }

  /// ? DODAJ PUTNIKA (dnevni ili mesecni) - ??? SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik) async {
    try {
      // ?? SVI PUTNICI MORAJU BITI REGISTROVANI
      // Ad-hoc putnici vi�e ne postoje - svi tipovi (radnik, ucenik, dnevni)
      // moraju biti u registrovani_putnici tabeli
      if (putnik.mesecnaKarta != true) {
        throw Exception(
          'NEREGISTROVAN PUTNIK!\n\n'
          'Svi putnici moraju biti registrovani u sistemu.\n'
          'Idite na: Meni ? Mesecni putnici da kreirate novog putnika.',
        );
      }

      // ?? STRIKTNA VALIDACIJA VOZACA
      if (putnik.dodaoVozac == null || putnik.dodaoVozac!.isEmpty || !VozacBoja.isValidDriver(putnik.dodaoVozac)) {
        throw Exception(
          'NEPOZNAT VOZAC: "${putnik.dodaoVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}',
        );
      }

      // ?? VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        throw Exception(
          'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vr�ac.',
        );
      }

      // ??? VALIDACIJA ADRESE
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        if (!GradAdresaValidator.validateAdresaForCity(
          putnik.adresa,
          putnik.grad,
        )) {
          throw Exception(
            'Adresa "${putnik.adresa}" nije validna za grad "${putnik.grad}". Dozvoljene su samo adrese iz Bele Crkve i Vr�ca.',
          );
        }
      }

      // ? PROVERAVA DA LI REGISTROVANI PUTNIK VEC POSTOJI
      final existingPutnici = await supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, aktivan, polasci_po_danu, radni_dani')
          .eq('putnik_ime', putnik.ime)
          .eq('aktivan', true);

      if (existingPutnici.isEmpty) {
        throw Exception('PUTNIK NE POSTOJI!\n\n'
            'Putnik "${putnik.ime}" ne postoji u listi registrovanih putnika.\n'
            'Idite na: Meni ? Mesecni putnici da kreirate novog putnika.');
      }

      // ?? A�URIRAJ polasci_po_danu za putnika sa novim polaskom
      final registrovaniPutnik = existingPutnici.first;
      final putnikId = registrovaniPutnik['id'] as String;

      Map<String, dynamic> polasciPoDanu = {};
      if (registrovaniPutnik['polasci_po_danu'] != null) {
        polasciPoDanu = Map<String, dynamic>.from(registrovaniPutnik['polasci_po_danu'] as Map);
      }

      final danKratica = putnik.dan.toLowerCase();

      final gradKey = putnik.grad.toLowerCase().contains('bela') ? 'bc' : 'vs';

      final polazakVreme = GradAdresaValidator.normalizeTime(putnik.polazak);

      if (!polasciPoDanu.containsKey(danKratica)) {
        polasciPoDanu[danKratica] = {'bc': null, 'vs': null};
      }
      final danPolasci = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map);
      danPolasci[gradKey] = polazakVreme;
      // ?? Dodaj broj mesta ako je > 1
      if (putnik.brojMesta > 1) {
        danPolasci['${gradKey}_mesta'] = putnik.brojMesta;
      } else {
        danPolasci.remove('${gradKey}_mesta');
      }

      // 🆕 Dodaj "adresa danas" ako je prosleđena (override za ovaj dan)
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        danPolasci['${gradKey}_adresa_danas_id'] = putnik.adresaId;
      }
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty && putnik.adresa != 'Adresa nije definisana') {
        danPolasci['${gradKey}_adresa_danas'] = putnik.adresa;
      }

      polasciPoDanu[danKratica] = danPolasci;

      String radniDani = registrovaniPutnik['radni_dani'] as String? ?? '';
      final radniDaniList = radniDani.split(',').map((d) => d.trim().toLowerCase()).where((d) => d.isNotEmpty).toList();
      if (!radniDaniList.contains(danKratica) && danKratica.isNotEmpty) {
        radniDaniList.add(danKratica);
        radniDani = radniDaniList.join(',');
      }

      // A�uriraj mesecnog putnika u bazi
      // ? UKLONJENO: updated_by izaziva foreign key gre�ku jer UUID nije u tabeli users
      // final updatedByUuid = VozacMappingService.getVozacUuidSync(putnik.dodaoVozac ?? '');

      // ?? Pripremi update mapu - BEZ updated_by (foreign key constraint)
      final updateData = <String, dynamic>{
        'polasci_po_danu': polasciPoDanu,
        'radni_dani': radniDani,
        'updated_at': DateTime.now().toIso8601String(),
      };
      // ? UKLONJENO: updated_by foreign key constraint ka users tabeli
      // if (updatedByUuid != null && updatedByUuid.isNotEmpty) {
      //   updateData['updated_by'] = updatedByUuid;
      // }

      await supabase.from('registrovani_putnici').update(updateData).eq('id', putnikId);

      // 📲 REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za današnji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Cet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      if (putnik.dan == todayName) {
        // 📲 ŠALJI PUSH SVIM VOZAČIMA (FCM + Huawei Push)
        RealtimeNotificationService.sendNotificationToAllDrivers(
          title: 'Novi putnik',
          body: 'Dodat je novi putnik ${putnik.ime} (${putnik.grad}, ${putnik.polazak})',
          excludeSender: putnik.dodaoVozac,
          data: {
            'type': 'novi_putnik',
            'putnik': {
              'ime': putnik.ime,
              'grad': putnik.grad,
              'vreme': putnik.polazak,
              'dan': putnik.dan,
            },
          },
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Putnik>> streamPutnici() {
    return RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici().map((registrovani) {
      final allPutnici = <Putnik>[];

      for (final item in registrovani) {
        final registrovaniPutnici = Putnik.fromRegistrovaniPutniciMultiple(item.toMap());
        allPutnici.addAll(registrovaniPutnici);
      }
      return allPutnici;
    });
  }

  /// ? UKLONI IZ TERMINA - samo nestane sa liste, bez otkazivanja/statistike
  Future<void> ukloniIzTermina(
    dynamic id, {
    required String datum,
    required String vreme,
    required String grad,
  }) async {
    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select('uklonjeni_termini').eq('id', id as String).single();

    List<dynamic> uklonjeni = [];
    if (response['uklonjeni_termini'] != null) {
      uklonjeni = List<dynamic>.from(response['uklonjeni_termini'] as List);
    }

    // Normalizuj vrednosti pre čuvanja za konzistentno poređenje
    final normDatum = datum.split('T')[0]; // ISO format bez vremena
    final normVreme = GradAdresaValidator.normalizeTime(vreme);

    uklonjeni.add({
      'datum': normDatum,
      'vreme': normVreme,
      'grad': grad,
    });

    await supabase.from(tabela).update({
      'uklonjeni_termini': uklonjeni,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// ? OBRISI PUTNIKA (Soft Delete - cuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    final tabela = await _getTableForPutnik(id);
    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();

    // ?? DODAJ U UNDO STACK (sigurno mapiranje)
    final undoResponse = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('delete', id, undoResponse);

    // ?? NE menjaj status - constraint check_registrovani_status_valid dozvoljava samo:
    // 'aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godi�nji'
    await supabase.from(tabela).update({
      'obrisan': true, // ? Soft delete flag
    }).eq('id', id);
  }

  /// ? OZNACI KAO POKUPLJEN
  /// [grad] - opcioni parametar za određivanje koje pokupljenje (BC ili VS)
  Future<void> oznaciPokupljen(dynamic id, String currentDriver, {String? grad}) async {
    // ?? DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    if (currentDriver.isEmpty) {
      throw ArgumentError(
        'Vozac mora biti specificiran.',
      );
    }

    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;
    final putnik = Putnik.fromMap(response);

    // ?? DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPickup = Map<String, dynamic>.from(response);
    _addToUndoStack('pickup', id, undoPickup);

    if (tabela == 'registrovani_putnici') {
      final now = DateTime.now();
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver);

      // ✅ NOVO: Odredi dan i place za polasci_po_danu JSON
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      final danKratica = daniKratice[now.weekday - 1];
      final bool jeBC = grad?.toLowerCase().contains('bela') ?? false;
      final place = jeBC ? 'bc' : 'vs';

      // ✅ NOVO: Ažuriraj polasci_po_danu JSON sa pokupljenjem
      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasci = response['polasci_po_danu'];
      if (rawPolasci != null) {
        if (rawPolasci is String) {
          try {
            polasciPoDanu = Map<String, dynamic>.from(jsonDecode(rawPolasci));
          } catch (_) {}
        } else if (rawPolasci is Map) {
          polasciPoDanu = Map<String, dynamic>.from(rawPolasci);
        }
      }

      // Ažuriraj dan sa pokupljenjem
      final dayData = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map? ?? {});
      dayData['${place}_pokupljeno'] = now.toIso8601String();
      dayData['${place}_pokupljeno_vozac'] = currentDriver; // Ime vozača, ne UUID
      polasciPoDanu[danKratica] = dayData;

      // ✅ Kolone za kompatibilnost (zadržavamo za sada)
      final String vremeKolona = jeBC ? 'vreme_pokupljenja_bc' : 'vreme_pokupljenja_vs';

      await supabase.from(tabela).update({
        vremeKolona: now.toIso8601String(),
        'vozac_id': vozacUuid,
        'polasci_po_danu': polasciPoDanu,
        'updated_at': now.toIso8601String(),
      }).eq('id', id);

      // ?? DODAJ ZAPIS U voznje_log za pracenje vo�nji
      final danas = now.toIso8601String().split('T')[0];
      try {
        await supabase.from('voznje_log').insert({
          'putnik_id': id.toString(),
          'datum': danas,
          'tip': 'voznja',
          'iznos': 0,
          'vozac_id': vozacUuid,
        });
      } catch (logError) {
        // Log insert not critical
      }

      // ?? AUTOMATSKA SINHRONIZACIJA - a�uriraj brojPutovanja iz istorije
      try {
        await RegistrovaniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(id);
      } catch (e) {
        // Sync not critical
      }
    }

    // ?? A�URIRAJ STATISTIKE ako je mesecni putnik i pokupljen je
    if (putnik.mesecnaKarta == true) {
      // Statistike se racunaju dinamicki kroz StatistikaService
      // bez potrebe za dodatnim a�uriranjem
    }

    // ?? DINAMICKI ETA UPDATE - ukloni putnika iz pracenja i preracunaj ETA
    try {
      final putnikIdentifier = putnik.ime.isNotEmpty ? putnik.ime : '${putnik.adresa} ${putnik.grad}';
      DriverLocationService.instance.removePassenger(putnikIdentifier);
    } catch (e) {
      // Tracking not active
    }
  }

  /// ? OZNACI KAO PLACENO
  Future<void> oznaciPlaceno(
    dynamic id,
    double iznos,
    String naplatioVozac,
  ) async {
    // ?? DUPLICATE PREVENTION
    final actionKey = 'payment_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;

    final undoPayment = response;
    _addToUndoStack('payment', id, undoPayment);

    final now = DateTime.now();
    String? validVozacId = naplatioVozac.isEmpty ? null : VozacMappingService.getVozacUuidSync(naplatioVozac);

    // ✅ NOVO: Ažuriraj polasci_po_danu JSON sa plaćanjem
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[now.weekday - 1];

    // Odredi place iz response (grad putnika)
    final gradPutnika = response['grad'] as String? ?? '';
    final place = gradPutnika.toLowerCase().contains('vr') ? 'vs' : 'bc';

    Map<String, dynamic> polasciPoDanu = {};
    final rawPolasci = response['polasci_po_danu'];
    if (rawPolasci != null) {
      if (rawPolasci is String) {
        try {
          polasciPoDanu = Map<String, dynamic>.from(jsonDecode(rawPolasci));
        } catch (_) {}
      } else if (rawPolasci is Map) {
        polasciPoDanu = Map<String, dynamic>.from(rawPolasci);
      }
    }

    // Ažuriraj dan sa plaćanjem
    final dayData = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map? ?? {});
    dayData['${place}_placeno'] = now.toIso8601String();
    dayData['${place}_placeno_vozac'] = naplatioVozac; // Ime vozača
    dayData['${place}_placeno_iznos'] = iznos;
    polasciPoDanu[danKratica] = dayData;

    await supabase.from(tabela).update({
      'cena': iznos,
      'vreme_placanja': now.toIso8601String(),
      'vozac_id': validVozacId,
      'polasci_po_danu': polasciPoDanu, // ✅ NOVO: Sačuvaj u JSON
      'updated_at': now.toIso8601String(),
    }).eq('id', id);
  }

  /// ? OTKAZI PUTNIKA - sada čuva otkazivanje PO POLASKU (grad) u polasci_po_danu JSON
  Future<void> otkaziPutnika(
    dynamic id,
    String otkazaoVozac, {
    String? selectedVreme,
    String? selectedGrad,
    String? selectedDan,
  }) async {
    try {
      final idStr = id.toString();
      final tabela = await _getTableForPutnik(idStr);

      final response = await supabase.from(tabela).select().eq('id', idStr).maybeSingle();
      if (response == null) return;
      final respMap = response;
      final cancelName = (respMap['putnik_ime'] ?? respMap['ime']) ?? '';

      // ?? DODAJ U UNDO STACK
      _addToUndoStack('cancel', idStr, respMap);

      if (tabela == 'registrovani_putnici') {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);

        // 🆕 Odredi place (bc/vs) iz selectedGrad ili iz putnikovog grada
        String place = 'bc'; // default
        final gradZaOtkazivanje = selectedGrad ?? respMap['grad'] as String? ?? '';
        if (gradZaOtkazivanje.toLowerCase().contains('vr') || gradZaOtkazivanje.toLowerCase().contains('vs')) {
          place = 'vs';
        }

        // 🆕 Odredi dan kratica
        final weekday = DateTime.now().weekday;
        const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
        final danKratica = daniKratice[weekday - 1];

        // 🆕 Učitaj postojeći polasci_po_danu JSON
        Map<String, dynamic> polasci = {};
        final polasciRaw = respMap['polasci_po_danu'];
        if (polasciRaw != null) {
          if (polasciRaw is String) {
            try {
              polasci = jsonDecode(polasciRaw) as Map<String, dynamic>;
            } catch (_) {}
          } else if (polasciRaw is Map) {
            polasci = Map<String, dynamic>.from(polasciRaw);
          }
        }

        // 🆕 Dodaj/ažuriraj otkazivanje za specifičan dan i grad
        if (!polasci.containsKey(danKratica)) {
          polasci[danKratica] = <String, dynamic>{};
        }
        final dayData = polasci[danKratica] as Map<String, dynamic>;
        final now = DateTime.now();
        dayData['${place}_otkazano'] = now.toIso8601String();
        dayData['${place}_otkazao_vozac'] = otkazaoVozac;
        polasci[danKratica] = dayData;

        // Kolona za otkazivanje (triggeruje realtime)
        final String vremeOtkazivanjaKolona = place == 'bc' ? 'vreme_otkazivanja_bc' : 'vreme_otkazivanja_vs';

        await supabase.from('registrovani_putnici').update({
          'polasci_po_danu': polasci, // 🔧 FIX: Map direktno, ne jsonEncode!
          vremeOtkazivanjaKolona: now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        }).eq('id', id.toString());

        try {
          await supabase.from('voznje_log').insert({
            'putnik_id': id.toString(),
            'datum': danas,
            'tip': 'otkazivanje',
            'iznos': 0,
            'vozac_id': vozacUuid,
          });
        } catch (logError) {
          // Log insert not critical
        }
      }

      // 📢 POŠALJI NOTIFIKACIJU ZA OTKAZIVANJE (samo za tekući dan)
      try {
        final now = DateTime.now();
        final dayNames = ['Pon', 'Uto', 'Sre', 'Cet', 'Pet', 'Sub', 'Ned'];
        final todayName = dayNames[now.weekday - 1];

        // Odredi dan za koji se otkazuje
        final putnikDan = selectedDan ?? (respMap['dan'] ?? '') as String;
        final isToday = putnikDan.toLowerCase().contains(todayName.toLowerCase()) || putnikDan == todayName;

        debugPrint('📢 OTKAZIVANJE: dan=$putnikDan, danas=$todayName, isToday=$isToday, ime=$cancelName');

        if (isToday) {
          RealtimeNotificationService.sendNotificationToAllDrivers(
            title: 'Otkazan putnik',
            body:
                'Otkazan je putnik $cancelName (${respMap['grad'] ?? ''}, ${respMap['vreme_polaska'] ?? respMap['polazak'] ?? ''})',
            excludeSender: otkazaoVozac,
            data: {
              'type': 'otkazan_putnik',
              'putnik': {
                'ime': respMap['putnik_ime'] ?? respMap['ime'],
                'grad': respMap['grad'],
                'vreme': respMap['vreme_polaska'] ?? respMap['polazak'],
              },
            },
          );
          debugPrint('📢 NOTIFIKACIJA POSLATA za $cancelName');
        } else {
          debugPrint('📢 NOTIFIKACIJA PRESKOČENA - nije današnji dan');
        }
      } catch (notifError) {
        debugPrint('📢 GREŠKA pri slanju notifikacije: $notifError');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// ?? OZNACI KAO BOLOVANJE/GODI�NJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
    dynamic id,
    String tipOdsustva,
    String currentDriver,
  ) async {
    // ?? DEBUG LOG
    // ? dynamic umesto int
    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;

    final undoOdsustvo = response;
    _addToUndoStack('odsustvo', id, undoOdsustvo);

    // 🔧 FIX: Koristi 'godisnji' bez dijakritike jer tako zahteva DB constraint
    String statusZaBazu = tipOdsustva.toLowerCase();
    if (statusZaBazu == 'godišnji') {
      statusZaBazu = 'godisnji';
    }

    try {
      await supabase.from(tabela).update({
        'status': statusZaBazu, // 'bolovanje' ili 'godisnji'
        'aktivan': true, // Putnik ostaje aktivan, samo je na odsustvu
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// ?? RESETUJ KARTICU U POCETNO STANJE (samo za validne vozace)
  /// ? KONZISTENTNO: Prima selectedVreme i selectedGrad za tacan reset po polasku
  Future<void> resetPutnikCard(
    String imePutnika,
    String currentDriver, {
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    try {
      if (currentDriver.isEmpty) {
        throw Exception('Funkcija zahteva specificiranje vozaca');
      }

      // ?? POJEDNOSTAVLJENO: Reset samo u registrovani_putnici tabeli
      try {
        // ? FIX: Koristi limit(1) umesto maybeSingle() jer mo�e postojati vi�e putnika sa istim imenom
        final registrovaniList =
            await supabase.from('registrovani_putnici').select().eq('putnik_ime', imePutnika).limit(1);

        if (registrovaniList.isNotEmpty) {
          final respMap = registrovaniList.first;

          // 🆕 Resetuj i per-trip otkazivanja u polasci_po_danu JSON-u
          Map<String, dynamic> polasci = {};
          final polasciRaw = respMap['polasci_po_danu'];
          if (polasciRaw != null) {
            if (polasciRaw is String) {
              try {
                polasci = jsonDecode(polasciRaw) as Map<String, dynamic>;
              } catch (_) {}
            } else if (polasciRaw is Map) {
              polasci = Map<String, dynamic>.from(polasciRaw);
            }
          }

          // Očisti SVA stanja za sve dane (otkazivanja, pokupljenja, plaćanja)
          polasci.forEach((day, data) {
            if (data is Map) {
              // Otkazivanja
              data.remove('bc_otkazano');
              data.remove('bc_otkazao_vozac');
              data.remove('vs_otkazano');
              data.remove('vs_otkazao_vozac');
              // Pokupljenja
              data.remove('bc_pokupljeno');
              data.remove('bc_pokupljeno_vozac');
              data.remove('vs_pokupljeno');
              data.remove('vs_pokupljeno_vozac');
              // Plaćanja
              data.remove('bc_placeno');
              data.remove('bc_naplatilac');
              data.remove('vs_placeno');
              data.remove('vs_naplatilac');
            }
          });

          // ? FIX: Update SVE putnike sa istim imenom (ako ih ima više)
          await supabase.from('registrovani_putnici').update({
            'aktivan': true,
            'status': 'radi',
            'polasci_po_danu': polasci, // 🔧 FIX: Map direktno, ne jsonEncode!
            'vreme_pokupljenja_bc': null,
            'vreme_pokupljenja_vs': null,
            'vreme_otkazivanja_bc': null,
            'vreme_otkazivanja_vs': null,
            'vreme_placanja': null,
            'cena': null,
            'vozac_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          return;
        }
      } catch (e) {
        // Putnik not found
      }
    } catch (e) {
      // Gre�ka pri resetovanju kartice
      rethrow;
    }
  }

  /// ❌ UKLONJENA LOGIKA - Admin ručno resetuje putnike
  /// Ova funkcija više ne radi automatski reset baziran na vremenu
  Future<void> resetPokupljenjaNaPolazak(
    String novoVreme,
    String grad,
    String currentDriver,
  ) async {
    // Namerno prazna - pokupljeni putnici ostaju pokupljeni dok admin ne resetuje
    return;
  }

  /// 🔄 PREBACI PUTNIKA DRUGOM VOZACU (ili ukloni vozača)
  /// Ažurira `vozac_id` kolonu u registrovani_putnici tabeli
  /// Ako je noviVozac null, uklanja vozača sa putnika
  Future<void> prebacijPutnikaVozacu(String putnikId, String? noviVozac) async {
    try {
      String? vozacUuid;

      if (noviVozac != null) {
        if (!VozacBoja.isValidDriver(noviVozac)) {
          throw Exception(
            'Nevalidan vozac: "$noviVozac". Dozvoljeni: ${VozacBoja.validDrivers.join(", ")}',
          );
        }
        vozacUuid = await VozacMappingService.getVozacUuid(noviVozac);
        if (vozacUuid == null) {
          throw Exception('Vozac "$noviVozac" nije pronaden u bazi');
        }
      }

      // 🔄 POJEDNOSTAVLJENO: Svi putnici su sada u registrovani_putnici
      await supabase.from('registrovani_putnici').update({
        'vozac_id': vozacUuid, // null ako se uklanja vozač
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);
    } catch (e) {
      throw Exception('Greška pri prebacivanju putnika: $e');
    }
  }
}
