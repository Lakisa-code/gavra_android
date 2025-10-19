import 'dart:async';
import 'dart:math'; // 🚗 DODANO za kilometražu kalkulacije

import 'package:async/async.dart'; // Za StreamZip i StreamGroup
// DateFormat import removed - not needed after debug cleanup
import 'package:rxdart/rxdart.dart'; // 🔧 DODANO za share() metodu
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚗 DODANO za GPS podatke

import '../models/mesecni_putnik.dart';
import '../models/putnik.dart';
import '../utils/logging.dart'; // 🔧 DODANO za dlog funkciju
import '../utils/novac_validacija.dart'; // 🆕 DODANO za centralizovanu validaciju
import '../utils/vozac_boja.dart'; // 🎯 DODANO za listu vozača
import 'clean_statistika_service.dart'; // 🆕 DODANO za clean statistike
import 'mesecni_putnik_service.dart'; // 🔄 DODANO za mesečne putnike
import 'putnik_service.dart'; // 🔄 DODANO za real-time streams
import 'vozac_mapping_service.dart'; // 🔧 DODANO za mapiranje UUID -> imena

class StatistikaService {
  StatistikaService._internal();
  // Singleton pattern
  static StatistikaService? _instance;
  static StatistikaService get instance => _instance ??= StatistikaService._internal(); // Private constructor

  // Instance cache za stream-ove da izbegnemo duplo kreiranje
  final Map<String, Stream<Map<String, double>>> _streamCache = {};

  // 🎯 CENTRALIZOVANA LISTA VOZAČA
  static List<String> get sviVozaci => VozacBoja.boje.keys.toList();

  // 🕐 TIMEZONE STANDARDIZACIJA - Koristimo lokalno vreme (SAMO DATUM)
  static DateTime _normalizeDateTime(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  // Debug logging completely removed for production build

  /// 💰 JEDINSTVENA LOGIKA ZA RAČUNANJE PAZARA - koristi centralizovanu validaciju
  static bool _jePazarValjan(Putnik putnik) {
    // ✅ KORISTI CENTRALIZOVANU VALIDACIJU
    return NovcanaValidacija.isValidPayment(putnik);
  }

  /// 🕐 STANDARDIZOVANO FILTRIRANJE PO VREMENSKOM OPSEGU
  static bool _jeUVremenskomOpsegu(
    DateTime? dateTime,
    DateTime from,
    DateTime to,
  ) {
    if (dateTime == null) return false;
    final normalized = _normalizeDateTime(dateTime);
    final normalizedFrom = _normalizeDateTime(from);
    final normalizedTo = _normalizeDateTime(to);

    // ✅ FIXED: Use proper inclusive date range comparison
    final result = !normalized.isBefore(normalizedFrom) && !normalized.isAfter(normalizedTo);

    if (!result) {
    } else {}

    return result;
  }

  /// 💰 PAZAR ZA ODREĐENOG VOZAČA - KORISTI VREMENSKI OPSEG
  static Future<double> pazarZaVozaca(
    List<Putnik> putnici,
    String vozac, {
    DateTime? from,
    DateTime? to,
  }) async {
    // Ako nisu prosleđeni parametri, koristi današnji dan
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _calculatePazarSync(putnici, vozac, fromDate, toDate);
  }

  /// 🔄 REAL-TIME PAZAR STREAM ZA ODREĐENOG VOZAČA - JEDNOSTAVNO BEZ DUPLIKOVANJA
  static Stream<double> streamPazarZaVozaca(
    String vozac, {
    DateTime? from,
    DateTime? to,
  }) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Kreiraj ISO datum za filter
    final isoDate =
        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';

    // � SAMO KOMBINOVANI STREAM SA DATUM FILTEROM - ne duplikuj mesečne putnike!
    return PutnikService().streamKombinovaniPutniciFiltered(isoDate: isoDate).map((putnici) {
      final pazar = _calculateSimplePazarSync(putnici, vozac, fromDate, toDate);
      return pazar;
    });
  }

  /// � JEDNOSTAVNA KALKULACIJA PAZARA - KORISTI KOMBINOVANI STREAM - POPRAVLJENA LOGIKA
  static double _calculateSimplePazarSync(
    List<Putnik> kombinovaniPutnici,
    String vozac,
    DateTime fromDate,
    DateTime toDate,
  ) {
    double ukupno = 0.0;

    // 🔧 GRUPIRANJE MESEČNIH PUTNIKA PO ID da se izbegne duplikovanje
    final Map<String, Putnik> uniqueMesecni = {};
    final List<Putnik> obicniPutnici = [];

    for (final putnik in kombinovaniPutnici) {
      if (putnik.mesecnaKarta == true) {
        // Za mesečne - grupiši po ID-u
        final kljuc = (putnik.id?.toString()) ?? '${putnik.ime}_${putnik.vozac}';
        if (!uniqueMesecni.containsKey(kljuc) && _jePazarValjan(putnik)) {
          uniqueMesecni[kljuc] = putnik;
        }
      } else {
        obicniPutnici.add(putnik);
      }
    }

    // Kombinuj unique mesečne i obične putnike
    final sviPutnici = [...uniqueMesecni.values, ...obicniPutnici];

    for (final putnik in sviPutnici) {
      if (_jePazarValjan(putnik)) {
        // 🔧 MAPIRANJE: Za mesečne putnike vozac je UUID, za dnevne je ime
        String vozacIme;
        if (putnik.mesecnaKarta == true) {
          vozacIme = VozacMappingService.getVozacImeWithFallbackSync(putnik.vozac);
        } else {
          vozacIme = putnik.naplatioVozac ?? putnik.vozac ?? '';
        }

        // Pokušaj i direktno UUID mapiranje ako ime ne radi
        final direktnoPodudaranje = (vozacIme == vozac) || (putnik.vozac == vozac) || (putnik.naplatioVozac == vozac);

        if (direktnoPodudaranje) {
          if (putnik.mesecnaKarta == true) {
            // Za mesečne putnike - uvek računaj pazar ako je aktivan
            final iznos = putnik.iznosPlacanja ?? 0.0;
            if (iznos > 0 && !putnik.jeOtkazan) {
              ukupno += iznos;
            }
          } else {
            // Za dnevne putnike - računaj pazar SAMO ako je plaćen u traženom opsegu
            final vremeZaProveru = putnik.vremePlacanja ?? putnik.vremeDodavanja;
            if (vremeZaProveru != null && _jeUVremenskomOpsegu(vremeZaProveru, fromDate, toDate)) {
              final iznos = putnik.iznosPlacanja ?? 0.0;
              if (iznos > 0) {
                ukupno += iznos;
              }
            }
          }
        }
      }
    }
    return ukupno;
  }

