// Enum za statuse putnika
enum PutnikStatus {
  otkazano,
  pokupljen,
  bolovanje,
  godisnji,
}

// Extension za konverziju između enum-a i string-a
extension PutnikStatusExtension on PutnikStatus {
  String get value {
    switch (this) {
      case PutnikStatus.otkazano:
        return 'Otkazano';
      case PutnikStatus.pokupljen:
        return 'Pokupljen';
      case PutnikStatus.bolovanje:
        return 'Bolovanje';
      case PutnikStatus.godisnji:
        return 'Godišnji';
    }
  }

  static PutnikStatus? fromString(String? status) {
    if (status == null) return null;

    switch (status.toLowerCase()) {
      case 'otkazano':
      case 'otkazan': // Podržava stare vrednosti
        return PutnikStatus.otkazano;
      case 'pokupljen':
        return PutnikStatus.pokupljen;
      case 'bolovanje':
        return PutnikStatus.bolovanje;
      case 'godišnji':
      case 'godisnji':
        return PutnikStatus.godisnji;
      default:
        return null;
    }
  }
}

class Putnik {
  final dynamic
      id; // ✅ Može biti int (putovanja_istorija) ili String (mesecni_putnici)
  final String ime;
  final String polazak;
  final bool? pokupljen;
  final DateTime? vremeDodavanja; // ✅ DateTime
  final bool? mesecnaKarta;
  final String dan;
  final String? status;
  final String? statusVreme;
  final DateTime? vremePokupljenja; // ✅ DateTime
  final DateTime? vremePlacanja; // ✅ DateTime
  final bool? placeno;
  final double? iznosPlacanja;
  final String? naplatioVozac;
  final String? dodaoVozac;
  final String? vozac;
  final String grad;
  final String? otkazaoVozac;
  final DateTime? vremeOtkazivanja; // NOVO - vreme kada je otkazano
  final String? adresa; // NOVO - adresa putnika za optimizaciju rute
  final bool obrisan; // NOVO - soft delete flag
  final int?
      priority; // NOVO - prioritet za optimizaciju ruta (1-5, gde je 1 najmanji)
  final String? brojTelefona; // NOVO - broj telefona putnika
  final double? depozit; // NOVO - depozit vozača za ovaj dan

  Putnik({
    this.id,
    required this.ime,
    required this.polazak,
    this.pokupljen,
    this.vremeDodavanja,
    this.mesecnaKarta,
    required this.dan,
    this.status,
    this.statusVreme,
    this.vremePokupljenja,
    this.vremePlacanja,
    this.placeno,
    this.iznosPlacanja,
    this.naplatioVozac,
    this.dodaoVozac,
    this.vozac,
    required this.grad,
    this.otkazaoVozac,
    this.vremeOtkazivanja,
    this.adresa,
    this.obrisan = false, // default vrednost
    this.priority, // prioritet za optimizaciju ruta
    this.brojTelefona, // broj telefona putnika
    this.depozit, // depozit vozača
  });

  // Getter-i za kompatibilnost
  String get destinacija => grad;
  String get vremePolaska => polazak;
  String get datumPolaska => DateTime.now()
      .toIso8601String()
      .split('T')[0]; // Današnji datum kao placeholder

  // Getter-i za centralizovanu logiku statusa
  bool get jeOtkazan =>
      status != null &&
      (status!.toLowerCase() == 'otkazano' ||
          status!.toLowerCase() == 'otkazan');

  bool get jeBolovanje =>
      status != null && status!.toLowerCase() == 'bolovanje';

  bool get jeGodisnji =>
      status != null &&
      (status!.toLowerCase() == 'godišnji' ||
          status!.toLowerCase() == 'godisnji');

  bool get jeOdsustvo => jeBolovanje || jeGodisnji;

  bool get jePokupljen => vremePokupljenja != null;

  bool get jePlacen => (iznosPlacanja ?? 0) > 0;

  PutnikStatus? get statusEnum => PutnikStatusExtension.fromString(status);

