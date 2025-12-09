import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_log.dart';
import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart'; // DODANO za validaciju gradova i adresa
import '../utils/registrovani_helpers.dart';
import '../utils/text_utils.dart'; // DODANO za konzistentno filtriranje statusa
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
    // // print('🔍 STREAM POZVAN SA: isoDate=$isoDate, grad=$grad, vreme=$vreme');

    final key = _streamKey(isoDate: isoDate, grad: grad, vreme: vreme);
    if (_streams.containsKey(key) && !_streams[key]!.isClosed) {
      // // print('📦 VRAĆAM POSTOJEĆI STREAM ZA KEY: $key');
      // Ako imamo cached vrednost, emituj je odmah
      final controller = _streams[key]!;
      if (_lastValues.containsKey(key)) {
        Future.microtask(() => controller.add(_lastValues[key]!));
      }
      return controller.stream;
    }

    // // print('🆕 KREIRAM NOVI STREAM ZA KEY: $key');
    final controller = StreamController<List<Putnik>>.broadcast();
    _streams[key] = controller;

    Future<void> doFetch() async {
      try {
        // print('🔄 FETCH POKRET STARTED za datum: $isoDate');
        final combined = <Putnik>[];

        // Fetch daily rows server-side if isoDate provided, otherwise fetch recent daily
        // print('📊 QUERY: putovanja_istorija WHERE datum_putovanja=$isoDate AND tip_putnika=dnevni');

        // 🚫 UKLONJENO: Ad-hoc dnevni putnici više ne postoje
        // Svi putnici (radnik, ucenik, dnevni) su registrovani u registrovani_putnici tabeli
        // i koriste istu logiku. Učitavanje iz putovanja_istorija sa tip_putnika='dnevni'
        // više nije potrebno.

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

        // 🔍 Dohvati sve mesečne zapise iz putovanja_istorija za ovaj dan
        // (otkazivanja, pokupljenja itd.) da bismo ih isključili/zamenili
        final Map<String, Map<String, dynamic>> registrovaniOverrides = {};
        // ✅ FIX: Uvek učitavaj overrides za današnji dan, ne samo ako isoDate != null
        final overrideDate = isoDate ?? DateTime.now().toIso8601String().split('T')[0];
        try {
          final registrovaniIstorija = await supabase
              .from('putovanja_istorija')
              .select('*, adrese:adresa_id(naziv, ulica, broj, grad)') // ✅ FIX: JOIN za adresu
              .eq('datum_putovanja', overrideDate)
              .eq('tip_putnika', 'mesecni')
              .eq('obrisan', false) // ✅ Ignoriši soft-deleted zapise
              .not('registrovani_putnik_id', 'is', null);

          for (final row in registrovaniIstorija) {
            final map = Map<String, dynamic>.from(row);

            // ✅ FIX: Izvuci adresu iz JOIN-a ako nije direktno u koloni
            if (map['adresa'] == null || (map['adresa'] as String?)?.isEmpty == true) {
              final adreseData = map['adrese'] as Map<String, dynamic>?;
              if (adreseData != null) {
                final naziv = adreseData['naziv'] as String?;
                final ulica = adreseData['ulica'] as String?;
                final broj = adreseData['broj'] as String?;
                if (naziv != null && naziv.isNotEmpty) {
                  map['adresa'] = naziv;
                } else if (ulica != null && ulica.isNotEmpty) {
                  map['adresa'] = '$ulica ${broj ?? ''}'.trim();
                }
              }
            }

            final mpId = map['registrovani_putnik_id']?.toString();
            final rowGrad = TextUtils.normalizeText(map['grad']?.toString() ?? ''); // ✅ Normalizuj grad
            final rowVreme = GradAdresaValidator.normalizeTime(map['vreme_polaska']?.toString() ?? '');
            if (mpId != null) {
              // Ključ: registrovani_putnik_id + grad + vreme (za slučaj više polazaka)
              final key = '${mpId}_${rowGrad}_$rowVreme';
              registrovaniOverrides[key] = map;
              print(
                  '📥 UČITAN OVERRIDE: ime=${map['putnik_ime']} key=$key status=${map['status']} adresa=${map['adresa']}');
            }
          }
        } catch (_) {
          // Ignorisi greške
        }

        // Query registrovani_putnici - uzmi aktivne mesečne putnike za ciljani dan
        final registrovani = await supabase
            .from('registrovani_putnici')
            .select(registrovaniFields)
            .eq('aktivan', true)
            .eq('obrisan', false);

        for (final m in registrovani) {
          // ✅ ISPRAVKA: Kreiraj putnike SAMO za ciljani dan kao u getAllPutniciFromBothTables
          final putniciZaDan = Putnik.fromRegistrovaniPutniciMultipleForDay(m, danKratica);
          for (final p in putniciZaDan) {
            print('📊 UČITAN MESEČNI PUTNIK: ${p.ime} grad=${p.grad} polazak=${p.polazak} adresa=${p.adresa}');
            // apply grad/vreme filter if provided
            final normVreme = GradAdresaValidator.normalizeTime(p.polazak);
            final normVremeFilter = vreme != null ? GradAdresaValidator.normalizeTime(vreme) : null;

            if (grad != null && p.grad != grad) {
              continue;
            }
            if (normVremeFilter != null && normVreme != normVremeFilter) {
              continue;
            }

            // 🔍 Proveri da li postoji override (otkazivanje/pokupljenje) za ovog mesečnog putnika
            final normGrad = TextUtils.normalizeText(p.grad); // ✅ Normalizuj grad za poređenje
            final overrideKey = '${p.id}_${normGrad}_$normVreme';
            print(
                '🔍 PROVERA OVERRIDE: ${p.ime} key=$overrideKey postoji=${registrovaniOverrides.containsKey(overrideKey)}');
            if (registrovaniOverrides.containsKey(overrideKey)) {
              // Zameni sa podacima iz putovanja_istorija (ima status otkazan, pokupljen itd.)
              final overrideData = registrovaniOverrides[overrideKey]!;
              final overridePutnik = Putnik.fromPutovanjaIstorija(overrideData);
              print(
                  '✅ PRIMENJEN OVERRIDE: ${overridePutnik.ime} status=${overridePutnik.status} jeOtkazan=${overridePutnik.jeOtkazan}');
              combined.add(overridePutnik);
            } else {
              combined.add(p);
            }
          }
        }

//         // print('📊 UKUPNO KOMBINOVANIH PUTNIKA: ${combined.length}');
        // for (final p in combined) {
//           // print('📊 FINALNI PUTNIK: ${p.ime} - ${p.grad} - ${p.polazak}');
        // }

        _lastValues[key] = combined; // Cache za replay
        if (!controller.isClosed) {
          controller.add(combined);
        }
      } catch (e) {
//         // print('❌ GREŠKA U doFetch: $e');
        _lastValues[key] = [];
        if (!controller.isClosed) {
          controller.add([]);
        }
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
  Future<String> _getTableForPutnik(dynamic id) async {
    try {
      // Pokušaj prvo putovanja_istorija (int ili string ID)
      final idStr = id.toString();
      final resp = await supabase.from('putovanja_istorija').select('id').eq('id', idStr).maybeSingle();
      if (resp != null) return 'putovanja_istorija';
    } catch (_) {
      // Greška pri upitu - nastavi sa proverom registrovani_putnici
    }
    // Ako nije pronađeno u putovanja_istorija vrati registrovani_putnici
    return 'registrovani_putnici';
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  Future<Putnik?> getPutnikByName(String imePutnika) async {
    try {
      // Prvo pokušaj iz registrovani_putnici
      final registrovaniResponse = await supabase
          .from('registrovani_putnici')
          .select(registrovaniFields)
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (registrovaniResponse != null) {
        return Putnik.fromRegistrovaniPutnici(registrovaniResponse);
      }

      // Ako nije u registrovani_putnici, pokušaj iz putovanja_istorija za danas
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum_putovanja', danas)
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

      // Ako nije u putovanja_istorija, pokušaj iz registrovani_putnici
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

  // 🆕 NOVI: Učitaj sve putnike iz obe tabele
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    List<Putnik> allPutnici = [];

    try {
      final targetDate = targetDay ?? _getTodayName();
      final datum = _parseDateFromDayName(targetDate);
      final danas = datum.toIso8601String().split('T')[0];

      // ✅ ISPRAVKA: Koristi istu logiku kao danas_screen - filtriraj po datum_putovanja koloni
      final dnevniResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('datum_putovanja', danas) // ✅ ISPRAVKA: Pravi naziv kolone
          .eq('tip_putnika', 'dnevni')
          .timeout(const Duration(seconds: 5));

      final List<Putnik> dnevniPutnici =
          dnevniResponse.map<Putnik>((item) => Putnik.fromPutovanjaIstorija(item)).where((putnik) {
        // 🔧 STANDARDIZACIJA: Koristi TextUtils.isStatusActive za konzistentnost
        final isValid = TextUtils.isStatusActive(putnik.status);
        return isValid;
      }).toList();

      allPutnici.addAll(dnevniPutnici);

      // 🗓️ CILJANI DAN: Učitaj mesečne putnike iz registrovani_putnici za selektovani dan
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
          if (tabela == 'registrovani_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'aktivan': true, // Vraća na aktivan umesto obrisan: false
            }).eq('id', lastAction.putnikId as String);
          } else {
            // putovanja_istorija - koristi novu 'status' kolonu
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'] ?? 'radi',
              'obrisan': false, // ✅ FIXED: Koristi obrisan umesto pokupljen
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno brisanje putnika';

        case 'pickup':
          if (tabela == 'registrovani_putnici') {
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
          if (tabela == 'registrovani_putnici') {
            await supabase.from(tabela).update({
              'cena': null, // ✅ RESETUJ cenu za mesecne putnike
              'vreme_placanja': null, // ✅ RESETUJ vreme placanja
              'vozac_id': null, // ✅ RESETUJ vozača kao UUID (uklanja i legacy)
            }).eq('id', lastAction.putnikId as String);
          } else {
            // ✅ FIXED: putovanja_istorija nema placeno/iznos_placanja/vreme_placanja kolone
            await supabase.from(tabela).update({
              'cena': 0, // ✅ Resetuj cenu
              'status': lastAction.oldData['status'] ?? 'radi', // ✅ RESETUJ status
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', lastAction.putnikId as String);
          }
          return 'Poništeno plaćanje';

        case 'cancel':
          if (tabela == 'registrovani_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
            }).eq('id', lastAction.putnikId as String);
          } else {
            // ✅ FIXED: putovanja_istorija nema 'vozac' kolonu - koristi samo status
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'] ?? 'radi',
              'updated_at': DateTime.now().toIso8601String(),
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
      polasciPoDanu[danKratica] = danPolasci;

      // Ažuriraj radni_dani ako dan nije već uključen
      String radniDani = registrovaniPutnik['radni_dani'] as String? ?? '';
      final radniDaniList = radniDani.split(',').map((d) => d.trim().toLowerCase()).where((d) => d.isNotEmpty).toList();
      if (!radniDaniList.contains(danKratica) && danKratica.isNotEmpty) {
        radniDaniList.add(danKratica);
        radniDani = radniDaniList.join(',');
      }

      // Ažuriraj mesečnog putnika u bazi
      // ✅ Konvertuj ime vozača u UUID za updated_by
      final updatedByUuid = VozacMappingService.getVozacUuidSync(putnik.dodaoVozac ?? '');

      // 🔧 Pripremi update mapu - updated_by samo ako postoji validan UUID
      final updateData = <String, dynamic>{
        'polasci_po_danu': polasciPoDanu,
        'radni_dani': radniDani,
        'updated_at': DateTime.now().toIso8601String(),
      };
      // Dodaj updated_by samo ako je validan UUID
      if (updatedByUuid != null && updatedByUuid.isNotEmpty) {
        updateData['updated_by'] = updatedByUuid;
      }

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
//       // print('🔄 POZIVAM RealtimeService.refreshNow()...');
      await RealtimeService.instance.refreshNow();

      // 🔄 DODATNO: Resetuj cache za sigurnost
//       // print('🗑️ BRIŠEM STREAM CACHE...');
      _streams.clear();

      // ⏳ KRATKA PAUZA da se obezbedi da je transakcija commitovana
//       // print('⏳ PAUZA ZBOG TRANSAKCIJE...');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 🔄 DODATNI REFRESH NAKON PAUZE
//       // print('🔄 DODATNI REFRESH NAKON PAUZE...');
      await RealtimeService.instance.refreshNow();

//       // print('✅ DODAVANJE PUTNIKA ZAVRŠENO USPEŠNO!');
    } catch (e) {
      rethrow;
    }
  }

  /// ✅ KOMBINOVANI STREAM - MESEČNI + DNEVNI PUTNICI (OPTIMIZOVANO, bez RxDart)
  /// 🚫 NAPOMENA: Svi putnici (radnik, ucenik, dnevni) su registrovani u registrovani_putnici tabeli
  Stream<List<Putnik>> streamKombinovaniPutnici() {
    final danasKratica = _getFilterDayAbbreviation(DateTime.now().weekday);

    // 🚀 OPTIMIZACIJA: Koristi RealtimeService singleton
    final registrovaniStream = RealtimeService.instance.tableStream('registrovani_putnici');
    final putovanjaStream = RealtimeService.instance.tableStream('putovanja_istorija');

    // Kombinuj stream-ove bez RxDart
    final controller = StreamController<List<Putnik>>.broadcast();
    List<dynamic>? lastRegistrovani;
    List<dynamic>? lastPutovanja;

    Future<void> emitCombined() async {
      if (lastRegistrovani == null || lastPutovanja == null) return;

      try {
        List<Putnik> sviPutnici = [];

        // 1. MESEČNI PUTNICI - UKLJUČI I OTKAZANE
        for (final item in lastRegistrovani!) {
          try {
            final radniDani = item['radni_dani']?.toString() ?? '';
            final daniList =
                radniDani.toLowerCase().split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();

            if (daniList.contains(danasKratica.toLowerCase())) {
              final registrovaniPutnici = Putnik.fromRegistrovaniPutniciMultipleForDay(
                item as Map<String, dynamic>,
                danasKratica,
              );
              sviPutnici.addAll(registrovaniPutnici);
            } else {}
          } catch (e) {
            // Silently ignore parsing errors
          }
        }

        // 🚫 UKLONJENO: Ad-hoc dnevni putnici više ne postoje
        // Svi putnici (radnik, ucenik, dnevni) su registrovani u registrovani_putnici tabeli

        // 2. DODATNO: Uključi specijalne "zakupljeno" zapise (ostavljamo postojeću metodu)
        try {
          final zakupljenoRows = await RegistrovaniPutnikService.getZakupljenoDanas();
          for (final item in zakupljenoRows) {
            try {
              final putnik = Putnik.fromPutovanjaIstorija(item);
              sviPutnici.add(putnik);
            } catch (e) {
              // Silently ignore
            }
          }
        } catch (e) {
          // Silently ignore
        }

        // ✅ SORTIRANJE: Otkazani na dno liste
        sviPutnici.sort((a, b) {
          if (a.jeOtkazan && !b.jeOtkazan) return 1;
          if (!a.jeOtkazan && b.jeOtkazan) return -1;
          return (b.vremeDodavanja ?? DateTime.now()).compareTo(a.vremeDodavanja ?? DateTime.now());
        });

        if (!controller.isClosed) {
          controller.add(sviPutnici);
        }
      } catch (e) {
        // Silently ignore
      }
    }

    // Slušaj oba stream-a
    final sub1 = registrovaniStream.listen((data) {
      lastRegistrovani = data is List ? data : <dynamic>[];
      emitCombined();
    });
    final sub2 = putovanjaStream.listen((data) {
      lastPutovanja = data is List ? data : <dynamic>[];
      emitCombined();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
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

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu
  Stream<List<Putnik>> streamregistrovaniPutnici(String grad) {
    return RealtimeService.instance.tableStream('registrovani_putnici').map((data) {
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

      final List<Putnik> registrovaniPutnici = uniquePutnici.values.toList();

      return registrovaniPutnici;
    });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu i danu
  Stream<List<Putnik>> streamregistrovaniPutniciPoGraduDanu(
    String grad,
    String dan,
  ) {
    return RealtimeService.instance.tableStream('registrovani_putnici').map((data) {
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
        // ✅ POBOLJŠANO: Tačno matchovanje dana umesto ==
        try {
          final radniDani = item['radni_dani']?.toString() ?? '';
          final daniList = radniDani.toLowerCase().split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();

          if (!daniList.contains(dan.toLowerCase())) continue;
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

      final List<Putnik> registrovaniPutnici = uniquePutnici.values.toList();

      return registrovaniPutnici;
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
    } else {
      // Za putovanja_istorija koristi action_log
      final vozacUuid = VozacMappingService.getVozacUuidSync(currentDriver) ?? currentDriver;
      final actionLog2 = ActionLog.fromDynamic(response['action_log']);
      final updatedActionLog2 = actionLog2.addAction(ActionType.picked, vozacUuid, 'Pokupljen');

      await supabase.from(tabela).update({
        'status': 'pokupljen',
        // vreme_pokupljenja ne postoji u putovanja_istorija - koristi se action_log
        'action_log': updatedActionLog2.toJson(), // ✅ FIXED: Ažuriraj action_log.picked_by
      }).eq('id', id as String);
    }

    // 📊 AUTOMATSKA SINHRONIZACIJA BROJA PUTOVANJA (NOVO za putovanja_istorija!)
    if (tabela == 'putovanja_istorija' && response['registrovani_putnik_id'] != null) {
      try {
        await RegistrovaniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
          response['registrovani_putnik_id'] as String,
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
    if (tabela == 'registrovani_putnici') {
      // Za mesečne putnike ažuriraj SVE potrebne kolone za plaćanje
      final now = DateTime.now();
      String? validVozacId = naplatioVozac.isEmpty ? null : VozacMappingService.getVozacUuidSync(naplatioVozac);

      // ✅ FIXED: Ažuriraj action_log.paid_by
      final actionLog = ActionLog.fromDynamic(undoPayment['action_log']);
      final updatedActionLog = actionLog.addAction(ActionType.paid, validVozacId ?? naplatioVozac, 'Plaćeno $iznos');

      await supabase.from(tabela).update({
        'cena': iznos, // ✅ CENA mesečne karte
        'vreme_placanja': now.toIso8601String(), // ✅ TIMESTAMP plaćanja
        'vozac_id': validVozacId, // ✅ FIXED: Samo UUID, null ako nema mapiranja
        'action_log': updatedActionLog.toJson(), // ✅ FIXED: Ažuriraj action_log.paid_by
        'updated_at': now.toIso8601String(), // ✅ AŽURIRAJ timestamp
      }).eq('id', id as String);
    } else {
      // Za putovanja_istorija koristi action_log
      String? validVozacId = naplatioVozac.isEmpty ? null : VozacMappingService.getVozacUuidSync(naplatioVozac);

      // ✅ FIXED: Ažuriraj action_log.paid_by
      final actionLog2 = ActionLog.fromDynamic(undoPayment['action_log']);
      final updatedActionLog2 = actionLog2.addAction(ActionType.paid, validVozacId ?? naplatioVozac, 'Plaćeno $iznos');

      await supabase.from(tabela).update({
        'cena': iznos,
        'vozac_id': validVozacId, // ✅ FIXED: Samo UUID, null ako nema mapiranja
        // ✅ FIXED: vreme_placanja NE POSTOJI u putovanja_istorija - koristi updated_at
        'updated_at': DateTime.now().toIso8601String(), // ✅ Koristi updated_at umesto vreme_placanja
        'action_log': updatedActionLog2.toJson(), // ✅ FIXED: Ažuriraj action_log.paid_by
        'status': 'placeno', // ✅ DODAJ STATUS plaćanja (konzistentno)
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
        // 🆕 NOVI PRISTUP: Za mesečne putnike kreiraj zapis u putovanja_istorija za konkretan dan
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final polazak = GradAdresaValidator.normalizeTime(selectedVreme ?? '5:00'); // Normalize vreme for overriding
        final grad = selectedGrad ?? 'Bela Crkva'; // Koristi proslijećeni grad ili default

        // Kreiraj zapis otkazivanja za današnji dan sa ActionLog
        final vozacUuid = await VozacMappingService.getVozacUuid(otkazaoVozac);
        final now = DateTime.now().toIso8601String();

        // ✅ FIX: Ručno kreiraj action_log kao Map (ne String) - isto kao u bazi
        final actionLogMap = {
          'created_by': vozacUuid,
          'paid_by': null,
          'picked_by': null,
          'cancelled_by': vozacUuid,
          'primary_driver': null,
          'created_at': now,
          'actions': [
            {
              'type': 'cancelled',
              'vozac_id': vozacUuid,
              'timestamp': now,
              'note': 'Otkazano',
            },
          ],
        };

        // ✅ FIX: Direktan insert bez SupabaseSafe wrappera
        // ✅ FIX: Izvuci adresu iz mesečnog putnika (koristi grad za određivanje koja adresa)
        String? adresa;
        String? adresaId;
        if (grad.toLowerCase().contains('bela')) {
          adresaId = respMap['adresa_bela_crkva_id'] as String?;
          // Pokušaj dohvatiti naziv adrese iz JOIN-a ako postoji
          final adresaBc = respMap['adresa_bc'] as Map<String, dynamic>?;
          adresa = adresaBc?['naziv'] as String? ?? respMap['adresa_bela_crkva'] as String?;
        } else {
          adresaId = respMap['adresa_vrsac_id'] as String?;
          final adresaVs = respMap['adresa_vs'] as Map<String, dynamic>?;
          adresa = adresaVs?['naziv'] as String? ?? respMap['adresa_vrsac'] as String?;
        }

        try {
          await supabase.from('putovanja_istorija').insert({
            'registrovani_putnik_id': id.toString(), // ✅ UUID kao string
            'putnik_ime': respMap['putnik_ime'],
            'tip_putnika': 'mesecni',
            'datum_putovanja': danas,
            'vreme_polaska': polazak,
            'grad': grad,
            // ✅ FIXED: 'adresa' TEXT kolona NE POSTOJI - koristi adresa_id i napomene
            'adresa_id': adresaId, // ✅ UUID reference u tabelu adrese
            'napomene': adresa != null ? 'Adresa: $adresa' : null, // ✅ Sačuvaj adresu u napomene
            'status': 'otkazan',
            'cena': 0,
            'vozac_id': null,
            'created_by': vozacUuid,
            'action_log': actionLogMap, // ✅ Kao Map, ne String
          });
        } catch (insertError) {
          rethrow;
        }
      } else {
        // Za putovanja_istorija koristi ActionLog
        final currentData = await supabase.from(tabela).select('action_log').eq('id', id.toString()).single();

        // ✅ FIXED: Sigurno parsiranje action_log
        final currentActionLog = ActionLog.fromDynamic(currentData['action_log']);
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

      // 📊 AUTOMATSKA SINHRONIZACIJA BROJA OTKAZIVANJA (NOVO!)
      if (tabela == 'putovanja_istorija' && (respMap['registrovani_putnik_id'] != null)) {
        try {
          await RegistrovaniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
            respMap['registrovani_putnik_id'] as String,
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
        .select('*, adrese(naziv, grad)')
        .eq('tip_putnika', 'dnevni')
        .eq('adrese.grad', grad) // ✅ PRAVO REŠENJE: koristi JOIN sa adrese tabelu
        .eq('vreme_polaska', vreme)
        .neq('status', 'otkazan') as List<dynamic>?;

    if (data == null) return [];
    return data.map((e) => Putnik.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// ✅ PROVERI DA LI POSTOJI DUPLIKAT DNEVNOG PUTNIKA SA ISTIM IMENOM/DATUMOM/VREMENOM
  Future<bool> existsDuplicatePutnik(Putnik putnik) async {
    try {
      // Koristi local map iz model da formiramo datum/vreme (da bude kompatibilno sa insert mapom)
      final baseMap = putnik.toPutovanjaIstorijaMap();
      final String datum = baseMap['datum_putovanja'] as String? ?? '';
      final String vreme = baseMap['vreme_polaska'] as String? ?? '';
      final String ime = baseMap['putnik_ime'] as String? ?? '';
      final String grad = baseMap['grad'] as String? ?? '';

      final response = await supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('tip_putnika', 'dnevni')
          .eq('putnik_ime', ime)
          .eq('datum_putovanja', datum)
          .eq('vreme_polaska', vreme)
          .eq('grad', grad)
          .neq('status', 'otkazan')
          .limit(1);

      final list = response as List<dynamic>?;
      if (list != null && list.isNotEmpty) return true;
      return false;
    } catch (e) {
      // Ako upit ne uspe, ne blokiramo dodavanje - samo ne možemo potvrditi duplikat
      return false;
    }
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

    final registrovaniData = await supabase
        .from('registrovani_putnici')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('aktivan', true)
        .gte('created_at', startOfYear.toIso8601String());

    final List<Putnik> voznje = [
      ...(dnevniData as List).map((e) => Putnik.fromMap(e as Map<String, dynamic>)),
      ...(registrovaniData as List).map(
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
      if (tabela == 'registrovani_putnici') {
        // ✅ DIREKTNO SETOVANJE STATUSA - zahteva ALTER constraint u bazi
        await supabase.from(tabela).update({
          'status': statusZaBazu, // 'bolovanje' ili 'godišnji'
          'aktivan': true, // Putnik ostaje aktivan, samo je na odsustvu
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', id as String);
      } else {
        // Za putovanja_istorija koristi 'status' kolonu
        await supabase.from(tabela).update({
          'status': statusZaBazu, // 'bolovanje' ili 'godišnji'
        }).eq('id', id as String);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 🔄 RESETUJ KARTICU U POČETNO STANJE (samo za validne vozače)
  Future<void> resetPutnikCard(String imePutnika, String currentDriver) async {
    try {
      if (currentDriver.isEmpty) {
        throw Exception('Funkcija zahteva specificiranje vozača');
      }

      final danas = DateTime.now().toIso8601String().split('T')[0];

      // 🔴 PRVO: Resetuj override zapise iz putovanja_istorija za danas (otkazivanja mesečnih)
      // Umesto DELETE koristimo UPDATE da postavimo status na 'resetovan' ili obrišemo soft-delete
      try {
        await supabase
            .from('putovanja_istorija')
            .update({
              'status': 'resetovan',
              'obrisan': true, // Soft delete
            })
            .eq('putnik_ime', imePutnika)
            .eq('datum_putovanja', danas)
            .eq('tip_putnika', 'mesecni');
      } catch (_) {
        // Ignore - možda nema zapisa
      }

      // Pokušaj reset u registrovani_putnici tabeli
      try {
        final registrovaniResponse =
            await supabase.from('registrovani_putnici').select().eq('putnik_ime', imePutnika).maybeSingle();

        if (registrovaniResponse != null) {
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

          // 📊 SINHRONIZUJ broj otkazivanja nakon reset-a (VAŽNO!)
          try {
            final putnikId = registrovaniResponse['id'] as String;
            await RegistrovaniPutnikService.sinhronizujBrojOtkazivanjaSaIstorijom(
              putnikId,
            );
            // 📊 TAKOĐE sinhronizuj broj putovanja (NOVO!)
            await RegistrovaniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
              putnikId,
            );
          } catch (syncError) {
            // Ignore sync errors
          }
          return;
        }
      } catch (e) {
        // Ako nema u registrovani_putnici, nastavi sa putovanja_istorija
      }

      // Pokušaj reset u putovanja_istorija tabeli (za DNEVNE putnike)
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum_putovanja', danas)
          .eq('tip_putnika', 'dnevni')
          .maybeSingle();

      if (putovanjaResponse != null) {
        // Reset action_log da ukloni cancelled_by
        final cleanActionLog = {
          'created_by': putovanjaResponse['created_by'],
          'paid_by': null,
          'picked_by': null,
          'cancelled_by': null, // ✅ UKLONI cancelled_by
          'primary_driver': null,
          'created_at': putovanjaResponse['created_at'],
          'actions': [], // ✅ OČISTI sve akcije
        };

        await supabase
            .from('putovanja_istorija')
            .update({
              'status': 'radi', // ✅ POČETNO STANJE
              'cena': 0, // ✅ VRATI cenu na 0
              'vozac_id': null, // ✅ UKLONI vozača
              'action_log': cleanActionLog, // ✅ RESET action_log
            })
            .eq('putnik_ime', imePutnika)
            .eq('datum_putovanja', danas)
            .eq('tip_putnika', 'dnevni');
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

      // Resetuj dnevne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final dnevniPutnici = await supabase
            .from('putovanja_istorija')
            .select(
              'id, putnik_ime, vreme_polaska',
            ) // UKLONITI vreme_akcije - kolona ne postoji
            .eq('datum_putovanja', danas)
            .eq('grad', grad)
            .eq('status', 'pokupljen');

        for (final putnik in dnevniPutnici) {
          // UKLONITI - vreme_akcije kolona ne postoji, koristi created_at ili updated_at
          // final vremeAkcije = DateTime.tryParse(putnik['vreme_akcije'] as String);
          // if (vremeAkcije == null) continue;

          // Jednostavno resetuj sve pokupljene putnike kada se menja vreme
          await supabase.from('putovanja_istorija').update({
            'status': 'radi',
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

      // 2. MESEČNA PLAĆANJA iz registrovani_putnici
      final mesecnaPlacanja = await supabase
          .from('registrovani_putnici')
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
  /// NAPOMENA: Ova metoda je zastarela jer koristimo action_log JSON umesto kolona
  Future<void> cleanupNevalidneVozace(String currentDriver) async {
    if (currentDriver.isEmpty) {
      throw Exception(
        'Cleanup zahteva specificiranje vozača.',
      );
    }

    // ✅ FIXED: Ne radimo cleanup jer kolone dodao_vozac ne postoje
    // Podaci se sada čuvaju u action_log.created_by JSON polju
  }

  /// 🔍 VALIDACIJA: Simplifikovana provera baze (bez validacije vozača)
  Future<Map<String, int>> proveriBazuZaNevalidneVozace() async {
    // Vraća praznu mapu jer ne radimo više sa validacijom vozača
    return <String, int>{
      'nevalidni_dodao': 0,
      'nevalidni_pokupio': 0,
      'nevalidni_naplatio': 0,
      'nevalidni_otkazao': 0,
      'nevalidni_registrovani_dodao': 0,
      'nevalidni_registrovani_naplatio': 0,
    };
  }

  /// 🔄 PREBACI PUTNIKA DRUGOM VOZAČU
  /// Ažurira `vozac_id` kolonu u registrovani_putnici tabeli (za mesečne putnike)
  /// ili `dodao_vozac` u putovanja_istorija tabeli (za dnevne putnike)
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

      // Proveri da li je mesečni putnik (UUID format) ili dnevni (int format)
      final isRegistrovani = putnikId.contains('-'); // UUID ima crtice

      if (isRegistrovani) {
        // 🎯 MESEČNI PUTNIK - ažuriraj vozac_id u registrovani_putnici
        await supabase.from('registrovani_putnici').update({
          'vozac_id': vozacUuid,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', putnikId);
      } else {
        // 📅 DNEVNI PUTNIK - ažuriraj vozac_id u putovanja_istorija (action_log.created_by)
        // Dohvati postojeći action_log i ažuriraj ga
        final current = await supabase.from('putovanja_istorija').select('action_log').eq('id', putnikId).single();
        final existingActionLog = current['action_log'];
        Map<String, dynamic> actionLogMap;
        if (existingActionLog != null) {
          actionLogMap = existingActionLog is String
              ? jsonDecode(existingActionLog) as Map<String, dynamic>
              : Map<String, dynamic>.from(existingActionLog as Map);
        } else {
          actionLogMap = {};
        }
        actionLogMap['created_by'] = vozacUuid;

        await supabase.from('putovanja_istorija').update({
          'vozac_id': vozacUuid,
          'action_log': actionLogMap,
        }).eq('id', putnikId);
      }

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
