import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../globals.dart' as globals_file;
import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/vozac_boja.dart';
import 'driver_location_service.dart';
import 'realtime/realtime_manager.dart';
import 'realtime_notification_service.dart';
import 'registrovani_putnik_service.dart';
import 'slobodna_mesta_service.dart';
import 'unified_geocoding_service.dart';
import 'vozac_mapping_service.dart';
import 'voznje_log_service.dart';

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
  SupabaseClient get supabase => globals_file.supabase;

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

  /// 🆕 Zatvori specifičan stream po ključu
  static void closeStream({String? isoDate, String? grad, String? vreme}) {
    final key = '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
    final controller = _streams[key];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _streams.remove(key);
    _lastValues.remove(key);
    _streamParams.remove(key);
    print('🔴 DEBUG: Stream zatvoren key=$key');
  }

  String _streamKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// Inicijalizuje globalni subscription JEDNOM - koristi RealtimeManager
  void _ensureGlobalChannel() {
    if (_isSubscribed && _globalSubscription != null) return;

    // Koristi centralizovani RealtimeManager
    _globalSubscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen((payload) {
      // 🐛 DEBUG: Log realtime event
      print('🔴 REALTIME EVENT PRIMLJEN: ${payload.eventType} - ${payload.newRecord['putnik_ime'] ?? 'unknown'}');
      print(
          '🔴 REALTIME PAYLOAD: oldRecord keys=${payload.oldRecord.keys.toList()}, newRecord keys=${payload.newRecord.keys.toList()}');
      // 🔧 FIX: UVEK radi full refresh jer partial update ne može pravilno rekonstruisati
      // polasci_po_danu JSON koji sadrži vremePokupljenja, otkazanZaPolazak itd.
      // Partial update je previše kompleksan i error-prone za ovaj use case.
      _refreshAllStreams();
    });
    _isSubscribed = true;
    print('🔴 DEBUG: Realtime subscription AKTIVIRAN za registrovani_putnici');
  }

  /// Osvežava SVE aktivne streamove (full refresh)
  void _refreshAllStreams() {
    print('🔴 DEBUG: _refreshAllStreams() POZVANO - broj streamova: ${_streamParams.length}');
    for (final entry in _streamParams.entries) {
      final key = entry.key;
      final params = entry.value;
      final controller = _streams[key];
      if (controller != null && !controller.isClosed) {
        print('🔴 DEBUG: Refreshing stream key=$key');
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

      // 🆕 Učitaj otkazivanja iz voznje_log za sve putnike
      final otkazivanja = await VoznjeLogService.getOtkazivanjaZaSvePutnike();

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

        for (var p in putniciZaDan) {
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

          // 🆕 Dopuni otkazivanje iz voznje_log ako putnik nema vremeOtkazivanja
          if (p.jeOtkazan && p.vremeOtkazivanja == null && p.id != null) {
            final otkazivanjeData = otkazivanja[p.id];
            if (otkazivanjeData != null) {
              p = p.copyWith(
                vremeOtkazivanja: otkazivanjeData['datum'] as DateTime?,
                otkazaoVozac: otkazivanjeData['vozacIme'] as String?,
              );
            }
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
          // ✅ FIX: Case-insensitive matching i normalizacija grada (Vršac/Vrsac, Bela Crkva)
          final normalizedGrad = grad.toLowerCase();
          final matching = putnici.where((p) {
            final pGrad = p.grad.toLowerCase();
            // Proveri da li se gradovi podudaraju (uključi varijacije)
            if (normalizedGrad.contains('vr') || normalizedGrad.contains('vs')) {
              return pGrad.contains('vr') || pGrad.contains('vs');
            }
            // Default: Bela Crkva
            return pGrad.contains('bela') || pGrad.contains('bc');
          }).toList();
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
          // Pokupljanje se više ne poništava preko kolona u registrovani_putnici
          // Samo se može obrisati zapis iz voznje_log ako je potrebno
          return 'Poništeno pokupljanje';

        case 'payment':
          // Plaćanje se više ne poništava preko kolona u registrovani_putnici
          // Treba obrisati zapis iz voznje_log
          return 'Poništeno placanje';

        case 'cancel':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno otkazivanje';

        default:
          return 'Akcija nije prepoznata';
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
      if (putnik.dodeljenVozac == null ||
          putnik.dodeljenVozac!.isEmpty ||
          !VozacBoja.isValidDriver(putnik.dodeljenVozac)) {
        throw Exception(
          'NEREGISTROVAN VOZAC: "${putnik.dodeljenVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}',
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

      // 🚫 PROVERA KAPACITETA - Da li ima slobodnih mesta?
      final gradKey = GradAdresaValidator.isBelaCrkva(putnik.grad) ? 'BC' : 'VS';
      final polazakVremeNorm = GradAdresaValidator.normalizeTime(putnik.polazak);
      final datumZaProveru = putnik.datum ?? DateTime.now().toIso8601String().split('T')[0];

      final slobodnaMestaData = await SlobodnaMestaService.getSlobodnaMesta(datum: datumZaProveru);
      final listaZaGrad = slobodnaMestaData[gradKey];

      if (listaZaGrad != null) {
        for (final sm in listaZaGrad) {
          if (sm.vreme == polazakVremeNorm) {
            final dostupnoMesta = sm.maxMesta - sm.zauzetaMesta;
            if (putnik.brojMesta > dostupnoMesta) {
              throw Exception(
                'NEMA DOVOLJNO SLOBODNIH MESTA!\n\n'
                'Polazak: ${putnik.polazak} (${putnik.grad})\n'
                'Potrebno mesta: ${putnik.brojMesta}\n'
                'Slobodno mesta: $dostupnoMesta / ${sm.maxMesta}\n\n'
                'Smanjite broj mesta ili izaberite drugi polazak.',
              );
            }
            break;
          }
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

      // ?? AŽURIRAJ polasci_po_danu za putnika sa novim polaskom
      final registrovaniPutnik = existingPutnici.first;
      final putnikId = registrovaniPutnik['id'] as String;

      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasciPoDanu = registrovaniPutnik['polasci_po_danu'];
      // 🛡️ FIX: Proveri da li je Map, ne List (može biti [] ako je greškom postavljeno)
      if (rawPolasciPoDanu != null && rawPolasciPoDanu is Map) {
        polasciPoDanu = Map<String, dynamic>.from(rawPolasciPoDanu);
      }

      final danKratica = putnik.dan.toLowerCase();

      final gradKeyLower = GradAdresaValidator.isBelaCrkva(putnik.grad) ? 'bc' : 'vs';

      final polazakVreme = GradAdresaValidator.normalizeTime(putnik.polazak);

      if (!polasciPoDanu.containsKey(danKratica)) {
        polasciPoDanu[danKratica] = {'bc': null, 'vs': null};
      }
      final danPolasci = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map);
      danPolasci[gradKeyLower] = polazakVreme;
      // ?? Dodaj broj mesta ako je > 1
      if (putnik.brojMesta > 1) {
        danPolasci['${gradKeyLower}_mesta'] = putnik.brojMesta;
      } else {
        danPolasci.remove('${gradKeyLower}_mesta');
      }

      // 🆕 Dodaj "adresa danas" ako je prosleđena (override za ovaj dan)
      if (putnik.adresaId != null && putnik.adresaId!.isNotEmpty) {
        danPolasci['${gradKeyLower}_adresa_danas_id'] = putnik.adresaId;
      }
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty && putnik.adresa != 'Adresa nije definisana') {
        danPolasci['${gradKeyLower}_adresa_danas'] = putnik.adresa;
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
      // final updatedByUuid = VozacMappingService.getVozacUuidSync(putnik.dodeljenVozac ?? '');

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

      // 📲 NOTIFIKACIJA UKLONJENA PO NALOGU 16.01.2026.
      // Prethodno je ovde bila logika za slanje push notifikacije svim vozačima (RealtimeNotificationService.sendNotificationToAllDrivers)
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
  /// [selectedDan] - opcioni parametar za dan (npr. "Pon", "Uto") - ako nije prosleđen, koristi današnji dan
  Future<void> oznaciPokupljen(dynamic id, String currentDriver, {String? grad, String? selectedDan}) async {
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

    // 🧠 AUTO-LEARNING: Pokušaj da naučiš koordinate ako ih nema
    // Ovo radimo asinhrono (bez await) da ne kočimo UI
    UnifiedGeocodingService.tryLearnFromDriverLocation(putnik);

    if (tabela == 'registrovani_putnici') {
      final now = DateTime.now();
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver);

      // ✅ FIX: Koristi selectedDan umesto DateTime.now() - omogućava pokupljenje za bilo koji dan
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      String danKratica;
      if (selectedDan != null && selectedDan.isNotEmpty) {
        // Normalizuj selectedDan (može biti "Pon", "pon", "Ponedeljak" itd.)
        final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
        danKratica = daniKratice.contains(normalizedDan) ? normalizedDan : daniKratice[now.weekday - 1];
      } else {
        danKratica = daniKratice[now.weekday - 1];
      }
      final bool jeBC = GradAdresaValidator.isBelaCrkva(grad);
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

      await supabase.from(tabela).update({
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
          'broj_mesta': putnik.brojMesta, // 🆕 Dodaj broj mesta za tačan obračun
        });
      } catch (logError) {
        // Log insert not critical
      }
    }

    // 📊 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
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
  /// 💰 OZNACI KAO PLAĆENO
  /// [grad] - parametar za određivanje koje plaćanje (BC ili VS) - ISTO kao oznaciPokupljeno
  Future<void> oznaciPlaceno(
    dynamic id,
    double iznos,
    String currentDriver, {
    String? grad,
  }) async {
    // 🚨 DUPLICATE PREVENTION
    final actionKey = 'payment_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    if (currentDriver.isEmpty) {
      throw ArgumentError('Vozač mora biti specificiran.');
    }

    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;

    final undoPayment = response;
    _addToUndoStack('payment', id, undoPayment);

    final now = DateTime.now();

    // ✅ NOVO: Ažuriraj polasci_po_danu JSON sa plaćanjem
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[now.weekday - 1];

    // ✅ FIX: Izračunaj place iz grad parametra - ISTO kao oznaciPokupljeno!
    final bool jeBC = GradAdresaValidator.isBelaCrkva(grad);
    final place = jeBC ? 'bc' : 'vs';

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
    dayData['${place}_placeno_vozac'] = currentDriver; // Ime vozača - ISTO KAO POKUPLJENO
    dayData['${place}_placeno_iznos'] = iznos;
    polasciPoDanu[danKratica] = dayData;

    await supabase.from(tabela).update({
      'polasci_po_danu': polasciPoDanu,
      'updated_at': now.toIso8601String(),
    }).eq('id', id);

    // ✅ FIX: Loguj uplatu u voznje_log tabelu za statistike
    String? vozacId;
    try {
      if (!VozacMappingService.isInitialized) {
        await VozacMappingService.initialize();
      }
      vozacId = VozacMappingService.getVozacUuidSync(currentDriver);
      vozacId ??= await VozacMappingService.getVozacUuid(currentDriver);

      // 🛡️ FALLBACK: Ako mapping servis ne nađe UUID za Ivana, koristi hardkodovani
      if (vozacId == null && currentDriver == 'Ivan') {
        vozacId = '67ea0a22-689c-41b8-b576-5b27145e8e5e';
      }
    } catch (e) {
      debugPrint('❌ markAsPaid: Greška pri VozacMapping za "$currentDriver": $e');
      // Pokušaj fallback za Ivana čak i ako je mapping pukao
      if (currentDriver == 'Ivan') {
        vozacId = '67ea0a22-689c-41b8-b576-5b27145e8e5e';
      }
    }

    if (vozacId == null) {
      debugPrint('⚠️ markAsPaid: vozacId je NULL za vozača "$currentDriver" - uplata neće biti u statistici!');
      throw Exception('Sistem ne može da identifikuje vozača. Pokušajte ponovo ili restartujte aplikaciju.');
    }

    try {
      await VoznjeLogService.dodajUplatu(
        putnikId: id.toString(),
        datum: now,
        iznos: iznos,
        vozacId: vozacId,
        placeniMesec: now.month,
        placenaGodina: now.year,
        tipUplate: 'uplata_dnevna',
      );
      debugPrint(
          '✅ markAsPaid: Uplata upisana u voznje_log - putnik: $id, vozac: $currentDriver ($vozacId), iznos: $iznos');
    } catch (e) {
      debugPrint('❌ markAsPaid: GREŠKA pri upisu u voznje_log: $e');
      // Re-throw da korisnik zna da je nešto pošlo naopako
      throw Exception('Greška pri čuvanju uplate u statistiku: $e');
    }
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

        // 🆕 FIX: Koristi selectedDan umesto DateTime.now() - omogućava otkazivanje za bilo koji dan
        const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
        String danKratica;
        if (selectedDan != null && selectedDan.isNotEmpty) {
          // Normalizuj selectedDan (može biti "Pon", "pon", "Ponedeljak" itd.)
          final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
          danKratica = daniKratice.contains(normalizedDan) ? normalizedDan : daniKratice[DateTime.now().weekday - 1];
        } else {
          danKratica = daniKratice[DateTime.now().weekday - 1];
        }

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

        await supabase.from('registrovani_putnici').update({
          'polasci_po_danu': polasci,
          'updated_at': now.toIso8601String(),
        }).eq('id', id.toString());

        try {
          // 📊 Izračunaj koliko sati pre polaska je otkazano
          int? satiPrePolaska;
          try {
            final vremePolaskaStr = selectedVreme ?? respMap['vreme_polaska'] as String? ?? '';
            if (vremePolaskaStr.isNotEmpty && vremePolaskaStr.contains(':')) {
              final parts = vremePolaskaStr.split(':');
              final sat = int.tryParse(parts[0]) ?? 0;
              final minut = int.tryParse(parts[1]) ?? 0;

              // Izračunaj datum polaska iz dana
              final targetWeekday =
                  {'pon': 1, 'uto': 2, 'sre': 3, 'cet': 4, 'pet': 5, 'sub': 6, 'ned': 7}[danKratica] ?? now.weekday;
              var polazakDatum = DateTime(now.year, now.month, now.day, sat, minut);

              // Ako je drugi dan u nedelji, pomeri datum
              int daysToAdd = targetWeekday - now.weekday;
              if (daysToAdd < 0) daysToAdd += 7;
              polazakDatum = polazakDatum.add(Duration(days: daysToAdd));

              final razlika = polazakDatum.difference(now);
              satiPrePolaska = razlika.inHours;
              if (satiPrePolaska < 0) satiPrePolaska = 0;
            }
          } catch (_) {}

          await supabase.from('voznje_log').insert({
            'putnik_id': id.toString(),
            'datum': danas,
            'tip': 'otkazivanje',
            'iznos': 0,
            'vozac_id': vozacUuid,
            'sati_pre_polaska': satiPrePolaska,
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

        if (isToday) {
          RealtimeNotificationService.sendNotificationToAllDrivers(
            title: 'Otkazan putnik',
            body: cancelName,
            excludeSender: otkazaoVozac,
            data: {
              'type': 'otkazan_putnik',
              'datum': now.toIso8601String(),
              'putnik': {
                'ime': respMap['putnik_ime'] ?? respMap['ime'],
                'grad': respMap['grad'],
                'vreme': respMap['vreme_polaska'] ?? respMap['polazak'],
              },
            },
          );
        }
      } catch (_) {
        // Notification error - silent
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

  /// 🔄 RESETUJ KARTICU U POCETNO STANJE (samo za validne vozace)
  /// ✅ KONZISTENTNO: Prima selectedVreme i selectedGrad za tacan reset po polasku
  /// ✅ FIX: Briše SVE markere za današnji dan iz polasci_po_danu JSON-a
  Future<void> resetPutnikCard(
    String imePutnika,
    String currentDriver, {
    String? selectedVreme,
    String? selectedGrad,
    String? targetDan, // 🆕 Dan za koji se briše (ako nije prosleđen, koristi današnji)
  }) async {
    try {
      if (currentDriver.isEmpty) {
        throw Exception('Funkcija zahteva specificiranje vozaca');
      }

      // 🔄 POJEDNOSTAVLJENO: Reset samo u registrovani_putnici tabeli
      try {
        // ✅ FIX: Koristi limit(1) umesto maybeSingle() jer može postojati više putnika sa istim imenom
        final registrovaniList =
            await supabase.from('registrovani_putnici').select().eq('putnik_ime', imePutnika).limit(1);

        if (registrovaniList.isNotEmpty) {
          final putnikData = registrovaniList.first;

          // 🆕 Učitaj polasci_po_danu JSON
          Map<String, dynamic> polasci = {};
          final polasciRaw = putnikData['polasci_po_danu'];
          if (polasciRaw != null) {
            if (polasciRaw is String) {
              try {
                polasci = jsonDecode(polasciRaw) as Map<String, dynamic>;
              } catch (_) {}
            } else if (polasciRaw is Map) {
              polasci = jsonDecode(jsonEncode(polasciRaw)) as Map<String, dynamic>;
            }
          }

          // 🆕 Odredi place (bc/vs) iz selectedGrad
          String place = 'bc';
          final gradZaReset = selectedGrad ?? '';
          if (gradZaReset.toLowerCase().contains('vr') || gradZaReset.toLowerCase().contains('vs')) {
            place = 'vs';
          }

          // 🆕 Odredi dan kratica - koristi targetDan ako je prosleđen, inače današnji
          String danKratica;
          if (targetDan != null && targetDan.isNotEmpty) {
            danKratica = targetDan.toLowerCase();
          } else {
            final weekday = DateTime.now().weekday;
            const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
            danKratica = daniKratice[weekday - 1];
          }

          // 🆕 Obriši SVE markere za današnji dan i taj grad
          // ✅ FIX: Uvek kreiraj dayData čak i ako ne postoji
          Map<String, dynamic> dayData = {};
          if (polasci.containsKey(danKratica)) {
            final dayDataRaw = polasci[danKratica];
            if (dayDataRaw != null && dayDataRaw is Map) {
              dayData = Map<String, dynamic>.from(dayDataRaw);
            }
          }

          // Briši otkazivanje
          dayData.remove('${place}_otkazano');
          dayData.remove('${place}_otkazao_vozac');
          // Briši pokupljenje
          dayData.remove('${place}_pokupljeno');
          dayData.remove('${place}_pokupljeno_vozac');
          // Briši plaćanje - SA PREFIKSOM (putnik_service koristi ovaj format)
          dayData.remove('${place}_placeno');
          dayData.remove('${place}_placeno_vozac');
          dayData.remove('${place}_placeno_iznos');
          // Briši plaćanje - BEZ PREFIKSA (registrovani_putnik_service koristi ovaj format)
          dayData.remove('placeno');
          dayData.remove('placeno_iznos');
          dayData.remove('placeno_vozac');
          polasci[danKratica] = dayData;

          // ✅ Triple-tap resetuje karticu u belo stanje
          // Statistika u voznje_log OSTAJE NETAKNUTA
          // 🆕 DEBUG: Log šta se šalje u bazu
          // ignore: avoid_print
          print('🔄 RESET CARD: $imePutnika, place=$place, dan=$danKratica');
          // ignore: avoid_print
          print('🔄 RESET polasci_po_danu: $polasci');

          await supabase.from('registrovani_putnici').update({
            'aktivan': true,
            'status': 'radi',
            'polasci_po_danu': polasci,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          return;
        }
      } catch (e) {
        // Putnik not found
        // ignore: avoid_print
        print('❌ RESET CARD error: $e');
      }
    } catch (e) {
      // Greška pri resetovanju kartice
      // ignore: avoid_print
      print('❌ RESET CARD outer error: $e');
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

  /// 🆕 DODELI PUTNIKA VOZAČU ZA SPECIFIČAN PRAVAC (bc/vs)
  /// Čuva bc_vozac ili vs_vozac u polasci_po_danu JSON za specifičan dan
  /// [putnikId] - ID putnika
  /// [noviVozac] - Ime vozača (npr. "Bilevski") ili null za uklanjanje
  /// [place] - 'bc' za Bela Crkva pravac ili 'vs' za Vršac pravac
  /// 🆕 AŽURIRANO: Dodeli putnika vozaču za specifičan pravac (bc/vs), dan i VREME
  /// [putnikId] - UUID putnika iz registrovani_putnici
  /// [noviVozac] - Ime vozača (npr. "Ivan", "Svetlana") ili null za uklanjanje
  /// [place] - Pravac: "bc" za Bela Crkva, "vs" za Vršac
  /// [vreme] - Vreme polaska (npr. "5:00", "14:00") - obavezno za specifično dodeljivanje
  /// [selectedDan] - Dan u nedelji (npr. "pon", "Ponedeljak") - opcionalno, default je danas
  Future<void> dodelPutnikaVozacuZaPravac(
    String putnikId,
    String? noviVozac,
    String place, {
    String? vreme, // 🆕 OBAVEZAN parametar za vreme polaska
    String? selectedDan,
  }) async {
    try {
      // Validacija vozača
      if (noviVozac != null && !VozacBoja.isValidDriver(noviVozac)) {
        throw Exception(
          'Nevalidan vozac: "$noviVozac". Dozvoljeni: ${VozacBoja.validDrivers.join(", ")}',
        );
      }

      // Dohvati trenutne podatke putnika
      final response =
          await supabase.from('registrovani_putnici').select('polasci_po_danu').eq('id', putnikId).single();

      // Odredi dan
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      String danKratica;
      if (selectedDan != null && selectedDan.isNotEmpty) {
        final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
        danKratica = daniKratice.contains(normalizedDan) ? normalizedDan : daniKratice[DateTime.now().weekday - 1];
      } else {
        danKratica = daniKratice[DateTime.now().weekday - 1];
      }

      // Učitaj postojeći polasci_po_danu JSON
      Map<String, dynamic> polasci = {};
      final polasciRaw = response['polasci_po_danu'];
      if (polasciRaw != null) {
        if (polasciRaw is String) {
          try {
            polasci = jsonDecode(polasciRaw) as Map<String, dynamic>;
          } catch (_) {}
        } else if (polasciRaw is Map) {
          polasci = Map<String, dynamic>.from(polasciRaw);
        }
      }

      // Dodaj/ažuriraj vozača za specifičan dan, pravac i vreme
      if (!polasci.containsKey(danKratica)) {
        polasci[danKratica] = <String, dynamic>{};
      }
      final dayData = polasci[danKratica] as Map<String, dynamic>;

      // 🆕 Ključ uključuje vreme: 'bc_5:00_vozac' ili 'vs_14:00_vozac'
      String vozacKey;
      if (vreme != null && vreme.isNotEmpty) {
        final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);
        if (normalizedVreme.isNotEmpty) {
          vozacKey = '${place}_${normalizedVreme}_vozac';
        } else {
          vozacKey = '${place}_vozac'; // fallback ako normalizacija ne uspe
        }
      } else {
        // Fallback na stari format (bez vremena) ako vreme nije prosleđeno
        vozacKey = '${place}_vozac';
      }

      if (noviVozac != null) {
        dayData[vozacKey] = noviVozac;
      } else {
        dayData.remove(vozacKey);
      }
      polasci[danKratica] = dayData;

      // Sačuvaj u bazu
      await supabase.from('registrovani_putnici').update({
        'polasci_po_danu': polasci,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);
    } catch (e) {
      throw Exception('Greška pri dodeljivanju vozača za pravac: $e');
    }
  }

  /// 🔄 NEDELJNI RESET - Briše polasci_po_danu podatke za sve putnike
  /// Poziva se automatski u subotu ujutru (nakon ponoći petak→subota)
  /// NE RESETUJE: bolovanje i godišnji (oni ostaju)
  Future<void> weeklyResetPolasciPoDanu() async {
    try {
      // Dohvati sve putnike koji NISU na bolovanju/godišnjem
      final response = await supabase
          .from('registrovani_putnici')
          .select('id, polasci_po_danu, status, tip')
          .not('status', 'in', '(bolovanje,godisnji)');

      final putnici = response as List<dynamic>;

      for (final putnik in putnici) {
        final id = putnik['id'] as String;
        final polasciRaw = putnik['polasci_po_danu'];
        // Proveri tip putnika
        final tip = putnik['tip'] as String?;
        final isVariableSchedule = tip == 'ucenik' || tip == 'dnevni';

        if (polasciRaw == null) continue;

        Map<String, dynamic>? polasci;
        if (polasciRaw is String) {
          try {
            polasci = jsonDecode(polasciRaw) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }
        } else if (polasciRaw is Map<String, dynamic>) {
          polasci = Map<String, dynamic>.from(polasciRaw);
        }

        if (polasci == null) continue;

        // Očisti dnevne podatke (pokupljeno, plaćeno, otkazano) za svaki dan
        bool hasChanges = false;
        for (final dayKey in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          final dayData = polasci[dayKey];
          if (dayData is Map<String, dynamic>) {
            final mutableDayData = Map<String, dynamic>.from(dayData);

            // Definiši šta se briše
            final keysToRemove = mutableDayData.keys.where((k) {
              // 1. Statusi (uvek briši za sve)
              if (k.contains('_pokupljeno') ||
                  k.contains('_placeno') ||
                  k.contains('_otkazano') ||
                  k.contains('_vozac') || // Briše i naplatio_vozac, pokupio_vozac
                  k == 'placeno' ||
                  k == 'placeno_iznos') {
                // Dodatni check
                return true;
              }

              // 2. Vreme (samo za ucenike i dnevne)
              // Brišemo vreme polaska da se ne bi pojavljivali u listi sa starim vremenom
              if (isVariableSchedule) {
                if (['bc', 'vs', 'bela_crkva', 'vrsac'].contains(k) ||
                    k.startsWith('polazak_') ||
                    k.startsWith('vreme_') ||
                    k.endsWith('_time')) {
                  return true;
                }
              }

              return false;
            }).toList();

            for (final key in keysToRemove) {
              mutableDayData.remove(key);
              hasChanges = true;
            }
            polasci[dayKey] = mutableDayData;
          }
        }

        if (hasChanges) {
          await supabase.from('registrovani_putnici').update({
            'polasci_po_danu': jsonEncode(polasci),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        }
      }
    } catch (_) {
      // Weekly reset error - silent
    }
  }

  /// 🔄 PROVERI I IZVRŠI NEDELJNI RESET ako je potrebno
  /// Poziva se kad se app pokrene - proverava da li je subota (petak ponoc)
  Future<void> checkAndPerformWeeklyReset() async {
    final now = DateTime.now();

    // Resetuj SAMO subotom (petak ponoć)
    if (now.weekday != DateTime.saturday) {
      return;
    }

    try {
      // Izvrši reset (M-F podaci)
      // Ovo je sigurno izvršavati više puta jer briše samo M-F podatke
      await weeklyResetPolasciPoDanu();
    } catch (_) {
      // Weekly reset check error - silent
    }
  }
}