  factory Putnik.fromMap(Map<String, dynamic> map) {
    // AUTOMATSKA DETEKCIJA TIPA TABELE - SAMO NOVE TABELE

    // Ako ima mesecni_putnik_id ili tip_putnika, iz putovanja_istorija tabele
    if (map.containsKey('mesecni_putnik_id') ||
        map.containsKey('tip_putnika')) {
      return Putnik.fromPutovanjaIstorija(map);
    }

    // Ako ima putnik_ime ili polazak_bela_crkva, iz mesecni_putnici tabele
    if (map.containsKey('putnik_ime') ||
        map.containsKey('polazak_bela_crkva')) {
      return Putnik.fromMesecniPutnici(map);
    }

    // GREŠKA - Nepoznata struktura tabele
    throw Exception(
        'Nepoznata struktura podataka - nisu iz mesecni_putnici ni putovanja_istorija');
  }

  // NOVI: Factory za mesecni_putnici tabelu
  factory Putnik.fromMesecniPutnici(Map<String, dynamic> map) {
    return Putnik(
      id: map['id'], // ✅ UUID iz mesecni_putnici
      ime: map['putnik_ime'] as String? ?? '',
      polazak: map['polazak_bela_crkva']?.toString() ??
          map['polazak_vrsac']?.toString() ??
          '6:00',
      pokupljen: map['status'] == null ||
          (map['status'] != 'bolovanje' && map['status'] != 'godisnji'),
      vremeDodavanja:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      mesecnaKarta: true, // uvek true za mesečne putnike
      dan: map['radni_dani'] as String? ?? 'Pon',
      status: map['status'] as String? ?? 'radi', // ✅ JEDNOSTAVNO
      statusVreme: map['updated_at'] as String?,
      vremePokupljenja: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje']).toLocal()
          : (map['vreme_pokupljenja'] != null
              ? DateTime.parse(map['vreme_pokupljenja']).toLocal()
              : null), // ✅ FALLBACK na vreme_pokupljenja kolonu
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja']).toLocal()
          : null, // ✅ ČITAJ iz vreme_placanja umesto datum_pocetka_meseca
      placeno: (map['cena'] as double? ?? 0) > 0, // koristi cena kolonu
      iznosPlacanja: map['cena'] as double?, // koristi cena kolonu
      naplatioVozac: map['vozac'] as String?, // ✅ ČITAJ vozača iz vozac kolone
      dodaoVozac: map['vozac'] as String?, // ✅ ČITAJ vozača iz vozac kolone
      vozac: map['vozac'] as String?, // ✅ ČITAJ vozača iz vozac kolone
      grad: _determineGradFromMesecni(map),
      otkazaoVozac: null,
      vremeOtkazivanja: null,
      adresa: _determineAdresaFromMesecni(map),
      obrisan: map['aktivan'] != true, // Koristi aktivan kolonu umesto obrisan
      brojTelefona: map['broj_telefona'] as String?,
      depozit: map['depozit'] as double?,
    );
  }