  /// 🎫 STREAM BROJ MESEČNIH KARATA ZA ODREĐENOG VOZAČA
  static Stream<int> streamBrojMesecnihKarataZaVozaca(
    String vozac, {
    DateTime? from,
    DateTime? to,
  }) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Konvertuj ime vozača u UUID jer MesecniPutnik koristi vozac_id (UUID)
    final vozacUuid = VozacMappingService.getVozacUuidSync(vozac) ?? vozac;

    return MesecniPutnikService.streamAktivniMesecniPutnici().map((mesecniPutnici) {
      int brojKarata = 0;
      for (final putnik in mesecniPutnici) {
        if (putnik.jePlacen &&
            putnik.vozac == vozacUuid &&
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
    List<Putnik> putnici,
    String vozac,
    DateTime fromDate,
    DateTime toDate,
  ) {
    // 1. PAZAR OD OBIČNIH PUTNIKA
    final filteredPutnici = putnici.where((putnik) {
      if (!_jePazarValjan(putnik)) return false;
      if (putnik.vremePlacanja == null) return false;
      if (putnik.vozac != vozac) return false;

      return _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate);
    }).toList();

    double ukupnoObicni = filteredPutnici.fold<double>(
      0.0,
      (sum, putnik) => sum + (putnik.iznosPlacanja ?? 0.0),
    );
    // 2. STVARNI PAZAR OD MESEČNIH KARATA
    double ukupnoMesecne = 0.0;
    try {
      // Sinhrono računanje za stream - koristimo podatke iz putnici koji su mesečni
      final mesecniPutnici = putnici.where((putnik) {
        if (putnik.mesecnaKarta != true) return false;
        if (putnik.iznosPlacanja == null || putnik.iznosPlacanja! <= 0) {
          return false;
        }
        if (putnik.vozac != vozac) return false;
        if (putnik.vremePlacanja == null) return false;

        return _jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate);
      }).toList();

      ukupnoMesecne = mesecniPutnici.fold<double>(
        0.0,
        (sum, putnik) => sum + (putnik.iznosPlacanja ?? 0.0),
      );
    } catch (e) {
      // ignore: empty_catches
    }

    final ukupno = ukupnoObicni + ukupnoMesecne;
    return ukupno;
  }

  /// 📊 KOMBINOVANI REAL-TIME PAZAR STREAM (obični + mesečni putnici)
  static Stream<Map<String, double>> streamKombinovanPazarSvihVozaca({
    DateTime? from,
    DateTime? to,
  }) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Kreiraj ISO datum za filter - isti kao u streamPazarZaVozaca
    final isoDate =
        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';

    // Kombinuj oba stream-a koristeći async* SA DATUM FILTEROM
    return instance._combineStreams(
      PutnikService().streamKombinovaniPutniciFiltered(isoDate: isoDate),
      MesecniPutnikService.streamAktivniMesecniPutnici(),
      fromDate,
      toDate,
    );
  }

  /// 🔄 POMOĆNA FUNKCIJA ZA KOMBINOVANJE STREAM-OVA - SIMPLIFIKOVANO
  Stream<Map<String, double>> _combineStreams(
    Stream<List<Putnik>> putnicStream,
    Stream<List<MesecniPutnik>> mesecniStream,
    DateTime fromDate,
    DateTime toDate,
  ) {
    // 🔧 POJEDNOSTAVLJENO: Koristi CombineLatest2 umesto StreamGroup
    return CombineLatestStream.combine2(
      putnicStream,
      mesecniStream,
      (List<Putnik> putnici, List<MesecniPutnik> mesecniPutnici) {
        final rezultat = _calculateKombinovanPazarSync(
          putnici,
          mesecniPutnici,
          fromDate,
          toDate,
        );

        return rezultat;
      },
    );
  }

  ///  PUBLIC SINHRONA KALKULACIJA KOMBINOVANOG PAZARA (za external usage)
  static Map<String, double> calculateKombinovanPazarSync(
    List<Putnik> putnici,
    List<MesecniPutnik> mesecniPutnici,
    DateTime fromDate,
    DateTime toDate,
  ) {
    return _calculateKombinovanPazarSync(
      putnici,
      mesecniPutnici,
      fromDate,
      toDate,
    );
  }

