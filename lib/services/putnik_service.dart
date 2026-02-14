import 'dart:async';
import 'dart:convert' as convert;

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
  final String type; // 'delete', 'pickup', 'payment', 'cancel', 'odsustvo'
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
  static final Map<String, StreamSubscription<dynamic>> _realtimeSubscriptions = {};

  // ?? UNDO STACK - Stack za cuvanje poslednih akcija
  static final List<UndoAction> undoStack = [];

  /// ?? Zatvori specifican stream po kljucu
  static void closeStream({String? isoDate, String? grad, String? vreme}) {
    final key = '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
    final controller = _streams[key];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    // Otkaži realtime subscription
    _realtimeSubscriptions[key]?.cancel();

    _streams.remove(key);
    _lastValues.remove(key);
    _streamParams.remove(key);
    _realtimeSubscriptions.remove(key);
    print('?? DEBUG: Stream zatvoren key=$key');
  }

  String _streamKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// ?? STREAM ZA FILTRIRANE PUTNIKE
  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    final key = _streamKey(isoDate: isoDate, grad: grad, vreme: vreme);

    // Ako stream vec postoji, vrati ga
    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      final controller = _streams[key]!;
      if (_lastValues.containsKey(key)) {
        Future.microtask(() {
          if (!controller.isClosed) {
            controller.add(_lastValues[key]!);
          }
        });
      } else {
        // Ucitaj podatke
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

  /// ?? FETCH PUTNIKA ZA CEO DAN (bez filtriranja grada/vremena)
  Future<List<Putnik>> getPutniciByDayIso(String isoDate) async {
    try {
      final combined = <Putnik>[];

      // Fetch monthly rows for the relevant day (if isoDate provided, convert)
      String? danKratica;
      try {
        final dt = DateTime.parse(isoDate);
        const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
        danKratica = dani[dt.weekday - 1];
      } catch (_) {
        danKratica = _getDayAbbreviationFromName(_getTodayName());
      }

      final todayDate = isoDate.split('T')[0];

      // ?? Ucitaj otkazivanja iz voznje_log za sve putnike
      final otkazivanja = await VoznjeLogService.getOtkazivanjaZaSvePutnike();

      final registrovani = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false); // ?? Ne ucitavaj duplikate

      for (final m in registrovani) {
        // Kreiraj putnike SAMO za ciljani dan
        final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(m, danKratica, isoDate: isoDate);

        // Dohvati uklonjene termine za ovog putnika
        final uklonjeniTerminiRaw = m['uklonjeni_termini'];
        late final List<dynamic> uklonjeniTermini;
        if (uklonjeniTerminiRaw is List<dynamic>) {
          uklonjeniTermini = uklonjeniTerminiRaw;
        } else if (uklonjeniTerminiRaw is String) {
          // 📦 Ako je JSON string, parsiraj ga
          try {
            final parsed = convert.jsonDecode(uklonjeniTerminiRaw);
            uklonjeniTermini = parsed is List ? List<dynamic>.from(parsed) : [];
          } catch (e) {
            debugPrint('⚠️ [PutnikService] Greška pri parsiranju uklonjeni_termini za putnika ${m['ime']}: $e');
            uklonjeniTermini = [];
          }
        } else {
          // Ako je neki drugi tip, pretvori u praznu listu
          uklonjeniTermini = [];
          if (uklonjeniTerminiRaw != null) {
            debugPrint('?? [PutnikService] uklonjeni_termini nije lista za putnika ${m['ime']}: $uklonjeniTerminiRaw');
          }
        }

        for (var p in putniciZaDan) {
          // Proveri da li je putnik uklonjen iz ovog termina
          final jeUklonjen = uklonjeniTermini.any((ut) {
            if (ut is! Map<String, dynamic>) return false;
            final utMap = ut;
            final utVreme = GradAdresaValidator.normalizeTime(utMap['vreme']?.toString());
            final pVreme = GradAdresaValidator.normalizeTime(p.polazak);
            final utDatum = utMap['datum']?.toString().split('T')[0];
            return utDatum == todayDate && utVreme == pVreme && utMap['grad'] == p.grad;
          });
          if (jeUklonjen) continue;

          // Dopuni otkazivanje iz voznje_log
          if (p.jeOtkazan && p.vremeOtkazivanja == null && p.id != null) {
            final Map<String, dynamic>? oData = otkazivanja[p.id];
            if (oData != null) {
              p = p.copyWith(
                vremeOtkazivanja: oData['datum'] as DateTime?,
                otkazaoVozac: oData['vozacIme'] as String?,
              );
            }
          }

          combined.add(p);
        }
      }
      return combined;
    } catch (e) {
      return [];
    }
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

      final todayDate = (isoDate ?? DateTime.now().toIso8601String()).split('T')[0];

      // ?? Ucitaj otkazivanja iz voznje_log za sve putnike
      final otkazivanja = await VoznjeLogService.getOtkazivanjaZaSvePutnike();

      final registrovani = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .eq('is_duplicate', false); // ?? Ne ucitavaj duplikate

      for (final m in registrovani) {
        // ? ISPRAVKA: Kreiraj putnike SAMO za ciljani dan
        final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(m, danKratica, isoDate: todayDate);

        // ?? Dohvati uklonjene termine za ovog putnika
        final uklonjeniTerminiRaw = m['uklonjeni_termini'];
        late final List<dynamic> uklonjeniTermini;
        if (uklonjeniTerminiRaw is List<dynamic>) {
          uklonjeniTermini = uklonjeniTerminiRaw;
        } else if (uklonjeniTerminiRaw is String) {
          // 📦 Ako je JSON string, parsiraj ga
          try {
            final parsed = convert.jsonDecode(uklonjeniTerminiRaw);
            uklonjeniTermini = parsed is List ? List<dynamic>.from(parsed) : [];
          } catch (e) {
            debugPrint('⚠️ [PutnikService] Greška pri parsiranju uklonjeni_termini za putnika ${m['ime']}: $e');
            uklonjeniTermini = [];
          }
        } else {
          // Ako je neki drugi tip, pretvori u praznu listu
          uklonjeniTermini = [];
          if (uklonjeniTerminiRaw != null) {
            debugPrint('?? [PutnikService] uklonjeni_termini nije lista za putnika ${m['ime']}: $uklonjeniTerminiRaw');
          }
        }

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
            if (ut is! Map<String, dynamic>) return false;
            final utMap = ut;
            // Normalizuj vreme za poredenje
            final utVreme = GradAdresaValidator.normalizeTime(utMap['vreme']?.toString());
            final pVreme = GradAdresaValidator.normalizeTime(p.polazak);
            // Datum može biti ISO format ili kraći format
            final utDatum = utMap['datum']?.toString().split('T')[0];
            return utDatum == todayDate && utVreme == pVreme && utMap['grad'] == p.grad;
          });
          if (jeUklonjen) {
            continue;
          }

          // ?? Dopuni otkazivanje iz voznje_log ako putnik nema vremeOtkazivanja
          if (p.jeOtkazan && p.vremeOtkazivanja == null && p.id != null) {
            final Map<String, dynamic>? oData = otkazivanja[p.id];
            if (oData != null) {
              p = p.copyWith(
                vremeOtkazivanja: oData['datum'] as DateTime?,
                otkazaoVozac: oData['vozacIme'] as String?,
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

      // 🔄 NOVO: Setup realtime listener da osvežava stream kada se podaci promene
      _setupRealtimeRefresh(key, isoDate, grad, vreme, controller);
    } catch (e) {
      debugPrint('?? [PutnikService] Error u _doFetchForStream: $e');
      _lastValues[key] = [];
      if (!controller.isClosed) {
        controller.add([]);
      }
    }
  }

  /// 🔄 NOVO: Setup realtime listener za refresh streama
  void _setupRealtimeRefresh(
    String key,
    String? isoDate,
    String? grad,
    String? vreme,
    StreamController<List<Putnik>> controller,
  ) {
    // Otkaži stare subscription
    _realtimeSubscriptions[key]?.cancel();

    // Pretplati se na promene u registrovani_putnici tabeli
    final subscription = RealtimeManager.instance.subscribe('registrovani_putnici').listen(
      (_) {
        // Kada se dogode promene, re-fetch podatke
        _doFetchForStream(key, isoDate, grad, vreme, controller);
      },
      onError: (error) {
        debugPrint('?? [PutnikService] Realtime error: $error');
      },
    );

    _realtimeSubscriptions[key] = subscription;
  }

  // ? DODATO: JOIN sa adrese tabelom za obe adrese
  static const String registrovaniFields = '*,'
      'polasci_po_danu';

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
  // ?? DODATO: Opcioni parametar grad za precizniji rezultat
  Future<Putnik?> getPutnikByName(String imePutnika, {String? grad}) async {
    try {
      final registrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (registrovaniResponse != null) {
        // ?? Ako je grad specificiran, vrati putnika za taj grad
        if (grad != null) {
          final weekday = DateTime.now().weekday;
          const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
          final danKratica = daniKratice[weekday - 1];

          final putnici = Putnik.fromRegistrovaniPutniciMultipleForDay(registrovaniResponse, danKratica);
          // ? FIX: Case-insensitive matching i normalizacija grada (Vr�ac/Vrsac, Bela Crkva)
          final normalizedGrad = grad.toLowerCase();
          final matching = putnici.where((p) {
            final pGrad = p.grad.toLowerCase();
            // Proveri da li se gradovi podudaraju (ukljuci varijacije)
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
          await supabase.from('registrovani_putnici').select(registrovaniFields).eq('id', id).limit(1);

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

  /// Ucitaj sve putnike iz registrovani_putnici tabele
  Future<List<Putnik>> getAllPutnici({String? targetDay}) async {
    List<Putnik> allPutnici = [];

    try {
      final targetDate = targetDay ?? _getTodayName();

      // ??? CILJANI DAN: Ucitaj putnike iz registrovani_putnici za selektovani dan
      final danKratica = _getDayAbbreviationFromName(targetDate);

      // Explicitly request polasci_po_danu and common per-day columns
      const registrovaniFields = '*,'
          'polasci_po_danu';

      // 🚀 OPTIMIZOVANO: Filtriraj po radni_dani direktno u SQL-u sa like za bolje performanse
      // Učitaj samo putnike čiji radni_dani sadrže zadati dan
      final registrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .like('radni_dani', '%$danKratica%') // 🔍 Filtrira direktno u bazi
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

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
    if (undoStack.isEmpty) {
      return 'Nema akcija za poništavanje';
    }

    final lastAction = undoStack.removeLast();

    try {
      final tabela = await _getTableForPutnik(lastAction.putnikId);

      switch (lastAction.type) {
        case 'delete':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
            'aktivan': true,
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno brisanje putnika';

        case 'pickup':
          // Pokupljanje se više ne poništava preko kolona u registrovani_putnici
          // Samo se može obrisati zapis iz voznje_log ako je potrebno
          return 'Poništeno pokupljanje';

        case 'payment':
          // Plaćanje se više ne poništava preko kolona u registrovani_putnici
          // Treba obrisati zapis iz voznje_log
          return 'Poništeno plaćanje';

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

  /// ?? DODAJ PUTNIKA (dnevni ili mesecni) - ??? SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik, {bool skipKapacitetCheck = false}) async {
    try {
      // 🎯 SVI PUTNICI MORAJU BITI REGISTROVANI
      // Ad-hoc putnici više ne postoje - svi tipovi (radnik, učenik, dnevni)
      // moraju biti u registrovani_putnici tabeli
      if (putnik.mesecnaKarta != true) {
        throw Exception(
          'NEREGISTROVAN PUTNIK!\n\n'
          'Svi putnici moraju biti registrovani u sistemu.\n'
          'Idite na: Meni → Mesečni putnici da kreirate novog putnika.',
        );
      }

      // ??? STRIKTNA VALIDACIJA VOZACA
      if (putnik.dodeljenVozac == null ||
          putnik.dodeljenVozac!.isEmpty ||
          !(VozacBoja.isValidDriverSync(putnik.dodeljenVozac))) {
        final validDrivers = VozacBoja.validDriversSync;
        throw Exception(
          'NEREGISTROVAN VOZAC: "${putnik.dodeljenVozac}". Dozvoljeni su samo: ${validDrivers.join(", ")}',
        );
      }

      // 🛡️ VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        throw Exception(
          'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.',
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

      // ?? PROVERA KAPACITETA - Da li ima slobodnih mesta?
      // ??? PRESKACI AKO JE skipKapacitetCheck=true (Admin bypass)
      if (!skipKapacitetCheck) {
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
                  'Admini mogu dodati preko kapaciteta.',
                );
              }
            }
          }
        }
      }

      // ?? PROVERI DUPLIKATE ZA TAJ TERMIN
      final existingPutnici = await supabase
          .from('registrovani_putnici')
          .select('id, putnik_ime, aktivan, polasci_po_danu, radni_dani')
          .eq('putnik_ime', putnik.ime)
          .eq('aktivan', true);

      if (existingPutnici.isEmpty) {
        throw Exception('PUTNIK NE POSTOJI!\n\n'
            'Putnik "${putnik.ime}" ne postoji u listi registrovanih putnika.\n'
            'Idite na: Meni → Mesečni putnici da kreirate novog putnika.');
      }

      // 🔄 AŽURIRAJ polasci_po_danu za putnika sa novim polaskom
      final registrovaniPutnik = existingPutnici.first;
      final putnikId = registrovaniPutnik['id'] as String;

      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasciPoDanu = registrovaniPutnik['polasci_po_danu'];

      // ??? polasci_po_danu je sada JSONB, direktno parsira kao Map
      if (rawPolasciPoDanu != null) {
        if (rawPolasciPoDanu is Map) {
          polasciPoDanu = Map<String, dynamic>.from(rawPolasciPoDanu);
        }
      }

      final danKratica = putnik.dan.toLowerCase();

      final gradKeyLower = GradAdresaValidator.isBelaCrkva(putnik.grad) ? 'bc' : 'vs';

      final polazakVreme = GradAdresaValidator.normalizeTime(putnik.polazak);

      // CUVAJ POSTOJECE PODATKE - ne kreiraj novu mapu sa samo bc/vs
      if (!polasciPoDanu.containsKey(danKratica)) {
        polasciPoDanu[danKratica] = <String, dynamic>{'bc': null, 'vs': null};
      } else if (polasciPoDanu[danKratica] is! Map) {
        // Ako dan postoji ali nije mapa, kreiraj novu
        polasciPoDanu[danKratica] = <String, dynamic>{'bc': null, 'vs': null};
      }

      // Kopiraj postojece podatke - ne briši markere!
      final danPolasci = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map);

      // Ažuriraj samo vreme, cuvaj ostale markere
      danPolasci[gradKeyLower] = polazakVreme;
      // 🆕 Dodaj broj mesta ako je > 1
      if (putnik.brojMesta > 1) {
        danPolasci['${gradKeyLower}_mesta'] = putnik.brojMesta;
      } else {
        danPolasci.remove('${gradKeyLower}_mesta');
      }

      // 📍 Dodaj "adresa danas" ako je prosleđena (override za ovaj dan)
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

      // Ažuriraj mesecnog putnika u bazi
      // ⚠️ UKLONJENO: updated_by izaziva foreign key grešku jer UUID nije u tabeli users
      // final updatedByUuid = VozacMappingService.getVozacUuidSync(putnik.dodeljenVozac ?? '');

      // 📝 Pripremi update mapu - BEZ updated_by (foreign key constraint)
      final updateData = <String, dynamic>{
        'polasci_po_danu': polasciPoDanu,
        'radni_dani': radniDani,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // ? UKLONJENO: updated_by foreign key constraint ka users tabeli
      // if (updatedByUuid != null && updatedByUuid.isNotEmpty) {
      //   updateData['updated_by'] = updatedByUuid;
      // }

      await supabase.from('registrovani_putnici').update(updateData).eq('id', putnikId);

      // ?? NOTIFIKACIJA UKLONJENA PO NALOGU 16.01.2026.
      // Prethodno je ovde bila logika za slanje push notifikacije svim vozacima (RealtimeNotificationService.sendNotificationToAllDrivers)
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
    // 🛡️ Provera da li je ID validan
    if (id == null || (id is String && id.isEmpty)) {
      debugPrint('⚠️ [PutnikService] Pokušaj uklanjanja termina za nevažeći ID: $id');
      return;
    }

    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select('uklonjeni_termini').eq('id', id as String).single();

    List<dynamic> uklonjeni = [];
    if (response['uklonjeni_termini'] != null) {
      final uklonjeniRaw = response['uklonjeni_termini'];
      try {
        if (uklonjeniRaw is List) {
          uklonjeni = List<dynamic>.from(uklonjeniRaw);
        } else if (uklonjeniRaw is String) {
          // 📦 Ako je JSON string, parsiraj ga
          final parsed = convert.jsonDecode(uklonjeniRaw);
          if (parsed is List) {
            uklonjeni = List<dynamic>.from(parsed);
          }
        }
      } catch (e) {
        debugPrint('❌ [PutnikService] Greška pri parsiranju uklonjeni_termini za putnika $id: $e');
      }
    }

    // Normalizuj vrednosti pre čuvanja za konzistentno poređenje
    final normDatum = datum.split('T')[0]; // ISO format bez vremena
    final normVreme = GradAdresaValidator.normalizeTime(vreme);

    // Spreči dupliranje istog termina
    final vecPostoji = uklonjeni.any((ut) {
      if (ut is! Map<String, dynamic>) return false;
      final utMap = ut;
      final utVreme = GradAdresaValidator.normalizeTime(utMap['vreme']?.toString());
      final utDatum = utMap['datum']?.toString().split('T')[0];
      return utDatum == normDatum && utVreme == normVreme && utMap['grad'] == grad;
    });

    if (vecPostoji) return;

    uklonjeni.add({
      'datum': normDatum,
      'vreme': normVreme,
      'grad': grad,
    });

    await supabase.from(tabela).update({
      'uklonjeni_termini': uklonjeni,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// 🗑️ OBRISI PUTNIKA (Soft Delete - čuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    final tabela = await _getTableForPutnik(id);
    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();

    // 🔄 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoResponse = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('delete', id, undoResponse);

    // 🛡️ NE menjaj status - constraint check_registrovani_status_valid dozvoljava samo:
    // 'aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godišnji'
    await supabase.from(tabela).update({
      'obrisan': true, // ✅ Soft delete flag
    }).eq('id', id);
  }

  /// 🚶 OZNACI KAO POKUPLJEN
  /// [grad] - opcioni parametar za određivanje koje pokupljenje (BC ili VS)
  /// [selectedDan] - opcioni parametar za dan (npr. "Pon", "Uto") - ako nije prosleđen, koristi današnji dan
  Future<void> oznaciPokupljen(dynamic id, String currentDriver,
      {String? grad, String? selectedDan, String? selectedVreme}) async {
    // 🛡️ DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    if (currentDriver.isEmpty) {
      throw ArgumentError(
        'Vozač mora biti specificiran.',
      );
    }

    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;
    final putnik = Putnik.fromMap(response);

    // 🔄 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPickup = Map<String, dynamic>.from(response);
    _addToUndoStack('pickup', id, undoPickup);

    if (tabela == 'registrovani_putnici') {
      final now = DateTime.now();
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver);

      // 📦 NOVO: polasci_po_danu je sada JSONB objekat
      Map<String, dynamic> polasciPoDanu = {};
      final rawPolasci = response['polasci_po_danu'];
      if (rawPolasci != null) {
        if (rawPolasci is Map) {
          polasciPoDanu = Map<String, dynamic>.from(rawPolasci);
        }
      }

      final bool jeBC = GradAdresaValidator.isBelaCrkva(grad);
      final place = jeBC ? 'bc' : 'vs';

      // 🔍 FIX: Odredi dan kratica - pronađi koji dan ima taj grad i vreme
      const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
      String danKratica = '';

      // Prvo pokušaj sa selectedDan ako je prosleđen
      if (selectedDan != null && selectedDan.isNotEmpty) {
        final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
        if (daniKratice.contains(normalizedDan)) {
          danKratica = normalizedDan;
        }
      }

      // Ako nije pronađen, pronađi iz polasci_po_danu koji dan ima taj grad i vreme
      final vremeZaPretragu = selectedVreme ?? putnik.polazak;
      if (danKratica.isEmpty && vremeZaPretragu.isNotEmpty) {
        for (var entry in polasciPoDanu.entries) {
          final dayName = entry.key;
          final dayData = entry.value;
          if (dayData is Map) {
            final vremeDaDay = dayData[place]?.toString();
            if (vremeDaDay == vremeZaPretragu) {
              danKratica = dayName;
              break;
            }
          }
        }
      }

      // Ako i dalje nije pronađen, koristi danas kao fallback
      if (danKratica.isEmpty) {
        danKratica = daniKratice[now.weekday - 1];
      }

      // Ažuriraj dan sa pokupljenjem
      final dayData = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map? ?? {});
      dayData['${place}_pokupljeno'] = now.toIso8601String();
      dayData['${place}_pokupljeno_vozac'] = currentDriver; // Ime vozača, ne UUID
      polasciPoDanu[danKratica] = dayData;

      await supabase.from(tabela).update({
        'polasci_po_danu': polasciPoDanu,
        'updated_at': now.toUtc().toIso8601String(),
      }).eq('id', id);

      // 📝 DODAJ ZAPIS U voznje_log za praćenje vožnji
      final danas = now.toIso8601String().split('T')[0];
      try {
        await supabase.from('voznje_log').insert({
          'putnik_id': id.toString(),
          'datum': danas,
          'tip': 'voznja',
          'iznos': 0,
          'vozac_id': vozacUuid,
          'broj_mesta': putnik.brojMesta, // 🎫 Dodaj broj mesta za tačan obračun
        });
      } catch (logError) {
        // Log insert not critical
      }
    }

    // 📈 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
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

  /// 💰 OZNACI KAO PLACENO
  /// [grad] - parametar za određivanje koje plaćanje (BC ili VS) - ISTO kao oznaciPokupljen
  /// [selectedVreme] - vreme polaska da bi se pronašao pravi dan
  Future<void> oznaciPlaceno(
    dynamic id,
    double iznos,
    String currentDriver, {
    String? grad,
    String? selectedVreme,
    String? selectedDan,
  }) async {
    // 🛡️ DUPLICATE PREVENTION
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

    // 🔍 FIX: Odredi dan kratica - pronađi koji dan ima taj grad i vreme
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    String danKratica = '';

    Map<String, dynamic> polasciPoDanu = {};
    final rawPolasci = response['polasci_po_danu'];
    if (rawPolasci != null) {
      if (rawPolasci is Map) {
        polasciPoDanu = Map<String, dynamic>.from(rawPolasci);
      }
    }

    // 🔍 FIX: Izračunaj place iz grad parametra - ISTO kao oznaciPokupljen!
    final bool jeBC = GradAdresaValidator.isBelaCrkva(grad);
    final place = jeBC ? 'bc' : 'vs';

    // Prvo pokušaj sa selectedDan ako je prosleđen
    if (selectedDan != null && selectedDan.isNotEmpty) {
      final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
      if (daniKratice.contains(normalizedDan)) {
        danKratica = normalizedDan;
      }
    }

    // Ako nije pronađen, pronađi dan koji ima taj grad i vreme
    if (danKratica.isEmpty && selectedVreme != null && selectedVreme.isNotEmpty) {
      for (var entry in polasciPoDanu.entries) {
        final dayName = entry.key;
        final dayData = entry.value;
        if (dayData is Map) {
          final vremeDaDay = dayData[place]?.toString();
          if (vremeDaDay == selectedVreme) {
            danKratica = dayName;
            break;
          }
        }
      }
    }
    // Ako nije pronađen, koristi danas kao fallback
    if (danKratica.isEmpty) {
      danKratica = daniKratice[now.weekday - 1];
    }

    // Ažuriraj dan sa plaćanjem - dozvoli VIŠESTRUKO PLAĆANJE
    final dayData = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map? ?? {});

    // Kreiraj ili ažuriraj niz za plaćanja
    List<Map<String, dynamic>> placanjaLista = [];
    final oldPlacanja = dayData['${place}_placanja'];
    if (oldPlacanja is List) {
      placanjaLista =
          List<Map<String, dynamic>>.from(oldPlacanja.map((p) => p is Map ? Map<String, dynamic>.from(p) : {}));
    }

    // Dodaj novo plaćanje
    placanjaLista.add({
      'iznos': iznos,
      'vozac': currentDriver,
      'vreme': now.toIso8601String(),
    });

    // Ažuriraj agregirane vrednosti
    dayData['${place}_placeno'] = now.toIso8601String(); // Poslednje plaćanje
    dayData['${place}_placeno_vozac'] = currentDriver;
    dayData['${place}_placanja'] = placanjaLista; // Niz svih plaćanja
    dayData['${place}_placeno_iznos'] = placanjaLista.fold<double>(
      0,
      (sum, p) => sum + ((p['iznos'] as num?)?.toDouble() ?? 0),
    ); // Ukupan iznos
    polasciPoDanu[danKratica] = dayData;

    await supabase.from(tabela).update({
      'polasci_po_danu': polasciPoDanu,
      'updated_at': now.toUtc().toIso8601String(),
    }).eq('id', id);

    // ? FIX: Loguj uplatu u voznje_log tabelu za statistike
    String? vozacId;
    try {
      if (!VozacMappingService.isInitialized) {
        await VozacMappingService.initialize();
      }
      vozacId = VozacMappingService.getVozacUuidSync(currentDriver);
      vozacId ??= await VozacMappingService.getVozacUuid(currentDriver);

      // Nema fallback-a - ako mapping ne radi, vozacId ostaje null
    } catch (e) {
      debugPrint('? markAsPaid: Greška pri VozacMapping za "$currentDriver": $e');
      // Nema fallback-a za hardkodovani UUID
    }

    if (vozacId == null) {
      debugPrint('⚠️ markAsPaid: vozacId je NULL za vozaca "$currentDriver" - uplata nece biti u statistici!');
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

  /// 🛑 OTKAŽI PUTNIKA - sada čuva otkazivanje PO POLASKU (grad) u polasci_po_danu JSON
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

      // 🔄 DODAJ U UNDO STACK
      _addToUndoStack('cancel', idStr, respMap);

      if (tabela == 'registrovani_putnici') {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);

        // 📍 Odredi place (bc/vs) iz selectedGrad ili iz putnikovog grada
        String place = 'bc'; // default
        final gradZaOtkazivanje = selectedGrad ?? respMap['grad'] as String? ?? '';
        if (gradZaOtkazivanje.toLowerCase().contains('vr') || gradZaOtkazivanje.toLowerCase().contains('vs')) {
          place = 'vs';
        }

        // 🔍 FIX: Koristi selectedDan umesto DateTime.now() - omogućava otkazivanje za bilo koji dan
        const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
        String danKratica = '';

        // Prvo pokušaj sa selectedDan ako je prosleđen
        if (selectedDan != null && selectedDan.isNotEmpty) {
          final normalizedDan = selectedDan.toLowerCase().substring(0, 3);
          if (daniKratice.contains(normalizedDan)) {
            danKratica = normalizedDan;
          }
        }

        // Ako nije pronađen, pronađi iz polasci_po_danu koji dan ima taj grad i vreme
        if (danKratica.isEmpty) {
          // ?? Ucitaj postojeci polasci_po_danu JSON prvo
          Map<String, dynamic> polasci = {};
          final polasciRaw = respMap['polasci_po_danu'];
          if (polasciRaw != null) {
            if (polasciRaw is String) {
              try {
                polasci = convert.jsonDecode(polasciRaw) as Map<String, dynamic>;
              } catch (_) {}
            } else if (polasciRaw is Map) {
              polasci = Map<String, dynamic>.from(polasciRaw);
            }
          }

          if (selectedVreme != null && selectedVreme.isNotEmpty) {
            for (var entry in polasci.entries) {
              final dayName = entry.key;
              final dayData = entry.value;
              if (dayData is Map) {
                final vremeDaDay = dayData[place]?.toString();
                if (vremeDaDay == selectedVreme) {
                  danKratica = dayName;
                  break;
                }
              }
            }
          }
        }

        // Ako i dalje nije pronaden, koristi danas kao fallback
        if (danKratica.isEmpty) {
          danKratica = daniKratice[DateTime.now().weekday - 1];
        }

        // ?? Ucitaj postojeci polasci_po_danu JSON
        Map<String, dynamic> polasci = {};
        final polasciRaw = respMap['polasci_po_danu'];
        if (polasciRaw != null) {
          if (polasciRaw is String) {
            try {
              polasci = convert.jsonDecode(polasciRaw) as Map<String, dynamic>;
            } catch (_) {}
          } else if (polasciRaw is Map) {
            polasci = Map<String, dynamic>.from(polasciRaw);
          }
        }

        // ?? Dodaj/ažuriraj otkazivanje za specifican dan i grad
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
          'updated_at': now.toUtc().toIso8601String(),
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

      // 🔔 POŠALJI NOTIFIKACIJU ZA OTKAZIVANJE (samo za tekući dan)
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

  /// 🏥 OZNACI KAO BOLOVANJE/GODIŠNJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
    dynamic id,
    String tipOdsustva,
    String currentDriver,
  ) async {
    // ?? DEBUG LOG
    // ? dynamic umesto int
    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id).maybeSingle();
    if (response == null) return;

    final undoOdsustvo = response;
    _addToUndoStack('odsustvo', id, undoOdsustvo);

    // 🛡️ FIX: Koristi 'godisnji' bez dijakritike jer tako zahteva DB constraint
    String statusZaBazu = tipOdsustva.toLowerCase();
    if (statusZaBazu == 'godišnji') {
      statusZaBazu = 'godisnji';
    }

    // 📋 LOG U DNEVNIK
    await VoznjeLogService.logGeneric(
      tip: statusZaBazu == 'radi' ? 'povratak_na_posao' : 'odsustvo',
      putnikId: id.toString(),
      vozacId: currentDriver == 'self' ? null : await VozacMappingService.getVozacUuid(currentDriver),
    );

    // 🛡️ ADMIN AUDIT LOG: Zabeleži promenu statusa (odsustvo/povratak)
    final currentUser = supabase.auth.currentUser;

    try {
      await supabase.from(tabela).update({
        'status': statusZaBazu,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// 🚐 PREBACI PUTNIKA DRUGOM VOZAČU (ili ukloni vozača)
  /// Ažurira `vozac_id` kolonu u registrovani_putnici tabeli
  /// Ako je noviVozac null, uklanja vozača sa putnika
  Future<void> prebacijPutnikaVozacu(String putnikId, String? noviVozac) async {
    try {
      String? vozacUuid;

      if (noviVozac != null) {
        if (!(VozacBoja.isValidDriverSync(noviVozac))) {
          final validDrivers = VozacBoja.validDriversSync;
          throw Exception(
            'Nevalidan vozač: "$noviVozac". Dozvoljeni: ${validDrivers.join(", ")}',
          );
        }
        vozacUuid = await VozacMappingService.getVozacUuid(noviVozac);
        if (vozacUuid == null) {
          throw Exception('Vozač "$noviVozac" nije pronađen u bazi');
        }
      }

      // 🔄 POJEDNOSTAVLJENO: Svi putnici su sada u registrovani_putnici
      await supabase.from('registrovani_putnici').update({
        'vozac_id': vozacUuid, // null ako se uklanja vozac
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', putnikId);
    } catch (e) {
      throw Exception('Greška pri prebacivanju putnika: $e');
    }
  }

  /// 🎯 DODELI PUTNIKA VOZAČU ZA SPECIFIČAN PRAVAC (bc/vs)
  /// Čuva bc_vozac ili vs_vozac u polasci_po_danu JSON za specifičan dan
  /// [putnikId] - ID putnika
  /// [noviVozac] - Ime vozača (npr. "Bilevski") ili null za uklanjanje
  /// [place] - 'bc' za Bela Crkva pravac ili 'vs' za Vršac pravac
  /// 🔄 AŽURIRANO: Dodeli putnika vozaču za specifičan pravac (bc/vs), dan i VREME
  /// [putnikId] - UUID putnika iz registrovani_putnici
  /// [noviVozac] - Ime vozača (npr. "Voja", "Bilevski") ili null za uklanjanje
  /// [place] - Pravac: "bc" za Bela Crkva, "vs" za Vršac
  /// [vreme] - Vreme polaska (npr. "5:00", "14:00") - obavezno za specifično dodeljivanje
  /// [selectedDan] - Dan u nedelji (npr. "pon", "Ponedeljak") - opcionalno, default je danas
  Future<void> dodelPutnikaVozacuZaPravac(
    String putnikId,
    String? noviVozac,
    String place, {
    String? vreme, // ⏱️ OBAVEZAN parametar za vreme polaska
    String? selectedDan,
  }) async {
    try {
      // Validacija vozača
      if (noviVozac != null && !(VozacBoja.isValidDriverSync(noviVozac))) {
        final validDrivers = VozacBoja.validDriversSync;
        throw Exception(
          'Nevalidan vozač: "$noviVozac". Dozvoljeni: ${validDrivers.join(", ")}',
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

      // Ucitaj postojeci polasci_po_danu JSON
      Map<String, dynamic> polasci = {};
      final polasciRaw = response['polasci_po_danu'];
      if (polasciRaw != null) {
        if (polasciRaw is String) {
          try {
            polasci = convert.jsonDecode(polasciRaw) as Map<String, dynamic>;
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

      // ?? Kljuc ukljucuje vreme: 'bc_5:00_vozac' ili 'vs_14:00_vozac'
      String vozacKey;
      if (vreme != null && vreme.isNotEmpty) {
        final normalizedVreme = GradAdresaValidator.normalizeTime(vreme);
        if (normalizedVreme.isNotEmpty) {
          vozacKey = '${place}_${normalizedVreme}_vozac';
        } else {
          vozacKey = '${place}_vozac'; // fallback ako normalizacija ne uspe
        }
      } else {
        // Fallback na stari format (bez vremena) ako vreme nije prosledeno
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', putnikId);
    } catch (e) {
      throw Exception('Greška pri dodeljivanju vozača za pravac: $e');
    }
  }
}
