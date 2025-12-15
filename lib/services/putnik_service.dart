import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_log.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart'; // DODANO za validaciju gradova i adresa
import '../utils/registrovani_helpers.dart';
import '../utils/vozac_boja.dart'; // DODATO za validaciju vozača
import 'driver_location_service.dart'; // DODANO za dinamički ETA update
import 'realtime_notification_service.dart';
import 'realtime_service.dart';
import 'registrovani_putnik_service.dart'; // DODANO za automatsku sinhronizaciju
import 'supabase_safe.dart';
import 'vozac_mapping_service.dart'; // DODATO za UUID<->ime konverziju

// 🔄 UNDO STACK - Stack za čuvanje poslednih akcija
class UndoAction {
  UndoAction({
    required this.type,
    required this.putnikId, // ✅ dynamic umesto int
    required this.oldData,
    required this.timestamp,
  });
  final String type; // 'delete', 'pickup', 'payment', 'cancel', 'odsustvo', 'reset'
  final dynamic putnikId; // ✅ dynamic umesto int
  final Map<String, dynamic> oldData;
  final DateTime timestamp;
}

class PutnikService {
  final supabase = Supabase.instance.client;

  // Stream caching: map of active filter keys to StreamController streams (bez RxDart)
  // ✅ STATIC da bi se delila između svih instanci PutnikService
  static final Map<String, StreamController<List<Putnik>>> _streams = {};
  static final Map<String, List<Putnik>> _lastValues = {}; // Cache poslednje vrednosti za replay
  static final Map<String, StreamSubscription> _subscriptions = {}; // Cuvaj subscriptions za cleanup