  /// 🔄 SINHRONA KALKULACIJA KOMBINOVANOG PAZARA (obični + mesečni)
  static Map<String, double> _calculateKombinovanPazarSync(
    List<Putnik> putnici,
    List<MesecniPutnik> mesecniPutnici,
    DateTime fromDate,
    DateTime toDate,
  ) {
    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA - RESETUJ SVE!
    final Map<String, double> pazarObicni = {};
    final Map<String, double> pazarMesecne = {};
    for (final vozac in sviVozaci) {
      pazarObicni[vozac] = 0.0; // 🔧 RESETUJ NA 0!
      pazarMesecne[vozac] = 0.0; // 🔧 RESETUJ NA 0!
    }

    // 1. SABERI OBIČNI PAZAR iz putovanja_istorija tabele - ISKLJUČI MESEČNE KARTE
    for (final putnik in putnici) {
      // 🛑 PRESKAČI MESEČNE KARTE - one se računaju odvojeno iz MesecniPutnikService
      if (putnik.mesecnaKarta == true) {
        continue;
      }

      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
          final vozac = putnik.vozac!;
          if (pazarObicni.containsKey(vozac)) {
            pazarObicni[vozac] = pazarObicni[vozac]! + putnik.iznosPlacanja!;
          }
        }
      }
      // 2. SABERI MESEČNE KARTE - KORISTI vremePlacanja (kad je plaćeno) umesto placeniMesec
      // 💡 SABERI SVE VALIDNE MESEČNE NAPLATE BEZ DUPLIKATA PO ID
      final Set<String> processedMesecni = {}; // Processed IDs to avoid duplicates

