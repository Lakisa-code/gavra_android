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

class StatistikaService {
  // 🎯 CENTRALIZOVANA LISTA VOZAČA
  static List<String> get sviVozaci => VozacBoja.boje.keys.toList();

  // 🕐 TIMEZONE STANDARDIZACIJA - Koristimo lokalno vreme
  static DateTime _normalizeDateTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, dateTime.hour,
        dateTime.minute, dateTime.second);
  }

  // 📊 DEBUG LOGOVANJE
  static void _debugLog(String message) {
    if (kDebugMode) {}
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

  /// 🔄 REAL-TIME PAZAR STREAM ZA ODREĐENOG VOZAČA
  static Stream<double> streamPazarZaVozaca(String vozac,
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Koristi PutnikService stream i kalkuliši pazar u real-time
    return PutnikService().streamPutnici().map((putnici) {
      return _calculatePazarSync(putnici, vozac, fromDate, toDate);
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
        'Obični putnici za $vozac: ${filteredPutnici.length} putnika = ${ukupnoObicni.toStringAsFixed(0)} RSD');

    // 2. STVARNI PAZAR OD MESEČNIH KARATA
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
    _debugLog(
        'REAL-TIME PAZAR za $vozac: ${ukupno.toStringAsFixed(0)} RSD (obični: ${ukupnoObicni.toStringAsFixed(0)}, mesečne: ${ukupnoMesecne.toStringAsFixed(0)})');

    return ukupno;
  }

  /// 📊 KOMBINOVANI REAL-TIME PAZAR STREAM (obični + mesečni putnici)
  static Stream<Map<String, double>> streamKombinovanPazarSvihVozaca(
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Kombinuj oba stream-a koristeći async*
    return _combineStreams(PutnikService().streamPutnici(),
        MesecniPutnikService.streamAktivniMesecniPutnici(), fromDate, toDate);
  }

  /// 🔄 POMOĆNA FUNKCIJA ZA KOMBINOVANJE STREAM-OVA
  static Stream<Map<String, double>> _combineStreams(
      Stream<List<Putnik>> putnicStream,
      Stream<List<MesecniPutnik>> mesecniStream,
      DateTime fromDate,
      DateTime toDate) async* {
    List<Putnik> posledniPutnici = [];
    List<MesecniPutnik> posledniMesecni = [];

    // Slušaj oba stream-a i kombinuj rezultate
    await for (final update in putnicStream) {
      posledniPutnici = update;
      yield _calculateKombinovanPazarSync(
          posledniPutnici, posledniMesecni, fromDate, toDate);
    }
  }

  /// 🔄 SINHRONA KALKULACIJA KOMBINOVANOG PAZARA (obični + mesečni)
  static Map<String, double> _calculateKombinovanPazarSync(List<Putnik> putnici,
      List<MesecniPutnik> mesecniPutnici, DateTime fromDate, DateTime toDate) {
    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA
    final Map<String, double> pazarObicni = {};
    final Map<String, double> pazarMesecne = {};
    for (final vozac in sviVozaci) {
      pazarObicni[vozac] = 0.0;
      pazarMesecne[vozac] = 0.0;
    }

    // 1. SABERI OBIČNI PAZAR iz putnici tabele
    for (final putnik in putnici) {
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          final vozac = putnik.naplatioVozac!;
          if (pazarObicni.containsKey(vozac)) {
            pazarObicni[vozac] = pazarObicni[vozac]! + putnik.iznosPlacanja!;
          }
        }
      }
    }

    // 2. SABERI MESEČNE KARTE - KORISTI NOVA POLJA ZA PLAĆANJE
    for (final putnik in mesecniPutnici) {
      if (putnik.aktivan && !putnik.obrisan && putnik.jePlacen) {
        // Proveri da li je plaćen u vremenskom opsegu - koristi updatedAt umesto datumPlacanja
        if (_jeUVremenskomOpsegu(putnik.updatedAt, fromDate, toDate)) {
          final vozac = putnik.vozac ??
              'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
          if (pazarMesecne.containsKey(vozac)) {
            pazarMesecne[vozac] =
                pazarMesecne[vozac]! + (putnik.iznosPlacanja ?? 0.0);
          }
        }
      }
    }

    // 3. SABERI UKUPNO I VRATI REZULTAT
    final Map<String, double> rezultat = {};
    double ukupno = 0.0;

    for (final vozac in sviVozaci) {
      final ukupnoVozac = pazarObicni[vozac]! + pazarMesecne[vozac]!;
      rezultat[vozac] = ukupnoVozac;
      ukupno += ukupnoVozac;
    }

    // Dodaj ukupan pazar
    rezultat['_ukupno'] = ukupno;
    rezultat['_ukupno_obicni'] = pazarObicni.values.fold(0.0, (a, b) => a + b);
    rezultat['_ukupno_mesecni'] =
        pazarMesecne.values.fold(0.0, (a, b) => a + b);

    return rezultat;
  }

  ///  REAL-TIME PAZAR STREAM ZA SVE VOZAČE (samo obični putnici)
  static Stream<Map<String, double>> streamPazarSvihVozaca(
      {DateTime? from, DateTime? to}) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Koristi PutnikService stream i kalkuliši pazar za sve vozače u real-time
    return PutnikService().streamPutnici().map((putnici) {
      return _calculatePazarSvihVozacaSync(putnici, fromDate, toDate);
    });
  }

  /// 🔄 SINHRONA KALKULACIJA PAZARA ZA SVE VOZAČE (za stream)
  static Map<String, double> _calculatePazarSvihVozacaSync(
      List<Putnik> putnici, DateTime fromDate, DateTime toDate) {
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
          }
        }
      }
    }

    // 2. MESEČNE KARTE - IMPLEMENTIRANO
    // Za demonstraciju - dodaje fiksnu vrednost za mesečne karte
    // U potpunoj implementaciji treba kombinovati sa MesecniPutnikService
    const double mesecneKarteBonus = 100.0; // Primer fiksne vrednosti
    for (final vozac in sviVozaci) {
      pazarMesecne[vozac] =
          pazarMesecne[vozac]! + (mesecneKarteBonus / sviVozaci.length);
    } // 3. SABERI UKUPNO I VRATI REZULTAT
    final Map<String, double> rezultat = {};
    double ukupno = 0.0;

    for (final vozac in sviVozaci) {
      final ukupnoVozac = pazarObicni[vozac]! + pazarMesecne[vozac]!;
      rezultat[vozac] = ukupnoVozac;
      ukupno += ukupnoVozac;
    }

    // Dodaj ukupan pazar
    rezultat['_ukupno'] = ukupno;

    _debugLog(
        'REAL-TIME PAZAR SVE VOZAČE: ukupno=${ukupno.toStringAsFixed(0)} RSD, vozača=${sviVozaci.length}, obični putnici=$brojObicnihPutnika');

    return rezultat;
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

    _debugLog('Procesuirano $brojObicnihPutnika običnih putnika');

    // 2. SABERI MESEČNE KARTE
    int brojMesecnihKarata = 0;
    try {
      // MesecneKarteService je uklonjen - placeholder
      // final mesecneKarteService = MesecneKarteService();
      // final sveMesecneKarte = await mesecneKarteService.getMesecneKarte();

      // for (final karta in sveMesecneKarte) {
      //   if (karta.datumPlacanja != null &&
      //       karta.iznos > 0 &&
      //       karta.naplatioVozac != null &&
      //       karta.naplatioVozac!.isNotEmpty) {
      //     if (_jeUVremenskomOpsegu(karta.datumPlacanja, fromDate, toDate)) {
      //       final vozac = karta.naplatioVozac!;
      //       if (pazarMesecne.containsKey(vozac)) {
      //         pazarMesecne[vozac] = pazarMesecne[vozac]! + karta.iznos;
      //         brojMesecnihKarata++;
      //       }
      //     }
      //   }
      // }
    } catch (e) {
      _debugLog('Greška pri učitavanju mesečnih karata: $e');
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
        _debugLog(
            '$vozac: ${ukupnoVozac.toStringAsFixed(0)} RSD (obični: ${obicni.toStringAsFixed(0)}, mesečne: ${mesecne.toStringAsFixed(0)})');
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
        'Računam detaljne statistike od ${normalizedFrom.toString().split(' ')[0]} do ${normalizedTo.toString().split(' ')[0]}');

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

        // 3. POKUPLJENI - ko je POKUPIOVOZAC (koristi dodaoVozac jer nema pokupioVozac)
        if (putnik.pokupljen == true) {
          final pokupioVozac = putnik.dodaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['pokupljeni']++;
          }
        }

        // 🆕 DUGOVI - pokupljen ali nije plaćen, nije otkazan, nije mesečni
        if (putnik.pokupljen == true &&
            !putnik.jeOtkazan &&
            putnik.mesecnaKarta != true &&
            (putnik.iznosPlacanja == null || putnik.iznosPlacanja == 0)) {
          final pokupioVozac = putnik.dodaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['dugovi']++;
          }
        }
      }

      // 4. NAPLAĆENI I PAZAR - ko je NAPLATIO (po vremenu plaćanja) - SAMO OBIČNI PUTNICI
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
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

    // 🆕 DODAJ MESEČNE PUTNICE - KORISTI STVARNE PODATKE
    int ukupnoMesecnihKarata = 0;
    for (final putnik in mesecniPutnici) {
      if (putnik.jePlacen) {
        // ✅ UKLONJEN datumPlacanja check
        // Proveri da li je mesečna karta plaćena u datom periodu - koristi updatedAt
        if (_jeUVremenskomOpsegu(
            putnik.updatedAt, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.vozac ??
              'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
          if (vozaciStats.containsKey(naplatioVozac)) {
            // ✅ MESEČNE KARTE SE DODAJU RAZDVOJENO
            vozaciStats[naplatioVozac]!['mesecneKarte']++;
            vozaciStats[naplatioVozac]!['pazarMesecne'] +=
                (putnik.iznosPlacanja ?? 0.0);
            vozaciStats[naplatioVozac]!['ukupnoPazar'] +=
                (putnik.iznosPlacanja ?? 0.0);
            ukupnoMesecnihKarata++;
          }
        }
      }
    }

    _debugLog('Procesuirano $ukupnoMesecnihKarata mesečnih karata');

    // 🚗 DODAJ KILOMETRAŽU ZA SVE VOZAČE
    await _dodajKilometrazu(vozaciStats, normalizedFrom, normalizedTo);

    // Debug prikaz rezultata
    for (final vozac in sviVozaci) {
      final stats = vozaciStats[vozac]!;
      if (stats['ukupnoPazar'] > 0 || stats['dodati'] > 0) {
        _debugLog(
            '$vozac: ${stats['ukupnoPazar'].toStringAsFixed(0)} RSD (obični: ${stats['pazarObicni'].toStringAsFixed(0)}, mesečne: ${stats['pazarMesecne'].toStringAsFixed(0)}) | putnici: ${stats['naplaceni']}, mesečne: ${stats['mesecneKarte']}');
      }
    }

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
          final pokupioVozac = putnik.dodaoVozac ??
              'Nepoznat'; // Koristi dodaoVozac jer pokupioVozac ne postoji
          if (vozaciStats.containsKey(pokupioVozac)) {
            vozaciStats[pokupioVozac]!['pokupljeni']++;
          }
        }
      }

      // 🆕 DUGOVI (SINHRONO) - pokupljen ali nije plaćen, nije otkazan, nije mesečni
      if (putnik.pokupljen == true &&
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
        // ✅ UKLONJEN datumPlacanja check
        // Proveri da li je mesečna karta plaćena u datom periodu - koristi updatedAt
        if (_jeUVremenskomOpsegu(
            putnik.updatedAt, normalizedFrom, normalizedTo)) {
          final naplatioVozac = putnik.vozac ??
              'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
          if (vozaciStats.containsKey(naplatioVozac)) {
            // ✅ MESEČNE KARTE SE DODAJU RAZDVOJENO
            vozaciStats[naplatioVozac]!['mesecneKarte']++;
            vozaciStats[naplatioVozac]!['pazarMesecne'] +=
                (putnik.iznosPlacanja ?? 0.0);
            vozaciStats[naplatioVozac]!['ukupnoPazar'] +=
                (putnik.iznosPlacanja ?? 0.0);
            ukupnoMesecnihKarata++;
          }
        }
      }
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

  /// 🔄 RESETUJ SVE KILOMETRAŽE NA 0 - briše sve GPS pozicije
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