  /// 🧹 Statička metoda za čišćenje cache-a - poziva se iz GlobalCacheManager
  static void clearCache() {
    // Zatvori sve aktivne stream controllere
    for (final controller in _streams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streams.clear();
    _lastValues.clear();
    // Ne čistimo _subscriptions jer će se ponovo kreirati pri sledećem pozivu
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// 🔄 INVALIDATE CACHED VALUES - forsira sve aktivne streamove da ponovo učitaju podatke
  /// Ovo NE zatvara streamove, već samo briše keširane vrednosti tako da sledeći
  /// poziv na stream ili RealtimeService refresh triggeruje novi fetch
  static void invalidateCachedValues() {
    _lastValues.clear();
  }

  // Helper to create a cache key for filters
  String _streamKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// Returns a broadcast stream of combined Putnik objects where initial data
  /// is fetched using server-side filters for `isoDate` (applies to daily rows)
  /// and for monthly rows we filter by day abbreviation and optional grad/vreme.
  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    final key = _streamKey(isoDate: isoDate, grad: grad, vreme: vreme);

    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      // Ako imamo cached vrednost, emituj je odmah
      final controller = _streams[key]!;
      if (_lastValues.containsKey(key)) {
        Future.microtask(() => controller.add(_lastValues[key]!));
      }
      return controller.stream;
    }

    final controller = StreamController<List<Putnik>>.broadcast();
    _streams[key] = controller;

    Future<void> doFetch() async {
      try {
        final combined = <Putnik>[];

        // Svi putnici su u registrovani_putnici tabeli

        // Fetch monthly rows for the relevant day (if isoDate provided, convert)
        String? danKratica;
        if (isoDate != null) {
          try {
            final dt = DateTime.parse(isoDate);
            const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
            danKratica = dani[dt.weekday - 1];
          } catch (_) {}
        }
        danKratica ??= _getDayAbbreviationFromName(_getTodayName());

        // Query registrovani_putnici - uzmi aktivne putnike za ciljani dan
        final registrovani = await supabase
            .from('registrovani_putnici')
            .select(registrovaniFields)
            .eq('aktivan', true)
            .eq('obrisan', false);

        for (final m in registrovani) {
          // ✅ ISPRAVKA: Kreiraj putnike SAMO za ciljani dan
          final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(m, danKratica);
          for (final p in putniciZaDan) {
            // apply grad/vreme filter if provided
            final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
            final normVremeFilter = vreme != null ? GradAdresaValidator.normalizeTime(vreme) : null;

            if (grad != null && p.grad != grad) {
              continue;
            }
            if (normVremeFilter != null && normVreme != normVremeFilter) {
              continue;
            }

            combined.add(p);
          }
        }

        _lastValues[key] = combined; // Cache za replay
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

    // initial fetch
    doFetch();

    // 🔄 POJEDNOSTAVLJENO: Koristi samo combinedPutniciStream za sve slučajeve
    // Parametric stream je uklonjen jer doFetch() radi svoje filtriranje
    final sub = RealtimeService.instance.combinedPutniciStream.listen((_) {
      doFetch();
    });
    _subscriptions[key] = sub;

    // Cleanup kada se controller zatvori
    controller.onCancel = () async {
      await _subscriptions[key]?.cancel();
      _subscriptions.remove(key);
      _streams.remove(key);
      _lastValues.remove(key);
    };

    return controller.stream;
  }

  // Fields to explicitly request from registrovani_putnici
  // ✅ DODATO: JOIN sa adrese tabelom za obe adrese
  static const String registrovaniFields = '*,'
      'polasci_po_danu,'
      'adresa_bc:adresa_bela_crkva_id(id,naziv,ulica,broj,grad,koordinate),'
      'adresa_vs:adresa_vrsac_id(id,naziv,ulica,broj,grad,koordinate)';

  // 📚 UNDO STACK - Čuva poslednje akcije (max 10)
  static final List<UndoAction> _undoStack = [];
  static const int maxUndoActions = 10;

  // 🚫 DUPLICATE PREVENTION - Čuva poslednje akcije po putnik ID
  static final Map<String, DateTime> _lastActionTime = {};
  static const Duration _duplicatePreventionDelay = Duration(milliseconds: 500);

  /// 🚫 DUPLICATE PREVENTION HELPER
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

  // 📝 DODAJ U UNDO STACK
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

    // Ograniči stack na max broj akcija
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  // 🔍 HELPER - Određi tabelu na osnovu putnika
  // 🔄 POJEDNOSTAVLJENO: Sada postoji samo registrovani_putnici tabela
  Future<String> _getTableForPutnik(dynamic id) async {
    // Svi putnici su sada u registrovani_putnici
    return 'registrovani_putnici';
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  Future<Putnik?> getPutnikByName(String imePutnika) async {
    try {
      final registrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (registrovaniResponse != null) {
        return Putnik.fromRegistrovaniPutnici(registrovaniResponse);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po ID)
  // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
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

  // 🆕 BATCH UČITAVANJE PUTNIKA IZ BILO KOJE TABELE (po listi ID-eva)
  // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
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
      // Fallback na pojedinačne pozive ako batch ne uspe
      for (final id in ids) {
        final putnik = await getPutnikFromAnyTable(id);
        if (putnik != null) results.add(putnik);
      }
      return results;
    }
  }

  // 🆕 NOVI: Učitaj sve putnike iz registrovani_putnici
  // 🔄 POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    List<Putnik> allPutnici = [];

    try {
      final targetDate = targetDay ?? _getTodayName();

      // 🗓️ CILJANI DAN: Učitaj putnike iz registrovani_putnici za selektovani dan
      final danKratica = _getDayAbbreviationFromName(targetDate);

      // Explicitly request polasci_po_danu and common per-day columns
      const registrovaniFields = '*,'
          'polasci_po_danu';

      // ✅ OPTIMIZOVANO: Prvo učitaj sve aktivne, zatim filtriraj po danu u Dart kodu (sigurniji pristup)
      final allregistrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      // Filtriraj rezultate sa tačnim matchovanjem dana
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

        // ✅ VALIDACIJA: Prikaži samo putnike sa validnim vremenima polazaka
        final validPutnici = registrovaniPutnici.where((putnik) {
          final polazak = putnik.polazak.trim();
          // Poboljšana validacija vremena
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

  // Helper funkcija za dobijanje današnjeg imena dana
  String _getTodayName() {
    final danas = DateTime.now();
    const daniNazivi = [
      'Ponedeljak',
      'Utorak',
      'Sreda',
      'Četvrtak',
      'Petak',
      'Subota',
      'Nedelja',
    ];
    return daniNazivi[danas.weekday - 1];
  }

  // Helper funkcija za konverziju punog naziva dana u kraticu
  String _getDayAbbreviationFromName(String dayName) {
    switch (dayName.toLowerCase()) {
      case 'ponedeljak':
        return 'pon';
      case 'utorak':
        return 'uto';
      case 'sreda':
        return 'sre';
      case 'četvrtak':
        return 'cet';
      case 'petak':
        return 'pet';
      case 'subota':
        return 'sub';
      case 'nedelja':
        return 'ned';
      default:
        return 'pon'; // default fallback
    }
  }

  // 🆕 NOVI: Sačuvaj putnika u odgovarajuću tabelu (workaround - sve u registrovani_putnici)
  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      // SVI PUTNICI - koristi registrovani_putnici tabelu kao workaround za RLS
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

  // ↩️ UNDO POSLEDNJU AKCIJU
  Future<String?> undoLastAction() async {
    if (_undoStack.isEmpty) {
      return 'Nema akcija za poništavanje';
    }

    final lastAction = _undoStack.removeLast();

    try {
      // Određi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(lastAction.putnikId);

      switch (lastAction.type) {
        case 'delete':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
            'aktivan': true,
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno brisanje putnika';

        case 'pickup':
          await supabase.from(tabela).update({
            'broj_putovanja': lastAction.oldData['broj_putovanja'],
            'pokupljen': false,
            'vreme_pokupljenja': null,
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno pokupljanje';

        case 'payment':
          await supabase.from(tabela).update({
            'cena': null,
            'vreme_placanja': null,
            'vozac_id': null,
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno plaćanje';

        case 'cancel':
          await supabase.from(tabela).update({
            'status': lastAction.oldData['status'],
          }).eq('id', lastAction.putnikId as String);
          return 'Poništeno otkazivanje';

        default:
          return 'Nepoznata akcija za poništavanje';
      }
    } catch (e) {
      return null;
    }
  }

  /// ✅ DODAJ PUTNIKA (dnevni ili mesečni) - 🏘️ SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik) async {
    try {
      // 🚫 SVI PUTNICI MORAJU BITI REGISTROVANI
      // Ad-hoc putnici više ne postoje - svi tipovi (radnik, ucenik, dnevni)
      // moraju biti u registrovani_putnici tabeli
      if (putnik.mesecnaKarta != true) {
        throw Exception(
          'NEREGISTROVAN PUTNIK!\n\n'
          'Svi putnici moraju biti registrovani u sistemu.\n'
          'Idite na: Meni → Mesečni putnici da kreirate novog putnika.',
        );
      }

      // 🚫 STRIKTNA VALIDACIJA VOZAČA
      if (putnik.dodaoVozac == null || putnik.dodaoVozac!.isEmpty || !VozacBoja.isValidDriver(putnik.dodaoVozac)) {
        throw Exception(
          'NEPOZNAT VOZAČ: "${putnik.dodaoVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}',
        );
      }

      // 🚫 VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        throw Exception(
          'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.',
        );
      }

      // 🏘️ VALIDACIJA ADRESE
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        if (!GradAdresaValidator.validateAdresaForCity(
          putnik.adresa,
          putnik.grad,
        )) {
          throw Exception(
            'Adresa "${putnik.adresa}" nije validna za grad "${putnik.grad}". Dozvoljene su samo adrese iz Bele Crkve i Vršca.',
          );
        }
      }

      // ✅ PROVERAVA DA LI REGISTROVANI PUTNIK VEĆ POSTOJI
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

      // 🎯 AŽURIRAJ polasci_po_danu za putnika sa novim polaskom
      final registrovaniPutnik = existingPutnici.first;
      final putnikId = registrovaniPutnik['id'] as String;

      // Dohvati postojeće polaske ili kreiraj novi map
      Map<String, dynamic> polasciPoDanu = {};
      if (registrovaniPutnik['polasci_po_danu'] != null) {
        polasciPoDanu = Map<String, dynamic>.from(registrovaniPutnik['polasci_po_danu'] as Map);
      }

      // Odredi dan kratica (pon, uto, sre, cet, pet)
      final danKratica = putnik.dan.toLowerCase();

      // Odredi grad (bc ili vs)
      final gradKey = putnik.grad.toLowerCase().contains('bela') ? 'bc' : 'vs';

      // Normalizuj vreme polaska
      final polazakVreme = GradAdresaValidator.normalizeTime(putnik.polazak);

      // Dodaj ili ažuriraj polazak za taj dan
      if (!polasciPoDanu.containsKey(danKratica)) {
        polasciPoDanu[danKratica] = {'bc': null, 'vs': null};
      }
      final danPolasci = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map);
      danPolasci[gradKey] = polazakVreme;
      // 🆕 Dodaj broj mesta ako je > 1
      if (putnik.brojMesta > 1) {
        danPolasci['${gradKey}_mesta'] = putnik.brojMesta;
      } else {
        danPolasci.remove('${gradKey}_mesta'); // Ukloni ako je 1 (default)
      }
      polasciPoDanu[danKratica] = danPolasci;

      // Ažuriraj radni_dani ako dan nije već uključen
      String radniDani = registrovaniPutnik['radni_dani'] as String? ?? '';
      final radniDaniList = radniDani.split(',').map((d) => d.trim().toLowerCase()).where((d) => d.isNotEmpty).toList();
      if (!radniDaniList.contains(danKratica) && danKratica.isNotEmpty) {
        radniDaniList.add(danKratica);
        radniDani = radniDaniList.join(',');
      }

      // Ažuriraj mesečnog putnika u bazi
      // ❌ UKLONJENO: updated_by izaziva foreign key grešku jer UUID nije u tabeli users
      // final updatedByUuid = VozacMappingService.getVozacUuidSync(putnik.dodaoVozac ?? '');

      // 🔧 Pripremi update mapu - BEZ updated_by (foreign key constraint)
      final updateData = <String, dynamic>{
        'polasci_po_danu': polasciPoDanu,
        'radni_dani': radniDani,
        'updated_at': DateTime.now().toIso8601String(),
      };
      // ❌ UKLONJENO: updated_by foreign key constraint ka users tabeli
      // if (updatedByUuid != null && updatedByUuid.isNotEmpty) {
      //   updateData['updated_by'] = updatedByUuid;
      // }

      await supabase.from('registrovani_putnici').update(updateData).eq('id', putnikId);

      // 🔔 REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za današnji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je putnik za današnji dan u nedelji
      if (putnik.dan == todayName) {
        // 📣 ŠALJI PUSH SVIM VOZAČIMA (FCM + Huawei Push)
        RealtimeNotificationService.sendNotificationToAllDrivers(
          title: 'Novi putnik',
          body: 'Dodat je novi putnik ${putnik.ime} (${putnik.grad}, ${putnik.polazak})',
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

      // 🔄 FORCE REFRESH SVA DVA STREAM-A
      await RealtimeService.instance.refreshNow();

      // 🔄 DODATNO: Resetuj cache za sigurnost
      _streams.clear();

      // ⏳ KRATKA PAUZA da se obezbedi da je transakcija commitovana
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 🔄 DODATNI REFRESH NAKON PAUZE
      await RealtimeService.instance.refreshNow();
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ STREAM SVIH PUTNIKA (iz registrovani_putnici tabele - workaround za RLS)
  Stream<List<Putnik>> streamPutnici() {
    return RealtimeService.instance.tableStream('registrovani_putnici').map((data) {
      final allPutnici = <Putnik>[];
      final items = data is List ? data : <dynamic>[];

      // Sort by created_at descending if possible
      try {
        items.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      } catch (_) {}

      for (final item in items) {
        // NOVA LOGIKA: Koristi fromRegistrovaniPutniciMultiple
        final registrovaniPutnici = Putnik.fromRegistrovaniPutniciMultiple(item as Map<String, dynamic>);
        allPutnici.addAll(registrovaniPutnici);
      }
      return allPutnici;
    });
  }

  /// ✅ OBRISI PUTNIKA (Soft Delete - čuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(
      id,
    ); // Prvo dohvati podatke putnika za undo stack
    final response = await SupabaseSafe.run(
      () => supabase.from(tabela).select().eq('id', id as String).single(),
    );

    // 📝 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoResponse = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('delete', id, undoResponse);

    // ✅ KONZISTENTNO BRISANJE - obe tabele imaju obrisan kolonu
    // ⚠️ NE menjaj status - constraint check_registrovani_status_valid dozvoljava samo:
    // 'aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godišnji'
    await supabase.from(tabela).update({
      'obrisan': true, // ✅ Soft delete flag
    }).eq('id', id as String);

    // 🔄 VIŠESTRUKI REFRESH NAKON BRISANJA za trenutno ažuriranje
    await RealtimeService.instance.refreshNow();

    // 🗑️ OČISTI STREAM CACHE da se forsira novo učitavanje
    _streams.clear();

    // ⏳ KRATKA PAUZA i DODATNI REFRESH
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await RealtimeService.instance.refreshNow();
  }

  /// ✅ OZNAČI KAO POKUPLJEN
  Future<void> oznaciPokupljen(dynamic id, String currentDriver) async {
    // 🚫 DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    // STRIKTNA VALIDACIJA VOZAČA - samo postojanje imena
    if (currentDriver.isEmpty) {
      throw ArgumentError(
        'Vozač mora biti specificiran.',
      );
    }

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await SupabaseSafe.run(
      () => supabase.from(tabela).select().eq('id', id as String).single(),
    );
    if (response == null) {
      return;
    }
    final putnik = Putnik.fromMap(Map<String, dynamic>.from(response as Map));

    // 📝 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPickup = Map<String, dynamic>.from(response);
    _addToUndoStack('pickup', id, undoPickup);

    if (tabela == 'registrovani_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za pokupljanje
      final now = DateTime.now();
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver);

      // ✅ FIXED: Ažuriraj action_log umesto nepostojeće kolone pokupljanje_vozac
      final actionLog = ActionLog.fromDynamic(response['action_log']);
      final updatedActionLog = actionLog.addAction(ActionType.picked, vozacUuid ?? currentDriver, 'Pokupljen');

      await supabase.from(tabela).update({
        'vreme_pokupljenja': now.toIso8601String(), // ✅ FIXED: Koristi samo vreme_pokupljenja
        'pokupljen': true, // ✅ BOOLEAN flag
        'vozac_id': vozacUuid, // ✅ FIXED: Samo UUID, null ako nema mapiranja
        'action_log': updatedActionLog.toJson(), // ✅ FIXED: Ažuriraj action_log.picked_by
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id as String);

      // 🔄 AUTOMATSKA SINHRONIZACIJA - ažuriraj brojPutovanja iz istorije
      try {
        await RegistrovaniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(id);
      } catch (e) {
        // Silently ignore sync errors
      }
    }

    // 📊 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
    if (putnik.mesecnaKarta == true) {
      // Statistike se računaju dinamički kroz StatistikaService
      // bez potrebe za dodatnim ažuriranjem
    }

    // 🚗 DINAMIČKI ETA UPDATE - ukloni putnika iz praćenja i preračunaj ETA
    try {
      final putnikIdentifier = putnik.ime.isNotEmpty ? putnik.ime : '${putnik.adresa} ${putnik.grad}';
      DriverLocationService.instance.removePassenger(putnikIdentifier);
    } catch (e) {
      // Silently ignore - tracking might not be active
    }
  }

  /// ✅ OZNAČI KAO PLAĆENO
  Future<void> oznaciPlaceno(
    dynamic id,
    double iznos,
    String naplatioVozac,
  ) async {
    // 🚫 DUPLICATE PREVENTION
    final actionKey = 'payment_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    // ✅ dynamic umesto int
    // Uklonili smo dodatnu validaciju - naplatioVozac se prihvata kao jeste

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await SupabaseSafe.run(
      () => supabase.from(tabela).select().eq('id', id as String).single(),
    );

    // 📝 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPayment = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('payment', id, undoPayment);

    // Za mesečne putnike ažuriraj SVE potrebne kolone za plaćanje
    final now = DateTime.now();
    String? validVozacId = naplatioVozac.isEmpty ? null : VozacMappingService.getVozacUuidSync(naplatioVozac);

    // Ažuriraj action_log.paid_by
    final actionLog = ActionLog.fromDynamic(undoPayment['action_log']);
    final updatedActionLog = actionLog.addAction(ActionType.paid, validVozacId ?? naplatioVozac, 'Plaćeno $iznos');

    await supabase.from(tabela).update({
      'cena': iznos,
      'vreme_placanja': now.toIso8601String(),
      'vozac_id': validVozacId,
      'action_log': updatedActionLog.toJson(),
      'updated_at': now.toIso8601String(),
    }).eq('id', id as String);
  }

  /// ✅ OTKAZI PUTNIKA
  Future<void> otkaziPutnika(
    dynamic id,
    String otkazaoVozac, {
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    try {
      final idStr = id.toString();
      // Određi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(idStr);

      // Prvo dohvati podatke putnika za notifikaciju
      final response = await SupabaseSafe.run(
        () => supabase.from(tabela).select().eq('id', idStr).single(),
      );
      final respMap = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
      final cancelName = (respMap['putnik_ime'] ?? respMap['ime']) ?? '';

      // ⚠️ Proveri da li je putnik već otkazan
      final currentStatus = respMap['status']?.toString().toLowerCase() ?? '';
      if (currentStatus == 'otkazan' || currentStatus == 'otkazano') {
        throw Exception('Putnik je već otkazan');
      }

      // 📝 DODAJ U UNDO STACK
      _addToUndoStack('cancel', idStr, respMap);

      if (tabela == 'registrovani_putnici') {
        // 🔄 POJEDNOSTAVLJENO: Ažuriraj status direktno u registrovani_putnici
        // i dodaj zapis u voznje_log za istoriju
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);

        // Ažuriraj status u registrovani_putnici
        await supabase.from('registrovani_putnici').update({
          'status': 'otkazan',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id.toString());

        // Dodaj zapis u voznje_log za istoriju
        try {
          await supabase.from('voznje_log').insert({
            'putnik_id': id.toString(),
            'datum': danas,
            'tip': 'otkazivanje',
            'iznos': 0,
            'vozac_id': vozacUuid,
          });
        } catch (logError) {
          // Nije kritično ako log ne uspe
        }
      }

      // 📬 POŠALJI NOTIFIKACIJU ZA OTKAZIVANJE (za tekući dan)
      try {
        final now = DateTime.now();
        final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
        final todayName = dayNames[now.weekday - 1];

        // Proverava da li je otkazani putnik za današnji dan u nedelji
        final putnikDan = (respMap['dan'] ?? '') as String;
        final danLowerCase = putnikDan.toLowerCase();
        final todayLowerCase = todayName.toLowerCase();

        if (danLowerCase.contains(todayLowerCase) || putnikDan == todayName) {
          // 📣 ŠALJI PUSH SVIM VOZAČIMA (FCM + Huawei Push)
          RealtimeNotificationService.sendNotificationToAllDrivers(
            title: 'Otkazan putnik',
            body:
                'Otkazan je putnik $cancelName (${respMap['grad'] ?? ''}, ${respMap['vreme_polaska'] ?? respMap['polazak'] ?? ''})',
            data: {
              'type': 'otkazan_putnik',
              'putnik': {
                'ime': respMap['putnik_ime'],
                'grad': respMap['grad'],
                'vreme': respMap['vreme_polaska'] ?? respMap['polazak'],
                'dan': respMap['dan'],
              },
            },
          );
        }
      } catch (notifError) {
        // Nastavi dalje - notifikacija nije kritična
      }

      // Sinhronizacija završena
    } catch (e) {
      rethrow;
    }
  }

  /// 🚫 OZNAČI KAO BOLOVANJE/GODIŠNJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
    dynamic id,
    String tipOdsustva,
    String currentDriver,
  ) async {
    // 🔍 DEBUG LOG
    // ✅ dynamic umesto int
    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za undo stack
    final response = await SupabaseSafe.run(
      () => supabase.from(tabela).select().eq('id', id as String).single(),
    );

    // 📝 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoOdsustvo = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('odsustvo', id, undoOdsustvo);

    // 🎯 FIX: Konvertuj 'godisnji' u 'godišnji' za bazu (constraint zahteva dijakritiku)
    String statusZaBazu = tipOdsustva.toLowerCase();
    if (statusZaBazu == 'godisnji') {
      statusZaBazu = 'godišnji';
    }

    try {
      await supabase.from(tabela).update({
        'status': statusZaBazu, // 'bolovanje' ili 'godišnji'
        'aktivan': true, // Putnik ostaje aktivan, samo je na odsustvu
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id as String);
    } catch (e) {
      rethrow;
    }
  }

  /// 🔄 RESETUJ KARTICU U POČETNO STANJE (samo za validne vozače)
  /// ✅ KONZISTENTNO: Prima selectedVreme i selectedGrad za tačan reset po polasku
  Future<void> resetPutnikCard(
    String imePutnika,
    String currentDriver, {
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    try {
      if (currentDriver.isEmpty) {
        throw Exception('Funkcija zahteva specificiranje vozača');
      }

      // 🔄 POJEDNOSTAVLJENO: Reset samo u registrovani_putnici tabeli
      // Pokušaj reset u registrovani_putnici tabeli
      try {
        // ✅ FIX: Koristi limit(1) umesto maybeSingle() jer može postojati više putnika sa istim imenom
        final registrovaniList =
            await supabase.from('registrovani_putnici').select().eq('putnik_ime', imePutnika).limit(1);

        if (registrovaniList.isNotEmpty) {
          // ✅ FIX: Update SVE putnike sa istim imenom (ako ih ima više)
          await supabase.from('registrovani_putnici').update({
            'aktivan': true, // ✅ KRITIČNO: VRATI na aktivan (jeOtkazan = false)
            'status': 'radi', // ✅ VRATI na radi
            'vreme_pokupljenja': null, // ✅ FIXED: Ukloni timestamp pokupljanja
            'vreme_placanja': null, // ✅ UKLONI timestamp plaćanja
            'pokupljen': false, // ✅ VRATI na false
            'cena': null, // ✅ UKLONI plaćanje
            'vozac_id': null, // ✅ UKLONI vozača (UUID kolona)
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          return;
        }
      } catch (e) {
        // Ako nema u registrovani_putnici, ignoriši
      }
    } catch (e) {
      // Greška pri resetovanju kartice
      rethrow;
    }
  }

  /// 🔄 RESETUJ POKUPLJENE PUTNIKE KADA SE PROMENI VREME POLASKA
  Future<void> resetPokupljenjaNaPolazak(
    String novoVreme,
    String grad,
    String currentDriver,
  ) async {
    try {
      if (currentDriver.isEmpty) {
        return;
      }

      // Resetuj mesečne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final registrovaniPutnici = await supabase
            .from('registrovani_putnici')
            .select(
              'id, putnik_ime, polasci_po_danu, vreme_pokupljenja',
            ) // ✅ FIXED: Koristi vreme_pokupljenja
            .eq('aktivan', true)
            .not(
              'vreme_pokupljenja',
              'is',
              null,
            ); // ✅ FIXED: Koristi vreme_pokupljenja

        for (final putnik in registrovaniPutnici) {
          final vremePokupljenja = DateTime.tryParse(
            putnik['vreme_pokupljenja'] as String,
          ); // ✅ FIXED: Koristi vreme_pokupljenja

          if (vremePokupljenja == null) continue;

          // Provjeri polazak za odgovarajući grad i trenutni dan
          String? polazakVreme;
          final danasnjiDan = _getDanNedelje();

          // Unified parsing: prefer JSON `polasci_po_danu` then per-day columns
          final place = grad == 'Bela Crkva' ? 'bc' : 'vs';
          polazakVreme = RegistrovaniHelpers.getPolazakForDay(putnik, danasnjiDan, place);

          if (polazakVreme == null || polazakVreme.isEmpty || polazakVreme == '00:00:00') {
            continue;
          }

          // Provjeri da li je pokupljen van vremenskog okvira novog polaska
          final novoPolazakSati = int.tryParse(novoVreme.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;
          final razlika = (pokupljenSati - novoPolazakSati).abs();

          // Ako je pokupljen van tolerancije (±3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            await supabase.from('registrovani_putnici').update({
              'vreme_pokupljenja': null, // ✅ FIXED: Koristi vreme_pokupljenja
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id'] as String);
          }
        }
      } catch (e) {
        // Silently ignore reset errors
      }

      // Reset završen
    } catch (e) {
      // Ignore outer errors
    }
  }

  // Helper metod za dobijanje naziva dana nedelje
  String _getDanNedelje() {
    final sada = DateTime.now();
    final danNedelje = sada.weekday; // 1=Monday, 7=Sunday

    switch (danNedelje) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub'; // Subota (ako dodamo)
      case 7:
        return 'ned'; // Nedelja (ako dodamo)
      default:
        return 'pon';
    }
  }

  /// 🔄 PREBACI PUTNIKA DRUGOM VOZAČU
  /// Ažurira `vozac_id` kolonu u registrovani_putnici tabeli
  Future<void> prebacijPutnikaVozacu(String putnikId, String noviVozac) async {
    // Validacija vozača
    if (!VozacBoja.isValidDriver(noviVozac)) {
      throw Exception(
        'Nevalidan vozač: "$noviVozac". Dozvoljeni: ${VozacBoja.validDrivers.join(", ")}',
      );
    }

    try {
      // Dobij UUID vozača
      final vozacUuid = await VozacMappingService.getVozacUuid(noviVozac);

      if (vozacUuid == null) {
        throw Exception('Vozač "$noviVozac" nije pronađen u bazi');
      }

      // 🔄 POJEDNOSTAVLJENO: Svi putnici su sada u registrovani_putnici
      await supabase.from('registrovani_putnici').update({
        'vozac_id': vozacUuid,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);

      // Forsiraj refresh realtime servisa
      try {
        await RealtimeService.instance.refreshNow();
      } catch (e) {
        // Ignoriši greške u refresh-u
      }
    } catch (e) {
      throw Exception('Greška pri prebacivanju putnika: $e');
    }
  }
}
