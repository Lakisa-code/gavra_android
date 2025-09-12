import '../models/putnik.dart';
import '../models/mesecni_putnik.dart';
import '../utils/vozac_boja.dart'; // 🎯 DODANO za listu vozača
import 'package:flutter/foundation.dart'; // Za debug logovanje
import 'putnik_service.dart'; // 🔄 DODANO za real-time streams
import 'mesecni_putnik_service.dart'; // 🔄 DODANO za mesečne putnike
import 'dart:async';
import 'dart:math'; // 🚗 DODANO za kilometražu kalkulacije
import 'package:async/async.dart'; // Za StreamZip
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚗 DODANO za GPS podatke
import 'package:intl/intl.dart'; // Za DateFormat
import 'package:rxdart/rxdart.dart'; // 🔧 DODANO za share() metodu

class StatistikaService {
  // Singleton pattern
  static StatistikaService? _instance;
  static StatistikaService get instance =>
      _instance ??= StatistikaService._internal();

  StatistikaService._internal(); // Private constructor

  // Instance cache za stream-ove da izbegnemo duplo kreiranje
  final Map<String, Stream<Map<String, double>>> _streamCache = {};

  // 🎯 CENTRALIZOVANA LISTA VOZAČA
  static List<String> get sviVozaci => VozacBoja.boje.keys.toList();