  // NOVA METODA: Kreira VIŠE putnik objekata za mesečne putnike sa više polazaka
  static List<Putnik> fromMesecniPutniciMultiple(Map<String, dynamic> map) {
    final List<Putnik> putnici = [];
    final ime = map['putnik_ime'] as String? ?? map['ime'] as String? ?? '';
    final dan = map['radni_dani'] as String? ?? 'Pon';
    final status = map['status'] as String? ?? 'radi'; // ✅ JEDNOSTAVNO
    final vremeDodavanja =
        map['created_at'] != null ? DateTime.parse(map['created_at']) : null;
    final vremePokupljenja = map['poslednje_putovanje'] != null
        ? DateTime.parse(map['poslednje_putovanje'])
        : (map['vreme_pokupljenja'] != null
            ? DateTime.parse(map['vreme_pokupljenja'])
            : null); // ✅ FALLBACK na vreme_pokupljenja
    final vremePlacanja = map['vreme_placanja'] != null
        ? DateTime.parse(map['vreme_placanja'])
        : null; // ✅ ČITAJ iz vreme_placanja
    final placeno = (map['cena'] as double? ?? 0) > 0; // čita iz cena kolone
    final iznosPlacanja = map['cena'] as double?; // čita iz cena kolone
    final vozac = map['vozac'] as String?; // ✅ ČITAJ vozača
    final obrisan = map['aktivan'] == false;

    // Kreiraj putnik za Bela Crkva ako ima polazak
    if (map['polazak_bela_crkva'] != null &&
        map['polazak_bela_crkva'].toString().isNotEmpty &&
        map['polazak_bela_crkva'].toString() != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null &&
          status != 'bolovanje' &&
          status != 'godisnji' &&
          status != 'otkazan') {
        final polazakVreme = map['polazak_bela_crkva'].toString();
        final pokupljenVreme = vremePokupljenja;

        // Pokupljen je za ovaj polazak ako je pokupljen u periodu ± 3 sata od polaska
        final polazakSati = int.tryParse(polazakVreme.split(':')[0]) ?? 0;
        final pokupljenSati = pokupljenVreme.hour;

        // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
        final razlika = (pokupljenSati - polazakSati).abs();
        pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
      }

      putnici.add(Putnik(
        id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
        ime: ime,
        polazak: map['polazak_bela_crkva'].toString(),
        pokupljen: pokupljenZaOvajPolazak,
        vremeDodavanja: vremeDodavanja,
        mesecnaKarta: true,
        dan: dan,
        status: status,
        statusVreme: map['updated_at'] as String?,
        vremePokupljenja: vremePokupljenja,
        vremePlacanja: vremePlacanja,
        placeno: placeno,
        iznosPlacanja: iznosPlacanja,
        naplatioVozac: vozac, // ✅ KORISTI vozač varijablu
        dodaoVozac: vozac, // ✅ KORISTI vozač varijablu
        vozac: vozac, // ✅ KORISTI vozač varijablu
        grad: 'Bela Crkva',
        otkazaoVozac: null,
        vremeOtkazivanja: null,
        adresa: map['adresa_bela_crkva'] as String?,
        obrisan: obrisan,
        brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
        depozit: map['depozit'] as double?, // ✅ DODATO
      ));
    }

    // Kreiraj putnik za Vršac ako ima polazak
    if (map['polazak_vrsac'] != null &&
        map['polazak_vrsac'].toString().isNotEmpty &&
        map['polazak_vrsac'].toString() != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null &&
          status != 'bolovanje' &&
          status != 'godisnji' &&
          status != 'otkazan') {
        final polazakVreme = map['polazak_vrsac'].toString();
        final pokupljenVreme = vremePokupljenja;

        // Pokupljen je za ovaj polazak ako je pokupljen u periodu ± 3 sata od polaska
        final polazakSati = int.tryParse(polazakVreme.split(':')[0]) ?? 0;
        final pokupljenSati = pokupljenVreme.hour;

        // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
        final razlika = (pokupljenSati - polazakSati).abs();
        pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
      }

