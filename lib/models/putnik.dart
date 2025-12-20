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

    // ✅ FIX: Proveri da li je otkazivanje bilo DANAS - ako nije, vrati status na 'radi'
    final statusIzBaze = map['status'] as String? ?? 'radi';
    final vremeOtkazivanja =
        map['vreme_otkazivanja'] != null ? DateTime.parse(map['vreme_otkazivanja'] as String).toLocal() : null;
    final danas = DateTime.now();
    String status = statusIzBaze;
    if (statusIzBaze == 'otkazan' || statusIzBaze == 'otkazano') {
      if (vremeOtkazivanja == null) {
        status = 'radi';
      } else {
        final otkazanDanas = vremeOtkazivanja.year == danas.year &&
            vremeOtkazivanja.month == danas.month &&
            vremeOtkazivanja.day == danas.day;
        if (!otkazanDanas) {
          status = 'radi';
        }
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
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String).toLocal()
          : null, // ✅ FIXED: Koristi samo vreme_pokupljenja kolonu
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String).toLocal()
          : null, // ✅ ČITAJ iz vreme_placanja umesto datum_pocetka_meseca
      placeno: RegistrovaniHelpers.priceIsPaid(map),
      cena: _parseDouble(map['cena']),
      // ✅ FIXED: Čitaj naplatioVozac iz action_log.paid_by sa fallback na dodali_vozaci[0]
      naplatioVozac: RegistrovaniHelpers.priceIsPaid(map)
          ? (_extractVozaciFromActionLog(map['action_log'])['paid_by'] ??
              _getVozacIme(map['vozac_id'] as String?) ??
              _extractDodaoVozacFromArray(map['dodali_vozaci']))
          : null,
      // ✅ FIXED: Čitaj vozače iz action_log JSON umesto nepostojećih kolona
      pokupioVozac: _extractVozaciFromActionLog(map['action_log'])['picked_by'],
      dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']) ??
          _getVozacIme(map['updated_by'] as String?) ??
          _extractVozaciFromActionLog(map['action_log'])['created_by'],
      grad: grad,
      adresa: _determineAdresaFromRegistrovani(map, grad), // ✅ FIX: Prosleđujemo grad za konzistentnost
      adresaId: _determineAdresaIdFromRegistrovani(map, grad), // ✅ NOVO - UUID adrese
      obrisan: !RegistrovaniHelpers.isActiveFromMap(map),
      brojTelefona: map['broj_telefona'] as String?,
      brojMesta: (map['broj_mesta'] as int?) ?? 1, // 🆕 Broj rezervisanih mesta
      tipPutnika: tipPutnika, // 🆕 Tip putnika: radnik, ucenik, dnevni
      // ✅ DODATO: Parsiranje vremena otkazivanja i vozača
      vremeOtkazivanja: vremeOtkazivanja,
      otkazaoVozac: map['otkazao_vozac'] as String?,
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
  bool get jeOtkazan =>
      obrisan || // 🆕 Dodaj prověru za obrisan (aktivan=false u bazi)
      (status != null && (status!.toLowerCase() == 'otkazano' || status!.toLowerCase() == 'otkazan'));

  bool get jeBolovanje => status != null && status!.toLowerCase() == 'bolovanje';

  bool get jeGodisnji => status != null && (status!.toLowerCase() == 'godišnji' || status!.toLowerCase() == 'godisnji');

  bool get jeOdsustvo => jeBolovanje || jeGodisnji;

  bool get jePokupljen =>
      vremePokupljenja != null || // Mesečni putnici
      status == 'pokupljen'; // Dnevni putnici

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
    final vremePokupljenja =
        map['vreme_pokupljenja'] != null ? DateTime.parse(map['vreme_pokupljenja'] as String) : null;
    final vremePlacanja = map['vreme_placanja'] != null ? DateTime.parse(map['vreme_placanja'] as String) : null;

    // ✅ FIX: Proveri da li je otkazivanje bilo DANAS - ako nije, vrati status na 'radi'
    final vremeOtkazivanja =
        map['vreme_otkazivanja'] != null ? DateTime.parse(map['vreme_otkazivanja'] as String).toLocal() : null;
    final danas = DateTime.now();
    String status = statusIzBaze;
    if (statusIzBaze == 'otkazan' || statusIzBaze == 'otkazano') {
      if (vremeOtkazivanja == null) {
        // Nema vreme otkazivanja - smatraj kao aktivnog
        status = 'radi';
      } else {
        final otkazanDanas = vremeOtkazivanja.year == danas.year &&
            vremeOtkazivanja.month == danas.month &&
            vremeOtkazivanja.day == danas.day;
        if (!otkazanDanas) {
          // Otkazan ranije, ne danas - vrati na 'radi'
          status = 'radi';
        }
      }
    }
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
      vremePokupljenja,
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
    DateTime? vremePokupljenja,
    DateTime? vremePlacanja,
    bool placeno,
    double? iznosPlacanja,
    String? vozac,
    bool obrisan,
    String targetDan,
    String? tipPutnika, // 🆕 FIX: Dodaj tipPutnika parametar
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

    // ✅ NOVO: Čitaj adrese iz JOIN-a sa adrese tabelom (ako postoji)
    // JOIN format: adresa_bc: {id, naziv, ulica, broj, grad, koordinate}
    final adresaBcJoin = map['adresa_bc'] as Map<String, dynamic>?;
    final adresaVsJoin = map['adresa_vs'] as Map<String, dynamic>?;

    // Koristi naziv iz JOIN-a, fallback na staro TEXT polje, pa null ako nema
    final adresaBelaCrkva = adresaBcJoin?['naziv'] as String? ?? map['adresa_bela_crkva'] as String?;
    final adresaVrsac = adresaVsJoin?['naziv'] as String? ?? map['adresa_vrsac'] as String?;

    // Kreiraj putnik za Bela Crkva ako ima polazak za targetDan
    if (polazakBC != null && polazakBC.isNotEmpty && polazakBC != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        // ✅ FIX: Prvo proveri da li je vremePokupljenja od DANAS
        final danas = DateTime.now();
        final pokupljenDatum = vremePokupljenja.toLocal();
        final jeDanas =
            pokupljenDatum.year == danas.year && pokupljenDatum.month == danas.month && pokupljenDatum.day == danas.day;

        if (jeDanas) {
          final polazakSati = int.tryParse(polazakBC.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;

          // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
          final razlika = (pokupljenSati - polazakSati).abs();
          pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
        }
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
          vremePokupljenja: vremePokupljenja,
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          // ✅ FIXED: Čitaj naplatioVozac iz action_log.paid_by sa fallback na dodali_vozaci[0]
          naplatioVozac: placeno && (iznosPlacanja ?? 0) > 0
              ? (_extractVozaciFromActionLog(map['action_log'])['paid_by'] ??
                  _getVozacIme(map['vozac_id'] as String?) ??
                  _extractDodaoVozacFromArray(map['dodali_vozaci']))
              : null,
          // ✅ FIX: Fallback na vozac_id ako action_log.picked_by je null
          pokupioVozac: _extractVozaciFromActionLog(map['action_log'])['picked_by'] ??
              (vremePokupljenja != null ? _getVozacIme(map['vozac_id'] as String?) : null),
          // ✅ FIX: Dodaj updated_by fallback za konzistentnost sa fromRegistrovaniPutnici
          dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']) ??
              _getVozacIme(map['updated_by'] as String?) ??
              _extractVozaciFromActionLog(map['action_log'])['created_by'],
          vozac: vozac,
          grad: 'Bela Crkva',
          adresa: adresaBelaCrkva, // ✅ KORISTI adresu iz JOIN-a sa adrese tabelom
          adresaId: map['adresa_bela_crkva_id'] as String?,
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'bc'), // 🆕 Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // 🆕 FIX: dodaj tip putnika
          vremeOtkazivanja:
              map['vreme_otkazivanja'] != null ? DateTime.parse(map['vreme_otkazivanja'] as String).toLocal() : null,
          otkazaoVozac: map['otkazao_vozac'] as String?,
        ),
      );
    }

    // Kreiraj putnik za Vršac ako ima polazak za targetDan
    if (polazakVS != null && polazakVS.isNotEmpty && polazakVS != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        // ✅ FIX: Prvo proveri da li je vremePokupljenja od DANAS
        final danas = DateTime.now();
        final pokupljenDatum = vremePokupljenja.toLocal();
        final jeDanas =
            pokupljenDatum.year == danas.year && pokupljenDatum.month == danas.month && pokupljenDatum.day == danas.day;

        if (jeDanas) {
          final polazakSati = int.tryParse(polazakVS.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;

          // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
          final razlika = (pokupljenSati - polazakSati).abs();
          pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
        }
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
          vremePokupljenja: vremePokupljenja,
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          // ✅ FIXED: Čitaj naplatioVozac iz action_log.paid_by sa fallback na dodali_vozaci[0]
          naplatioVozac: placeno && (iznosPlacanja ?? 0) > 0
              ? (_extractVozaciFromActionLog(map['action_log'])['paid_by'] ??
                  _getVozacIme(map['vozac_id'] as String?) ??
                  _extractDodaoVozacFromArray(map['dodali_vozaci']))
              : null,
          // ✅ FIX: Fallback na vozac_id ako action_log.picked_by je null
          pokupioVozac: _extractVozaciFromActionLog(map['action_log'])['picked_by'] ??
              (vremePokupljenja != null ? _getVozacIme(map['vozac_id'] as String?) : null),
          // ✅ FIX: Dodaj updated_by fallback za konzistentnost sa fromRegistrovaniPutnici
          dodaoVozac: _extractDodaoVozacFromArray(map['dodali_vozaci']) ??
              _getVozacIme(map['updated_by'] as String?) ??
              _extractVozaciFromActionLog(map['action_log'])['created_by'],
          vozac: vozac,
          grad: 'Vršac',
          adresa: adresaVrsac, // ✅ KORISTI adresu iz JOIN-a sa adrese tabelom
          adresaId: map['adresa_vrsac_id'] as String?,
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
          brojMesta: RegistrovaniHelpers.getBrojMestaForDay(
              map, normalizedTarget, 'vs'), // 🆕 Broj rezervisanih mesta iz JSON-a
          tipPutnika: tipPutnika, // 🆕 FIX: dodaj tip putnika
          vremeOtkazivanja:
              map['vreme_otkazivanja'] != null ? DateTime.parse(map['vreme_otkazivanja'] as String).toLocal() : null,
          otkazaoVozac: map['otkazao_vozac'] as String?,
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
      'ukupna_cena_meseca': iznosPlacanja ?? 0.0, // možda treba cena umesto ovoga
      'broj_putovanja': 0, // ✅ NOVA KOLONA - default 0
      'broj_otkazivanja': 0, // ✅ NOVA KOLONA - default 0
      'vreme_pokupljenja':
          vremePokupljenja?.toIso8601String(), // ✅ FIXED: Koristi vreme_pokupljenja umesto poslednje_putovanje
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

  // ✅ HELPER: Izvlači vozača iz action_log JSON-a
  // Podržava: picked_by, paid_by, cancelled_by, created_by
  static Map<String, String?> _extractVozaciFromActionLog(dynamic actionLog) {
    final result = <String, String?>{
      'picked_by': null,
      'paid_by': null,
      'cancelled_by': null,
      'created_by': null,
    };

    if (actionLog == null) return result;

    Map<String, dynamic>? logMap;
    if (actionLog is String && actionLog.isNotEmpty) {
      try {
        logMap = Map<String, dynamic>.from(jsonDecode(actionLog) as Map);
      } catch (_) {}
    } else if (actionLog is Map) {
      logMap = Map<String, dynamic>.from(actionLog);
    }

    if (logMap != null) {
      // ✅ FIX: Ako je vrednost već ime vozača (ne UUID), koristi direktno
      result['picked_by'] = _getVozacImeOrDirect(logMap['picked_by'] as String?);
      result['paid_by'] = _getVozacImeOrDirect(logMap['paid_by'] as String?);
      result['cancelled_by'] = _getVozacImeOrDirect(logMap['cancelled_by'] as String?);
      result['created_by'] = _getVozacImeOrDirect(logMap['created_by'] as String?);
    }

    return result;
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
  // ═══════════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Putnik) return false;

    // Ako oba imaju id, koristi id za poređenje
    if (id != null && other.id != null) {
      return id == other.id;
    }

    // Fallback: koristi ime + grad + polazak za jedinstvenu identifikaciju
    return ime == other.ime && grad == other.grad && polazak == other.polazak;
  }

  @override
  int get hashCode {
    // Ako ima id, koristi ga za hash
    if (id != null) {
      return id.hashCode;
    }

    // Fallback: kombinacija ime + grad + polazak
    return Object.hash(ime, grad, polazak);
  }
}