  // 🕐 TIMEZONE STANDARDIZACIJA - Koristimo lokalno vreme
  static DateTime _normalizeDateTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour,
        dateTime.minute, dateTime.second);
  }

  // 📊 DEBUG LOGOVANJE
  static void _debugLog(String message) {
    if (kDebugMode) {
      print('💰 [STATISTIKA] $message');
    }
  }

  /// 💰 JEDINSTVENA LOGIKA ZA RAČUNANJE PAZARA - koristi se svuda!
  static bool _jePazarValjan(Putnik putnik, {bool logDetails = false}) {
    // Osnovni uslovi za validno računanje pazara
    final imaIznos = putnik.iznosPlacanja != null && putnik.iznosPlacanja! > 0;
    final imaVozaca =
        putnik.naplatioVozac != null && putnik.naplatioVozac!.isNotEmpty;
    final nijeOtkazan = !putnik.jeOtkazan;
    final isValid = imaIznos && imaVozaca && nijeOtkazan;

    if (logDetails) {
      _debugLog(
          'Validacija putnika ${putnik.ime}: iznos=$imaIznos, vozac=$imaVozaca, otkazan=${!nijeOtkazan} => valid=$isValid');
    }

    return isValid;
  }

  /// 🕐 STANDARDIZOVANO FILTRIRANJE PO VREMENSKOM OPSEGU
  static bool _jeUVremenskomOpsegu(
      DateTime? dateTime, DateTime from, DateTime to) {
    if (dateTime == null) return false;
    final normalized = _normalizeDateTime(dateTime);
    final normalizedFrom = _normalizeDateTime(from);
    final normalizedTo = _normalizeDateTime(to);

    return normalized
            .isAfter(normalizedFrom.subtract(const Duration(seconds: 1))) &&
        normalized.isBefore(normalizedTo.add(const Duration(days: 1)));
  }

  /// 💰 PAZAR ZA ODREĐENOG VOZAČA - KORISTI VREMENSKI OPSEG
  static Future<double> pazarZaVozaca(List<Putnik> putnici, String vozac,
      {DateTime? from, DateTime? to}) async {
    // Ako nisu prosleđeni parametri, koristi današnji dan
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    _debugLog(
        '🔍 POZVAN pazarZaVozaca za $vozac sa ${putnici.length} putnika od ${fromDate.toString().split(' ')[0]} do ${toDate.toString().split(' ')[0]}');

    return _calculatePazarSync(putnici, vozac, fromDate, toDate);
  }

  /// 🔄 REAL-TIME PAZAR STREAM ZA ODREĐENOG VOZAČA (uključuje mesečne karte)
  static Stream<double> streamPazarZaVozaca(String vozac,
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // 🔄 KORISTI KOMBINOVANE STREAMOVE (obični + mesečni putnici)
    return instance
        ._combineStreams(
            PutnikService().streamPutnici(),
            MesecniPutnikService.streamAktivniMesecniPutnici(),
            fromDate,
            toDate)
        .map((pazarMap) {
      return pazarMap[vozac] ?? 0.0;
    });
  }

  /// 🎫 STREAM BROJ MESEČNIH KARATA ZA ODREĐENOG VOZAČA
  static Stream<int> streamBrojMesecnihKarataZaVozaca(String vozac,
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    return MesecniPutnikService.streamAktivniMesecniPutnici()
        .map((mesecniPutnici) {
      int brojKarata = 0;
      for (final putnik in mesecniPutnici) {
        if (putnik.jePlacen &&
            putnik.vozac == vozac &&
            putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          brojKarata++;
        }
      }
      return brojKarata;
    });
  }

  /// 🔄 SINHRONA KALKULACIJA PAZARA (za stream)
  static double _calculatePazarSync(
      List<Putnik> putnici, String vozac, DateTime fromDate, DateTime toDate) {
    // 1. PAZAR OD OBIČNIH PUTNIKA
    final filteredPutnici = putnici.where((putnik) {
      if (!_jePazarValjan(putnik)) return false;
      if (putnik.vremePlacanja == null) return false;
      if (putnik.naplatioVozac != vozac) return false;

      return _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate);
    }).toList();

    double ukupnoObicni = filteredPutnici.fold<double>(
        0.0, (sum, putnik) => sum + (putnik.iznosPlacanja ?? 0.0));

    _debugLog(
        'Obični putnici za $vozac: ${filteredPutnici.length} putnika = ${ukupnoObicni.toStringAsFixed(0)} RSD'); // 2. STVARNI PAZAR OD MESEČNIH KARATA
    double ukupnoMesecne = 0.0;
    try {
      // Sinhrono računanje za stream - koristimo podatke iz putnici koji su mesečni
      final mesecniPutnici = putnici.where((putnik) {
        if (putnik.mesecnaKarta != true) return false;
        if (putnik.iznosPlacanja == null || putnik.iznosPlacanja! <= 0) {
          return false;
        }
        if (putnik.naplatioVozac != vozac) return false;
        if (putnik.vremePlacanja == null) return false;

        return _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate);
      }).toList();

      ukupnoMesecne = mesecniPutnici.fold<double>(
          0.0, (sum, putnik) => sum + (putnik.iznosPlacanja ?? 0.0));

      _debugLog(
          'Mesečni putnici za $vozac: ${mesecniPutnici.length} plaćenih = ${ukupnoMesecne.toStringAsFixed(0)} RSD');
    } catch (e) {
      _debugLog('Greška pri učitavanju mesečnih karata: $e');
    }

    final ukupno = ukupnoObicni + ukupnoMesecne;
    _debugLog('REAL-TIME PAZAR za $vozac: ${ukupno.toStringAsFixed(0)} RSD');
    return ukupno;
  }

  /// 📊 KOMBINOVANI REAL-TIME PAZAR STREAM (obični + mesečni putnici)
  static Stream<Map<String, double>> streamKombinovanPazarSvihVozaca(
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Kombinuj oba stream-a koristeći async*
    return instance._combineStreams(PutnikService().streamPutnici(),
        MesecniPutnikService.streamAktivniMesecniPutnici(), fromDate, toDate);
  }

  /// 🔄 POMOĆNA FUNKCIJA ZA KOMBINOVANJE STREAM-OVA
  Stream<Map<String, double>> _combineStreams(
      Stream<List<Putnik>> putnicStream,
      Stream<List<MesecniPutnik>> mesecniStream,
      DateTime fromDate,
      DateTime toDate) async* {
    _debugLog(
        '🔄 COMBINE STREAMS pozvan sa datumima: ${DateFormat('dd.MM.yyyy HH:mm').format(fromDate)} - ${DateFormat('dd.MM.yyyy HH:mm').format(toDate)}');

    List<Putnik> posledniPutnici = [];
    List<MesecniPutnik> posledniMesecni = [];
    Map<String, double>? posledniRezultat;

    // Kombiniraj oba stream-a koristeći StreamGroup
    await for (final kombinovani in StreamGroup.merge([
      putnicStream.map((putnici) => {'putnici': putnici}),
      mesecniStream.map((mesecni) => {'mesecni': mesecni}),
    ])) {
      // Ažuriraj odgovarajuću listu
      if (kombinovani.containsKey('putnici')) {
        posledniPutnici = kombinovani['putnici'] as List<Putnik>;
      }
      if (kombinovani.containsKey('mesecni')) {
        posledniMesecni = kombinovani['mesecni'] as List<MesecniPutnik>;
      }

      // Izračunaj novi rezultat
      final noviRezultat = _calculateKombinovanPazarSync(
          posledniPutnici, posledniMesecni, fromDate, toDate);

      // 🚫 DEDUPLICATION: Emituj samo ako se rezultat stvarno promenio
      if (posledniRezultat == null ||
          !_rezultatiJednaki(posledniRezultat, noviRezultat)) {
        // 🔧 FIXED: Saberi SAMO vozače, ne i ukupne vrednosti (_ukupno, _ukupno_obicni, _ukupno_mesecni)
        final ukupanPazar = noviRezultat.entries
            .where((entry) => !entry.key.startsWith('_'))
            .fold<double>(0.0, (sum, entry) => sum + entry.value);
        _debugLog(
            '🔄 COMBINE STREAMS emituje NOVI rezultat: ${ukupanPazar.toStringAsFixed(0)} RSD');

        posledniRezultat = Map.from(noviRezultat);
        yield noviRezultat;
      } else {
        _debugLog('🚫 COMBINE STREAMS preskače duplikat - rezultat je isti');
      }
    }
  }

  /// 🔍 HELPER FUNKCIJA ZA POREĐENJE REZULTATA
  static bool _rezultatiJednaki(
      Map<String, double> stari, Map<String, double> novi) {
    if (stari.length != novi.length) return false;

    for (final entry in stari.entries) {
      if (!novi.containsKey(entry.key)) return false;
      if ((novi[entry.key]! - entry.value).abs() > 0.01)
        return false; // 1 cent tolerancija
    }
    return true;
  }

  /// 🔄 PUBLIC SINHRONA KALKULACIJA KOMBINOVANOG PAZARA (za external usage)
  static Map<String, double> calculateKombinovanPazarSync(List<Putnik> putnici,
      List<MesecniPutnik> mesecniPutnici, DateTime fromDate, DateTime toDate) {
    return _calculateKombinovanPazarSync(
        putnici, mesecniPutnici, fromDate, toDate);
  }

  /// 🔄 SINHRONA KALKULACIJA KOMBINOVANOG PAZARA (obični + mesečni)
  static Map<String, double> _calculateKombinovanPazarSync(List<Putnik> putnici,
      List<MesecniPutnik> mesecniPutnici, DateTime fromDate, DateTime toDate) {
    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA - RESETUJ SVE!
    final Map<String, double> pazarObicni = {};
    final Map<String, double> pazarMesecne = {};
    for (final vozac in sviVozaci) {
      pazarObicni[vozac] = 0.0; // 🔧 RESETUJ NA 0!
      pazarMesecne[vozac] = 0.0; // 🔧 RESETUJ NA 0!
    }

    // 1. SABERI OBIČNI PAZAR iz putnici tabele - ISKLJUČI MESEČNE KARTE
    for (final putnik in putnici) {
      // 🛑 PRESKAČI MESEČNE KARTE - one se računaju odvojeno iz MesecniPutnikService
      if (putnik.mesecnaKarta == true) {
        _debugLog(
            '⏭️ PRESKAČEM mesečni putnik iz PutnikService: ${putnik.ime}');
        continue;
      }

      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          final vozac = putnik.naplatioVozac!;
          if (pazarObicni.containsKey(vozac)) {
            pazarObicni[vozac] = pazarObicni[vozac]! + putnik.iznosPlacanja!;
          }
        }
      }
    }

    // 2. SABERI MESEČNE KARTE - KORISTI vremePlacanja (kad je plaćeno) umesto placeniMesec
    _debugLog(
        '🔍 PAZAR DEBUG: Procesuiram ${mesecniPutnici.length} mesečnih putnika');

    // 💡 GRUPIRAJ MESEČNE PUTNIKE PO ID DA SE IZBEGNE DUPLO RAČUNANJE
    final Map<String, MesecniPutnik> uniqueMesecni = {};
    for (final putnik in mesecniPutnici) {
      uniqueMesecni[putnik.id] = putnik;
    }

    _debugLog(
        '🔄 PAZAR: ${mesecniPutnici.length} polazaka -> ${uniqueMesecni.length} jedinstvenih mesečnih putnika');

    for (final putnik in uniqueMesecni.values) {
      _debugLog(
          '🔍 MESEČNI PUTNIK: ${putnik.putnikIme}, aktivan: ${putnik.aktivan}, obrisan: ${putnik.obrisan}, jePlacen: ${putnik.jePlacen}');

      if (putnik.aktivan && !putnik.obrisan && putnik.jePlacen) {
        // 💰 NOVA LOGIKA: Proveravamo da li je DANAS plaćeno (vremePlacanja), ne za koji mesec
        if (putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          final vozac = putnik.vozac ?? 'Nepoznat';
          final iznos = putnik.iznosPlacanja ?? 0.0;

          _debugLog(
              '✅ DODAJEM MESEČNI PAZAR: ${putnik.putnikIme} -> $vozac, iznos: $iznos RSD (plaćeno: ${putnik.vremePlacanja})');

          if (pazarMesecne.containsKey(vozac)) {
            pazarMesecne[vozac] = pazarMesecne[vozac]! + iznos;
          }
        } else {
          _debugLog(
              '❌ MESEČNI PUTNIK ${putnik.putnikIme} NIJE PLAĆEN DANAS (vremePlacanja: ${putnik.vremePlacanja})');
        }
      } else {
        _debugLog(
            '❌ MESEČNI PUTNIK ${putnik.putnikIme} NE ISPUNJAVA USLOVE (aktivan: ${putnik.aktivan}, obrisan: ${putnik.obrisan}, jePlacen: ${putnik.jePlacen})');
      }
    }

    // 3. SABERI UKUPNO I VRATI REZULTAT
    final Map<String, double> rezultat = {};
    double ukupno = 0.0;

    for (final vozac in sviVozaci) {
      final ukupnoVozac = pazarObicni[vozac]! + pazarMesecne[vozac]!;
      rezultat[vozac] = ukupnoVozac;
      ukupno += ukupnoVozac;

      // 📊 DEBUG LOGOVANJE PO VOZAČIMA
      if (ukupnoVozac > 0) {
        _debugLog('💰 VOZAČ $vozac: ${ukupnoVozac.toStringAsFixed(0)} RSD');
      }
    }

    // Dodaj ukupan pazar
    rezultat['_ukupno'] = ukupno;
    rezultat['_ukupno_obicni'] = pazarObicni.values.fold(0.0, (a, b) => a + b);
    rezultat['_ukupno_mesecni'] =
        pazarMesecne.values.fold(0.0, (a, b) => a + b);

    _debugLog('🏆 UKUPAN PAZAR DANAS: ${ukupno.toStringAsFixed(0)} RSD');

    return rezultat;
  }

  ///  REAL-TIME PAZAR STREAM ZA SVE VOZAČE (samo obični putnici)
  static Stream<Map<String, double>> streamPazarSvihVozaca(
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    _debugLog(
        '🔍 STREAM PAZAR POZIV: od ${DateFormat('dd.MM.yyyy HH:mm').format(fromDate)} do ${DateFormat('dd.MM.yyyy HH:mm').format(toDate)}');

    // Kreiraj ključ za cache
    final cacheKey =
        '${fromDate.millisecondsSinceEpoch}-${toDate.millisecondsSinceEpoch}';

    // Koristi singleton instancu da proveri cache
    return instance._getOrCreateStream(cacheKey, fromDate, toDate);
  }

  // Instance metoda za kreiranje i cache-ovanje stream-a
  Stream<Map<String, double>> _getOrCreateStream(
      String cacheKey, DateTime fromDate, DateTime toDate) {
    if (!_streamCache.containsKey(cacheKey)) {
      _debugLog('🆕 KREIRANJE NOVOG STREAM-A za ključ: $cacheKey');
      _streamCache[cacheKey] = _combineStreams(
              PutnikService().streamPutnici(),
              MesecniPutnikService.streamAktivniMesecniPutnici(),
              fromDate,
              toDate)
          .share(); // 🔧 SHARE STREAM da sprečimo duplu subscription!
    } else {
      _debugLog('♻️ KORIŠTENJE POSTOJEĆEG STREAM-A za ključ: $cacheKey');
    }

    return _streamCache[cacheKey]!;
  }

  // Metoda za čišćenje cache-a (korisno za testiranje ili promenu datuma)
  static void clearStreamCache() {
    instance._streamCache.clear();
    _debugLog('🧹 STREAM CACHE OČIŠĆEN');
  }

  /// �💰 PAZAR PO SVIM VOZAČIMA - KORISTI VREMENSKI OPSEG
  static Future<Map<String, double>> pazarSvihVozaca(List<Putnik> putnici,
      {DateTime? from, DateTime? to}) async {
    // Ako nisu prosleđeni parametri, koristi današnji dan
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    _debugLog(
        'Računam pazar za sve vozače od ${fromDate.toString().split(' ')[0]} do ${toDate.toString().split(' ')[0]}');
    _debugLog('Ukupno putnika za analizu: ${putnici.length}');

    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA
    final Map<String, double> pazarObicni = {};
    final Map<String, double> pazarMesecne = {};
    for (final vozac in sviVozaci) {
      pazarObicni[vozac] = 0.0;
      pazarMesecne[vozac] = 0.0;
    }

    // 1. SABERI OBIČNI PAZAR iz putnici tabele
    int brojObicnihPutnika = 0;
    for (final putnik in putnici) {
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          final vozac = putnik.naplatioVozac!;
          if (pazarObicni.containsKey(vozac)) {
            pazarObicni[vozac] = pazarObicni[vozac]! + putnik.iznosPlacanja!;
            brojObicnihPutnika++;
            _debugLog(
                '✅ Dodao pazar: ${putnik.ime} (${putnik.iznosPlacanja}) -> $vozac na dan ${putnik.vremePlacanja?.toString().split(' ')[0]}');
          }
        } else {
          _debugLog(
              '❌ Putnik ${putnik.ime} van opsega: ${putnik.vremePlacanja?.toString().split(' ')[0]}');
        }
      }
    }

    _debugLog('Procesuirano $brojObicnihPutnika putnika');

    // 2. SABERI MESEČNE KARTE - STVARNI PODACI
    int brojMesecnihKarata = 0;
    try {
      // Učitaj sve mesečne putnike
      final mesecniPutnici =
          await MesecniPutnikService.getAktivniMesecniPutnici();

      for (final putnik in mesecniPutnici) {
        // Proveri da li je putnik platio u ovom periodu
        if (putnik.vremePlacanja != null &&
            putnik.cena != null &&
            putnik.cena! > 0 &&
            putnik.vozac != null &&
            putnik.vozac!.isNotEmpty) {
          if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
            final vozac = putnik.vozac!;
            if (pazarMesecne.containsKey(vozac)) {
              pazarMesecne[vozac] = pazarMesecne[vozac]! + putnik.cena!;
              brojMesecnihKarata++;
              _debugLog(
                  '✅ Dodao mesečnu kartu: ${putnik.putnikIme} (${putnik.cena}) -> $vozac na dan ${putnik.vremePlacanja?.toString().split(' ')[0]}');
            }
          }
        }
      }
    } catch (e) {
      _debugLog('Greška pri učitavanju mesečnih putnika: $e');
    }

    _debugLog('Procesuirano $brojMesecnihKarata mesečnih karata');

    // 3. SABERI UKUPNO I KREIRAJ FINALNI MAP
    final Map<String, double> ukupnoPazar = {};
    double ukupno = 0.0;

    for (final vozac in sviVozaci) {
      final obicni = pazarObicni[vozac] ?? 0.0;
      final mesecne = pazarMesecne[vozac] ?? 0.0;
      final ukupnoVozac = obicni + mesecne;

      ukupnoPazar[vozac] = ukupnoVozac;
      ukupno += ukupnoVozac;

      if (ukupnoVozac > 0) {
        _debugLog('$vozac: ${ukupnoVozac.toStringAsFixed(0)} RSD');
      }
    }

    _debugLog('UKUPAN PAZAR SVIH VOZAČA: ${ukupno.toStringAsFixed(0)} RSD');

    return {...ukupnoPazar, '_ukupno': ukupno};
  }

  /// Vraca detaljne statistike po vozacu - STVARNI MESEČNI PUTNICI
  static Future<Map<String, Map<String, dynamic>>> detaljneStatistikePoVozacima(
      List<Putnik> putnici, DateTime from, DateTime to) async {
    final normalizedFrom = _normalizeDateTime(from);
    final normalizedTo = _normalizeDateTime(to);

    _debugLog(
        '🔍 DETALJNE STATISTIKE: Računam od ${normalizedFrom.toString().split(' ')[0]} do ${normalizedTo.toString().split(' ')[0]}');
    _debugLog('🔍 DETALJNE STATISTIKE: Ukupno putnika: ${putnici.length}');

    final Map<String, Map<String, dynamic>> vozaciStats = {};

    // UČITAJ STVARNE MESEČNE PUTNIKE
    final mesecniPutnici = await MesecniPutnikService.getAllMesecniPutnici();

    // 🎯 INICIJALIZUJ SVE VOZAČE SA NULAMA - DODANA POLJA ZA MESEČNE KARTE
    for (final vozac in sviVozaci) {
      vozaciStats[vozac] = {
        'dodati': 0,
        'otkazani': 0,
        'naplaceni': 0, // SAMO obični putnici
        'pokupljeni': 0,
        'dugovi': 0, // 🆕 BROJ dugova (pokupljen ali nije plaćen)
        'ukupnoPazar': 0.0, // obični + mesečne karte
        'mesecneKarte': 0, // 🆕 BROJ mesečnih karata
        'pazarMesecne': 0.0, // 🆕 PAZAR od mesečnih karata
        'pazarObicni': 0.0, // 🆕 PAZAR od običnih putnika
        'kilometraza': 0.0, // 🚗 KILOMETRAŽA za taj dan
      };
    }

    int ukupnoProcessiranihPutnika = 0;

    for (final putnik in putnici) {
      // Proverava da li je putnik u datom periodu (po vremenu dodavanja)
      if (putnik.vremeDodavanja != null &&
          _jeUVremenskomOpsegu(
              putnik.vremeDodavanja, normalizedFrom, normalizedTo)) {
        ukupnoProcessiranihPutnika++;

        // 1. DODATI PUTNICI - ko je DODAO
        final dodaoVozac = putnik.dodaoVozac ?? 'Nepoznat';
        if (vozaciStats.containsKey(dodaoVozac)) {
          vozaciStats[dodaoVozac]!['dodati']++;
        }

        // 2. OTKAZANI - ko je OTKAZAO (ili ko je dodao ako nema otkazaoVozac)
        if (putnik.jeOtkazan) {
          final otkazaoVozac =
              putnik.otkazaoVozac ?? putnik.dodaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(otkazaoVozac)) {
            vozaciStats[otkazaoVozac]!['otkazani']++;
          }
        }

        // 3. POKUPLJENI - ko je POKUPIOVOZAC
        if (putnik.jePokupljen) {
          final pokupioVozac = putnik.pokupioVozac;
          if (pokupioVozac != null && vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['pokupljeni']++;
          }
        }

        // 🆕 DUGOVI - pokupljen ali nije plaćen, nije otkazan, nije mesečni
        if (putnik.jePokupljen &&
            !putnik.jeOtkazan &&
            putnik.mesecnaKarta != true &&
            (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0)) {
          final pokupioVozac = putnik.pokupioVozac;
          if (pokupioVozac != null && vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['dugovi']++;
          }
        }
      }

      // 4. NAPLAĆENI I PAZAR - ko je NAPLATIO (po vremenu plaćanja) - SAMO OBIČNI PUTNICI
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        // 🎯 ISKLJUČI MESEČNE PUTNIKE - isti kao u _calculateKombinovanPazarSync
        if (putnik.mesecnaKarta == true) continue;

        // Proveri da li je plaćen u datom periodu
        if (_jeUVremenskomOpsegu(
            putnik.vremePlacanja, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.naplatioVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(naplatioVozac)) {
            vozaciStats[naplatioVozac]!['naplaceni']++;
            vozaciStats[naplatioVozac]!['pazarObicni'] += putnik.iznosPlacanja!;
            vozaciStats[naplatioVozac]!['ukupnoPazar'] += putnik.iznosPlacanja!;
          }
        }
      }
    }

    _debugLog('Procesuirano $ukupnoProcessiranihPutnika putnika');

    // 🆕 DODAJ MESEČNE PUTNICE - KORISTI STVARNE PODATKE (GRUPE PO ID)
    int ukupnoMesecnihKarata = 0;

    // 💡 GRUPIRAJ MESEČNE PUTNIKE PO ID - jedan mesečni putnik može imati više polazaka,
    // ali treba se računati samo jednom u statistike
    final Map<String, MesecniPutnik> uniqueMesecniPutnici = {};
    for (final putnik in mesecniPutnici) {
      uniqueMesecniPutnici[putnik.id] = putnik;
    }

    _debugLog(
        '🔄 MESEČNI PUTNICI: ${mesecniPutnici.length} polazaka -> ${uniqueMesecniPutnici.length} jedinstvenih putnika');

    for (final putnik in uniqueMesecniPutnici.values) {
      if (putnik.jePlacen) {
        // ✅ UNIFIKOVANA LOGIKA: koristi vremePlacanja umesto updatedAt
        // Proveri da li je mesečna karta plaćena u datom periodu
        if (putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(
                putnik.vremePlacanja, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.vozac ??
              'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
          if (vozaciStats.containsKey(naplatioVozac)) {
            // ✅ MESEČNE KARTE SE DODAJU RAZDVOJENO
            vozaciStats[naplatioVozac]!['mesecneKarte']++;
            // ✅ DODANO: mesečne karte se TAKOĐER računaju u 'naplaceni' - ukupan broj naplaćenih
            vozaciStats[naplatioVozac]!['naplaceni']++;
            vozaciStats[naplatioVozac]!['pazarMesecne'] +=
                (putnik.iznosPlacanja ?? 0.0);
            vozaciStats[naplatioVozac]!['ukupnoPazar'] +=
                (putnik.iznosPlacanja ?? 0.0);
            ukupnoMesecnihKarata++;

            _debugLog(
                '✅ DODAO JEDINSTVENU MESEČNU KARTU: ${putnik.putnikIme} (${putnik.iznosPlacanja} RSD) -> $naplatioVozac');
          }
        }
      }
    }

    _debugLog('Procesuirano $ukupnoMesecnihKarata mesečnih karata');

    // 🚗 DODAJ KILOMETRAŽU ZA SVE VOZAČE
    await _dodajKilometrazu(vozaciStats, normalizedFrom, normalizedTo);

    // Debug prikaz rezultata
    double ukupanPazar = 0;
    for (final vozac in sviVozaci) {
      final stats = vozaciStats[vozac]!;
      ukupanPazar += stats['ukupnoPazar'];
      if (stats['ukupnoPazar'] > 0 || stats['dodati'] > 0) {
        _debugLog(
            '$vozac: ${stats['ukupnoPazar'].toStringAsFixed(0)} RSD | putnici: ${stats['naplaceni']}, mesečne: ${stats['mesecneKarte']}');
      }
    }
    _debugLog(
        '🔥 DETALJNE STATISTIKE UKUPAN PAZAR: ${ukupanPazar.toStringAsFixed(0)} RSD (${DateFormat('dd.MM.yyyy').format(from)} - ${DateFormat('dd.MM.yyyy').format(to)})');

    return vozaciStats;
  }

  /// 🔄 REAL-TIME DETALJNE STATISTIKE STREAM ZA SVE VOZAČE
  static Stream<Map<String, Map<String, dynamic>>>
      streamDetaljneStatistikePoVozacima(DateTime from, DateTime to) {
    // Koristi kombinovani stream (putnici + mesečni putnici)
    return StreamZip([
      PutnikService().streamPutnici(),
      MesecniPutnikService.streamAktivniMesecniPutnici(),
    ]).map((data) {
      final putnici = data[0] as List<Putnik>;
      final mesecniPutnici = data[1] as List<MesecniPutnik>;
      return _calculateDetaljneStatistikeSinhronno(
          putnici, mesecniPutnici, from, to);
    });
  }

  /// 🔄 PUBLIC SINHRONA KALKULACIJA DETALJNIH STATISTIKA (za external usage)
  static Map<String, Map<String, dynamic>> calculateDetaljneStatistikeSinhronno(
      List<Putnik> putnici,
      List<MesecniPutnik> mesecniPutnici,
      DateTime from,
      DateTime to) {
    return _calculateDetaljneStatistikeSinhronno(
        putnici, mesecniPutnici, from, to);
  }

  /// 🔄 SINHRONA KALKULACIJA DETALJNIH STATISTIKA (za stream)
  static Map<String, Map<String, dynamic>>
      _calculateDetaljneStatistikeSinhronno(List<Putnik> putnici,
          List<MesecniPutnik> mesecniPutnici, DateTime from, DateTime to) {
    final normalizedFrom = _normalizeDateTime(from);
    final normalizedTo = _normalizeDateTime(to);

    final Map<String, Map<String, dynamic>> vozaciStats = {};

    // 🎯 INICIJALIZUJ SVE VOZAČE SA NULAMA - DODANA POLJA ZA MESEČNE KARTE
    for (final vozac in sviVozaci) {
      vozaciStats[vozac] = {
        'dodati': 0,
        'otkazani': 0,
        'naplaceni': 0, // SAMO obični putnici
        'pokupljeni': 0,
        'dugovi': 0, // 🆕 BROJ dugova (pokupljen ali nije plaćen)
        'ukupnoPazar': 0.0, // obični + mesečne karte
        'mesecneKarte': 0, // 🆕 BROJ mesečnih karata
        'pazarObicni': 0.0, // 🆕 PAZAR samo od običnih putnika
        'pazarMesecne': 0.0, // 🆕 PAZAR samo od mesečnih karata
        'kilometraza': 0.0, // 🚗 KILOMETRAŽA za taj dan
      };
    }

    // PROCESUIRAJ OBIČNE PUTNIKE
    int ukupnoProcessiranihPutnika = 0;
    for (final putnik in putnici) {
      if (putnik.vremeDodavanja != null) {
        if (_jeUVremenskomOpsegu(
            putnik.vremeDodavanja, normalizedFrom, normalizedTo)) {
          final dodaoVozac = putnik.dodaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(dodaoVozac)) {
            vozaciStats[dodaoVozac]!['dodati']++;
            ukupnoProcessiranihPutnika++;
          }
        }
      }

      // Proveri da li je otkazan u datom periodu
      if (putnik.jeOtkazan && putnik.vremeOtkazivanja != null) {
        if (_jeUVremenskomOpsegu(
            putnik.vremeOtkazivanja, normalizedFrom, normalizedTo)) {
          final otkazaoVozac = putnik.otkazaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(otkazaoVozac)) {
            vozaciStats[otkazaoVozac]!['otkazani']++;
          }
        }
      }

      // Proveri da li je naplaćen u datom periodu
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(
            putnik.vremePlacanja, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.naplatioVozac!;
          if (vozaciStats.containsKey(naplatioVozac)) {
            vozaciStats[naplatioVozac]!['naplaceni']++;
            vozaciStats[naplatioVozac]!['pazarObicni'] += putnik.iznosPlacanja!;
            vozaciStats[naplatioVozac]!['ukupnoPazar'] += putnik.iznosPlacanja!;
          }
        }
      }

      // Proveri da li je pokupljen u datom periodu
      if (putnik.vremePokupljenja != null) {
        if (_jeUVremenskomOpsegu(
            putnik.vremePokupljenja, normalizedFrom, normalizedTo)) {
          final pokupioVozac = putnik.pokupioVozac;
          if (pokupioVozac != null && vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['pokupljeni']++;
          }
        }
      }

      // 🆕 DUGOVI (SINHRONO) - pokupljen ali nije plaćen, nije otkazan, nije mesečni
      if (putnik.jePokupljen &&
          !putnik.jeOtkazan &&
          putnik.mesecnaKarta != true &&
          (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0)) {
        if (putnik.vremePokupljenja != null) {
          if (_jeUVremenskomOpsegu(
              putnik.vremePokupljenja, normalizedFrom, normalizedTo)) {
            final pokupioVozac = putnik.dodaoVozac ?? 'Nepoznat';
            if (vozaciStats.containsKey(pokupioVozac)) {
              vozaciStats[pokupioVozac]!['dugovi']++;
            }
          }
        }
      }
    }

    // 🆕 DODAJ MESEČNE KARTE - KORISTI STVARNE PODATKE (SINHRONO)
    int ukupnoMesecnihKarata = 0;
    for (final putnik in mesecniPutnici) {
      if (putnik.jePlacen) {
        // ✅ UNIFIKOVANA LOGIKA: koristi vremePlacanja umesto updatedAt
        // Proveri da li je mesečna karta plaćena u datom periodu
        if (putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(
                putnik.vremePlacanja, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.vozac ??
              'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
          if (vozaciStats.containsKey(naplatioVozac)) {
            // ✅ MESEČNE KARTE SE DODAJU RAZDVOJENO
            vozaciStats[naplatioVozac]!['mesecneKarte']++;
            // ✅ DODANO: mesečne karte se TAKOĐER računaju u 'naplaceni' - ukupan broj naplaćenih
            vozaciStats[naplatioVozac]!['naplaceni']++;
            vozaciStats[naplatioVozac]!['pazarMesecne'] +=
                (putnik.iznosPlacanja ?? 0.0);
            vozaciStats[naplatioVozac]!['ukupnoPazar'] +=
                (putnik.iznosPlacanja ?? 0.0);
            ukupnoMesecnihKarata++;
          }
        }
      }
    }

    // 🚗 DODAJ KILOMETRAŽU ZA SVE VOZAČE (SINHRONO - uprošćeno)
    try {
      // Za real-time stream, koristimo uprošćenu kilometražu bez database poziva
      // jer bi to bilo previše sporo za real-time azuriranje
      for (final vozac in sviVozaci) {
        vozaciStats[vozac]!['kilometraza'] =
            0.0; // Default vrednost za real-time
      }
    } catch (e) {
      _debugLog('🚨 Greška pri sinhronoj kilometraži: $e');
    }

    _debugLog(
        'REAL-TIME DETALJNE STATISTIKE: putnici=$ukupnoProcessiranihPutnika, mesečne=$ukupnoMesecnihKarata');

    return vozaciStats;
  }

  /// 🎯 PAZAR SAMO OD PUTNIKA - BEZ MESEČNIH KARATA (za admin screen filtriranje po danu)
  static Map<String, double> pazarSamoPutnici(List<Putnik> putnici) {
    _debugLog('Računam pazar samo od putnika (bez mesečnih karata)');
    _debugLog('Ukupno putnika za analizu: ${putnici.length}');

    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA
    final Map<String, double> pazar = {};
    for (final vozac in sviVozaci) {
      pazar[vozac] = 0.0;
    }

    // SABERI PAZAR SAMO IZ PUTNIKA
    int brojValidnihPutnika = 0;
    for (final putnik in putnici) {
      if (_jePazarValjan(putnik)) {
        final vozac = putnik.naplatioVozac!;
        if (pazar.containsKey(vozac)) {
          pazar[vozac] = pazar[vozac]! + putnik.iznosPlacanja!;
          brojValidnihPutnika++;
          _debugLog(
              '✅ Dodao pazar: ${putnik.ime} (${putnik.iznosPlacanja}) -> $vozac');
        }
      }
    }

    _debugLog('Procesuirano $brojValidnihPutnika validnih putnika');

    // Debug prikaz rezultata
    double ukupno = 0.0;
    for (final vozac in sviVozaci) {
      final vozacPazar = pazar[vozac] ?? 0.0;
      if (vozacPazar > 0) {
        _debugLog('$vozac: ${vozacPazar.toStringAsFixed(0)} RSD');
        ukupno += vozacPazar;
      }
    }

    _debugLog('UKUPAN PAZAR (samo putnici): ${ukupno.toStringAsFixed(0)} RSD');

    return {...pazar, '_ukupno': ukupno};
  }

  /// Vraca mapu: {imeVozaca: sumaPazara} i ukupno, za dati period - STANDARDIZOVANO FILTRIRANJE
  /// @deprecated Koristi pazarSvihVozaca() umesto ovoga za konzistentnost
  static Future<Map<String, double>> pazarPoVozacima(
      List<Putnik> putnici, DateTime from, DateTime to) async {
    // Preusmeri na novu standardizovanu funkciju
    return await pazarSvihVozaca(putnici, from: from, to: to);
  }

  // 🚗 KILOMETRAŽA FUNKCIJE

  /// Dodaje kilometražu za sve vozače u vozaciStats
  static Future<void> _dodajKilometrazu(
      Map<String, Map<String, dynamic>> vozaciStats,
      DateTime from,
      DateTime to) async {
    try {
      // ✅ OPTIMIZACIJA: ograniči opseg na maksimalno 7 dana da ne bude previše sporo
      const limitOpseg = Duration(days: 7);
      final opsegDana = to.difference(from);

      if (opsegDana > limitOpseg) {
        _debugLog(
            '⚠️ KILOMETRAŽA OPTIMIZACIJA: opseg ${opsegDana.inDays} dana ograničen na ${limitOpseg.inDays} dana');
        from = to.subtract(limitOpseg);
      }

      for (final vozac in sviVozaci) {
        final km = await _kmZaVozaca(vozac, from, to);
        vozaciStats[vozac]!['kilometraza'] = km;
      }
    } catch (e) {
      _debugLog('🚨 Greška pri učitavanju kilometraže: $e');
      // Dodeli default vrednosti ako je greška
      for (final vozac in sviVozaci) {
        vozaciStats[vozac]!['kilometraza'] = 0.0;
      }
    }
  }

  /// Računa kilometražu za vozača u datom periodu (SA PAMETNIM FILTRIRANJEM)
  static Future<double> _kmZaVozaca(
      String vozac, DateTime from, DateTime to) async {
    try {
      final response = await Supabase.instance.client
          .from('gps_lokacije')
          .select()
          .eq('name', vozac)
          .gte('timestamp', from.toIso8601String())
          .lte('timestamp', to.toIso8601String())
          .order('timestamp');

      final lokacije = (response as List).cast<Map<String, dynamic>>();

      if (lokacije.length < 2) return 0.0;

      _debugLog(
          '🔍 KILOMETRAŽA DEBUG - $vozac: ukupno ${lokacije.length} GPS pozicija');

      double ukupno = 0;
      int validnePozicije = 0;
      double maksimalnaDistancaPoSegmentu = 5.0; // 5km max po segmentu

      for (int i = 1; i < lokacije.length; i++) {
        final lat1 = (lokacije[i - 1]['lat'] as num).toDouble();
        final lng1 = (lokacije[i - 1]['lng'] as num).toDouble();
        final lat2 = (lokacije[i]['lat'] as num).toDouble();
        final lng2 = (lokacije[i]['lng'] as num).toDouble();

        final distanca = _distanceKm(lat1, lng1, lat2, lng2);

        // ✅ PAMETAN FILTER: preskoči nerealne distanca (npr. GPS greške)
        if (distanca <= maksimalnaDistancaPoSegmentu && distanca > 0.001) {
          ukupno += distanca;
          validnePozicije++;
        } else if (distanca > maksimalnaDistancaPoSegmentu) {
          _debugLog(
              '⚠️ KILOMETRAŽA FILTER - preskačem nerealnu distancu: ${distanca.toStringAsFixed(2)}km');
        }
      }

      _debugLog(
          '✅ KILOMETRAŽA REZULTAT - $vozac: ${ukupno.toStringAsFixed(2)}km od $validnePozicije validnih segmenata');
      return ukupno;
    } catch (e) {
      _debugLog('🚨 Greška pri računanju kilometraže za $vozac: $e');
      return 0.0;
    }
  }

  /// � JAVNA METODA: Dobij kilometražu za vozača u određenom periodu
  static Future<double> getKilometrazu(
      String vozac, DateTime from, DateTime to) async {
    return await _kmZaVozaca(vozac, from, to);
  }

  /// �🔄 RESETUJ SVE KILOMETRAŽE NA 0 - briše sve GPS pozicije
  static Future<bool> resetujSveKilometraze() async {
    try {
      _debugLog('🔄 RESET KILOMETRAŽA START - brišem sve GPS pozicije');

      final supabase = Supabase.instance.client;

      // Obriši sve GPS pozicije iz tabele
      await supabase
          .from('gps_lokacije')
          .delete()
          .neq('id', 0); // Briše sve redove (neq sa nepostojećim ID)

      _debugLog('✅ RESET KILOMETRAŽA ZAVRŠEN - sve GPS pozicije obrisane');
      return true;
    } catch (e) {
      _debugLog('🚨 GREŠKA PRI RESETOVANJU KILOMETRAŽE: $e');
      return false;
    }
  }

  /// 💰 RESETUJ PAZAR ZA ODREĐENOG VOZAČA - briše podatke o naplatama
  static Future<bool> resetujPazarZaVozaca(String vozac,
      {DateTime? from, DateTime? to}) async {
    try {
      final now = _normalizeDateTime(DateTime.now());
      final fromDate = from ?? DateTime(now.year, now.month, now.day);
      final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

      _debugLog(
          '🔄 RESET PAZAR START za $vozac od ${fromDate.toString().split(' ')[0]} do ${toDate.toString().split(' ')[0]}');

      final supabase = Supabase.instance.client;
      num ukupnoObrisano = 0;

      // 1. RESETUJ OBIČNE PUTNIKE - postavi iznos_placanja na 0 i obriši vreme_placanja
      try {
        final putnikResult = await supabase
            .from('putnici')
            .update({
              'iznos_placanja': 0.0,
              'vreme_placanja': null,
              'naplatio_vozac': null,
            })
            .eq('naplatio_vozac', vozac)
            .not('vreme_placanja', 'is', null)
            .gte('vreme_placanja', fromDate.toIso8601String())
            .lte('vreme_placanja', toDate.toIso8601String());

        _debugLog(
            '✅ Resetovano ${putnikResult?.length ?? 0} običnih putnika za $vozac');
        ukupnoObrisano += (putnikResult?.length ?? 0);
      } catch (e) {
        _debugLog('⚠️ Greška pri resetovanju putnika za $vozac: $e');
      }

      // 2. RESETUJ MESEČNE KARTE - postavi cena na 0 i obriši vreme_placanja
      try {
        final mesecniResult = await supabase
            .from('mesecni_putnici')
            .update({
              'cena': 0.0,
              'vreme_placanja': null,
            })
            .eq('vozac', vozac)
            .not('vreme_placanja', 'is', null)
            .gte('vreme_placanja', fromDate.toIso8601String())
            .lte('vreme_placanja', toDate.toIso8601String());

        _debugLog(
            '✅ Resetovano ${mesecniResult?.length ?? 0} mesečnih karata za $vozac');
        ukupnoObrisano += (mesecniResult?.length ?? 0);
      } catch (e) {
        _debugLog('⚠️ Greška pri resetovanju mesečnih putnika za $vozac: $e');
      }

      _debugLog(
          '✅ RESET PAZAR ZAVRŠEN za $vozac - ukupno obrisano: $ukupnoObrisano stavki');
      return true;
    } catch (e) {
      _debugLog('🚨 GREŠKA PRI RESETOVANJU PAZARA za $vozac: $e');
      return false;
    }
  }

  /// 💰 RESETUJ SAMO DANAS PAZAR ZA VOZAČA - brži reset za današnji dan
  static Future<bool> resetujDanasPazarZaVozaca(String vozac) async {
    final now = DateTime.now();
    final danasStart = DateTime(now.year, now.month, now.day);
    final danasEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return await resetujPazarZaVozaca(vozac, from: danasStart, to: danasEnd);
  }

  /// 🚨 RESETUJ PAZAR ZA SVE VOZAČE - briše SVE podatke o naplatama za sve vozače
  static Future<bool> resetujPazarZaSveVozace({
    DateTime? from,
    DateTime? to,
  }) async {
    _debugLog('🚨 POČETAK RESETOVANJA PAZARA ZA SVE VOZAČE...');

    int uspesnoResetovano = 0;
    int ukupnoVozaca = sviVozaci.length;
    List<String> neuspesniVozaci = [];

    for (String vozac in sviVozaci) {
      _debugLog('🔄 Resetujem pazar za vozača: $vozac');

      try {
        bool uspeh = await resetujPazarZaVozaca(vozac, from: from, to: to);
        if (uspeh) {
          uspesnoResetovano++;
          _debugLog('✅ Uspešno resetovan pazar za: $vozac');
        } else {
          neuspesniVozaci.add(vozac);
          _debugLog('❌ Neuspešan reset pazara za: $vozac');
        }
      } catch (e) {
        neuspesniVozaci.add(vozac);
        _debugLog('🚨 Greška pri resetovanju pazara za $vozac: $e');
      }
    }

    _debugLog('🏁 ZAVRŠEN RESET PAZARA ZA SVE VOZAČE:');
    _debugLog(
        '   ✅ Uspešno resetovano: $uspesnoResetovano/$ukupnoVozaca vozača');
    if (neuspesniVozaci.isNotEmpty) {
      _debugLog('   ❌ Neuspešno resetovani: ${neuspesniVozaci.join(", ")}');
    }

    return neuspesniVozaci.isEmpty;
  }

  /// 🚨 RESETUJ DANAŠNJI PAZAR ZA SVE VOZAČE - brži reset samo za današnji dan
  static Future<bool> resetujDanasPazarZaSveVozace() async {
    final now = DateTime.now();
    final danasStart = DateTime(now.year, now.month, now.day);
    final danasEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return await resetujPazarZaSveVozace(from: danasStart, to: danasEnd);
  }

  /// 🚨 NUKLEARNI RESET - briše SVE podatke o naplatama za sve vozače (cela istorija!)
  static Future<bool> nuklearniResetSvihPazara() async {
    _debugLog('☢️ NUKLEARNI RESET - BRIŠEM SVU ISTORIJU PAZARA ZA SVE VOZAČE!');
    return await resetujPazarZaSveVozace(); // Bez from/to parametara = briše sve
  }

  /// Računa rastojanje između dve GPS koordinate u kilometrima (Haversine formula)
  static double _distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius Zemlje u km
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;
    double a = 0.5 -
        cos(dLat) / 2 +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * (1 - cos(dLon)) / 2;
    return R * 2 * asin(sqrt(a));
  }
}