      putnici.add(Putnik(
        id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
        ime: ime,
        polazak: map['polazak_vrsac'].toString(),
        pokupljen: pokupljenZaOvajPolazak,
        vremeDodavanja: vremeDodavanja,
        mesecnaKarta: true,
        dan: dan,
        status: status,
        statusVreme: map['updated_at'] as String?,
        vremePokupljenja: vremePokupljenja,
        vremePlacanja: vremePlacanja,
        placeno: placeno,
        iznosPlacanja: iznosPlacanja,
        naplatioVozac: vozac, // ✅ KORISTI vozač varijablu
        dodaoVozac: vozac, // ✅ KORISTI vozač varijablu
        vozac: vozac, // ✅ KORISTI vozač varijablu
        grad: 'Vršac',
        otkazaoVozac: null,
        vremeOtkazivanja: null,
        adresa: map['adresa_vrsac'] as String?,
        obrisan: obrisan,
        brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
        depozit: map['depozit'] as double?, // ✅ DODATO
      ));
    }

    return putnici;
  }

  // NOVI: Factory za putovanja_istorija tabelu
  factory Putnik.fromPutovanjaIstorija(Map<String, dynamic> map) {
    return Putnik(
      id: map['id'], // ✅ UUID iz putovanja_istorija
      ime: map['putnik_ime'] as String? ?? '',
      polazak: _formatVremePolaska(map['vreme_polaska']?.toString() ?? '6:00'),
      pokupljen: map['status'] == 'pokupljen', // ✅ NOVA LOGIKA - jednostavno
      vremeDodavanja:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      mesecnaKarta: map['tip_putnika'] == 'mesecni',
      dan: _determineDanFromDatum(map['datum']),
      status: map['status'] as String?, // ✅ DIREKTNO IZ NOVE KOLONE
      statusVreme: map['vreme_akcije'] as String?,
      vremePokupljenja:
          map['vreme_akcije'] != null && map['status'] == 'pokupljen'
              ? DateTime.parse(map['vreme_akcije'])
              : null,
      vremePlacanja: map['cena'] != null && (map['cena'] as double) > 0
          ? (map['vreme_akcije'] != null
              ? DateTime.parse(map['vreme_akcije'])
              : null)
          : null,
      placeno: (map['cena'] as double? ?? 0) > 0,
      iznosPlacanja: map['cena'] as double?,
      naplatioVozac: null, // putovanja_istorija nema ovu kolonu
      dodaoVozac: null, // putovanja_istorija nema ovu kolonu
      vozac: null, // putovanja_istorija nema ovu kolonu
      grad: map['adresa_polaska'] as String? ?? 'Bela Crkva',
      otkazaoVozac: null,
      vremeOtkazivanja: null,
      adresa: map['adresa_polaska'] as String?,
      obrisan: map['obrisan'] == true, // ✅ Sada čita iz obrisan kolone
      brojTelefona: map['broj_telefona'] as String?,
      depozit: map['depozit'] as double?,
    );
  }

  // HELPER FUNKCIJA - Formatiranje vremena iz 06:00:00 u 6:00
  static String _formatVremePolaska(String vremeString) {
    if (vremeString.contains(':')) {
      // Parse 06:00:00 format
      final parts = vremeString.split(':');
      if (parts.isNotEmpty) {
        final hour = int.tryParse(parts[0]) ?? 6;
        final minute =
            parts.length > 1 ? (parts[1] == '00' ? '00' : parts[1]) : '00';
        // Ako su minuti 00, ne prikazuj ih; inače prikazuj
        if (minute == '00') {
          return '$hour:00';
        } else {
          return '$hour:$minute';
        }
      }
    }
    return vremeString;
  }

  // HELPER METODE za mapiranje
  static String _determineGradFromMesecni(Map<String, dynamic> map) {
    if (map['adresa_bela_crkva'] != null &&
        map['adresa_bela_crkva'].toString().isNotEmpty) {
      return 'Bela Crkva';
    } else if (map['adresa_vrsac'] != null &&
        map['adresa_vrsac'].toString().isNotEmpty) {
      return 'Vršac';
    }
    return 'Bela Crkva'; // default
  }

  static String? _determineAdresaFromMesecni(Map<String, dynamic> map) {
    if (map['adresa_bela_crkva'] != null &&
        map['adresa_bela_crkva'].toString().isNotEmpty) {
      return map['adresa_bela_crkva'] as String;
    } else if (map['adresa_vrsac'] != null &&
        map['adresa_vrsac'].toString().isNotEmpty) {
      return map['adresa_vrsac'] as String;
    }
    return null;
  }

  static String _determineDanFromDatum(String? datum) {
    if (datum == null) return 'Pon';
    try {
      final date = DateTime.parse(datum);
      const dani = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      return dani[date.weekday - 1];
    } catch (e) {
      return 'Pon';
    }
  }

  // 🆕 MAPIRANJE ZA MESECNI_PUTNICI TABELU
  Map<String, dynamic> toMesecniPutniciMap() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return {
      // 'id': id, // Uklonjen - Supabase će auto-generirati UUID
      'putnik_ime': ime,
      'tip': 'radnik', // ili 'ucenik' - treba logiku za određivanje
      'tip_skole': null, // ✅ NOVA KOLONA - možda treba logika
      'broj_telefona': brojTelefona,
      'polazak_bela_crkva': grad == 'Bela Crkva' ? polazak : null,
      'adresa_bela_crkva': grad == 'Bela Crkva' ? adresa : null,
      'polazak_vrsac': grad == 'Vršac' ? polazak : null,
      'adresa_vrsac': grad == 'Vršac' ? adresa : null,
      'tip_prikazivanja': null, // ✅ NOVA KOLONA - možda treba logika
      'radni_dani': dan,
      'aktivan': !obrisan,
      'status': status ?? 'radi', // ✅ JEDNOSTAVNO - jedna kolona
      'datum_pocetka_meseca':
          startOfMonth.toIso8601String().split('T')[0], // OBAVEZNO
      'datum_kraja_meseca':
          endOfMonth.toIso8601String().split('T')[0], // OBAVEZNO
      'ukupna_cena_meseca':
          iznosPlacanja ?? 0.0, // možda treba cena umesto ovoga
      'broj_putovanja': 0, // ✅ NOVA KOLONA - default 0
      'broj_otkazivanja': 0, // ✅ NOVA KOLONA - default 0
      'poslednje_putovanje':
          vremePokupljenja?.toIso8601String(), // ✅ TIMESTAMP format
      // Ne uključujemo 'obrisan' kolonu za putovanja_istorija tabelu
      'depozit': depozit ?? 0.0,
      'created_at': vremeDodavanja?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Helper metoda - konvertuje dan u datum sledeće nedelje za taj dan
  String _getDateForDay(String dan) {
    print('🔍 _getDateForDay pozvan sa dan: "$dan"');
    final now = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final dayNamesLower = ['pon', 'uto', 'sre', 'čet', 'pet', 'sub', 'ned'];

    // Probaj sa originalnim formatom
    int targetDayIndex = dayNames.indexOf(dan);
    print('🔍 Prvi pokušaj (velikim): $targetDayIndex');

    // Ako nije pronađen, probaj sa malim slovima
    if (targetDayIndex == -1) {
      targetDayIndex = dayNamesLower.indexOf(dan.toLowerCase());
      print('🔍 Drugi pokušaj (malim): $targetDayIndex');
      print('🔍 Tražim "${dan.toLowerCase()}" u $dayNamesLower');
    }

    print('🔍 Konačni targetDayIndex za "$dan": $targetDayIndex');
    if (targetDayIndex == -1) {
      // Ako dan nije valjan, koristi današnji datum
      print('⚠️ INVALID DAN: "$dan" - koristim današnji datum');
      return now.toIso8601String().split('T')[0];
    }
    final currentDayIndex = now.weekday - 1; // Monday = 0
    print('🔍 currentDayIndex (today): $currentDayIndex');

    // Izračunaj koliko dana treba dodati da dođemo do ciljnog dana
    int daysToAdd;
    if (targetDayIndex >= currentDayIndex) {
      // Ciljni dan je u ovoj nedelji ili danas
      daysToAdd = targetDayIndex - currentDayIndex;
    } else {
      // Ciljni dan je u sledećoj nedelji
      daysToAdd = (7 - currentDayIndex) + targetDayIndex;
    }

    print('🔍 daysToAdd: $daysToAdd');
    final targetDate = now.add(Duration(days: daysToAdd));
    final result = targetDate.toIso8601String().split('T')[0];
    print('🔍 Final result: $result (${dayNames[targetDate.weekday - 1]})');
    return result;
  } // NOVI: Mapiranje za putovanja_istorija tabelu

  Map<String, dynamic> toPutovanjaIstorijaMap() {
    return {
      // 'id': id, // Uklonjen - Supabase će automatski generirati UUID
      'mesecni_putnik_id': mesecnaKarta == true ? id : null,
      'tip_putnika': mesecnaKarta == true ? 'mesecni' : 'dnevni',
      'datum': _getDateForDay(dan), // koristi izabrani dan umesto dagens datum
      'dan': dan, // ✅ DODATO NAZAD - dodajemo kolonu dan u tabelu
      'grad': grad, // ✅ DODATO NAZAD - dodajemo kolonu grad u tabelu
      'vreme_polaska': polazak,
      'vreme_akcije': vremePokupljenja?.toIso8601String() ??
          vremePlacanja?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'adresa_polaska': adresa ??
          (grad == 'Bela Crkva'
              ? 'Bela Crkva centar'
              : 'Vršac centar'), // ✅ DODAJ DEFAULT ADRESU
      'putnik_ime': ime,
      'broj_telefona': brojTelefona,
      'cena': iznosPlacanja ?? 0.0,
      'depozit': depozit ?? 0.0,
      'status': status, // ✅ NOVA JEDNOSTAVNA KOLONA
      'created_at':
          vremeDodavanja?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(), // ✅ NOVA KOLONA
    };
  }
}
