import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_log.dart';
import '../models/putnik.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/grad_adresa_validator.dart';
import '../utils/registrovani_helpers.dart';
import '../utils/vozac_boja.dart';
import 'driver_location_service.dart';
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

class PutnikService {
  final supabase = Supabase.instance.client;

  // Stream caching: map of active filter keys to StreamController streams (bez RxDart)
  // ? STATIC da bi se delila izmedu svih instanci PutnikService
  static final Map<String, StreamController<List<Putnik>>> _streams = {};
  static final Map<String, List<Putnik>> _lastValues = {}; // Cache poslednje vrednosti za replay
  static final Map<String, StreamSubscription> _subscriptions = {}; // Cuvaj subscriptions za cleanup

  /// ?? Staticka metoda za ci�cenje cache-a - ZATVARA streamove
  /// Koristi samo kada treba potpuno resetovati (npr. logout)
  static void clearCache() {
    for (final controller in _streams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streams.clear();
    _lastValues.clear();
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
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

    // Proveri da li stream vec postoji i nije zatvoren
    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      final controller = _streams[key]!;
      // ✅ FIX: Ako imamo cache, emituj odmah za nove listenere
      // Zatim uradi background fetch za svežije podatke
      if (_lastValues.containsKey(key)) {
        Future.microtask(() {
          if (!controller.isClosed) {
            controller.add(_lastValues[key]!);
          }
        });
      }
      // Background refresh - osigurava da svi dobiju najnovije podatke
      _doFetchForStream(key, isoDate, grad, vreme, controller);
      return controller.stream;
    }

    final controller = StreamController<List<Putnik>>.broadcast();
    _streams[key] = controller;

    // Initial fetch
    _doFetchForStream(key, isoDate, grad, vreme, controller);

    // Direktan Supabase realtime umesto RealtimeHubService
    // Sanitize channel name - ukloni specijalne karaktere
    final channelName = 'putnici_${key.replaceAll(RegExp(r'[|: ]'), '_').toLowerCase()}';
    final channel = supabase.channel(channelName);
    channel
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'registrovani_putnici',
      callback: (payload) {
        debugPrint('🔄 [$channelName] Postgres change: ${payload.eventType}');
        _doFetchForStream(key, isoDate, grad, vreme, controller);
      },
    )
        .subscribe((status, [error]) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          debugPrint('✅ [$channelName] Subscribed successfully');
          break;
        case RealtimeSubscribeStatus.channelError:
          debugPrint('❌ [$channelName] Channel error: $error');
          break;
        case RealtimeSubscribeStatus.closed:
          debugPrint('🔴 [$channelName] Channel closed');
          break;
        case RealtimeSubscribeStatus.timedOut:
          debugPrint('⏰ [$channelName] Subscription timed out');
          break;
      }
    });

    // Cleanup kada se controller zatvori
    controller.onCancel = () async {
      debugPrint('🧹 [$channelName] Unsubscribing and cleaning up');
      await channel.unsubscribe();
      _streams.remove(key);
      _lastValues.remove(key);
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

      // Dana�nji datum za filter uklonjenih termina
      final todayDate = isoDate ?? DateTime.now().toIso8601String().split('T')[0];

      // Query registrovani_putnici - uzmi aktivne putnike za ciljani dan
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
          // apply grad/vreme filter if provided
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
            return utMap['datum'] == todayDate && utMap['vreme'] == p.polazak && utMap['grad'] == p.grad;
          });
          if (jeUklonjen) {
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

  // Fields to explicitly request from registrovani_putnici
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

    // Ogranici stack na max broj akcija
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  // ?? HELPER - Odredi tabelu na osnovu putnika
  // ?? POJEDNOSTAVLJENO: Sada postoji samo registrovani_putnici tabela
  Future<String> _getTableForPutnik(dynamic id) async {
    // Svi putnici su sada u registrovani_putnici
    return 'registrovani_putnici';
  }

  // ?? UCITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  // ?? POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
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

  // ?? NOVI: Ucitaj sve putnike iz registrovani_putnici
  // ?? POJEDNOSTAVLJENO: Samo registrovani_putnici tabela
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
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

  // Helper funkcija za dobijanje dana�njeg imena dana
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

  // Helper funkcija za konverziju punog naziva dana u kraticu
  String _getDayAbbreviationFromName(String dayName) {
    return app_date_utils.DateUtils.getDayAbbreviation(dayName);
  }

  // ?? NOVI: Sacuvaj putnika u odgovarajucu tabelu (workaround - sve u registrovani_putnici)
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

  // ?? UNDO POSLEDNJU AKCIJU
  Future<String?> undoLastAction() async {
    if (_undoStack.isEmpty) {
      return 'Nema akcija za poni�tavanje';
    }

    final lastAction = _undoStack.removeLast();

    try {
      // Odredi tabelu na osnovu ID-ja
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
            'pokupljen': false,
            'vreme_pokupljenja': null,
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

      // Dohvati postojece polaske ili kreiraj novi map
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

      // Dodaj ili a�uriraj polazak za taj dan
      if (!polasciPoDanu.containsKey(danKratica)) {
        polasciPoDanu[danKratica] = {'bc': null, 'vs': null};
      }
      final danPolasci = Map<String, dynamic>.from(polasciPoDanu[danKratica] as Map);
      danPolasci[gradKey] = polazakVreme;
      // ?? Dodaj broj mesta ako je > 1
      if (putnik.brojMesta > 1) {
        danPolasci['${gradKey}_mesta'] = putnik.brojMesta;
      } else {
        danPolasci.remove('${gradKey}_mesta'); // Ukloni ako je 1 (default)
      }
      polasciPoDanu[danKratica] = danPolasci;

      // A�uriraj radni_dani ako dan nije vec ukljucen
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

      // ?? REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za dana�nji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Cet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je putnik za dana�nji dan u nedelji
      if (putnik.dan == todayName) {
        // ?? �ALJI PUSH SVIM VOZACIMA (FCM + Huawei Push)
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
      // Supabase realtime automatski triggeruje refresh
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Putnik>> streamPutnici() {
    return RegistrovaniPutnikService.streamAktivniRegistrovaniPutnici().map((registrovani) {
      final allPutnici = <Putnik>[];

      for (final item in registrovani) {
        // NOVA LOGIKA: Koristi fromRegistrovaniPutniciMultiple
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

    // Dohvati trenutne uklonjene termine
    final response = await supabase.from(tabela).select('uklonjeni_termini').eq('id', id as String).single();

    List<dynamic> uklonjeni = [];
    if (response['uklonjeni_termini'] != null) {
      uklonjeni = List<dynamic>.from(response['uklonjeni_termini'] as List);
    }

    // Dodaj novi uklonjen termin
    uklonjeni.add({
      'datum': datum,
      'vreme': vreme,
      'grad': grad,
    });

    // Sacuvaj
    await supabase.from(tabela).update({
      'uklonjeni_termini': uklonjeni,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    // Supabase realtime automatski triggeruje refresh
  }

  /// ? OBRISI PUTNIKA (Soft Delete - cuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    // Odredi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);
    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();

    // ?? DODAJ U UNDO STACK (sigurno mapiranje)
    final undoResponse = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('delete', id, undoResponse);

    // ? KONZISTENTNO BRISANJE - obe tabele imaju obrisan kolonu
    // ?? NE menjaj status - constraint check_registrovani_status_valid dozvoljava samo:
    // 'aktivan', 'neaktivan', 'pauziran', 'radi', 'bolovanje', 'godi�nji'
    await supabase.from(tabela).update({
      'obrisan': true, // ? Soft delete flag
    }).eq('id', id);
    // Supabase realtime automatski triggeruje refresh
  }

  /// ? OZNACI KAO POKUPLJEN
  Future<void> oznaciPokupljen(dynamic id, String currentDriver) async {
    // ?? DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    // STRIKTNA VALIDACIJA VOZACA - samo postojanje imena
    if (currentDriver.isEmpty) {
      throw ArgumentError(
        'Vozac mora biti specificiran.',
      );
    }

    // Odredi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;
    final putnik = Putnik.fromMap(response);

    // ?? DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPickup = Map<String, dynamic>.from(response);
    _addToUndoStack('pickup', id, undoPickup);

    if (tabela == 'registrovani_putnici') {
      // Za mesecne putnike a�uriraj SVE potrebne kolone za pokupljanje
      final now = DateTime.now();
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver);

      // ? FIXED: A�uriraj action_log umesto nepostojece kolone pokupljanje_vozac
      final actionLog = ActionLog.fromDynamic(response['action_log']);
      final updatedActionLog = actionLog.addAction(ActionType.picked, vozacUuid ?? currentDriver, 'Pokupljen');

      await supabase.from(tabela).update({
        'vreme_pokupljenja': now.toIso8601String(), // ? FIXED: Koristi samo vreme_pokupljenja
        'pokupljen': true, // ? BOOLEAN flag
        'vozac_id': vozacUuid, // ? FIXED: Samo UUID, null ako nema mapiranja
        'action_log': updatedActionLog.toJson(), // ? FIXED: A�uriraj action_log.picked_by
        'updated_at': now.toIso8601String(), // ? A�URIRAJ timestamp
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
        // Nije kriticno ako log ne uspe
      }

      // ?? AUTOMATSKA SINHRONIZACIJA - a�uriraj brojPutovanja iz istorije
      try {
        await RegistrovaniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(id);
      } catch (e) {
        // Silently ignore sync errors
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
      // Silently ignore - tracking might not be active
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

    // ? dynamic umesto int
    // Uklonili smo dodatnu validaciju - naplatioVozac se prihvata kao jeste

    // Odredi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;

    final undoPayment = response;
    _addToUndoStack('payment', id, undoPayment);

    // Za mesecne putnike a�uriraj SVE potrebne kolone za placanje
    final now = DateTime.now();
    String? validVozacId = naplatioVozac.isEmpty ? null : VozacMappingService.getVozacUuidSync(naplatioVozac);

    // A�uriraj action_log.paid_by
    final actionLog = ActionLog.fromDynamic(undoPayment['action_log']);
    final updatedActionLog = actionLog.addAction(ActionType.paid, validVozacId ?? naplatioVozac, 'Placeno $iznos');

    await supabase.from(tabela).update({
      'cena': iznos,
      'vreme_placanja': now.toIso8601String(),
      'vozac_id': validVozacId,
      'action_log': updatedActionLog.toJson(),
      'updated_at': now.toIso8601String(),
    }).eq('id', id);
  }

  /// ? OTKAZI PUTNIKA
  Future<void> otkaziPutnika(
    dynamic id,
    String otkazaoVozac, {
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    try {
      final idStr = id.toString();
      // Odredi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(idStr);

      final response = await supabase.from(tabela).select().eq('id', idStr).maybeSingle();
      if (response == null) return;
      final respMap = response;
      final cancelName = (respMap['putnik_ime'] ?? respMap['ime']) ?? '';

      // ?? Proveri da li je putnik vec otkazan
      final currentStatus = respMap['status']?.toString().toLowerCase() ?? '';
      if (currentStatus == 'otkazan' || currentStatus == 'otkazano') {
        throw Exception('Putnik je vec otkazan');
      }

      // ?? DODAJ U UNDO STACK
      _addToUndoStack('cancel', idStr, respMap);

      if (tabela == 'registrovani_putnici') {
        // ?? POJEDNOSTAVLJENO: A�uriraj status direktno u registrovani_putnici
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);

        // A�uriraj status, vreme otkazivanja i vozac koji je otkazao
        await supabase.from('registrovani_putnici').update({
          'status': 'otkazan',
          'vreme_otkazivanja': DateTime.now().toIso8601String(),
          'otkazao_vozac': otkazaoVozac,
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
          // Nije kriticno ako log ne uspe
        }
      }

      // ?? PO�ALJI NOTIFIKACIJU ZA OTKAZIVANJE (za tekuci dan)
      try {
        final now = DateTime.now();
        final dayNames = ['Pon', 'Uto', 'Sre', 'Cet', 'Pet', 'Sub', 'Ned'];
        final todayName = dayNames[now.weekday - 1];

        // Proverava da li je otkazani putnik za dana�nji dan u nedelji
        final putnikDan = (respMap['dan'] ?? '') as String;
        final danLowerCase = putnikDan.toLowerCase();
        final todayLowerCase = todayName.toLowerCase();

        if (danLowerCase.contains(todayLowerCase) || putnikDan == todayName) {
          // ?? �ALJI PUSH SVIM VOZACIMA (FCM + Huawei Push)
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
        // Nastavi dalje - notifikacija nije kriticna
      }

      // Sinhronizacija zavr�ena
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
    // Odredi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    final response = await supabase.from(tabela).select().eq('id', id as String).maybeSingle();
    if (response == null) return;

    final undoOdsustvo = response;
    _addToUndoStack('odsustvo', id, undoOdsustvo);

    // ?? FIX: Konvertuj 'godisnji' u 'godi�nji' za bazu (constraint zahteva dijakritiku)
    String statusZaBazu = tipOdsustva.toLowerCase();
    if (statusZaBazu == 'godisnji') {
      statusZaBazu = 'godi�nji';
    }

    try {
      await supabase.from(tabela).update({
        'status': statusZaBazu, // 'bolovanje' ili 'godi�nji'
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
      // Poku�aj reset u registrovani_putnici tabeli
      try {
        // ? FIX: Koristi limit(1) umesto maybeSingle() jer mo�e postojati vi�e putnika sa istim imenom
        final registrovaniList =
            await supabase.from('registrovani_putnici').select().eq('putnik_ime', imePutnika).limit(1);

        if (registrovaniList.isNotEmpty) {
          // ? FIX: Update SVE putnike sa istim imenom (ako ih ima vi�e)
          await supabase.from('registrovani_putnici').update({
            'aktivan': true, // ? KRITICNO: VRATI na aktivan (jeOtkazan = false)
            'status': 'radi', // ? VRATI na radi
            'vreme_pokupljenja': null, // ? FIXED: Ukloni timestamp pokupljanja
            'vreme_placanja': null, // ? UKLONI timestamp placanja
            'pokupljen': false, // ? VRATI na false
            'cena': null, // ? UKLONI placanje
            'vozac_id': null, // ? UKLONI vozaca (UUID kolona)
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          return;
        }
      } catch (e) {
        // Ako nema u registrovani_putnici, ignori�i
      }
    } catch (e) {
      // Gre�ka pri resetovanju kartice
      rethrow;
    }
  }

  /// ?? RESETUJ POKUPLJENE PUTNIKE KADA SE PROMENI VREME POLASKA
  Future<void> resetPokupljenjaNaPolazak(
    String novoVreme,
    String grad,
    String currentDriver,
  ) async {
    try {
      if (currentDriver.isEmpty) {
        return;
      }

      // Resetuj mesecne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final registrovaniPutnici = await supabase
            .from('registrovani_putnici')
            .select(
              'id, putnik_ime, polasci_po_danu, vreme_pokupljenja',
            ) // ? FIXED: Koristi vreme_pokupljenja
            .eq('aktivan', true)
            .not(
              'vreme_pokupljenja',
              'is',
              null,
            ); // ? FIXED: Koristi vreme_pokupljenja

        for (final putnik in registrovaniPutnici) {
          final vremePokupljenja = DateTime.tryParse(
            putnik['vreme_pokupljenja'] as String,
          ); // ? FIXED: Koristi vreme_pokupljenja

          if (vremePokupljenja == null) continue;

          // Provjeri polazak za odgovarajuci grad i trenutni dan
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

          // Ako je pokupljen van tolerancije (�3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            await supabase.from('registrovani_putnici').update({
              'vreme_pokupljenja': null, // ? FIXED: Koristi vreme_pokupljenja
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id'] as String);
          }
        }
      } catch (e) {
        // Silently ignore reset errors
      }

      // Reset zavr�en
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

  /// ?? PREBACI PUTNIKA DRUGOM VOZACU
  /// A�urira `vozac_id` kolonu u registrovani_putnici tabeli
  Future<void> prebacijPutnikaVozacu(String putnikId, String noviVozac) async {
    // Validacija vozaca
    if (!VozacBoja.isValidDriver(noviVozac)) {
      throw Exception(
        'Nevalidan vozac: "$noviVozac". Dozvoljeni: ${VozacBoja.validDrivers.join(", ")}',
      );
    }

    try {
      // Dobij UUID vozaca
      final vozacUuid = await VozacMappingService.getVozacUuid(noviVozac);

      if (vozacUuid == null) {
        throw Exception('Vozac "$noviVozac" nije pronaden u bazi');
      }

      // ?? POJEDNOSTAVLJENO: Svi putnici su sada u registrovani_putnici
      await supabase.from('registrovani_putnici').update({
        'vozac_id': vozacUuid,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', putnikId);
    } catch (e) {
      throw Exception('Gre�ka pri prebacivanju putnika: $e');
    }
  }
}
