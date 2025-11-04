import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_log.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart'; // DODANO za validaciju gradova i adresa
import '../utils/mesecni_helpers.dart';
import '../utils/vozac_boja.dart'; // DODATO za validaciju vozača
import 'mesecni_putnik_service.dart'; // DODANO za automatsku sinhronizaciju
import 'realtime_notification_service.dart';
import 'realtime_service.dart';
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

  // Stream caching: map of active filter keys to BehaviorSubject streams
  final Map<String, BehaviorSubject<List<Putnik>>> _streams = {};

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
    if (_streams.containsKey(key)) return _streams[key]!.stream;

    final subject = BehaviorSubject<List<Putnik>>();
    _streams[key] = subject;

    Future<void> doFetch() async {
      try {
        final combined = <Putnik>[];

        print('📅 === STREAM KOMBINOVANI DEBUG ===');
        print('📅 isoDate: $isoDate, grad: $grad, vreme: $vreme');

        // Fetch daily rows server-side if isoDate provided, otherwise fetch recent daily
        final dnevniResponse = await SupabaseSafe.run(
          () async {
            if (isoDate != null) {
              print('📅 Fetchujem dnevne za datum: $isoDate');
              return await supabase
                  .from('putovanja_istorija')
                  .select()
                  .gte('created_at', '${isoDate}T00:00:00.000Z')
                  .lt(
                    'created_at',
                    '${DateTime.parse(isoDate).add(const Duration(days: 1)).toIso8601String().split('T')[0]}T00:00:00.000Z',
                  )
                  .eq('tip_putnika', 'dnevni');
            }
            print('📅 Fetchujem sve dnevne (bez datuma)');
            return await supabase
                .from('putovanja_istorija')
                .select()
                .eq('tip_putnika', 'dnevni')
                .order('created_at', ascending: false);
          },
          fallback: <dynamic>[],
        );

        print('📅 Dnevni response: ${dnevniResponse?.length ?? 0}');

        if (dnevniResponse is List) {
          for (final d in dnevniResponse) {
            combined.add(Putnik.fromPutovanjaIstorija(d as Map<String, dynamic>));
          }
        }

        // 🛑 UKLONJENO: Mesečni putnici se učitavaju preko MesecniPutnikService
        // da se izbegne duplo računanje u admin screen-u

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

        // Query mesecni_putnici - uzmi SVE aktivne mesečne putnike
        // ✅ ISPRAVKA: Ne filtriraj po danu jer sada kreiramo objekte za sve radne dane
        final mesecni =
            await supabase.from('mesecni_putnici').select(mesecniFields).eq('aktivan', true).eq('obrisan', false);

        print('📅 Mesečni response: ${mesecni.length}');
        int streamMesecniBc6 = 0;

        for (final m in mesecni) {
          // ✅ ISPRAVKA: Generiši putnik objekte za SVE radne dane, ne samo trenutni
          final radniDaniString = m['radni_dani'] as String? ?? '';
          final radniDaniLista = radniDaniString.split(',').map((d) => d.trim()).toList();

          // Kreiraj putnik objekte za svaki radni dan
          for (final dan in radniDaniLista) {
            if (dan.isEmpty) continue;

            final putniciZaDan = Putnik.fromMesecniPutniciMultipleForDay(m, dan);
            for (final p in putniciZaDan) {
              // apply grad/vreme filter if provided
              final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
              final normVremeFilter = vreme != null ? GradAdresaValidator.normalizeTime(vreme) : null;
              // ✅ ISPRAVLJENO: Za mesečne putnike koristi direktno poređenje grada
              if (grad != null && p.grad != grad) {
                continue;
              }
              if (normVremeFilter != null && normVreme != normVremeFilter) {
                continue;
              }

              // Debug BC 6:00 mesečni
              if (normVreme == '6:00' &&
                  (p.grad.toLowerCase().contains('bela') || p.grad.toLowerCase().contains('bc'))) {
                streamMesecniBc6++;
                print('📅 BC 6:00 mesečni (stream): ${p.ime}, dan=$dan, polazak=${p.polazak}');
              }

              combined.add(p);
            }
          }
        }

        print('📅 Stream BC 6:00 mesečni: $streamMesecniBc6');
        print('📅 Stream ukupno kombinovano: ${combined.length}');

        subject.add(combined);
      } catch (e) {
        subject.add([]);
      }
    }

    // initial fetch
    doFetch();

    // Subscribe to centralized RealtimeService to refresh on changes.
    // If filters are provided, listen to the parametric stream to reduce traffic.
    final Stream<dynamic> refreshStream = (isoDate != null || grad != null || vreme != null)
        ? RealtimeService.instance.streamKombinovaniPutniciParametric(
            isoDate: isoDate,
            grad: grad,
            vreme: vreme,
          )
        : RealtimeService.instance.combinedPutniciStream;

    final sub = refreshStream.listen((_) {
      doFetch();
    });

    // When subject is closed, cancel subscription
    subject.onCancel = () async {
      await sub.cancel();
      _streams.remove(key);
    };

    return subject.stream;
  }

  // Fields to explicitly request from mesecni_putnici
  static const String mesecniFields = '*,'
      'polasci_po_danu';

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
  Future<String> _getTableForPutnik(dynamic id) async {
    try {
      // Pokušaj prvo putovanja_istorija (int ili string ID)
      final resp = await SupabaseSafe.run(
        () => supabase.from('putovanja_istorija').select('id').eq('id', id as String).single(),
      );
      if (resp != null) return 'putovanja_istorija';
    } catch (e) {
      return 'mesecni_putnici';
    }
    // Ako nije pronađeno u putovanja_istorija vrati mesecni_putnici
    return 'mesecni_putnici';
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  Future<Putnik?> getPutnikByName(String imePutnika) async {
    try {
      // Prvo pokušaj iz mesecni_putnici
      final mesecniResponse =
          await supabase.from('mesecni_putnici').select(mesecniFields).eq('putnik_ime', imePutnika).maybeSingle();

      if (mesecniResponse != null) {
        return Putnik.fromMesecniPutnici(mesecniResponse);
      }

      // Ako nije u mesecni_putnici, pokušaj iz putovanja_istorija za danas
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        return Putnik.fromPutovanjaIstorija(putovanjaResponse);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po ID)
  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    try {
      // Prvo pokušaj iz putovanja_istorija
      final response = await supabase.from('putovanja_istorija').select().eq('id', id as String).limit(1);

      if (response.isNotEmpty) {
        return Putnik.fromPutovanjaIstorija(response.first);
      }

      // Ako nije u putovanja_istorija, pokušaj iz mesecni_putnici
      final mesecniResponse = await supabase.from('mesecni_putnici').select(mesecniFields).eq('id', id).limit(1);

      if (mesecniResponse.isNotEmpty) {
        return Putnik.fromMesecniPutnici(mesecniResponse.first);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 NOVI: Učitaj sve putnike iz obe tabele
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    List<Putnik> allPutnici = [];

    try {
      final targetDate = targetDay ?? _getTodayName();
      final datum = _parseDateFromDayName(targetDate);
      final danas = datum.toIso8601String().split('T')[0];

      print('🏠 PutnikService.getAllPutniciFromBothTables: targetDay=$targetDay, danas=$danas');

      // ✅ ISPRAVKA: Koristi istu logiku kao danas_screen - filtriraj po created_at umesto datum_putovanja
      final dnevniResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .gte('created_at', '${danas}T00:00:00.000Z')
          .lt(
            'created_at',
            '${DateTime.parse(danas).add(const Duration(days: 1)).toIso8601String().split('T')[0]}T00:00:00.000Z',
          )
          .eq('tip_putnika', 'dnevni')
          .timeout(const Duration(seconds: 5));

      print('🏠 Dnevni putnici response: ${dnevniResponse.length}');

      final List<Putnik> dnevniPutnici =
          dnevniResponse.map<Putnik>((item) => Putnik.fromPutovanjaIstorija(item)).where((putnik) {
        final normalizedStatus = (putnik.status ?? '').toLowerCase().trim();
        final isValid = normalizedStatus != 'otkazano' &&
            normalizedStatus != 'otkazan' &&
            normalizedStatus != 'bolovanje' &&
            normalizedStatus != 'godisnji' &&
            normalizedStatus != 'godišnji' &&
            normalizedStatus != 'obrisan';
        if (!isValid) {
          print('🏠 Preskoči dnevni putnik: ${putnik.ime}, status=$normalizedStatus');
        }
        return isValid;
      }).toList();

      print('🏠 Validni dnevni putnici: ${dnevniPutnici.length}');

      // Debug: prikaži BC 6:00 dnevne putnike
      final bc6Dnevni = dnevniPutnici
          .where(
            (p) =>
                p.polazak == '6:00' && (p.grad.toLowerCase().contains('bela') || p.grad.toLowerCase().contains('bc')),
          )
          .length;
      print('🏠 BC 6:00 dnevni putnici: $bc6Dnevni');

      allPutnici.addAll(dnevniPutnici);

      // 🗓️ CILJANI DAN: Učitaj mesečne putnike iz mesecni_putnici za selektovani dan
      final danKratica = _getDayAbbreviationFromName(targetDate);

      // Explicitly request polasci_po_danu and common per-day columns
      const mesecniFields = '*,'
          'polasci_po_danu';

      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select(mesecniFields)
          .eq('aktivan', true)
          .eq('obrisan', false)
          .like('radni_dani', '%$danKratica%') // ✅ FIXED: like umesto ilike za bolje performance
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      print('🏠 Mesečni putnici response: ${mesecniResponse.length}');

      int validniMesecni = 0;
      int bc6Mesecni = 0;

      for (final data in mesecniResponse) {
        // KORISTI fromMesecniPutniciMultipleForDay da kreira putnike samo za selektovani dan
        final mesecniPutnici = Putnik.fromMesecniPutniciMultipleForDay(data, danKratica);

        // ✅ VALIDACIJA: Prikaži samo putnike sa validnim vremenima polazaka
        final validPutnici = mesecniPutnici.where((putnik) {
          final polazak = putnik.polazak.trim();
          final isValid = polazak.isNotEmpty && polazak != '00:00:00' && polazak != '00:00' && polazak != 'null';
          if (isValid) {
            validniMesecni++;
            if (polazak == '6:00' &&
                (putnik.grad.toLowerCase().contains('bela') || putnik.grad.toLowerCase().contains('bc'))) {
              bc6Mesecni++;
              print('🏠 BC 6:00 mesečni putnik: ${putnik.ime}, polazak=$polazak, grad=${putnik.grad}');
            }
          }
          return isValid;
        }).toList();

        allPutnici.addAll(validPutnici);
      }

      print('🏠 Validni mesečni putnici: $validniMesecni');
      print('🏠 BC 6:00 mesečni putnici: $bc6Mesecni');
      print('🏠 Ukupno putnika (dnevni + mesečni): ${allPutnici.length}');
      return allPutnici;
    } catch (e) {
      return [];
    }
  }

  // Helper funkcija za konverziju weekday u kraticu
  String _getDayAbbreviation(int weekday) {
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return dani[weekday - 1];
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

  // ✅ DODANO: Helper funkcija za konverziju naziva dana u DateTime objekat
  DateTime _parseDateFromDayName(String dayName) {
    final today = DateTime.now();
    final todayWeekday = today.weekday;

    int targetWeekday;
    switch (dayName.toLowerCase()) {
      case 'ponedeljak':
        targetWeekday = 1;
        break;
      case 'utorak':
        targetWeekday = 2;
        break;
      case 'sreda':
        targetWeekday = 3;
        break;
      case 'četvrtak':
        targetWeekday = 4;
        break;
      case 'petak':
        targetWeekday = 5;
        break;
      case 'subota':
        targetWeekday = 6;
        break;
      case 'nedelja':
        targetWeekday = 7;
        break;
      default:
        targetWeekday = todayWeekday; // Defaultuje na danas
    }

    // Izračunaj koliko dana treba dodati/oduzeti
    int daysDifference = targetWeekday - todayWeekday;

    // Ako je ciljan dan u prošlosti ove nedelje, uzmi iz sledeće nedelje
    if (daysDifference < 0) {
      daysDifference += 7;
    }

    return today.add(Duration(days: daysDifference));
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

  // ✅ NOVA FUNKCIJA - vikendom vraća ponedeljak kao home_screen
  String _getFilterDayAbbreviation(int weekday) {
    // Vikend (subota=6, nedelja=7) -> prebaci na ponedeljak (1)
    if (weekday == 6 || weekday == 7) {
      return 'pon'; // ponedeljak
    }
    return _getDayAbbreviation(weekday);
  }

  // 🆕 NOVI: Sačuvaj putnika u odgovarajuću tabelu (workaround - sve u mesecni_putnici)
  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      // SVI PUTNICI - koristi mesecni_putnici tabelu kao workaround za RLS
      final data = putnik.toMesecniPutniciMap();

      if (putnik.id != null) {
        await supabase.from('mesecni_putnici').update(data).eq('id', putnik.id! as String);
      } else {
        await supabase.from('mesecni_putnici').insert(data);
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
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'aktivan': true, // Vraća na aktivan umesto obrisan: false
            }).eq('id', lastAction.putnikId as String);
          } else {
            // putovanja_istorija - koristi novu 'status' kolonu
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'] ?? 'nije_se_pojavio',
              'pokupljen': false, // ✅ RESETUJ pokupljen flag
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno brisanje putnika';

        case 'pickup':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'broj_putovanja': lastAction.oldData['broj_putovanja'],
              'pokupljen': false, // ✅ RESETUJ pokupljen flag za mesecne putnike
              'vreme_pokupljenja': null, // ✅ FIXED: Resetuj vreme pokupljanja umesto poslednje_putovanje
            }).eq('id', lastAction.putnikId as String);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              // 'vreme_akcije': null, // UKLONITI - kolona ne postoji
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno pokupljanje';

        case 'payment':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'cena': null, // ✅ RESETUJ cenu za mesecne putnike
              'vreme_placanja': null, // ✅ RESETUJ vreme placanja
              'vozac_id': null, // ✅ RESETUJ vozača kao UUID (uklanja i legacy)
            }).eq('id', lastAction.putnikId as String);
          } else {
            await supabase.from(tabela).update({
              'placeno': false,
              'iznos_placanja': null,
              'vreme_placanja': null,
              'status': lastAction.oldData['status'], // ✅ RESETUJ status
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno plaćanje';

        case 'cancel':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
            }).eq('id', lastAction.putnikId as String);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              // 'vreme_akcije': lastAction.oldData['vreme_akcije'], // UKLONITI - kolona ne postoji
              'vozac': lastAction.oldData['vozac'], // ✅ Koristi vozac umesto otkazao_vozac
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno otkazivanje';

        default:
          return 'Nepoznata akcija za poništavanje';
      }
    } catch (e) {
      return null;
    }
  }

  // 📋 BROJ DOSTUPNIH UNDO AKCIJA
  int get undoActionsCount => _undoStack.length;

  // 🕒 POSLEDNJA AKCIJA INFO
  String? get lastActionInfo {
    if (_undoStack.isEmpty) return null;
    final action = _undoStack.last;
    final timeAgo = DateTime.now().difference(action.timestamp).inMinutes;
    return '${action.type} (pre ${timeAgo}min)';
  }

  /// ✅ DODAJ PUTNIKA (dnevni ili mesečni) - 🏘️ SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik) async {
    try {
      // 🚫 STRIKTNA VALIDACIJA VOZAČA
      if (!VozacBoja.isValidDriver(putnik.dodaoVozac)) {
        throw Exception(
          'NEVALJAN VOZAČ: "${putnik.dodaoVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}',
        );
      }

      // 🚫 VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        throw Exception(
          'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.',
        );
      } // 🏘️ VALIDACIJA ADRESE
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
      if (putnik.mesecnaKarta == true) {
        // ✅ PROVERAVA DA LI MESEČNI PUTNIK VEĆ POSTOJI
        final existingPutnici = await supabase
            .from('mesecni_putnici')
            .select('id, putnik_ime, aktivan')
            .eq('putnik_ime', putnik.ime)
            .eq('aktivan', true);

        if (existingPutnici.isEmpty) {
          throw Exception('MESEČNI PUTNIK NE POSTOJI!\n\n'
              'Putnik "${putnik.ime}" ne postoji u listi mesečnih putnika.\n'
              'Idite na: Meni → Mesečni putnici da kreirate novog mesečnog putnika.');
        }

        // 🎯 NOVA LOGIKA: Za mesečne putnike se prisustvo evidentira kroz mesecni_putnici tabelu
        // ℹ️ Ne dodajemo duplikate u putovanja_istorija jer to kvari statistike
      } else {
        // ✅ DIREKTNO DODAJ U PUTOVANJA_ISTORIJA TABELU (JEDNOSTAVNO I POUZDANO)
        final insertData = putnik.toPutovanjaIstorijaMap();
        await supabase.from('putovanja_istorija').insert(insertData);
      }

      // 🔔 REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za današnji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je putnik za današnji dan u nedelji
      if (putnik.dan == todayName) {
        RealtimeNotificationService.sendRealtimeNotification(
          'Novi putnik',
          'Dodjen je novi putnik ${putnik.ime}',
          {
            'type': 'novi_putnik',
            'putnik': {
              'ime': putnik.ime,
              'grad': putnik.grad,
              'vreme': putnik.polazak,
              'dan': putnik.dan,
            },
          },
        );
      } else {}
    } catch (e) {
      rethrow; // Ponovno baci grešku da je home_screen može uhvatiti
    }
  }

  /// ✅ KOMBINOVANI STREAM - MESEČNI + DNEVNI PUTNICI
  Stream<List<Putnik>> streamKombinovaniPutnici() {
    final danasKratica = _getFilterDayAbbreviation(DateTime.now().weekday);
    final danas = DateTime.now().toIso8601String().split('T')[0];

    final mesecniStream = RealtimeService.instance.tableStream('mesecni_putnici');
    final putovanjaStream = RealtimeService.instance.tableStream('putovanja_istorija');

    return CombineLatestStream.combine2(
      mesecniStream,
      putovanjaStream,
      (mesecniData, putovanjaData) => {
        'mesecni': mesecniData,
        'putovanja': putovanjaData,
      },
    ).asyncMap((maps) async {
      final mesecniData = maps['mesecni'] as List;
      final putovanjaData = maps['putovanja'] as List;

      List<Putnik> sviPutnici = []; // 1. MESEČNI PUTNICI - UKLJUČI I OTKAZANE
      for (final item in mesecniData) {
        try {
          final radniDani = item['radni_dani']?.toString() ?? '';

          if (radniDani.toLowerCase().contains(danasKratica.toLowerCase())) {
            final mesecniPutnici = Putnik.fromMesecniPutniciMultipleForDay(
              item as Map<String, dynamic>,
              danasKratica,
            );
            sviPutnici.addAll(mesecniPutnici);
          } else {}
        } catch (e) {}
      }

      // 2. DNEVNI PUTNICI - koristi događaje iz putovanja_istorija stream-a filtrirane na danas
      try {
        final List<dynamic> dnevniFiltered = putovanjaData.where((row) {
          try {
            return (row['datum'] == danas) && (row['tip_putnika'] == 'dnevni');
          } catch (_) {
            return false;
          }
        }).toList();
        for (final item in dnevniFiltered) {
          try {
            final putnik = Putnik.fromPutovanjaIstorija(item as Map<String, dynamic>);
            sviPutnici.add(putnik);
          } catch (e) {}
        }
      } catch (e) {}

      // 3. DODATNO: Uključi specijalne "zakupljeno" zapise (ostavljamo postojeću metodu)
      try {
        final zakupljenoRows = await MesecniPutnikService.getZakupljenoDanas();
        if (zakupljenoRows.isNotEmpty) {}

        for (final item in zakupljenoRows) {
          try {
            final putnik = Putnik.fromPutovanjaIstorija(item);
            sviPutnici.add(putnik);
          } catch (e) {}
        }
      } catch (e) {} // ✅ SORTIRANJE: Otkazani na dno liste
      sviPutnici.sort((a, b) {
        if (a.jeOtkazan && !b.jeOtkazan) return 1;
        if (!a.jeOtkazan && b.jeOtkazan) return -1;
        return (b.vremeDodavanja ?? DateTime.now()).compareTo(a.vremeDodavanja ?? DateTime.now());
      });
      return sviPutnici;
    });
  }

  /// ✅ STREAM SVIH PUTNIKA (iz mesecni_putnici tabele - workaround za RLS)
  Stream<List<Putnik>> streamPutnici() {
    return RealtimeService.instance.tableStream('mesecni_putnici').map((data) {
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
        // NOVA LOGIKA: Koristi fromMesecniPutniciMultiple
        final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item as Map<String, dynamic>);
        allPutnici.addAll(mesecniPutnici);
      }
      return allPutnici;
    });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu
  Stream<List<Putnik>> streamMesecniPutnici(String grad) {
    return RealtimeService.instance.tableStream('mesecni_putnici').map((data) {
      final Map<String, Putnik> uniquePutnici = {}; // Mapa po imenima da izbegnemo duplikate
      final items = data is List ? data : <dynamic>[];

      // Sort by created_at descending if present
      try {
        items.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      } catch (_) {}

      for (final item in items) {
        // Preskačemo obrisane putnike
        if (item['aktivan'] != true) continue;

        bool dodaj = false;
        String? adresa;

        // Filter po gradu - proveri odgovarajuće adresno polje
        if (grad == 'Bela Crkva') {
          if (item['adresa_bela_crkva'] != null && item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
            dodaj = true;
            adresa = item['adresa_bela_crkva'] as String?;
          }
        } else if (grad == 'Vršac') {
          if (item['adresa_vrsac'] != null && item['adresa_vrsac'].toString().trim().isNotEmpty) {
            dodaj = true;
            adresa = item['adresa_vrsac'] as String?;
          }
        }

        if (dodaj) {
          final ime = item['ime']?.toString() ?? '';

          // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
          uniquePutnici[ime] = Putnik.fromMap({
            'id': item['id'],
            'ime': ime,
            'mesecna_karta': true,
            'status': item['status'],
            'tip_putnika': item['tip'],
            'aktivan': item['aktivan'],
            'iznos_placanja': null,
            'vreme_placanja': null,

            'adresa': adresa,
            'vreme_dodavanja': item['created_at'],
            'broj_putovanja': item['broj_putovanja'],
            'poslednja_voznja': item['poslednja_voznja'],
            // Meta podaci za mesečne putnike
            'grad': grad, // Eksplicitno postavljamo grad
            'polazak': '', // Prazan jer mesečni nemaju polazak
            'dan': item['dan'] ?? '', // Dan iz baze podataka
          });
        }
      }

      final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

      return mesecniPutnici;
    });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu i danu
  Stream<List<Putnik>> streamMesecniPutniciPoGraduDanu(
    String grad,
    String dan,
  ) {
    return RealtimeService.instance.tableStream('mesecni_putnici').map((data) {
      final Map<String, Putnik> uniquePutnici = {}; // Mapa po imenima da izbegnemo duplikate
      final items = data is List ? data : <dynamic>[];

      // Optionally sort by created_at desc
      try {
        items.sort((a, b) {
          final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      } catch (_) {}

      for (final item in items) {
        // Skip non-matching day early
        try {
          if ((item['dan'] ?? '') != dan) continue;
        } catch (_) {
          continue;
        }

        // Preskačemo obrisane putnike
        if (item['aktivan'] != true) continue;

        bool dodaj = false;
        String? adresa;

        // Filter po gradu - proveri odgovarajuće adresno polje
        if (grad == 'Bela Crkva') {
          if (item['adresa_bela_crkva'] != null && item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
            dodaj = true;
            adresa = item['adresa_bela_crkva'] as String?;
          }
        } else if (grad == 'Vršac') {
          if (item['adresa_vrsac'] != null && item['adresa_vrsac'].toString().trim().isNotEmpty) {
            dodaj = true;
            adresa = item['adresa_vrsac'] as String?;
          }
        }

        if (dodaj) {
          final ime = item['ime']?.toString() ?? '';

          // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
          uniquePutnici[ime] = Putnik.fromMap({
            'id': item['id'],
            'ime': ime,
            'mesecna_karta': true,
            'status': item['status'],
            'tip_putnika': item['tip'],
            'aktivan': item['aktivan'],
            'iznos_placanja': null,
            'vreme_placanja': null,

            'adresa': adresa,
            'vreme_dodavanja': item['created_at'],
            'broj_putovanja': item['broj_putovanja'],
            'poslednja_voznja': item['poslednja_voznja'],
            // Meta podaci za mesečne putnike
            'grad': grad, // Eksplicitno postavljamo grad
            'polazak': '', // Prazan jer mesečni nemaju polazak
            'dan': item['dan'] ?? '', // Dan iz baze podataka
          });
        }
      }

      final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

      return mesecniPutnici;
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
    await supabase.from(tabela).update({
      'obrisan': true, // ✅ Sada POSTOJI u obe tabele
      'status': 'obrisan', // Dodatno označavanje u status
      // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
    }).eq('id', id as String);
  }

  /// ✅ OZNAČI KAO POKUPLJEN
  Future<void> oznaciPokupljen(dynamic id, String currentDriver) async {
    // 🚫 DUPLICATE PREVENTION
    final actionKey = 'pickup_$id';
    if (_isDuplicateAction(actionKey)) {
      return;
    }

    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(currentDriver)) {
      throw ArgumentError(
        'NEVALJAN VOZAČ: "$currentDriver". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}',
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
    final undoPickup = Map<String, dynamic>.from(response as Map);
    _addToUndoStack('pickup', id, undoPickup);

    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za pokupljanje
      final now = DateTime.now();

      await supabase.from(tabela).update({
        'vreme_pokupljenja': now.toIso8601String(), // ✅ FIXED: Koristi samo vreme_pokupljenja
        'pokupljen': true, // ✅ BOOLEAN flag
        'vozac_id': (currentDriver.isEmpty) ? null : currentDriver, // UUID validacija
        'pokupljanje_vozac': currentDriver, // ✅ NOVA KOLONA - vozač koji je pokupljanje izvršio
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id as String);

      // 🔄 AUTOMATSKA SINHRONIZACIJA - ažuriraj brojPutovanja iz istorije
      try {
        await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(id);
      } catch (e) {}
    } else {
      // Za putovanja_istorija koristi novu 'status' kolonu

      await supabase.from(tabela).update({
        'status': 'pokupljen',
        'pokupljanje_vozac': currentDriver, // ✅ NOVA KOLONA - vozač koji je pokupljanje izvršio
        'vreme_pokupljenja': DateTime.now().toIso8601String(), // ✅ DODATO - vreme pokupljanja
      }).eq('id', id as String);
    }

    // 📊 AUTOMATSKA SINHRONIZACIJA BROJA PUTOVANJA (NOVO za putovanja_istorija!)
    if (tabela == 'putovanja_istorija' && response['mesecni_putnik_id'] != null) {
      try {
        await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
          response['mesecni_putnik_id'] as String,
        );
      } catch (syncError) {
        // Nastavi dalje - sinhronizacija nije kritična
      }
    }

    // 📊 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
    if (putnik.mesecnaKarta == true) {
      // Statistike se računaju dinamički kroz StatistikaService
      // bez potrebe za dodatnim ažuriranjem
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
    // ⚠️ BLAŽU VALIDACIJU VOZAČA - dozvoli fallback umesto greške
    if (!VozacBoja.isValidDriver(naplatioVozac)) {
      // ✅ Umesto da bacamo grešku, koristimo vozača kao jeste
      // Aplikacija će se nositi sa fallback vozačem
    }

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await SupabaseSafe.run(
      () => supabase.from(tabela).select().eq('id', id as String).single(),
    );

    // 📝 DODAJ U UNDO STACK (sigurno mapiranje)
    final undoPayment = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
    _addToUndoStack('payment', id, undoPayment);
    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za plaćanje
      final now = DateTime.now(); // Konvertuj ime vozača u UUID ako nije već UUID
      String? validVozacId =
          naplatioVozac.isEmpty ? null : (VozacMappingService.getVozacUuidSync(naplatioVozac) ?? naplatioVozac);

      await supabase.from(tabela).update({
        'cena': iznos, // ✅ CENA mesečne karte
        'vreme_placanja': now.toIso8601String(), // ✅ TIMESTAMP plaćanja
        'vozac_id': validVozacId, // ✅ STANDARDIZOVANO - samo vozac_id (UUID)
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id as String);
    } else {
      // Za putovanja_istorija koristi cena kolonu// Konvertuj ime vozača u UUID ako nije već UUID
      String? validVozacId =
          naplatioVozac.isEmpty ? null : (VozacMappingService.getVozacUuidSync(naplatioVozac) ?? naplatioVozac);

      await supabase.from(tabela).update({
        'cena': iznos,
        'vozac_id': validVozacId, // ✅ STANDARDIZOVANO - samo vozac_id (UUID)
        'status': 'placen', // ✅ DODAJ STATUS plaćanja
      }).eq('id', id as String);
    } // (Uklonjeno slanje notifikacije za plaćanje)
  }

  /// ✅ OTKAZI PUTNIKA
  Future<void> otkaziPutnika(
    dynamic id,
    String otkazaoVozac, {
    String? selectedVreme,
    String? selectedGrad,
  }) async {
    try {
      // ✅ dynamic umesto int
      // Određi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(id);

      // Prvo dohvati podatke putnika za notifikaciju
      final response = await SupabaseSafe.run(
        () => supabase.from(tabela).select().eq('id', id as String).single(),
      );
      final respMap = response == null ? <String, dynamic>{} : Map<String, dynamic>.from(response as Map);
      final cancelName = (respMap['putnik_ime'] ?? respMap['ime']) ?? '';

      // 📝 DODAJ U UNDO STACK
      _addToUndoStack('cancel', id, respMap);

      if (tabela == 'mesecni_putnici') {
        // 🆕 NOVI PRISTUP: Za mesečne putnike kreiraj zapis u putovanja_istorija za konkretan dan
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final polazak = selectedVreme ?? '5:00'; // Koristi proslijećeno vreme ili default
        final grad = selectedGrad ?? 'Bela Crkva'; // Koristi proslijećeni grad ili default

        // Kreiraj zapis otkazivanja za današnji dan sa ActionLog
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);
        final actionLog = ActionLog.empty().addAction(
          ActionType.cancelled,
          vozacUuid ?? '',
          'Otkazano',
        );

        await SupabaseSafe.run(
          () => supabase.from('putovanja_istorija').upsert({
            'putnik_ime': respMap['putnik_ime'],
            'datum_putovanja': danas,
            'vreme_polaska': polazak,
            'grad': grad,
            'status': 'otkazan',
            'cena': 0,
            'vozac_id': null,
            'created_by': vozacUuid,
            'action_log': actionLog.toJsonString(),
          }),
          fallback: <dynamic>[],
        );
      } else {
        // Za putovanja_istorija koristi ActionLog
        final currentData = await supabase.from(tabela).select('action_log').eq('id', id.toString()).single();

        final currentActionLog = ActionLog.fromString(currentData['action_log'] as String?);
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);
        final updatedActionLog = currentActionLog.addAction(
          ActionType.cancelled,
          vozacUuid ?? '',
          'Otkazano',
        );

        await supabase.from(tabela).update({
          'status': 'otkazan',
          'action_log': updatedActionLog.toJsonString(),
        }).eq('id', id.toString());
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
          RealtimeNotificationService.sendRealtimeNotification(
            'Otkazan putnik',
            'Otkazan je putnik $cancelName',
            {
              'type': 'otkazan_putnik',
              'putnik': {
                'ime': respMap['putnik_ime'],
                'grad': respMap['grad'],
                'vreme': respMap['vreme_polaska'] ?? respMap['polazak'],
                'dan': respMap['dan'],
              },
            },
          );
        } else {}
      } catch (notifError) {
        // Nastavi dalje - notifikacija nije kritična
      }

      // 📊 AUTOMATSKA SINHRONIZACIJA BROJA OTKAZIVANJA (NOVO!)
      if (tabela == 'putovanja_istorija' && (respMap['mesecni_putnik_id'] != null)) {
        try {
          await MesecniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
            respMap['mesecni_putnik_id'] as String,
          );
        } catch (syncError) {
          // Nastavi dalje - sinhronizacija nije kritična
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ DOHVATI PO GRADU, DANU, VREMENU (iz putovanja_istorija)
  Future<List<Putnik>> getPutniciZaGradDanVreme(
    String grad,
    String dan,
    String vreme,
  ) async {
    final data = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('tip_putnika', 'dnevni')
        .eq('adresa_polaska', grad) // koristimo adresa_polaska umesto grad
        .eq('vreme_polaska', vreme)
        .neq('status', 'otkazan') as List<dynamic>?;

    if (data == null) return [];
    return data.map((e) => Putnik.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// 📊 PREDVIĐANJE BROJ PUTNIKA (iz putovanja_istorija)
  Future<Map<String, dynamic>> getPredvidjanje() async {
    try {
      // Dohvati sve putnike iz putovanja_istorija iz poslednja 4 nedelje
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

      final data = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('tip_putnika', 'dnevni')
          .gte('created_at', fourWeeksAgo.toIso8601String())
          .neq('status', 'otkazan') as List<dynamic>?;

      if (data == null || data.isEmpty) {
        return {
          'ukupno_prosek': 0.0,
          'po_danima': <String, double>{},
          'po_vremenima': <String, double>{},
          'po_gradovima': <String, double>{},
          'preporuke': <String>[],
        };
      }

      final putnici = data.map((e) => Putnik.fromMap(e as Map<String, dynamic>)).toList();

      // Grupisanje po danima
      final poDanima = <String, List<Putnik>>{};
      final poVremenima = <String, List<Putnik>>{};
      final poGradovima = <String, List<Putnik>>{};

      for (final putnik in putnici) {
        // Po danima
        poDanima.putIfAbsent(putnik.dan, () => []).add(putnik);

        // Po vremenima
        final vreme = putnik.polazak;
        poVremenima.putIfAbsent(vreme, () => []).add(putnik);

        // Po gradovima
        final grad = putnik.grad;
        poGradovima.putIfAbsent(grad, () => []).add(putnik);
      }

      // Proseci
      final prosekPoDanima = <String, double>{};
      poDanima.forEach((dan, lista) {
        prosekPoDanima[dan] = lista.length / 4.0; // 4 nedelje
      });

      final prosekPoVremenima = <String, double>{};
      poVremenima.forEach((vreme, lista) {
        prosekPoVremenima[vreme] = lista.length / 4.0;
      });

      final prosekPoGradovima = <String, double>{};
      poGradovima.forEach((grad, lista) {
        prosekPoGradovima[grad] = lista.length / 4.0;
      });

      // Preporuke na osnovu podataka
      final preporuke = <String>[];

      // Najpopularniji dan
      if (prosekPoDanima.isNotEmpty) {
        final najpopularnijiDan = prosekPoDanima.entries.reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
          'Najpopularniji dan: ${najpopularnijiDan.key} (${najpopularnijiDan.value.toStringAsFixed(1)} putnika/dan)',
        );
      }

      // Najpopularnije vreme
      if (prosekPoVremenima.isNotEmpty) {
        final najpopularnijeVreme = prosekPoVremenima.entries.reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
          'Najpopularnije vreme: ${najpopularnijeVreme.key} (${najpopularnijeVreme.value.toStringAsFixed(1)} putnika/dan)',
        );
      }

      // Najpopularniji grad
      if (prosekPoGradovima.isNotEmpty) {
        final najpopularnijiGrad = prosekPoGradovima.entries.reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
          'Najpopularniji grad: ${najpopularnijiGrad.key} (${najpopularnijiGrad.value.toStringAsFixed(1)} putnika/dan)',
        );
      }

      // Dodatne preporuke
      if (prosekPoDanima['Pet'] != null && prosekPoDanima['Pet']! > 15) {
        preporuke.add(
          '⚠️ Petak je često preopterećen - razmisliti o dodatnim polascima',
        );
      }

      if (prosekPoVremenima['7:00'] != null && prosekPoVremenima['7:00']! > 12) {
        preporuke.add('🌅 Jutarnji polasci (7:00) su vrlo popularni');
      }

      return {
        'ukupno_prosek': putnici.length / 4.0,
        'po_danima': prosekPoDanima,
        'po_vremenima': prosekPoVremenima,
        'po_gradovima': prosekPoGradovima,
        'preporuke': preporuke,
        'period_analiza': '${fourWeeksAgo.day}/${fourWeeksAgo.month} - ${DateTime.now().day}/${DateTime.now().month}',
      };
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  // 📊 Statistike po mesecima (kombinovano dnevni i mesečni putnici)
  Future<Map<String, int>> getBrojVoznjiPoMesecima(String imePutnika) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year);

    // Dohvati iz putovanja_istorija
    final dnevniData = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('tip_putnika', 'dnevni')
        .gte('created_at', startOfYear.toIso8601String());

    final mesecniData = await supabase
        .from('mesecni_putnici')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('aktivan', true)
        .gte('created_at', startOfYear.toIso8601String());

    final List<Putnik> voznje = [
      ...(dnevniData as List).map((e) => Putnik.fromMap(e as Map<String, dynamic>)),
      ...(mesecniData as List).map(
        (e) => Putnik.fromMap({
          ...(e as Map<String, dynamic>),
          'created_at': e['created_at'],
          'status': e['status'] ?? 'radi', // ✅ JEDNOSTAVNO
        }),
      ),
    ];

    // Grupisanje po mesecu i danu
    final Map<String, Map<String, List<Putnik>>> poMesecuDanu = {};
    for (var v in voznje) {
      if (v.vremeDodavanja != null) {
        final mesec = '${v.vremeDodavanja!.month.toString().padLeft(2, '0')}.${v.vremeDodavanja!.year}';
        final dan = v.vremeDodavanja!.toIso8601String().substring(0, 10); // yyyy-MM-dd
        poMesecuDanu.putIfAbsent(mesec, () => {});
        poMesecuDanu[mesec]!.putIfAbsent(dan, () => []);
        poMesecuDanu[mesec]![dan]!.add(v);
      }
    }

    // Za svaki dan proveri: ako postoji bar jedan putnik koji NIJE otkazan, bolovanje ili godišnji, broji se kao vožnja
    final Map<String, int> brojPoMesecima = {};
    poMesecuDanu.forEach((mesec, daniMap) {
      int brojac = 0;
      daniMap.forEach((dan, listaPutnika) {
        final allExcluded = listaPutnika.every(
          (p) => (p.status != null &&
              (p.status!.toLowerCase() == 'otkazano' ||
                  p.status!.toLowerCase() == 'otkazan' ||
                  p.status!.toLowerCase() == 'bolovanje' ||
                  p.status!.toLowerCase() == 'godisnji')),
        );
        if (!allExcluded) {
          brojac++;
        }
      });
      brojPoMesecima[mesec] = brojac;
    });
    return brojPoMesecima;
  }

  /// 🚫 OZNAČI KAO BOLOVANJE/GODIŠNJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
    dynamic id,
    String tipOdsustva,
    String currentDriver,
  ) async {
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

    if (tabela == 'mesecni_putnici') {
      // ✅ JEDNOSTAVNO - samo setuj status na bolovanje/godisnji
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id as String);
    } else {
      // Za putovanja_istorija koristi 'status' kolonu
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
      }).eq('id', id as String);
    }
  }

  /// 🔄 RESETUJ KARTICU U POČETNO STANJE (samo za validne vozače)
  Future<void> resetPutnikCard(String imePutnika, String currentDriver) async {
    try {
      if (!VozacBoja.isValidDriver(currentDriver)) {
        throw Exception('Samo validni vozači mogu da resetuju kartice');
      } // Pokušaj reset u mesecni_putnici tabeli
      try {
        final mesecniResponse =
            await supabase.from('mesecni_putnici').select().eq('putnik_ime', imePutnika).maybeSingle();

        if (mesecniResponse != null) {
          await supabase.from('mesecni_putnici').update({
            'aktivan': true, // ✅ KRITIČNO: VRATI na aktivan (jeOtkazan = false)
            'status': 'radi', // ✅ VRATI na radi
            'vreme_pokupljenja': null, // ✅ FIXED: Ukloni timestamp pokupljanja
            'vreme_placanja': null, // ✅ UKLONI timestamp plaćanja
            'pokupljen': false, // ✅ VRATI na false
            'cena': null, // ✅ UKLONI plaćanje
            'vozac_id': null, // ✅ UKLONI vozača (UUID kolona)
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          // 📊 SINHRONIZUJ broj otkazivanja nakon reset-a (VAŽNO!)
          try {
            final putnikId = mesecniResponse['id'] as String;
            await MesecniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
              putnikId,
            );
            // 📊 TAKOĐE sinhronizuj broj putovanja (NOVO!)
            await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
              putnikId,
            );
          } catch (syncError) {
            // Ignore sync errors
          }
          return;
        }
      } catch (e) {
        // Ako nema u mesecni_putnici, nastavi sa putovanja_istorija
      }

      // Pokušaj reset u putovanja_istorija tabeli
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        await supabase
            .from('putovanja_istorija')
            .update({
              'status': 'nije_se_pojavio', // ✅ POČETNO STANJE umesto null
              'cena': 0, // ✅ VRATI cenu na 0
              // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
              'vozac': null, // ✅ UKLONI vozača
            })
            .eq('putnik_ime', imePutnika)
            .eq('datum', danas);
      } else {
        // Nema zapis u putovanja_istorija za danas - nastavi
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
      if (!VozacBoja.isValidDriver(currentDriver)) {
        return;
      }

      // Resetuj mesečne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final mesecniPutnici = await supabase
            .from('mesecni_putnici')
            .select(
              'id, putnik_ime, polasci_po_danu, vreme_pokupljenja',
            ) // ✅ FIXED: Koristi vreme_pokupljenja
            .eq('aktivan', true)
            .not(
              'vreme_pokupljenja',
              'is',
              null,
            ); // ✅ FIXED: Koristi vreme_pokupljenja

        for (final putnik in mesecniPutnici) {
          final vremePokupljenja = DateTime.tryParse(
            putnik['vreme_pokupljenja'] as String,
          ); // ✅ FIXED: Koristi vreme_pokupljenja

          if (vremePokupljenja == null) continue;

          // Provjeri polazak za odgovarajući grad i trenutni dan
          String? polazakVreme;
          final danasnjiDan = _getDanNedelje();

          // Unified parsing: prefer JSON `polasci_po_danu` then per-day columns
          final place = grad == 'Bela Crkva' ? 'bc' : 'vs';
          polazakVreme = MesecniHelpers.getPolazakForDay(putnik, danasnjiDan, place);

          if (polazakVreme == null || polazakVreme.isEmpty || polazakVreme == '00:00:00') {
            continue;
          }

          // Provjeri da li je pokupljen van vremenskog okvira novog polaska
          final novoPolazakSati = int.tryParse(novoVreme.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;
          final razlika = (pokupljenSati - novoPolazakSati).abs();

          // Ako je pokupljen van tolerancije (±3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            await supabase.from('mesecni_putnici').update({
              'vreme_pokupljenja': null, // ✅ FIXED: Koristi vreme_pokupljenja
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id'] as String);
          }
        }
      } catch (e) {}

      // Resetuj dnevne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final dnevniPutnici = await supabase
            .from('putovanja_istorija')
            .select(
              'id, putnik_ime, vreme_polaska',
            ) // UKLONITI vreme_akcije - kolona ne postoji
            .eq('datum', danas)
            .eq('grad', grad)
            .eq('status', 'pokupljen');

        for (final putnik in dnevniPutnici) {
          // UKLONITI - vreme_akcije kolona ne postoji, koristi created_at ili updated_at
          // final vremeAkcije = DateTime.tryParse(putnik['vreme_akcije'] as String);
          // if (vremeAkcije == null) continue;

          // Jednostavno resetuj sve pokupljene putnike kada se menja vreme
          await supabase.from('putovanja_istorija').update({
            'status': 'nije_se_pojavio',
            'cena': 0,
            // 'vreme_akcije': DateTime.now().toIso8601String(), // UKLONITI - kolona ne postoji
          }).eq('id', putnik['id'] as String);
        }
      } catch (e) {
        // Ignore errors during reset
      }
    } catch (e) {
      // Ignore outer errors
    }
  }

  /// 📊 DOHVATI SVA UKRCAVANJA ZA PUTNIKA
  Future<List<Map<String, dynamic>>> dohvatiUkrcavanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final ukrcavanja = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', putnikIme)
          .eq('status', 'pokupljen')
          .order('created_at', ascending: false) as List<dynamic>;

      return ukrcavanja.cast<Map<String, dynamic>>();
    } catch (e) {
      return <Map<String, dynamic>>[];
    }
  }

  /// 📊 DOHVATI SVE OTKAZE ZA PUTNIKA
  Future<List<Map<String, dynamic>>> dohvatiOtkazeZaPutnika(
    String putnikIme,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final otkazi = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', putnikIme)
          .eq('status', 'otkazan')
          .order('created_at', ascending: false) as List<dynamic>;

      return otkazi.cast<Map<String, dynamic>>();
    } catch (e) {
      return <Map<String, dynamic>>[];
    }
  }

  /// 📊 DOHVATI SVA PLAĆANJA ZA PUTNIKA
  Future<List<Map<String, dynamic>>> dohvatiPlacanjaZaPutnika(
    String putnikIme,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> svaPlacanja = [];

      // 1. REDOVNA PUTOVANJA iz putovanja_istorija
      final redovnaPlacanja = await supabase
          .from('putovanja_istorija')
          .select(
            '*, vozac_id, naplata_vozac',
          ) // Dodaj i vozac_id i naplata_vozac za fallback
          .eq('putnik_ime', putnikIme)
          .gt('cena', 0)
          .order('created_at', ascending: false) as List<dynamic>;

      // Konvertuj redovna plaćanja sa vozac_id->ime mapiranjem
      for (var redovno in redovnaPlacanja) {
        final redovnoMap = redovno as Map<String, dynamic>;
        // Koristi vozac_id prvo, fallback na naplata_vozac za legacy podatke
        final vozacId = redovnoMap['vozac_id'] as String?;
        final legacyVozac = redovnoMap['naplata_vozac'] as String?;

        redovnoMap['vozac_ime'] =
            vozacId != null ? (await VozacMappingService.getVozacImeWithFallback(vozacId)) ?? legacyVozac : legacyVozac;

        svaPlacanja.add(redovnoMap);
      }

      // 2. MESEČNA PLAĆANJA iz mesecni_putnici
      final mesecnaPlacanja = await supabase
          .from('mesecni_putnici')
          .select(
            'cena, vreme_placanja, vozac_id, placeni_mesec, placena_godina',
          )
          .eq('putnik_ime', putnikIme)
          .not('vreme_placanja', 'is', null)
          .order('vreme_placanja', ascending: false) as List<dynamic>;

      // Konvertuj mesečna plaćanja u isti format kao redovna
      for (var mesecno in mesecnaPlacanja) {
        svaPlacanja.add({
          'cena': mesecno['cena'],
          'created_at': mesecno['vreme_placanja'],
          'vozac_ime': VozacMappingService.getVozacImeWithFallback(
            mesecno['vozac_id'] as String?,
          ), // UUID->ime konverzija
          'putnik_ime': putnikIme,
          'tip': 'mesecna_karta',
          'placeniMesec': mesecno['placeni_mesec'],
          'placenaGodina': mesecno['placena_godina'],
        });
      }

      // Sortiraj sve po datumu, najnovije prvo
      svaPlacanja.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateB.compareTo(dateA);
      });

      return svaPlacanja;
    } catch (e) {
      return <Map<String, dynamic>>[];
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

  /// 🧹 DATA CLEANUP: Popravlja nevalidne vozače u bazi podataka
  Future<void> cleanupNevalidneVozace(String currentDriver) async {
    if (!VozacBoja.isValidDriver(currentDriver)) {
      throw Exception(
        'Cleanup može izvršiti samo valjan vozač: ${VozacBoja.validDrivers.join(", ")}',
      );
    }

    try {
      // 1. Očisti putovanja_istorija tabelu
      await supabase.from('putovanja_istorija').update({
        'dodao_vozac': currentDriver,
      }).or('dodao_vozac.is.null,dodao_vozac.eq.');

      await supabase.from('putovanja_istorija').update({
        'pokupio_vozac': null,
      }).not('pokupio_vozac', 'in', VozacBoja.validDrivers);

      await supabase.from('putovanja_istorija').update({
        'naplatio_vozac': null,
      }).not('naplatio_vozac', 'in', VozacBoja.validDrivers);

      await supabase.from('putovanja_istorija').update({
        'otkazao_vozac': null,
      }).not('otkazao_vozac', 'in', VozacBoja.validDrivers);

      // 2. Očisti mesecni_putnici tabelu
      await supabase.from('mesecni_putnici').update({
        'dodao_vozac': currentDriver,
      }).or('dodao_vozac.is.null,dodao_vozac.eq.');

      await supabase.from('mesecni_putnici').update({
        'naplatio_vozac': null,
      }).not('naplatio_vozac', 'in', VozacBoja.validDrivers);
    } catch (e) {
      throw Exception('Greška pri cleanup-u: $e');
    }
  }

  /// 🔍 VALIDACIJA: Proveri da li ima nevalidnih vozača u bazi
  Future<Map<String, int>> proveriBazuZaNevalidneVozace() async {
    final rezultat = <String, int>{};

    try {
      // Proveri putovanja_istorija
      final putovanjaResponse =
          await supabase.from('putovanja_istorija').select('dodao_vozac, pokupio_vozac, naplatio_vozac, otkazao_vozac');

      int nevalidniDodao = 0;
      int nevalidniPokupio = 0;
      int nevalidniNaplatio = 0;
      int nevalidniOtkazao = 0;

      for (final red in putovanjaResponse) {
        if (red['dodao_vozac'] != null && !VozacBoja.isValidDriver(red['dodao_vozac'] as String?)) {
          nevalidniDodao++;
        }
        if (red['pokupio_vozac'] != null && !VozacBoja.isValidDriver(red['pokupio_vozac'] as String?)) {
          nevalidniPokupio++;
        }
        if (red['naplatio_vozac'] != null && !VozacBoja.isValidDriver(red['naplatio_vozac'] as String?)) {
          nevalidniNaplatio++;
        }
        if (red['otkazao_vozac'] != null && !VozacBoja.isValidDriver(red['otkazao_vozac'] as String?)) {
          nevalidniOtkazao++;
        }
      }

      rezultat['nevalidni_dodao'] = nevalidniDodao;
      rezultat['nevalidni_pokupio'] = nevalidniPokupio;
      rezultat['nevalidni_naplatio'] = nevalidniNaplatio;
      rezultat['nevalidni_otkazao'] = nevalidniOtkazao;

      // Proveri mesecni_putnici
      final mesecniResponse = await supabase.from('mesecni_putnici').select('dodao_vozac, naplatio_vozac');

      int nevalidniMesecniDodao = 0;
      int nevalidniMesecniNaplatio = 0;

      for (final red in mesecniResponse) {
        if (red['dodao_vozac'] != null && !VozacBoja.isValidDriver(red['dodao_vozac'] as String?)) {
          nevalidniMesecniDodao++;
        }
        if (red['naplatio_vozac'] != null && !VozacBoja.isValidDriver(red['naplatio_vozac'] as String?)) {
          nevalidniMesecniNaplatio++;
        }
      }

      rezultat['nevalidni_mesecni_dodao'] = nevalidniMesecniDodao;
      rezultat['nevalidni_mesecni_naplatio'] = nevalidniMesecniNaplatio;

      return rezultat;
    } catch (e) {
      throw Exception('Greška pri proveri baze: $e');
    }
  }
}