      for (final putnik in mesecniPutnici) {
        if (putnik.aktivan && !putnik.obrisan && putnik.jePlacen) {
          // Za mesečne putnike - računaj pazar SAMO AKO JE PLAĆENO DANAS!
          final danas = DateTime.now();
          final danasDatum = DateTime(danas.year, danas.month, danas.day);

          // Proveri da li je vremePlacanja danas
          final jeNaplacenoUDanas = putnik.vremePlacanja != null &&
              DateTime(putnik.vremePlacanja!.year, putnik.vremePlacanja!.month, putnik.vremePlacanja!.day) ==
                  danasDatum;

          if (jeNaplacenoUDanas) {
            // Samo jednom po ID
            if (!processedMesecni.contains(putnik.id)) {
              processedMesecni.add(putnik.id);

              // 🔧 MAPIRANJE UUID -> IME VOZAČA
              final vozacData = putnik.vozac ?? 'Nepoznat';
              final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacData);
              final iznos = putnik.iznosPlacanja ?? 0.0;

              if (pazarMesecne.containsKey(vozacIme)) {
                pazarMesecne[vozacIme] = pazarMesecne[vozacIme]! + iznos;
              }
            }
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
    rezultat['_ukupno_mesecni'] = pazarMesecne.values.fold(0.0, (a, b) => a + b);

    return rezultat;
  }

  ///  REAL-TIME PAZAR STREAM ZA SVE VOZAČE - POPRAVLJENA LOGIKA BEZ DUPLIKOVANJA
  static Stream<Map<String, double>> streamPazarSvihVozaca({
    DateTime? from,
    DateTime? to,
  }) {
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    // 🔧 KORISTI KOMBINOVANI STREAM UMESTO DUPLO RAČUNANJE MESEČNIH
    return streamKombinovanPazarSvihVozaca(from: fromDate, to: toDate);
  }

  // Metoda za čišćenje cache-a (korisno za testiranje ili promenu datuma)
  static void clearStreamCache() {
    instance._streamCache.clear();
  }

  /// �💰 PAZAR PO SVIM VOZAČIMA - KORISTI VREMENSKI OPSEG
  static Future<Map<String, double>> pazarSvihVozaca(
    List<Putnik> putnici, {
    DateTime? from,
    DateTime? to,
  }) async {
    // Ako nisu prosleđeni parametri, koristi današnji dan
    final now = _normalizeDateTime(DateTime.now());
    final fromDate = from ?? DateTime(now.year, now.month, now.day);
    final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

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
          // ✅ SAMO REGISTROVANI VOZAČI: naplatioVozac > vozac (BEZ FALLBACK-a)
          final vozac = putnik.naplatioVozac ?? putnik.vozac!;
          // ✅ Validacija da je vozač registrovan
          if (pazarObicni.containsKey(vozac) && VozacBoja.isValidDriver(vozac)) {
            pazarObicni[vozac] = pazarObicni[vozac]! + putnik.iznosPlacanja!;
          }
        } else {}
      }
    }

    // 2. SABERI MESEČNE KARTE - STVARNI PODACI
    try {
      // Učitaj sve mesečne putnike
      final mesecniPutnici = await MesecniPutnikService().getAktivniMesecniPutnici();

      for (final putnik in mesecniPutnici) {
        // Proveri da li je putnik platio u ovom periodu
        if (putnik.vremePlacanja != null &&
            putnik.iznosPlacanja != null &&
            putnik.iznosPlacanja! > 0 &&
            putnik.vozac != null &&
            putnik.vozac!.isNotEmpty) {
          // 🔧 KONVERTUJ UUID u ime vozača
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(putnik.vozac);
          if (VozacBoja.isValidDriver(vozacIme)) {
            if (_jeUVremenskomOpsegu(putnik.vremePlacanja, fromDate, toDate)) {
              // ✅ SAMO REGISTROVANI VOZAČI za mesečne putnike
              if (pazarMesecne.containsKey(vozacIme)) {
                pazarMesecne[vozacIme] = pazarMesecne[vozacIme]! + putnik.iznosPlacanja!;
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore: empty_catches
    }

    // 3. SABERI UKUPNO I KREIRAJ FINALNI MAP
    final Map<String, double> ukupnoPazar = {};
    double ukupno = 0.0;

    for (final vozac in sviVozaci) {
      final obicni = pazarObicni[vozac] ?? 0.0;
      final mesecne = pazarMesecne[vozac] ?? 0.0;
      final ukupnoVozac = obicni + mesecne;

      ukupnoPazar[vozac] = ukupnoVozac;
      ukupno += ukupnoVozac;

      if (ukupnoVozac > 0) {}
    }

    return {...ukupnoPazar, '_ukupno': ukupno};
  }

  /// Vraca detaljne statistike po vozacu - STVARNI MESEČNI PUTNICI
  static Future<Map<String, Map<String, dynamic>>> detaljneStatistikePoVozacima(
    List<Putnik> putnici,
    DateTime from,
    DateTime to,
  ) async {
    final normalizedFrom = _normalizeDateTime(from);
    final normalizedTo = _normalizeDateTime(to);

    final Map<String, Map<String, dynamic>> vozaciStats = {};

    // UČITAJ STVARNE MESEČNE PUTNIKE
    final mesecniPutnici = await MesecniPutnikService().getAllMesecniPutnici();

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

    for (final putnik in putnici) {
      // Proverava da li je putnik u datom periodu (po vremenu dodavanja)
      if (putnik.vremeDodavanja != null &&
          _jeUVremenskomOpsegu(
            putnik.vremeDodavanja,
            normalizedFrom,
            normalizedTo,
          )) {
        // 1. DODATI PUTNICI - ko je DODAO
        final dodaoVozac = putnik.dodaoVozac ?? 'Nepoznat';
        if (vozaciStats.containsKey(dodaoVozac)) {
          vozaciStats[dodaoVozac]!['dodati']++;
        }

        // 2. OTKAZANI - ko je OTKAZAO (ili ko je dodao ako nema otkazaoVozac)
        if (putnik.jeOtkazan) {
          final otkazaoVozac = putnik.otkazaoVozac ?? putnik.dodaoVozac ?? 'Nepoznat';
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
          putnik.vremePlacanja,
          normalizedFrom,
          normalizedTo,
        )) {
          // ✅ SAMO REGISTROVANI VOZAČI: naplatioVozac > vozac (BEZ FALLBACK-a)
          final vozacIme = putnik.naplatioVozac ?? putnik.vozac!;
          if (vozaciStats.containsKey(vozacIme) && VozacBoja.isValidDriver(vozacIme)) {
            vozaciStats[vozacIme]!['naplaceni']++;
            vozaciStats[vozacIme]!['pazarObicni'] += putnik.iznosPlacanja!;
            vozaciStats[vozacIme]!['ukupnoPazar'] += putnik.iznosPlacanja!;
          }
        }
      }
    }

    // 🆕 DODAJ MESEČNE PUTNICE - KORISTI STVARNE PODATKE (GRUPE PO ID)
    // 💡 GRUPIRAJ MESEČNE PUTNIKE PO ID - jedan mesečni putnik može imati više polazaka,
    // ali treba se računati samo jednom u statistike
    final Map<String, MesecniPutnik> uniqueMesecniPutnici = {};
    for (final putnik in mesecniPutnici) {
      uniqueMesecniPutnici[putnik.id] = putnik;
    }

    for (final putnik in uniqueMesecniPutnici.values) {
      if (putnik.jePlacen) {
        // ✅ UNIFIKOVANA LOGIKA: koristi vremePlacanja umesto updatedAt
        // Proveri da li je mesečna karta plaćena u datom periodu
        if (putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(
              putnik.vremePlacanja,
              normalizedFrom,
              normalizedTo,
            )) {
          // ✅ SAMO REGISTROVANI VOZAČI za mesečne putnike (BEZ FALLBACK-a)
          // 🔧 KONVERTUJ UUID u ime vozača
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(putnik.vozac);
          if (vozaciStats.containsKey(vozacIme) && VozacBoja.isValidDriver(vozacIme)) {
            // ✅ MESEČNE KARTE SE DODAJU RAZDVOJENO
            vozaciStats[vozacIme]!['mesecneKarte']++;
            // ✅ DODANO: mesečne karte se TAKOĐER računaju u 'naplaceni' - ukupan broj naplaćenih
            vozaciStats[vozacIme]!['naplaceni']++;
            vozaciStats[vozacIme]!['pazarMesecne'] += (putnik.iznosPlacanja ?? 0.0);
            vozaciStats[vozacIme]!['ukupnoPazar'] += (putnik.iznosPlacanja ?? 0.0);
          }
        }
      }
    }

    // 🚗 DODAJ KILOMETRAŽU ZA SVE VOZAČE
    await _dodajKilometrazu(vozaciStats, normalizedFrom, normalizedTo);

    return vozaciStats;
  }

  /// 🔄 REAL-TIME DETALJNE STATISTIKE STREAM ZA SVE VOZAČE
  static Stream<Map<String, Map<String, dynamic>>> streamDetaljneStatistikePoVozacima(DateTime from, DateTime to) {
    // Koristi kombinovani stream (putnici + mesečni putnici)
    return StreamZip([
      PutnikService().streamKombinovaniPutniciFiltered(),
      MesecniPutnikService.streamAktivniMesecniPutnici(),
    ]).map((data) {
      final putnici = data[0] as List<Putnik>;
      final mesecniPutnici = data[1] as List<MesecniPutnik>;
      return _calculateDetaljneStatistikeSinhronno(
        putnici,
        mesecniPutnici,
        from,
        to,
      );
    });
  }

  /// 🔄 PUBLIC SINHRONA KALKULACIJA DETALJNIH STATISTIKA (za external usage)
  static Map<String, Map<String, dynamic>> calculateDetaljneStatistikeSinhronno(
    List<Putnik> putnici,
    List<MesecniPutnik> mesecniPutnici,
    DateTime from,
    DateTime to,
  ) {
    return _calculateDetaljneStatistikeSinhronno(
      putnici,
      mesecniPutnici,
      from,
      to,
    );
  }

  /// 🔄 SINHRONA KALKULACIJA DETALJNIH STATISTIKA (za stream)
  static Map<String, Map<String, dynamic>> _calculateDetaljneStatistikeSinhronno(
    List<Putnik> putnici,
    List<MesecniPutnik> mesecniPutnici,
    DateTime from,
    DateTime to,
  ) {
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
        'detaljiNaplata': <Map<String, dynamic>>[], // 🆕 Lista detaljnih naplata
        'poslednjaNaplata': null, // 🆕 Poslednja naplata
        'prosecanIznos': 0.0, // 🆕 Prosečan iznos naplate
      };
    }

    // PROCESUIRAJ OBIČNE PUTNIKE
    for (final putnik in putnici) {
      if (putnik.vremeDodavanja != null) {
        if (_jeUVremenskomOpsegu(
          putnik.vremeDodavanja,
          normalizedFrom,
          normalizedTo,
        )) {
          final dodaoVozac = putnik.dodaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(dodaoVozac)) {
            vozaciStats[dodaoVozac]!['dodati']++;
          }
        }
      }

      // Proveri da li je otkazan u datom periodu
      if (putnik.jeOtkazan && putnik.vremeOtkazivanja != null) {
        if (_jeUVremenskomOpsegu(
          putnik.vremeOtkazivanja,
          normalizedFrom,
          normalizedTo,
        )) {
          final otkazaoVozac = putnik.otkazaoVozac ?? 'Nepoznat';
          if (vozaciStats.containsKey(otkazaoVozac)) {
            vozaciStats[otkazaoVozac]!['otkazani']++;
          }
        }
      }

      // Proveri da li je naplaćen u datom periodu
      if (_jePazarValjan(putnik) && putnik.vremePlacanja != null) {
        if (_jeUVremenskomOpsegu(
          putnik.vremePlacanja,
          normalizedFrom,
          normalizedTo,
        )) {
          // ✅ SAMO REGISTROVANI VOZAČI: naplatioVozac > vozac (BEZ FALLBACK-a)
          final vozacData = putnik.naplatioVozac ?? putnik.vozac!;
          // 🔧 KORISTI DINAMIČKO MAPIRANJE umesto hardkodovane mape
          final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacData);
          if (vozaciStats.containsKey(vozacIme) && VozacBoja.isValidDriver(vozacIme)) {
            final iznos = putnik.iznosPlacanja!;

            // Dodaj detalj naplate
            final detalj = {
              'ime': putnik.ime,
              'iznos': iznos,
              'vreme': putnik.vremePlacanja!.millisecondsSinceEpoch,
              'tip': putnik.mesecnaKarta == true ? 'Mesečna' : 'Dnevna',
            };

            (vozaciStats[vozacIme]!['detaljiNaplata'] as List<Map<String, dynamic>>).add(detalj);

            // Ažuriraj poslednju naplatu
            if (vozaciStats[vozacIme]!['poslednjaNaplata'] == null ||
                putnik.vremePlacanja!.isAfter(
                  DateTime.fromMillisecondsSinceEpoch(
                    vozaciStats[vozacIme]!['poslednjaNaplata']['vreme'] as int,
                  ),
                )) {
              vozaciStats[vozacIme]!['poslednjaNaplata'] = detalj;
            }

            // ❌ MESEČNE KARTE SE NE RAČUNAJU U 'naplaceni' - to je samo za obične putnike
            if (putnik.mesecnaKarta != true) {
              vozaciStats[vozacIme]!['naplaceni']++;
              vozaciStats[vozacIme]!['pazarObicni'] += iznos;
              vozaciStats[vozacIme]!['ukupnoPazar'] += iznos;
            }
          }
        }
      }

      // Proveri da li je pokupljen u datom periodu
      if (putnik.vremePokupljenja != null) {
        if (_jeUVremenskomOpsegu(
          putnik.vremePokupljenja,
          normalizedFrom,
          normalizedTo,
        )) {
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
            putnik.vremePokupljenja,
            normalizedFrom,
            normalizedTo,
          )) {
            final pokupioVozac = putnik.dodaoVozac ?? 'Nepoznat';
            if (vozaciStats.containsKey(pokupioVozac)) {
              vozaciStats[pokupioVozac]!['dugovi']++;
            }
          }
        }
      }
    }

    // 🆕 DODAJ MESEČNE KARTE - KORISTI STVARNE PODATKE (SINHRONO) SA GRUPIRANJEM

    // 🎫 GRUPIRANJE MESEČNIH PUTNIKA PO IMENU (isto kao u streamPazarSvihVozaca)
    final Map<String, MesecniPutnik> grupisaniMesecniPutnici = {};

    // � FIX: KORISTI PROSLEĐENI OPSEG (from/to) umesto hardkodovanog mesečnog opsega
    // Ovo omogućava filtriranje mesečnih karata za godišnji period
    final mesecniFrom = normalizedFrom;
    final mesecniTo = normalizedTo;

    for (final putnik in mesecniPutnici) {
      if (putnik.jePlacen) {
        // ✅ MESEČNE KARTE: koristi MESEČNI opseg umesto sedmičnog/dnevnog
        // Proveri da li je mesečna karta plaćena u OVOM MESECU
        if (putnik.vremePlacanja != null &&
            _jeUVremenskomOpsegu(
              putnik.vremePlacanja,
              mesecniFrom,
              mesecniTo,
            )) {
          // 🎫 GRUPIRANJE: Dodaj samo prvi polazak po imenu (putnikIme)
          final kljuc = putnik.putnikIme.trim();
          if (!grupisaniMesecniPutnici.containsKey(kljuc)) {
            grupisaniMesecniPutnici[kljuc] = putnik;
          }
        }
      }
    }

    // 🎫 PROCES GRUPISANIH MESEČNIH PUTNIKA
    for (final putnik in grupisaniMesecniPutnici.values) {
      final vozacIme = putnik.vozac ?? 'Nepoznat'; // ✅ KORISTI vozac umesto naplatioVozac
      if (vozaciStats.containsKey(vozacIme)) {
        final iznos = putnik.iznosPlacanja ?? 0.0;

        // Dodaj detalj naplate za mesečnu kartu
        if (putnik.vremePlacanja != null) {
          final detalj = {
            'ime': putnik.putnikIme,
            'iznos': iznos,
            'vreme': putnik.vremePlacanja!.millisecondsSinceEpoch,
            'tip': 'Mesečna',
          };

          (vozaciStats[vozacIme]!['detaljiNaplata'] as List<Map<String, dynamic>>).add(detalj);

          // Ažuriraj poslednju naplatu
          if (vozaciStats[vozacIme]!['poslednjaNaplata'] == null ||
              putnik.vremePlacanja!.isAfter(
                DateTime.fromMillisecondsSinceEpoch(
                  vozaciStats[vozacIme]!['poslednjaNaplata']['vreme'] as int,
                ),
              )) {
            vozaciStats[vozacIme]!['poslednjaNaplata'] = detalj;
          }
        }

        // 🔧 FIX: MESEČNE KARTE SE NE DODAJU U 'naplaceni' - to je samo za obične putnike
        // 'naplaceni' = samo obični putnici, 'mesecneKarte' = samo mesečne karte
        vozaciStats[vozacIme]!['mesecneKarte']++;
        vozaciStats[vozacIme]!['pazarMesecne'] += iznos;
        vozaciStats[vozacIme]!['ukupnoPazar'] += iznos;
      }
    }

    // 🚗 DODAJ KILOMETRAŽU ZA SVE VOZAČE (ESTIMACIJA BAZIRANA NA PUTNICIMA)
    try {
      for (final vozac in sviVozaci) {
        // 🚗 ESTIMACIJA: ~15km po putniku (prosečna ruta Mladenovac-Beograd)
        final brojPutnika = (vozaciStats[vozac]!['pokupljeni'] as int) + (vozaciStats[vozac]!['mesecneKarte'] as int);
        final estimiranaKilometraza = brojPutnika * 15.0; // 15km po putniku

        vozaciStats[vozac]!['kilometraza'] = estimiranaKilometraza;
      }
    } catch (e) {
      // Fallback na 0.0 ako nešto pukne
      for (final vozac in sviVozaci) {
        vozaciStats[vozac]!['kilometraza'] = 0.0;
      }
    }

    // 🧮 KALKULIŠI PROSEČNE IZNOSE ZA SVE VOZAČE
    for (final vozac in sviVozaci) {
      final detalji = vozaciStats[vozac]!['detaljiNaplata'] as List<Map<String, dynamic>>;
      if (detalji.isNotEmpty) {
        final ukupanIznos = detalji.fold<double>(
          0.0,
          (sum, detalj) => sum + (detalj['iznos'] as num).toDouble(),
        );
        vozaciStats[vozac]!['prosecanIznos'] = ukupanIznos / detalji.length;
      }
    }

    return vozaciStats;
  }

  /// 🎯 PAZAR SAMO OD PUTNIKA - BEZ MESEČNIH KARATA (za admin screen filtriranje po danu)
  static Map<String, double> pazarSamoPutnici(List<Putnik> putnici) {
    // 🎯 DINAMIČKA INICIJALIZACIJA VOZAČA
    final Map<String, double> pazar = {};
    for (final vozac in sviVozaci) {
      pazar[vozac] = 0.0;
    }

    // SABERI PAZAR SAMO IZ PUTNIKA
    for (final putnik in putnici) {
      if (_jePazarValjan(putnik)) {
        final vozac = putnik.vozac!;
        if (pazar.containsKey(vozac)) {
          pazar[vozac] = pazar[vozac]! + putnik.iznosPlacanja!;
        }
      }
    }

    return {...pazar, '_ukupno': pazar.values.fold(0.0, (a, b) => a + b)};
  }

  /// Vraca mapu: {imeVozaca: sumaPazara} i ukupno, za dati period - STANDARDIZOVANO FILTRIRANJE
  /// @deprecated Koristi pazarSvihVozaca() umesto ovoga za konzistentnost
  static Future<Map<String, double>> pazarPoVozacima(
    List<Putnik> putnici,
    DateTime from,
    DateTime to,
  ) async {
    // Preusmeri na novu standardizovanu funkciju
    return await pazarSvihVozaca(putnici, from: from, to: to);
  }

  // 🚗 KILOMETRAŽA FUNKCIJE

  /// Dodaje kilometražu za sve vozače u vozaciStats
  static Future<void> _dodajKilometrazu(
    Map<String, Map<String, dynamic>> vozaciStats,
    DateTime from,
    DateTime to,
  ) async {
    try {
      // ✅ OPTIMIZACIJA: ograniči opseg na maksimalno 7 dana da ne bude previše sporo
      const limitOpseg = Duration(days: 7);
      final opsegDana = to.difference(from);

      if (opsegDana > limitOpseg) {
        from = to.subtract(limitOpseg);
      }

      for (final vozac in sviVozaci) {
        final km = await _kmZaVozaca(vozac, from, to);
        vozaciStats[vozac]!['kilometraza'] = km;
      }
    } catch (e) {
      // Dodeli default vrednosti ako je greška
      for (final vozac in sviVozaci) {
        vozaciStats[vozac]!['kilometraza'] = 0.0;
      }
    }
  }

  /// Računa kilometražu za vozača u datom periodu (SA PAMETNIM FILTRIRANJEM)
  static Future<double> _kmZaVozaca(
    String vozac,
    DateTime from,
    DateTime to,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('gps_lokacije')
          .select()
          .eq('vozac_id', vozac) // ✅ Ispravljen naziv kolone
          .gte('vreme', from.toIso8601String()) // ✅ Ispravljen naziv kolone
          .lte('vreme', to.toIso8601String()) // ✅ Ispravljen naziv kolone
          .order('vreme');

      final lokacije = (response as List).cast<Map<String, dynamic>>();

      if (lokacije.length < 2) return 0.0;

      double ukupno = 0;
      double maksimalnaDistancaPoSegmentu = 5.0; // 5km max po segmentu

      for (int i = 1; i < lokacije.length; i++) {
        final lat1 = (lokacije[i - 1]['latitude'] as num).toDouble(); // ✅ Ispravljen naziv
        final lng1 = (lokacije[i - 1]['longitude'] as num).toDouble(); // ✅ Ispravljen naziv
        final lat2 = (lokacije[i]['latitude'] as num).toDouble(); // ✅ Ispravljen naziv
        final lng2 = (lokacije[i]['longitude'] as num).toDouble(); // ✅ Ispravljen naziv

        final distanca = _distanceKm(lat1, lng1, lat2, lng2);

        // ✅ PAMETAN FILTER: preskoči nerealne distanca (npr. GPS greške)
        if (distanca <= maksimalnaDistancaPoSegmentu && distanca > 0.001) {
          ukupno += distanca;
        } else if (distanca > maksimalnaDistancaPoSegmentu) {}
      }
      return ukupno;
    } catch (e) {
      return 0.0;
    }
  }

  /// � JAVNA METODA: Dobij kilometražu za vozača u određenom periodu
  static Future<double> getKilometrazu(
    String vozac,
    DateTime from,
    DateTime to,
  ) async {
    return await _kmZaVozaca(vozac, from, to);
  }

  /// �🔄 RESETUJ SVE KILOMETRAŽE NA 0 - briše sve GPS pozicije
  static Future<bool> resetujSveKilometraze() async {
    try {
      final supabase = Supabase.instance.client;

      // Obriši sve GPS pozicije iz tabele
      await supabase.from('gps_lokacije').delete().neq('id', 0); // Briše sve redove (neq sa nepostojećim ID)
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 💰 RESETUJ PAZAR ZA ODREĐENOG VOZAČA - briše podatke o naplatama
  static Future<bool> resetujPazarZaVozaca(
    String vozac, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final now = _normalizeDateTime(DateTime.now());
      final fromDate = from ?? DateTime(now.year, now.month, now.day);
      final toDate = to ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

      final supabase = Supabase.instance.client;

      // 1. RESETUJ OBIČNE PUTNIKE - (upit ka tabeli 'putnici' uklonjen po zahtevu)
      // Ova sekcija je prazna jer tabela 'putnici' više nije u upotrebi.

      // 2. RESETUJ MESEČNE KARTE - postavi cena na 0 i obriši vreme_placanja
      try {
        await supabase
            .from('mesecni_putnici')
            .update({
              'cena': 0.0,
              'vreme_placanja': null,
            })
            .eq('vozac', vozac)
            .not('vreme_placanja', 'is', null)
            .gte('vreme_placanja', fromDate.toIso8601String())
            .lte('vreme_placanja', toDate.toIso8601String());
      } catch (e) {
        // ignore: empty_catches
      }
      return true;
    } catch (e) {
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
    List<String> neuspesniVozaci = [];

    for (String vozac in sviVozaci) {
      try {
        bool uspeh = await resetujPazarZaVozaca(vozac, from: from, to: to);
        if (!uspeh) {
          neuspesniVozaci.add(vozac);
        }
      } catch (e) {
        neuspesniVozaci.add(vozac);
      }
    }
    if (neuspesniVozaci.isNotEmpty) {}

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
    return await resetujPazarZaSveVozace(); // Bez from/to parametara = briše sve
  }

  /// Računa rastojanje između dve GPS koordinate u kilometrima (Haversine formula)
  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371; // Radius Zemlje u km
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;
    double a = 0.5 - cos(dLat) / 2 + cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * (1 - cos(dLon)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  // 🆕 CLEAN STATISTIKE METODE - bez duplikata

  /// Dohvati clean statistike bez duplikata
  static Future<Map<String, dynamic>> dohvatiCleanStatistike() async {
    try {
      return await CleanStatistikaService.dohvatiUkupneStatistike();
    } catch (e) {
      dlog('Greška pri dohvatanju clean statistika: $e');
      rethrow;
    }
  }

  /// Proveri da li podaci nemaju duplikate
  static Future<bool> proveriBezDuplikata() async {
    try {
      final stats = await CleanStatistikaService.dohvatiUkupneStatistike();
      return stats['no_duplicates'] as bool;
    } catch (e) {
      dlog('Greška pri proveri duplikata: $e');
      return false;
    }
  }

  /// Dohvati clean mesečne statistike bez duplikata
  static Future<Map<String, dynamic>> getCleanMesecneStatistike(
    int mesec,
    int godina,
  ) async {
    try {
      return await CleanStatistikaService.dohvatiMesecneStatistike(
        mesec,
        godina,
      );
    } catch (e) {
      dlog('Greška pri dohvatanju clean mesečnih statistika: $e');
      rethrow;
    }
  }

  /// Dohvati clean listu svih putnika bez duplikata
  static Future<List<Map<String, dynamic>>> dohvatiCleanSvePutnike() async {
    try {
      return await CleanStatistikaService.dohvatiSvePutnikeClean();
    } catch (e) {
      dlog('Greška pri dohvatanju clean liste putnika: $e');
      rethrow;
    }
  }

  /// Dohvati clean ukupan iznos bez duplikata
  static Future<double> dohvatiCleanUkupanIznos() async {
    try {
      final stats = await CleanStatistikaService.dohvatiUkupneStatistike();
      return (stats['ukupno_sve'] as num).toDouble();
    } catch (e) {
      dlog('Greška pri dohvatanju clean ukupnog iznosa: $e');
      rethrow;
    }
  }

  /// Debug informacije za clean statistike
  static Future<Map<String, dynamic>> cleanDebugInfo() async {
    try {
      final stats = await CleanStatistikaService.dohvatiUkupneStatistike();
      final actualAmount = (stats['ukupno_sve'] as num).toDouble();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'StatistikaService.cleanDebugInfo -> CleanStatistikaService',
        'clean_stats': stats,
        'validation': {
          'no_duplicates': stats['no_duplicates'],
          'actual_amount': actualAmount,
          'total_records': stats['broj_ukupno'],
          'mesecni_records': stats['broj_mesecnih'],
          'standalone_records': stats['broj_standalone'],
        },
      };
    } catch (e) {
      dlog('Greška pri debug info clean statistika: $e');
      rethrow;
    }
  }

  /// � KREIRAJ DAILY_CHECKINS TABELU AKO NE POSTOJI
  static Future<bool> kreirajDailyCheckinsTabelu() async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc<void>('create_daily_checkins_table_if_not_exists');
      return true;
    } catch (e) {
      dlog('Greška pri kreiranju daily_checkins tabele: $e');
      return false;
    }
  }

  /// �🔍 DUBOKA ANALIZA MESEČNIH KARATA ZA DANAŠNJI DAN
  static Future<Map<String, dynamic>> dubokaAnalizaMesecnihKarata() async {
    final danas = DateTime.now();
    final rezultat = <String, dynamic>{};

    try {
      // INFO: Preskačemo kreiranje daily_checkins tabele za sada jer može da pravi probleme
      // Prvo kreiraj tabelu ako ne postoji (tiho)
      // try {
      //   await kreirajDailyCheckinsTabelu();
      // } catch (e) {
      //   // Ignoraj greške pri kreiranju tabele
      //   dlog('Info: Tabela možda već postoji: $e');
      // }

      // Učitaj sve mesečne putnike
      final mesecniService = MesecniPutnikService();
      final sviMesecni = await mesecniService.getAllMesecniPutnici();

      rezultat['ukupno_mesecnih_putnika'] = sviMesecni.length;
      rezultat['datum_analize'] = '${danas.day}.${danas.month}.${danas.year}';
      rezultat['vreme_analize'] = '${danas.hour}:${danas.minute}';

      // Analiza po statusu
      final aktivni = sviMesecni.where((p) => p.aktivan && !p.obrisan).toList();
      final placeni = aktivni.where((p) => p.jePlacen).toList();
      final placeniOvajMesec = placeni
          .where(
            (p) => p.placeniMesec == danas.month && p.placenaGodina == danas.year,
          )
          .toList();

      rezultat['aktivni_putnici'] = aktivni.length;
      rezultat['placeni_putnici'] = placeni.length;
      rezultat['placeni_ovaj_mesec'] = placeniOvajMesec.length;

      // Analiza po vozačima
      final Map<String, Map<String, dynamic>> poVozacima = {};

      for (final putnik in placeniOvajMesec) {
        final vozacUuid = putnik.vozac ?? 'Nepoznat';
        final vozacIme = VozacMappingService.getVozacImeWithFallbackSync(vozacUuid);

        if (!poVozacima.containsKey(vozacIme)) {
          poVozacima[vozacIme] = {
            'broj_putnika': 0,
            'ukupan_iznos': 0.0,
            'putnici': <Map<String, dynamic>>[],
            'vozac_uuid': vozacUuid,
          };
        }

        final iznos = putnik.iznosPlacanja ?? 0.0;
        poVozacima[vozacIme]!['broj_putnika'] = (poVozacima[vozacIme]!['broj_putnika'] as int) + 1;
        poVozacima[vozacIme]!['ukupan_iznos'] = (poVozacima[vozacIme]!['ukupan_iznos'] as double) + iznos;

        (poVozacima[vozacIme]!['putnici'] as List).add({
          'ime': putnik.putnikIme,
          'id': putnik.id,
          'iznos': iznos,
          'placeni_mesec': putnik.placeniMesec,
          'placena_godina': putnik.placenaGodina,
          'vreme_placanja': putnik.vremePlacanja?.toIso8601String(),
          'cena': putnik.cena,
          'ukupna_cena_meseca': putnik.ukupnaCenaMeseca,
        });
      }

      rezultat['analiza_po_vozacima'] = poVozacima;

      // Ukupni pazar
      double ukupanPazar = 0.0;
      for (final vozacData in poVozacima.values) {
        ukupanPazar += vozacData['ukupan_iznos'] as double;
      }
      rezultat['ukupan_pazar_mesecnih'] = ukupanPazar;

      // Problematični putnici
      final problematicni = <Map<String, dynamic>>[];

      for (final putnik in aktivni) {
        final problemi = <String>[];

        if (!putnik.jePlacen) problemi.add('NIJE_PLACEN');
        if (putnik.placeniMesec != danas.month) problemi.add('POGRESAN_MESEC');
        if (putnik.placenaGodina != danas.year) problemi.add('POGRESNA_GODINA');
        if ((putnik.iznosPlacanja ?? 0.0) <= 0) problemi.add('NEMA_IZNOS');
        if (putnik.vozac == null || putnik.vozac!.isEmpty) problemi.add('NEMA_VOZACA');

        if (problemi.isNotEmpty) {
          problematicni.add({
            'ime': putnik.putnikIme,
            'id': putnik.id,
            'problemi': problemi,
            'vozac_uuid': putnik.vozac,
            'vozac_ime': VozacMappingService.getVozacImeWithFallbackSync(putnik.vozac),
            'placeni_mesec': putnik.placeniMesec,
            'placena_godina': putnik.placenaGodina,
            'iznos': putnik.iznosPlacanja,
          });
        }
      }

      rezultat['problematicni_putnici'] = problematicni;
      rezultat['broj_problematicnih'] = problematicni.length;

      return rezultat;
    } catch (e) {
      return {
        'greska': e.toString(),
        'datum_analize': '${danas.day}.${danas.month}.${danas.year}',
        'status': 'NEUSPESNO',
      };
    }
  }
}
