import 'dart:convert';

import '../services/vozac_mapping_service.dart'; // DODATO za UUID<->ime konverziju
import '../utils/registrovani_helpers.dart';

// Enum za statuse putnika
enum PutnikStatus { otkazano, pokupljen, bolovanje, godisnji }

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
  // NOVO - originalni datum za dnevne putnike (ISO yyyy-MM-dd)

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
    this.cena, // ✅ STANDARDIZOVANO: cena umesto iznosPlacanja
    this.naplatioVozac,
    this.pokupioVozac,
    this.dodaoVozac,
    this.vozac,
    required this.grad,
    this.otkazaoVozac,
    this.vremeOtkazivanja,
    this.adresa,
    this.adresaId, // NOVO - UUID reference u tabelu adrese
    this.obrisan = false, // default vrednost
    this.priority, // prioritet za optimizaciju ruta
    this.brojTelefona, // broj telefona putnika
    this.datum,
    this.brojMesta = 1, // 🆕 Broj rezervisanih mesta (default 1)
    this.tipPutnika, // 🆕 Tip putnika: radnik, ucenik, dnevni
    this.otkazanZaPolazak = false, // 🆕 Da li je otkazan za ovaj specifični polazak (grad)
  });

  factory Putnik.fromMap(Map<String, dynamic> map) {
    // Svi podaci dolaze iz registrovani_putnici tabele
    if (map.containsKey('putnik_ime')) {
      return Putnik.fromRegistrovaniPutnici(map);
    }

    // GREŠKA - Nepoznata struktura tabele
    throw Exception(
      'Nepoznata struktura podataka - očekuje se putnik_ime kolona iz registrovani_putnici',
    );
  }

  // NOVI: Factory za registrovani_putnici tabelu
  factory Putnik.fromRegistrovaniPutnici(Map<String, dynamic> map) {
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];
    final grad = _determineGradFromRegistrovani(map);
    // Choose place key: 'bc' for Bela Crkva, 'vs' for Vršac
    final place = grad.toLowerCase().contains('vr') ? 'vs' : 'bc';
    // Only use explicit per-day or JSON values; do not fallback to legacy single-time columns
    final polazakRaw = RegistrovaniHelpers.getPolazakForDay(map, danKratica, place);
    // 🆕 Tip putnika iz baze
    final tipPutnika = map['tip'] as String?;

    // 🆕 Proveri da li je putnik otkazan ZA OVAJ POLAZAK (grad) danas
    final otkazanZaPolazak = RegistrovaniHelpers.isOtkazanForDayAndPlace(map, danKratica, place);
    // 🆕 Čitaj vreme otkazivanja i vozača iz JSON-a (po danu i gradu)
    final vremeOtkazivanja = RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, danKratica, place);
    final otkazaoVozac = RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, danKratica, place);

    // ✅ FIX: Proveri da li je otkazivanje bilo DANAS - ako nije, vrati status na 'radi'
    final statusIzBaze = map['status'] as String? ?? 'radi';
    String status = statusIzBaze;
    if (statusIzBaze == 'otkazan' || statusIzBaze == 'otkazano') {
      // Koristi otkazanZaPolazak umesto vremeOtkazivanja za proveru
      if (!otkazanZaPolazak) {
        status = 'radi';
      }
    }

    return Putnik(
      id: map['id'], // ✅ UUID iz registrovani_putnici
      ime: map['putnik_ime'] as String? ?? '',
      polazak: RegistrovaniHelpers.normalizeTime(polazakRaw?.toString()) ?? '6:00',
      pokupljen: map['status'] == null || (map['status'] != 'bolovanje' && map['status'] != 'godisnji'),
      vremeDodavanja: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      mesecnaKarta: tipPutnika != 'dnevni', // 🆕 FIX: false za dnevni tip
      dan: map['radni_dani'] as String? ?? 'Pon',
      status: status, // ✅ Koristi provereni status
      statusVreme: map['updated_at'] as String?,
      // ✅ NOVO: Čitaj vremePokupljenja iz polasci_po_danu (samo DANAS)
      vremePokupljenja: RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, danKratica, place),
      // ✅ NOVO: Čitaj vremePlacanja iz polasci_po_danu (samo DANAS)
      vremePlacanja: RegistrovaniHelpers.getVremePlacanjaForDayAndPlace(map, danKratica, place),
      placeno: RegistrovaniHelpers.priceIsPaid(map),
      cena: _parseDouble(map['cena']),
      // ✅ NOVO: Čitaj naplatioVozac iz polasci_po_danu (samo DANAS)
      naplatioVozac: RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, danKratica, place) ??
          _getVozacIme(map['vozac_id'] as String?) ??
          _extractDodaoVozacFromArray(map['dodali_vozaci']),
      // ✅ NOVO: Čitaj pokupioVozac iz polasci_po_danu (samo DANAS)
      pokupioVozac: RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, danKratica, place),
      dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']),
      grad: grad,
      adresa: _determineAdresaFromRegistrovani(map, grad), // ✅ FIX: Prosleđujemo grad za konzistentnost
      adresaId: _determineAdresaIdFromRegistrovani(map, grad), // ✅ NOVO - UUID adrese
      obrisan: !RegistrovaniHelpers.isActiveFromMap(map),
      brojTelefona: map['broj_telefona'] as String?,
      brojMesta: (map['broj_mesta'] as int?) ?? 1, // 🆕 Broj rezervisanih mesta
      tipPutnika: tipPutnika, // 🆕 Tip putnika: radnik, ucenik, dnevni
      // ✅ DODATO: Parsiranje vremena otkazivanja i vozača iz JSON-a
      vremeOtkazivanja: vremeOtkazivanja,
      otkazaoVozac: otkazaoVozac,
      otkazanZaPolazak: otkazanZaPolazak, // 🆕 Da li je otkazan za ovaj polazak
    );
  }

  // Helper metoda za čitanje polaska za određeni dan iz novih kolona

  final dynamic id; // UUID iz registrovani_putnici
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
  final double? cena; // ✅ STANDARDIZOVANO: cena umesto iznosPlacanja
  final String? naplatioVozac;
  final String? pokupioVozac; // NOVO - vozač koji je pokupljanje izvršio
  final String? dodaoVozac;
  final String? vozac;
  final String grad;
  final String? otkazaoVozac;
  final DateTime? vremeOtkazivanja; // NOVO - vreme kada je otkazano
  final String? adresa; // NOVO - adresa putnika za optimizaciju rute
  final String? adresaId; // NOVO - UUID reference u tabelu adrese
  final bool obrisan; // NOVO - soft delete flag
  final int? priority; // NOVO - prioritet za optimizaciju ruta (1-5, gde je 1 najmanji)
  final String? brojTelefona; // NOVO - broj telefona putnika
  final String? datum;
  final int brojMesta; // 🆕 Broj rezervisanih mesta (1, 2, 3...)
  final String? tipPutnika; // 🆕 Tip putnika: radnik, ucenik, dnevni
  final bool otkazanZaPolazak; // 🆕 Da li je otkazan za ovaj specifični polazak (grad)

  // 🆕 Helper getter za proveru da li je dnevni tip
  bool get isDnevniTip => tipPutnika == 'dnevni' || mesecnaKarta == false;

  // 🆕 Helper getter za proveru da li je radnik ili ucenik (prikazuje MESEČNA badge)
  // Fallback: ako tipPutnika nije poznat, koristi mesecnaKarta kao indikator
  bool get isMesecniTip =>
      tipPutnika == 'radnik' || tipPutnika == 'ucenik' || (tipPutnika == null && mesecnaKarta == true);

  // Getter-i za kompatibilnost
  String get destinacija => grad;
  String get vremePolaska => polazak;

  // Getter-i za centralizovanu logiku statusa
  // 🆕 IZMENJENO: jeOtkazan sada proverava otkazanZaPolazak (po gradu) umesto globalnog statusa
  // Dodata provera za status 'otkazano' za kompatibilnost
  bool get jeOtkazan =>
      obrisan || otkazanZaPolazak || status?.toLowerCase() == 'otkazano' || status?.toLowerCase() == 'otkazan';

  bool get jeBolovanje => status != null && status!.toLowerCase() == 'bolovanje';

  bool get jeGodisnji => status != null && (status!.toLowerCase() == 'godišnji' || status!.toLowerCase() == 'godisnji');

  bool get jeOdsustvo => jeBolovanje || jeGodisnji;

  // ✅ FIX: jePokupljen mora proveriti da li je pokupljeno DANAS, ne samo da postoji timestamp
  bool get jePokupljen {
    // Ako je pokupljen flag eksplicitno postavljen (iz _createPutniciForDay)
    if (pokupljen == true) return true;

    // Fallback: proveri vremePokupljenja ali SAMO ako je DANAS
    if (vremePokupljenja != null) {
      final danas = DateTime.now();
      final pokupljenDatum = vremePokupljenja!.toLocal();
      return pokupljenDatum.year == danas.year &&
          pokupljenDatum.month == danas.month &&
          pokupljenDatum.day == danas.day;
    }

    // Status pokupljen za dnevne putnike
    return status == 'pokupljen';
  }

  bool get jePlacen => (cena ?? 0) > 0;

  // ✅ KOMPATIBILNOST: getter za stari iznosPlacanja naziv
  double? get iznosPlacanja => cena;

  PutnikStatus? get statusEnum => PutnikStatusExtension.fromString(status);

  // NOVA METODA: Kreira VIŠE putnik objekata za mesečne putnike sa više polazaka
  static List<Putnik> fromRegistrovaniPutniciMultiple(Map<String, dynamic> map) {
    final danas = DateTime.now();
    final trenutniDan = _getDanNedeljeKratica(danas.weekday);
    return _parseAndCreatePutniciForDay(map, trenutniDan);
  }

  // NOVA METODA: Kreira putnik objekte za SPECIFIČAN DAN (umesto trenutni dan)
  static List<Putnik> fromRegistrovaniPutniciMultipleForDay(
    Map<String, dynamic> map,
    String targetDan,
  ) {
    return _parseAndCreatePutniciForDay(map, targetDan);
  }

  // 🆕 HELPER: Zajednička logika za parsiranje i kreiranje putnika
  static List<Putnik> _parseAndCreatePutniciForDay(Map<String, dynamic> map, String targetDan) {
    final ime = map['putnik_ime'] as String? ?? map['ime'] as String? ?? '';
    final danString = map['radni_dani'] as String? ?? 'pon';
    final statusIzBaze = map['status'] as String? ?? 'radi';
    final vremeDodavanja = map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null;
    final vremePlacanja = map['vreme_placanja'] != null ? DateTime.parse(map['vreme_placanja'] as String) : null;

    // ✅ FIX: Status se određuje na osnovu otkazanZaPolazak koji se proverava u _createPutniciForDay
    // Ovde samo prosleđujemo statusIzBaze, a stvarna provera je po gradu
    String status = statusIzBaze;
    final double iznosPlacanja = _parseDouble(map['cena']);
    final bool placeno = iznosPlacanja > 0;
    final vozac = (map['vozac'] as String?) ?? _getVozacIme(map['vozac_id'] as String?);
    final obrisan = map['aktivan'] == false;
    // 🆕 FIX: Čitaj tip putnika iz baze
    final tipPutnika = map['tip'] as String?;

    return _createPutniciForDay(
      map,
      ime,
      danString,
      status,
      vremeDodavanja,
      vremePlacanja,
      placeno,
      iznosPlacanja,
      vozac,
      obrisan,
      targetDan,
      tipPutnika,
    );
  }

  // Helper metoda za kreiranje putnika za određen dan
  static List<Putnik> _createPutniciForDay(
    Map<String, dynamic> map,
    String ime,
    String danString,
    String status,
    DateTime? vremeDodavanja,
    DateTime? vremePlacanja,
    bool placeno,
    double? iznosPlacanja,
    String? vozac,
    bool obrisan,
    String targetDan,
    String? tipPutnika,
  ) {
    final List<Putnik> putnici = [];
    // 🆕 FIX: mesecnaKarta = true samo za radnik i ucenik, false za dnevni
    final bool mesecnaKarta = tipPutnika != 'dnevni';

    // ✅ NOVA LOGIKA: Čitaj vremena iz novih kolona po danima
    // Određi da li putnik radi za targetDan
    final radniDani = danString.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
    final normalizedTarget = targetDan.trim().toLowerCase();

    if (!radniDani.contains(normalizedTarget)) {
      return putnici; // Putnik ne radi za targetDan
    }

    // Čitaj vremena za targetDan koristeći helpers koji kombinuju JSON i stare kolone
    final polazakBC = RegistrovaniHelpers.getPolazakForDay(map, targetDan, 'bc');
    final polazakVS = RegistrovaniHelpers.getPolazakForDay(map, targetDan, 'vs');

    // ✅ NOVO: Čitaj vremena pokupljenja iz polasci_po_danu JSON (samo DANAS)
    final vremePokupljenjaBC = RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, normalizedTarget, 'bc');
    final vremePokupljenjaVS = RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, normalizedTarget, 'vs');

    // ✅ NOVO: Čitaj vozače koji su pokupili iz polasci_po_danu JSON
    final pokupioVozacBC = RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, normalizedTarget, 'bc');
    final pokupioVozacVS = RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, normalizedTarget, 'vs');

    // ✅ NOVO: Čitaj vozače koji su naplatili iz polasci_po_danu JSON
    final naplatioVozacBC = RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, normalizedTarget, 'bc');
    final naplatioVozacVS = RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, normalizedTarget, 'vs');

    // ✅ NOVO: Čitaj adrese iz JOIN-a sa adrese tabelom (ako postoji)
    // JOIN format: adresa_bc: {id, naziv, ulica, broj, grad, koordinate}
    final adresaBcJoin = map['adresa_bc'] as Map<String, dynamic>?;
    final adresaVsJoin = map['adresa_vs'] as Map<String, dynamic>?;

    // Koristi naziv iz JOIN-a, fallback na staro TEXT polje, pa null ako nema
    final adresaBelaCrkva = adresaBcJoin?['naziv'] as String? ?? map['adresa_bela_crkva'] as String?;
    final adresaVrsac = adresaVsJoin?['naziv'] as String? ?? map['adresa_vrsac'] as String?;

    // 🆕 Čitaj "adresa danas" override iz polasci_po_danu JSON
    final adresaDanasBcId = RegistrovaniHelpers.getAdresaDanasIdForDay(map, normalizedTarget, 'bc');
    final adresaDanasBcNaziv = RegistrovaniHelpers.getAdresaDanasNazivForDay(map, normalizedTarget, 'bc');
    final adresaDanasVsId = RegistrovaniHelpers.getAdresaDanasIdForDay(map, normalizedTarget, 'vs');
    final adresaDanasVsNaziv = RegistrovaniHelpers.getAdresaDanasNazivForDay(map, normalizedTarget, 'vs');

    // 🆕 Prioritet: adresa_danas > stalna adresa
    final finalAdresaBc = adresaDanasBcNaziv ?? adresaBelaCrkva;
    final finalAdresaBcId = adresaDanasBcId ?? map['adresa_bela_crkva_id'] as String?;
    final finalAdresaVs = adresaDanasVsNaziv ?? adresaVrsac;
    final finalAdresaVsId = adresaDanasVsId ?? map['adresa_vrsac_id'] as String?;

    // Kreiraj putnik za Bela Crkva ako ima polazak za targetDan
    if (polazakBC != null && polazakBC.isNotEmpty && polazakBC != '00:00:00') {
      // ✅ KORISTI ODVOJENU KOLONU: vreme_pokupljenja_bc za Bela Crkva polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenjaBC != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        pokupljenZaOvajPolazak = true; // Već je provera DANAS u helper funkciji
      }

      putnici.add(
        Putnik(
          id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: polazakBC,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: mesecnaKarta, // 🆕 FIX: koristi izračunatu vrednost
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: status,
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenjaBC, // ✅ NOVO: Iz polasci_po_danu
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          // ✅ NOVO: Čitaj naplatioVozac iz polasci_po_danu
          naplatioVozac: naplatioVozacBC ??
              _getVozacIme(map['vozac_id'] as String?) ??
              _extractDodaoVozacFromArray(map['dodali_vozaci']),
          // ✅ NOVO: Čitaj pokupioVozac iz polasci_po_danu
          pokupioVozac: pokupioVozacBC,
          dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']),
          vozac: vozac,
          grad: 'Bela Crkva',
          adresa: finalAdresaBc, // 🆕 PRIORITET: adresa_danas > stalna adresa
          adresaId: finalAdresaBcId, // 🆕 PRIORITET: adresa_danas_id > stalni ID
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'bc'), // 🆕 Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // 🆕 FIX: dodaj tip putnika
          vremeOtkazivanja: RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, normalizedTarget, 'bc'),
          otkazaoVozac: RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, normalizedTarget, 'bc'),
          otkazanZaPolazak: RegistrovaniHelpers.isOtkazanForDayAndPlace(map, normalizedTarget, 'bc'), // ✅ DODATO
        ),
      );
    }

    // Kreiraj putnik za Vršac ako ima polazak za targetDan
    if (polazakVS != null && polazakVS.isNotEmpty && polazakVS != '00:00:00') {
      // ✅ NOVO: Čitaj vreme pokupljenja iz polasci_po_danu (samo DANAS)
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenjaVS != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        pokupljenZaOvajPolazak = true; // Već je provera DANAS u helper funkciji
      }

      putnici.add(
        Putnik(
          id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: polazakVS,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: mesecnaKarta, // 🆕 FIX: koristi izračunatu vrednost
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: status,
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenjaVS, // ✅ NOVO: Iz polasci_po_danu
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          // ✅ NOVO: Čitaj naplatioVozac iz polasci_po_danu
          naplatioVozac: naplatioVozacVS ??
              _getVozacIme(map['vozac_id'] as String?) ??
              _extractDodaoVozacFromArray(map['dodali_vozaci']),
          // ✅ NOVO: Čitaj pokupioVozac iz polasci_po_danu
          pokupioVozac: pokupioVozacVS,
          dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']),
          vozac: vozac,
          grad: 'Vršac',
          adresa: finalAdresaVs, // 🆕 PRIORITET: adresa_danas > stalna adresa
          adresaId: finalAdresaVsId, // 🆕 PRIORITET: adresa_danas_id > stalni ID
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'vs'), // 🆕 Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // 🆕 FIX: dodaj tip putnika
          vremeOtkazivanja: RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, normalizedTarget, 'vs'),
          otkazaoVozac: RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, normalizedTarget, 'vs'),
          otkazanZaPolazak: RegistrovaniHelpers.isOtkazanForDayAndPlace(map, normalizedTarget, 'vs'), // ✅ DODATO
        ),
      );
    }

    return putnici;
  }

  // HELPER FUNKCIJA - Parseovanje double iz različitih tipova
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // HELPER METODE za mapiranje
  static String _determineGradFromRegistrovani(Map<String, dynamic> map) {
    // Odredi grad na osnovu AKTIVNOG polaska za danas
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];

    // Proveri koji polazak postoji za danas
    final bcPolazak = RegistrovaniHelpers.getPolazakForDay(map, danKratica, 'bc');
    final vsPolazak = RegistrovaniHelpers.getPolazakForDay(map, danKratica, 'vs');

    // Ako ima BC polazak danas, putnik putuje IZ Bela Crkva (pokupljaš ga tamo)
    if (bcPolazak != null && bcPolazak.toString().isNotEmpty) {
      return 'Bela Crkva';
    }

    // Ako ima VS polazak danas, putnik putuje IZ Vršac (pokupljaš ga tamo)
    if (vsPolazak != null && vsPolazak.toString().isNotEmpty) {
      return 'Vršac';
    }

    // Fallback: proveri adrese ako nema polazaka danas
    final adresaVS = map['adresa_vrsac'] as String?;
    if (adresaVS != null && adresaVS.trim().isNotEmpty) {
      return 'Vršac';
    }

    return 'Bela Crkva';
  }

  static String? _determineAdresaFromRegistrovani(Map<String, dynamic> map, String grad) {
    // ✅ FIX: Koristi grad parametar za određivanje adrese umesto ponovnog računanja
    // Ovo osigurava konzistentnost između grad i adresa polja

    // ✅ NOVO: Čitaj adresu iz JOIN objekta (adresa_bc, adresa_vs)
    String? adresaBC;
    String? adresaVS;

    // Proveri da li postoji JOIN objekat za BC adresu
    final adresaBcObj = map['adresa_bc'] as Map<String, dynamic>?;
    if (adresaBcObj != null) {
      adresaBC = adresaBcObj['naziv'] as String? ?? '${adresaBcObj['ulica'] ?? ''} ${adresaBcObj['broj'] ?? ''}'.trim();
      if (adresaBC.isEmpty) adresaBC = null;
    }
    // Fallback na staru kolonu ako nema JOIN
    adresaBC ??= map['adresa_bela_crkva'] as String?;

    // Proveri da li postoji JOIN objekat za VS adresu
    final adresaVsObj = map['adresa_vs'] as Map<String, dynamic>?;
    if (adresaVsObj != null) {
      adresaVS = adresaVsObj['naziv'] as String? ?? '${adresaVsObj['ulica'] ?? ''} ${adresaVsObj['broj'] ?? ''}'.trim();
      if (adresaVS.isEmpty) adresaVS = null;
    }
    // Fallback na staru kolonu ako nema JOIN
    adresaVS ??= map['adresa_vrsac'] as String?;

    // ✅ FIX: Koristi grad parametar za određivanje ispravne adrese
    // Ako je grad Bela Crkva, koristi BC adresu (gde pokupljaš putnika)
    // Ako je grad Vršac, koristi VS adresu
    if (grad.toLowerCase().contains('bela') || grad.toLowerCase().contains('bc')) {
      return adresaBC ?? adresaVS ?? 'Adresa nije definisana';
    }

    // Za Vršac ili bilo koji drugi grad, koristi VS adresu
    return adresaVS ?? adresaBC ?? 'Adresa nije definisana';
  }

  static String? _determineAdresaIdFromRegistrovani(Map<String, dynamic> map, String grad) {
    // Koristi UUID reference na osnovu grada
    if (grad.toLowerCase().contains('bela')) {
      return map['adresa_bela_crkva_id'] as String?;
    } else {
      return map['adresa_vrsac_id'] as String?;
    }
  }

  // 🆕 MAPIRANJE ZA registrovani_putnici TABELU
  Map<String, dynamic> toRegistrovaniPutniciMap() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return {
      // 'id': id, // Uklonjen - Supabase će auto-generirati UUID
      'putnik_ime': ime,
      'tip': 'radnik', // ili 'ucenik' - treba logiku za određivanje
      'tip_skole': null, // ✅ NOVA KOLONA - možda treba logika
      'broj_telefona': brojTelefona,
      // Store per-day polasci as canonical JSON
      'polasci_po_danu': jsonEncode({
        // map display day (Pon/Uto/...) to kratica used by registrovani_putnici
        (() {
          final map = {
            'Pon': 'pon',
            'Uto': 'uto',
            'Sre': 'sre',
            'Čet': 'cet',
            'Cet': 'cet',
            'Pet': 'pet',
            'Sub': 'sub',
            'Ned': 'ned',
          };
          return map[dan] ?? dan.toLowerCase().substring(0, 3);
        })(): grad == 'Bela Crkva' ? {'bc': polazak} : {'vs': polazak},
      }),
      'adresa_bela_crkva': grad == 'Bela Crkva' ? adresa : null,
      'adresa_vrsac': grad == 'Vršac' ? adresa : null,
      'tip_prikazivanja': null, // ✅ NOVA KOLONA - možda treba logika
      'radni_dani': dan,
      'aktivan': !obrisan,
      'status': status ?? 'radi', // ✅ JEDNOSTAVNO - jedna kolona
      'datum_pocetka_meseca': startOfMonth.toIso8601String().split('T')[0], // OBAVEZNO
      'datum_kraja_meseca': endOfMonth.toIso8601String().split('T')[0], // OBAVEZNO
      'ukupna_cena_meseca': iznosPlacanja ?? 0.0,
      'broj_putovanja': 0,
      'broj_otkazivanja': 0,
      // UUID validacija za vozac_id
      'vozac_id': (vozac?.isEmpty ?? true) ? null : vozac,
      'created_at': vremeDodavanja?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Helper metoda za dobijanje kratice dana u nedelji

  static String _getDanNedeljeKratica(int weekday) {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return daniKratice[weekday - 1];
  }

  // ✅ HELPER: Izvlači prvi element iz dodali_vozaci arraya
  // 🔧 FIX: Konvertuje UUID u ime vozača ako je potrebno
  static String? _extractDodaoVozacFromArray(dynamic dodaliVozaci) {
    if (dodaliVozaci == null) return null;
    if (dodaliVozaci is List && dodaliVozaci.isNotEmpty) {
      final value = dodaliVozaci[0]?.toString();
      // Konvertuj UUID u ime ako je potrebno
      return _getVozacImeOrDirect(value);
    }
    return null;
  }

  // ✅ CENTRALIZOVANO: Konvertuj UUID u ime vozača sa fallback-om
  static String? _getVozacIme(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;
    return VozacMappingService.getVozacImeWithFallbackSync(uuid) ?? _mapUuidToVozacHardcoded(uuid);
  }

  // ✅ NOVO: Ako je već ime vozača (ne UUID), vrati direktno; inače konvertuj UUID u ime
  static String? _getVozacImeOrDirect(String? value) {
    if (value == null || value.isEmpty) return null;
    // Ako je kraće od 20 karaktera i nema '-', verovatno je već ime
    if (value.length < 20 && !value.contains('-')) {
      return value; // Već je ime (Bojan, Bruda, itd.)
    }
    // Inače je UUID - konvertuj u ime
    return _getVozacIme(value);
  }

  // ✅ FALLBACK MAPIRANJE UUID -> VOZAČ IME
  static String? _mapUuidToVozacHardcoded(String? uuid) {
    if (uuid == null) return null;

    switch (uuid) {
      case '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e':
        return 'Bojan';
      case '5b379394-084e-1c7d-76bf-fc193a5b6c7d':
        return 'Svetlana';
      case '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f':
        return 'Bruda';
      case '8e6ac6c7-3b5b-4f0g-a9f2-2f4c5d8e9f0g':
        return 'Bilevski';
      case '67ea0a22-689c-41b8-b576-5b27145e8e5e':
        return 'Ivan';
      default:
        return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎯 EQUALITY OPERATORS - za stabilno mapiranje u Map<Putnik, Position>
  // 🔧 FIX: Uključi SVE relevantne atribute za detekciju promena iz realtime-a
  // ═══════════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Putnik) return false;

    // 🔧 FIX: Poredi SVE relevantne atribute, ne samo id
    // Ovo omogućava da didUpdateWidget detektuje promene iz realtime-a
    return id == other.id &&
        ime == other.ime &&
        grad == other.grad &&
        polazak == other.polazak &&
        status == other.status &&
        pokupljen == other.pokupljen &&
        placeno == other.placeno &&
        cena == other.cena &&
        vremePokupljenja == other.vremePokupljenja &&
        vremeOtkazivanja == other.vremeOtkazivanja &&
        otkazanZaPolazak == other.otkazanZaPolazak;
  }

  @override
  int get hashCode {
    // Koristi samo stabilne atribute za hash (id ili ime+grad+polazak)
    if (id != null) {
      return id.hashCode;
    }
    return Object.hash(ime, grad, polazak);
  }
}
