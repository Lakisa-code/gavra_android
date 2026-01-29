import 'dart:convert';

import '../services/adresa_supabase_service.dart'; // DODATO za fallback učitavanje adrese
import '../services/vozac_mapping_service.dart'; // DODATO za UUID<->ime konverziju
import '../services/vreme_vozac_service.dart'; // ?? Za per-vreme dodeljivanje vozaca
import '../utils/registrovani_helpers.dart';

// Enum za statuse putnika
enum PutnikStatus { otkazano, pokupljen, bolovanje, godisnji }

// Extension za konverziju izmedu enum-a i string-a
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
    this.cena, // ? STANDARDIZOVANO: cena umesto iznosPlacanja
    this.naplatioVozac,
    this.pokupioVozac,
    this.dodeljenVozac,
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
    this.brojMesta = 1, // ?? Broj rezervisanih mesta (default 1)
    this.tipPutnika, // ?? Tip putnika: radnik, ucenik, dnevni
    this.otkazanZaPolazak = false, // ?? Da li je otkazan za ovaj specificni polazak (grad)
  });

  factory Putnik.fromMap(Map<String, dynamic> map) {
    // Svi podaci dolaze iz registrovani_putnici tabele
    if (map.containsKey('putnik_ime')) {
      return Putnik.fromRegistrovaniPutnici(map);
    }

    // GREŠKA - Struktura tabele nije prepoznata
    throw Exception(
      'Struktura podataka nije prepoznata - ocekuje se putnik_ime kolona iz registrovani_putnici',
    );
  }

  // NOVI: Factory za registrovani_putnici tabelu
  factory Putnik.fromRegistrovaniPutnici(Map<String, dynamic> map) {
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];
    final grad = _determineGradFromRegistrovani(map);
    // Choose place key: 'bc' for Bela Crkva, 'vs' for Vršac
    final place = grad.toLowerCase().contains('vr') || grad.contains('Vršac') ? 'vs' : 'bc';
    // Only use explicit per-day or JSON values; do not fallback to legacy single-time columns
    final polazakRaw = RegistrovaniHelpers.getPolazakForDay(map, danKratica, place);
    // ?? Tip putnika iz baze
    final tipPutnika = map['tip'] as String?;

    // ?? Proveri da li je putnik otkazan ZA OVAJ POLAZAK (grad) danas
    final otkazanZaPolazak = RegistrovaniHelpers.isOtkazanForDayAndPlace(map, danKratica, place);
    // ?? Citaj vreme otkazivanja i vozaca iz JSON-a (po danu i gradu)
    final vremeOtkazivanja = RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, danKratica, place);
    final otkazaoVozac = RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, danKratica, place);

    // ? FIX: Proveri status. Bolovanje i godisnji su globalni, ostalo je po polasku.
    final statusIzBaze = map['status'] as String? ?? 'radi';
    String status = statusIzBaze;
    if (statusIzBaze != 'bolovanje' && statusIzBaze != 'godisnji') {
      if (otkazanZaPolazak) {
        status = 'otkazan';
      } else {
        status = 'radi';
      }
    }

    // ? FIX: Citaj pokupljenje iz polasci_po_danu JSON-a (ne iz status kolone)
    final vremePokupljenja = RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, danKratica, place);
    final jePokupljenDanas = vremePokupljenja != null;

    final vremePlacanja = RegistrovaniHelpers.getVremePlacanjaForDayAndPlace(map, danKratica, place);
    final isDnevni = tipPutnika == 'dnevni' || tipPutnika == 'posiljka';

    return Putnik(
      id: map['id'], // ? UUID iz registrovani_putnici
      ime: map['putnik_ime'] as String? ?? '',
      polazak: RegistrovaniHelpers.normalizeTime(polazakRaw?.toString()) ?? '6:00',
      pokupljen: jePokupljenDanas, // ? FIX: Koristi stvarno pokupljenje iz JSON-a
      vremeDodavanja: map['created_at'] != null ? DateTime.parse(map['created_at'] as String).toLocal() : null,
      mesecnaKarta: tipPutnika != 'dnevni' && tipPutnika != 'posiljka', // ?? FIX: false za dnevni i posiljku
      dan: map['radni_dani'] as String? ?? 'Pon',
      status: status, // ? Koristi provereni status
      statusVreme: map['updated_at'] as String?,
      // ? NOVO: Citaj vremePokupljenja iz polasci_po_danu (samo DANAS)
      vremePokupljenja: vremePokupljenja,
      // ? NOVO: Citaj vremePlacanja iz polasci_po_danu (samo DANAS)
      vremePlacanja: vremePlacanja,
      placeno: isDnevni ? (vremePlacanja != null) : RegistrovaniHelpers.priceIsPaid(map),
      cena: isDnevni
          ? (vremePlacanja != null ? _parseDouble(map['cena_po_danu'] ?? map['cena']) : 0.0)
          : _parseDouble(map['cena_po_danu'] ?? map['cena']),
      // ? NOVO: Citaj naplatioVozac iz polasci_po_danu (samo DANAS)
      naplatioVozac: RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, danKratica, place) ??
          _getVozacIme(map['vozac_id'] as String?),
      // ? NOVO: Citaj pokupioVozac iz polasci_po_danu (samo DANAS)
      pokupioVozac: RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, danKratica, place),
      // ?? dodeljenVozac - 3 nivoa: 1) per-putnik (bc_vozac/vs_vozac), 2) per-vreme, 3) globalni vozac_id
      dodeljenVozac: _getDodeljenVozacWithPriority(
        map: map,
        danKratica: danKratica,
        place: place,
        grad: grad,
        vreme: polazakRaw ?? '',
      ),
      grad: grad,
      adresa: _determineAdresaFromRegistrovani(map, grad), // ? FIX: Prosledujemo grad za konzistentnost
      adresaId: _determineAdresaIdFromRegistrovani(map, grad), // ? NOVO - UUID adrese
      obrisan: !RegistrovaniHelpers.isActiveFromMap(map),
      brojTelefona: map['broj_telefona'] as String?,
      brojMesta: (map['broj_mesta'] as int?) ?? 1, // ?? Broj rezervisanih mesta
      tipPutnika: tipPutnika, // ?? Tip putnika: radnik, ucenik, dnevni
      // ? DODATO: Parsiranje vremena otkazivanja i vozaca iz JSON-a
      vremeOtkazivanja: vremeOtkazivanja,
      otkazaoVozac: otkazaoVozac,
      otkazanZaPolazak: otkazanZaPolazak, // ?? Da li je otkazan za ovaj polazak
    );
  }

  // Helper metoda za citanje polaska za odredeni dan iz novih kolona

  final dynamic id; // UUID iz registrovani_putnici
  final String ime;
  final String polazak;
  final bool? pokupljen;
  final DateTime? vremeDodavanja; // ? DateTime
  final bool? mesecnaKarta;
  final String dan;
  final String? status;
  final String? statusVreme;
  final DateTime? vremePokupljenja; // ? DateTime
  final DateTime? vremePlacanja; // ? DateTime
  final bool? placeno;
  final double? cena; // ? STANDARDIZOVANO: cena umesto iznosPlacanja
  final String? naplatioVozac;
  final String? pokupioVozac; // NOVO - vozac koji je pokupljanje izvršio
  final String? dodeljenVozac;
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
  final int brojMesta; // ?? Broj rezervisanih mesta (1, 2, 3...)
  final String? tipPutnika; // ?? Tip putnika: radnik, ucenik, dnevni
  final bool otkazanZaPolazak; // ?? Da li je otkazan za ovaj specificni polazak (grad)

  // ?? Helper getter za proveru da li je dnevni tip
  bool get isDnevniTip => tipPutnika == 'dnevni' || mesecnaKarta == false;

  // ?? Helper getter za proveru da li je radnik ili ucenik (prikazuje MESECNA badge)
  // Fallback: ako tipPutnika nije poznat, koristi mesecnaKarta kao indikator
  bool get isMesecniTip =>
      tipPutnika == 'radnik' || tipPutnika == 'ucenik' || (tipPutnika == null && mesecnaKarta == true);

  // Getter-i za kompatibilnost
  String get destinacija => grad;
  String get vremePolaska => polazak;

  /// Izračunava efektivnu cenu po mestu za ovaj polazak
  double get effectivePrice {
    // 1. Custom cena iz baze (AKO JE POSTAVLJENA - NAJVEĆI PRIORITET)
    if (cena != null && cena! > 0) {
      return cena!;
    }

    final tipLower = tipPutnika?.toLowerCase() ?? '';
    final imeLower = ime.toLowerCase();

    // 2. Zubi (Specijalna cena - Fallback)
    if (tipLower == 'posiljka' && imeLower.contains('zubi')) {
      return 300.0;
    }

    // 3. Pošiljka ili YU auto (Fiksno 500)
    if (tipLower == 'posiljka' || imeLower.contains('yu auto')) {
      return 500.0;
    }

    // 4. Dnevni (Fiksno 600)
    if (tipLower == 'dnevni' || mesecnaKarta == false) {
      return 600.0;
    }

    return 0.0;
  }

  // Getter-i za centralizovanu logiku statusa
  // ?? IZMENJENO: jeOtkazan sada proverava otkazanZaPolazak (po gradu) umesto globalnog statusa
  // Dodata provera za status 'otkazano' za kompatibilnost
  bool get jeOtkazan =>
      obrisan || otkazanZaPolazak || status?.toLowerCase() == 'otkazano' || status?.toLowerCase() == 'otkazan';

  bool get jeBolovanje => status != null && status!.toLowerCase() == 'bolovanje';

  bool get jeGodisnji => status != null && (status!.toLowerCase() == 'godišnji' || status!.toLowerCase() == 'godisnji');

  bool get jeOdsustvo => jeBolovanje || jeGodisnji;

  // ? FIX: jePokupljen mora proveriti da li je pokupljeno DANAS, ne samo da postoji timestamp
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

  // ? KOMPATIBILNOST: getter za stari iznosPlacanja naziv
  double? get iznosPlacanja => cena;

  PutnikStatus? get statusEnum => PutnikStatusExtension.fromString(status);

  // NOVA METODA: Kreira VIŠE putnik objekata za mesecne putnike sa više polazaka
  static List<Putnik> fromRegistrovaniPutniciMultiple(Map<String, dynamic> map) {
    final danas = DateTime.now();
    final trenutniDan = _getDanNedeljeKratica(danas.weekday);
    return _parseAndCreatePutniciForDay(map, trenutniDan);
  }

  // NOVA METODA: Kreira putnik objekte za SPECIFICAN DAN (umesto trenutni dan)
  static List<Putnik> fromRegistrovaniPutniciMultipleForDay(
    Map<String, dynamic> map,
    String targetDan, {
    String? isoDate,
  }) {
    return _parseAndCreatePutniciForDay(map, targetDan, isoDate: isoDate);
  }

  // ?? HELPER: Zajednicka logika za parsiranje i kreiranje putnika
  static List<Putnik> _parseAndCreatePutniciForDay(
    Map<String, dynamic> map,
    String targetDan, {
    String? isoDate,
  }) {
    final ime = map['putnik_ime'] as String? ?? map['ime'] as String? ?? '';
    final danString = map['radni_dani'] as String? ?? 'pon';
    final statusIzBaze = map['status'] as String? ?? 'radi';
    final vremeDodavanja = map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null;

    // Status se odreduje na osnovu otkazanZaPolazak koji se proverava u _createPutniciForDay
    String status = statusIzBaze;
    // Placanje se sada cita iz voznje_log, ne iz registrovani_putnici
    final bool placeno = false; // Proverava se naknadno iz voznje_log
    final double iznosPlacanja = 0.0;
    final vozac = (map['vozac'] as String?) ?? _getVozacIme(map['vozac_id'] as String?);
    final obrisan = map['aktivan'] == false;
    // ?? FIX: Citaj tip putnika iz baze
    final tipPutnika = map['tip'] as String?;

    return _createPutniciForDay(
      map,
      ime,
      danString,
      status,
      vremeDodavanja,
      null, // vremePlacanja - sada iz voznje_log
      placeno,
      iznosPlacanja,
      vozac,
      obrisan,
      targetDan,
      tipPutnika,
      isoDate: isoDate,
    );
  }

  // Helper metoda za kreiranje putnika za odreden dan
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
    String? tipPutnika, {
    String? isoDate,
  }) {
    final List<Putnik> putnici = [];
    // ?? FIX: mesecnaKarta = true samo za radnik i ucenik, false za dnevni i posiljka
    final bool mesecnaKarta = tipPutnika != 'dnevni' && tipPutnika != 'posiljka';

    // ? NOVA LOGIKA: Citaj vremena iz novih kolona po danima
    // ?? FIX: Ako radni_dani kolona nedostaje, koristi polasci_po_danu za odredivanje radnih dana
    final List<String> radniDani;
    if (map['radni_dani'] != null) {
      radniDani = (map['radni_dani'] as String)
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      // Ako nema radni_dani, izvuci ih iz polasci_po_danu
      final polasci = RegistrovaniHelpers.parsePolasciPoDanu(map['polasci_po_danu']);
      radniDani = polasci.keys.toList();
    }

    final normalizedTarget = targetDan.trim().toLowerCase();

    if (!radniDani.contains(normalizedTarget)) {
      return putnici; // Putnik ne radi za targetDan
    }

    // Citaj vremena za targetDan koristeci helpers koji kombinuju JSON i stare kolone
    final polazakBC = RegistrovaniHelpers.getPolazakForDay(map, targetDan, 'bc');
    final polazakVS = RegistrovaniHelpers.getPolazakForDay(map, targetDan, 'vs');

    // ? NOVO: Citaj vremena pokupljenja iz polasci_po_danu JSON (samo DANAS)
    final vremePokupljenjaBC = RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, normalizedTarget, 'bc');
    final vremePokupljenjaVS = RegistrovaniHelpers.getVremePokupljenjaForDayAndPlace(map, normalizedTarget, 'vs');

    // ? NOVO: Citaj vozace koji su pokupili iz polasci_po_danu JSON
    final pokupioVozacBC = RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, normalizedTarget, 'bc');
    final pokupioVozacVS = RegistrovaniHelpers.getPokupioVozacForDayAndPlace(map, normalizedTarget, 'vs');

    // ? NOVO: Citaj vozace koji su naplatili iz polasci_po_danu JSON
    final naplatioVozacBC = RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, normalizedTarget, 'bc');
    final naplatioVozacVS = RegistrovaniHelpers.getNaplatioVozacForDayAndPlace(map, normalizedTarget, 'vs');

    // ? FIX: Citaj iznose placanja iz polasci_po_danu JSON (za dnevne putnike)
    final iznosPlacanjaBC = RegistrovaniHelpers.getIznosPlacanjaForDayAndPlace(map, normalizedTarget, 'bc');
    final iznosPlacanjaVS = RegistrovaniHelpers.getIznosPlacanjaForDayAndPlace(map, normalizedTarget, 'vs');

    // ? FIX: Citaj vremena placanja iz polasci_po_danu JSON (za filter dužnika)
    final vremePlacanjaBC = RegistrovaniHelpers.getVremePlacanjaForDayAndPlace(map, normalizedTarget, 'bc');
    final vremePlacanjaVS = RegistrovaniHelpers.getVremePlacanjaForDayAndPlace(map, normalizedTarget, 'vs');

    // ? NOVO: Citaj adrese iz JOIN-a sa adrese tabelom (ako postoji)
    // JOIN format: adresa_bc: {id, naziv, ulica, broj, grad, koordinate}
    final adresaBcJoin = map['adresa_bc'] as Map<String, dynamic>?;
    final adresaVsJoin = map['adresa_vs'] as Map<String, dynamic>?;

    // Koristi naziv iz JOIN-a (adresa_bc, adresa_vs su sada jedini izvor)
    final adresaBelaCrkva = adresaBcJoin?['naziv'] as String?;
    final adresaVrsac = adresaVsJoin?['naziv'] as String?;

    // ?? Citaj "adresa danas" override iz polasci_po_danu JSON
    final adresaDanasBcId = RegistrovaniHelpers.getAdresaDanasIdForDay(map, normalizedTarget, 'bc');
    final adresaDanasBcNaziv = RegistrovaniHelpers.getAdresaDanasNazivForDay(map, normalizedTarget, 'bc');
    final adresaDanasVsId = RegistrovaniHelpers.getAdresaDanasIdForDay(map, normalizedTarget, 'vs');
    final adresaDanasVsNaziv = RegistrovaniHelpers.getAdresaDanasNazivForDay(map, normalizedTarget, 'vs');

    // ?? Prioritet: adresa_danas > stalna adresa
    final finalAdresaBc = adresaDanasBcNaziv ?? adresaBelaCrkva;
    final finalAdresaBcId = adresaDanasBcId ?? map['adresa_bela_crkva_id'] as String?;
    final finalAdresaVs = adresaDanasVsNaziv ?? adresaVrsac;
    final finalAdresaVsId = adresaDanasVsId ?? map['adresa_vrsac_id'] as String?;

    // ?? Proveri da li je putnik otkazan za ovaj dan i grad
    final bcOtkazan = RegistrovaniHelpers.isOtkazanForDayAndPlace(map, normalizedTarget, 'bc');
    final vsOtkazan = RegistrovaniHelpers.isOtkazanForDayAndPlace(map, normalizedTarget, 'vs');

    // ?? Citaj status iz polasci_po_danu JSON-a
    final bcStatus = RegistrovaniHelpers.getStatusForDayAndPlace(map, normalizedTarget, 'bc');
    final vsStatus = RegistrovaniHelpers.getStatusForDayAndPlace(map, normalizedTarget, 'vs');

    // Kreiraj putnik za Bela Crkva ako ima polazak za targetDan ILI ako je otkazan
    if ((polazakBC != null && polazakBC.isNotEmpty && polazakBC != '00:00:00') || bcOtkazan) {
      // ? KORISTI ODVOJENU KOLONU: vreme_pokupljenja_bc za Bela Crkva polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenjaBC != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        pokupljenZaOvajPolazak = true; // Vec je provera DANAS u helper funkciji
      }

      // ?? Ako je otkazan bez polaska, koristi placeholder
      final efectivePolazakBC = polazakBC ?? 'Otkazano';

      putnici.add(
        Putnik(
          id: map['id'], // ? Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: efectivePolazakBC,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: mesecnaKarta, // ?? FIX: koristi izracunatu vrednost
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: bcOtkazan ? 'otkazan' : (bcStatus ?? status), // ?? Prioritet: bcStatus iz JSON > globalni status
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenjaBC, // ? NOVO: Iz polasci_po_danu
          vremePlacanja: vremePlacanjaBC, // ? FIX: Citaj iz JSON-a za BC
          placeno: (iznosPlacanjaBC ?? 0) > 0, // ? FIX: placeno ako ima iznos
          cena: iznosPlacanjaBC ?? iznosPlacanja, // ? FIX: citaj iz JSON-a
          // ? NOVO: Citaj naplatioVozac iz polasci_po_danu
          naplatioVozac: naplatioVozacBC ?? _getVozacIme(map['vozac_id'] as String?),
          // ? NOVO: Citaj pokupioVozac iz polasci_po_danu
          pokupioVozac: pokupioVozacBC,
          // ?? dodeljenVozac - 3 nivoa: 1) per-putnik (bc_vozac), 2) per-vreme, 3) globalni vozac_id
          dodeljenVozac: polazakBC != null
              ? _getDodeljenVozacWithPriority(
                  map: map,
                  danKratica: normalizedTarget,
                  place: 'bc',
                  grad: 'Bela Crkva',
                  vreme: polazakBC,
                )
              : null,
          vozac: vozac,
          grad: 'Bela Crkva',
          adresa: finalAdresaBc, // ?? PRIORITET: adresa_danas > stalna adresa
          adresaId: finalAdresaBcId, // ?? PRIORITET: adresa_danas_id > stalni ID
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ? DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'bc'), // ?? Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // ?? FIX: dodaj tip putnika
          vremeOtkazivanja: RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, normalizedTarget, 'bc'),
          otkazaoVozac: RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, normalizedTarget, 'bc'),
          otkazanZaPolazak: bcOtkazan, // ? Koristi vec izracunatu vrednost
          datum: isoDate, // ?? FIX: Postavi datum za koji je putnik kreiran
        ),
      );
    }

    // Kreiraj putnik za Vršac ako ima polazak za targetDan ILI ako je otkazan
    if ((polazakVS != null && polazakVS.isNotEmpty && polazakVS != '00:00:00') || vsOtkazan) {
      // ? NOVO: Citaj vreme pokupljenja iz polasci_po_danu (samo DANAS)
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenjaVS != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        pokupljenZaOvajPolazak = true; // Vec je provera DANAS u helper funkciji
      }

      // ?? Ako je otkazan bez polaska, koristi placeholder
      final efectivePolazakVS = polazakVS ?? 'Otkazano';

      putnici.add(
        Putnik(
          id: map['id'], // ? Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: efectivePolazakVS,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: mesecnaKarta, // ?? FIX: koristi izracunatu vrednost
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: vsOtkazan ? 'otkazan' : (vsStatus ?? status), // ?? Prioritet: vsStatus iz JSON > globalni status
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenjaVS, // ? NOVO: Iz polasci_po_danu
          vremePlacanja: vremePlacanjaVS, // ? FIX: Citaj iz JSON-a za VS
          placeno: (iznosPlacanjaVS ?? 0) > 0, // ? FIX: placeno ako ima iznos
          cena: iznosPlacanjaVS ?? iznosPlacanja, // ? FIX: citaj iz JSON-a
          // ? NOVO: Citaj naplatioVozac iz polasci_po_danu
          naplatioVozac: naplatioVozacVS ?? _getVozacIme(map['vozac_id'] as String?),
          // ? NOVO: Citaj pokupioVozac iz polasci_po_danu
          pokupioVozac: pokupioVozacVS,
          // ?? dodeljenVozac - 3 nivoa: 1) per-putnik (vs_vozac), 2) per-vreme, 3) globalni vozac_id
          dodeljenVozac: polazakVS != null
              ? _getDodeljenVozacWithPriority(
                  map: map,
                  danKratica: normalizedTarget,
                  place: 'vs',
                  grad: 'Vršac',
                  vreme: polazakVS,
                )
              : null,
          vozac: vozac,
          grad: 'Vršac',
          adresa: finalAdresaVs, // ?? PRIORITET: adresa_danas > stalna adresa
          adresaId: finalAdresaVsId, // ?? PRIORITET: adresa_danas_id > stalni ID
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ? DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'vs'), // ?? Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // ?? FIX: dodaj tip putnika
          vremeOtkazivanja: RegistrovaniHelpers.getVremeOtkazivanjaForDayAndPlace(map, normalizedTarget, 'vs'),
          otkazaoVozac: RegistrovaniHelpers.getOtkazaoVozacForDayAndPlace(map, normalizedTarget, 'vs'),
          otkazanZaPolazak: vsOtkazan, // ? Koristi vec izracunatu vrednost
          datum: isoDate, // ?? FIX: Postavi datum za koji je putnik kreiran
        ),
      );
    }

    return putnici;
  }

  // HELPER FUNKCIJA - Parseovanje double iz razlicitih tipova
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

    // Fallback: proveri da li ima VS adresu u JOIN-u
    final adresaVsObj = map['adresa_vs'] as Map<String, dynamic>?;
    if (adresaVsObj != null && adresaVsObj['naziv'] != null) {
      return 'Vršac';
    }

    return 'Bela Crkva';
  }

  static String? _determineAdresaFromRegistrovani(Map<String, dynamic> map, String grad) {
    // ? FIX: Koristi grad parametar za odredivanje adrese umesto ponovnog racunanja
    // Ovo osigurava konzistentnost izmedu grad i adresa polja

    // ? NOVO: Citaj adresu iz JOIN objekta (adresa_bc, adresa_vs)
    String? adresaBC;
    String? adresaVS;

    // Proveri da li postoji JOIN objekat za BC adresu
    final adresaBcObj = map['adresa_bc'] as Map<String, dynamic>?;
    if (adresaBcObj != null) {
      adresaBC = adresaBcObj['naziv'] as String? ?? '${adresaBcObj['ulica'] ?? ''} ${adresaBcObj['broj'] ?? ''}'.trim();
      if (adresaBC.isEmpty) adresaBC = null;
    }

    // Proveri da li postoji JOIN objekat za VS adresu
    final adresaVsObj = map['adresa_vs'] as Map<String, dynamic>?;
    if (adresaVsObj != null) {
      adresaVS = adresaVsObj['naziv'] as String? ?? '${adresaVsObj['ulica'] ?? ''} ${adresaVsObj['broj'] ?? ''}'.trim();
      if (adresaVS.isEmpty) adresaVS = null;
    }

    // ? FIX: Koristi grad parametar za odredivanje ispravne adrese
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

  // ?? MAPIRANJE ZA registrovani_putnici TABELU
  Map<String, dynamic> toRegistrovaniPutniciMap() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return {
      // 'id': id, // Uklonjen - Supabase ce auto-generirati UUID
      'putnik_ime': ime,
      'tip': 'radnik', // ili 'ucenik' - treba logiku za odredivanje
      'tip_skole': null, // ? NOVA KOLONA - možda treba logika
      'broj_telefona': brojTelefona,
      // Store per-day polasci as canonical JSON
      'polasci_po_danu': jsonEncode({
        // map display day (Pon/Uto/...) to kratica used by registrovani_putnici
        (() {
          final map = {
            'Pon': 'pon',
            'Uto': 'uto',
            'Sre': 'sre',
            'Cet': 'cet',
            'Pet': 'pet',
            'Sub': 'sub',
            'Ned': 'ned',
          };
          return map[dan] ?? dan.toLowerCase().substring(0, 3);
        })(): grad == 'Bela Crkva' ? {'bc': polazak} : {'vs': polazak},
      }),
      'tip_prikazivanja': null,
      'radni_dani': dan,
      'aktivan': !obrisan,
      'status': status ?? 'radi',
      'datum_pocetka_meseca': startOfMonth.toIso8601String().split('T')[0],
      'datum_kraja_meseca': endOfMonth.toIso8601String().split('T')[0],
      // UUID validacija za vozac_id
      'vozac_id': (vozac?.isEmpty ?? true) ? null : vozac,
      'created_at': vremeDodavanja?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // Helper metoda za dobijanje kratice dana u nedelji

  static String _getDanNedeljeKratica(int weekday) {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return daniKratice[weekday - 1];
  }

  /// ?? HELPER: Odredi dodel?enog vozaca sa 3 nivoa prioriteta
  /// 1) Per-putnik per-pravac (bc_vozac/vs_vozac iz polasci_po_danu)
  /// 2) Per-vreme (iz vreme_vozac tabele - svi putnici na tom terminu)
  /// 3) Globalni vozac_id (fallback)
  static String? _getDodeljenVozacWithPriority({
    required Map<String, dynamic> map,
    required String danKratica,
    required String place,
    required String grad,
    required String vreme,
  }) {
    // 1?? NAJVIŠI PRIORITET: Per-putnik per-pravac per-vreme (bc_5:00_vozac ili vs_14:00_vozac)
    final perPutnikPerVreme = RegistrovaniHelpers.getDodeljenVozacForDayAndPlace(
      map,
      danKratica,
      place,
      vreme: vreme, // ?? Prosledivanje vremena za specificno dodeljivanje
    );
    if (perPutnikPerVreme != null && perPutnikPerVreme.isNotEmpty) {
      return perPutnikPerVreme;
    }

    // 2?? SREDNJI PRIORITET: Per-vreme (iz vreme_vozac tabele)
    // Koristi sinhroni pristup keširanju - keš MORA biti ucitan pre poziva!
    final perVreme = VremeVozacService().getVozacZaVremeSync(grad, vreme, danKratica);
    if (perVreme != null && perVreme.isNotEmpty) {
      return perVreme;
    }

    // ? UKLONJEN NAJNIŽI PRIORITET: Globalni vozac_id (reset u ponoc)
    return null;
  }

  // ? CENTRALIZOVANO: Konvertuj UUID u ime vozaca sa fallback-om
  static String? _getVozacIme(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;
    return VozacMappingService.getVozacImeWithFallbackSync(uuid) ?? _mapUuidToVozacHardcoded(uuid);
  }

  // ? FALLBACK MAPIRANJE UUID -> VOZAC IME
  static String? _mapUuidToVozacHardcoded(String? uuid) {
    if (uuid == null) return null;

    switch (uuid) {
      case '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e':
        return 'Bojan';
      case '5b379394-084e-1c7d-76bf-fc193a5b6c7d':
        return 'Svetlana';
      case '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f':
        return 'Bruda';
      case '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f':
        return 'Bilevski';
      case '67ea0a22-689c-41b8-b576-5b27145e8e5e':
        return 'Ivan';
      default:
        return null;
    }
  }

  // -----------------------------------------------------------------------
  // ?? COPY WITH - za ažurivanje putnika sa novim podacima
  // -----------------------------------------------------------------------

  Putnik copyWith({
    String? id,
    String? ime,
    String? polazak,
    bool? pokupljen,
    DateTime? vremeDodavanja,
    bool? mesecnaKarta,
    String? dan,
    String? status,
    String? statusVreme,
    DateTime? vremePokupljenja,
    DateTime? vremePlacanja,
    bool? placeno,
    double? cena,
    String? naplatioVozac,
    String? pokupioVozac,
    String? dodeljenVozac,
    String? vozac,
    String? grad,
    String? otkazaoVozac,
    DateTime? vremeOtkazivanja,
    String? adresa,
    String? adresaId,
    bool? obrisan,
    int? priority,
    String? brojTelefona,
    String? datum,
    int? brojMesta,
    String? tipPutnika,
    bool? otkazanZaPolazak,
  }) {
    return Putnik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      polazak: polazak ?? this.polazak,
      pokupljen: pokupljen ?? this.pokupljen,
      vremeDodavanja: vremeDodavanja ?? this.vremeDodavanja,
      mesecnaKarta: mesecnaKarta ?? this.mesecnaKarta,
      dan: dan ?? this.dan,
      status: status ?? this.status,
      statusVreme: statusVreme ?? this.statusVreme,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      placeno: placeno ?? this.placeno,
      cena: cena ?? this.cena,
      naplatioVozac: naplatioVozac ?? this.naplatioVozac,
      pokupioVozac: pokupioVozac ?? this.pokupioVozac,
      dodeljenVozac: dodeljenVozac ?? this.dodeljenVozac,
      vozac: vozac ?? this.vozac,
      grad: grad ?? this.grad,
      otkazaoVozac: otkazaoVozac ?? this.otkazaoVozac,
      vremeOtkazivanja: vremeOtkazivanja ?? this.vremeOtkazivanja,
      adresa: adresa ?? this.adresa,
      adresaId: adresaId ?? this.adresaId,
      obrisan: obrisan ?? this.obrisan,
      priority: priority ?? this.priority,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      datum: datum ?? this.datum,
      brojMesta: brojMesta ?? this.brojMesta,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      otkazanZaPolazak: otkazanZaPolazak ?? this.otkazanZaPolazak,
    );
  }

  // -----------------------------------------------------------------------
  // ?? EQUALITY OPERATORS - za stabilno mapiranje u Map<Putnik, Position>
  // ?? FIX: Ukljuci SVE relevantne atribute za detekciju promena iz realtime-a
  // -----------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Putnik) return false;

    // ?? FIX: Poredi SVE relevantne atribute, ne samo id
    // Ovo omogucava da didUpdateWidget detektuje promene iz realtime-a
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

  // 🔄 FALLBACK METODA: Učitaj adresu ako je NULL (fallback za JOIN koji nije radio)
  Future<String?> getAdresaFallback() async {
    // Ako već imamo adresu, vrati je
    if (adresa != null && adresa!.isNotEmpty && adresa != 'Adresa nije definisana') {
      return adresa;
    }

    // Ako nemamo adresaId, ne možemo učitati
    if (adresaId == null || adresaId!.isEmpty) {
      return adresa; // vrati šta god imamo (ili null)
    }

    try {
      // Pokušaj da učitaš adresu direktno iz baze koristeći UUID
      final fetchedAdresa = await AdresaSupabaseService.getNazivAdreseByUuid(adresaId);
      if (fetchedAdresa != null && fetchedAdresa.isNotEmpty) {
        return fetchedAdresa;
      }
    } catch (_) {
      // Ignore error i vrati šta god imamo
    }

    return adresa;
  }

  // ?? Helper za parsiranje radnih dana (iz kolone ili JSON-a)
}
