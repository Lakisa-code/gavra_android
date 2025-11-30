import 'dart:convert';

import '../services/adresa_supabase_service.dart'; // DODATO za pravo rešenje adresa
import '../services/vozac_mapping_service.dart'; // DODATO za UUID<->ime konverziju
import '../utils/mesecni_helpers.dart';

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
    // ✅ DODANO: Nova polja za kompatibilnost sa DnevniPutnik modelom
    this.rutaNaziv,
    this.adresaKoordinate,
  });

  factory Putnik.fromMap(Map<String, dynamic> map) {
    // AUTOMATSKA DETEKCIJA TIPA TABELE - SAMO NOVE TABELE

    // Ako ima mesecni_putnik_id ili tip_putnika, iz putovanja_istorija tabele
    if (map.containsKey('mesecni_putnik_id') || map.containsKey('tip_putnika')) {
      return Putnik.fromPutovanjaIstorija(map);
    }

    // Ako ima putnik_ime, iz mesecni_putnici tabele
    if (map.containsKey('putnik_ime')) {
      return Putnik.fromMesecniPutnici(map);
    }

    // GREŠKA - Nepoznata struktura tabele
    throw Exception(
      'Nepoznata struktura podataka - nisu iz mesecni_putnici ni putovanja_istorija',
    );
  }

  // NOVI: Factory za mesecni_putnici tabelu
  factory Putnik.fromMesecniPutnici(Map<String, dynamic> map) {
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];
    final grad = _determineGradFromMesecni(map);
    // Choose place key: 'bc' for Bela Crkva, 'vs' for Vršac
    final place = grad.toLowerCase().contains('vr') ? 'vs' : 'bc';
    // Only use explicit per-day or JSON values; do not fallback to legacy single-time columns
    final polazakRaw = MesecniHelpers.getPolazakForDay(map, danKratica, place);

    return Putnik(
      id: map['id'], // ✅ UUID iz mesecni_putnici
      ime: map['putnik_ime'] as String? ?? '',
      polazak: MesecniHelpers.normalizeTime(polazakRaw?.toString()) ?? '6:00',
      pokupljen: map['status'] == null || (map['status'] != 'bolovanje' && map['status'] != 'godisnji'),
      vremeDodavanja: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      mesecnaKarta: true, // uvek true za mesečne putnike
      dan: map['radni_dani'] as String? ?? 'Pon',
      status: map['status'] as String? ?? 'radi', // ✅ JEDNOSTAVNO
      statusVreme: map['updated_at'] as String?,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String).toLocal()
          : null, // ✅ FIXED: Koristi samo vreme_pokupljenja kolonu
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String).toLocal()
          : null, // ✅ ČITAJ iz vreme_placanja umesto datum_pocetka_meseca
      placeno: MesecniHelpers.priceIsPaid(map),
      cena: _parseDouble(map['cena']), // koristi cena kolonu
      naplatioVozac: MesecniHelpers.priceIsPaid(map)
          ? VozacMappingService.getVozacImeWithFallbackSync(
              map['vozac_id'] as String?,
            )
          : null,
      pokupioVozac: map['pokupljanje_vozac'] as String?,
      dodaoVozac: map['dodao_vozac'] as String? ?? 'Bojan', // ✅ FALLBACK: Sistemski vozač za mesečne putnike
      grad: grad,
      adresa: _determineAdresaFromMesecni(map),
      adresaId: _determineAdresaIdFromMesecni(map, grad), // ✅ NOVO - UUID adrese
      obrisan: !MesecniHelpers.isActiveFromMap(map),
      brojTelefona: map['broj_telefona'] as String?,
    );
  }

  // NOVI: Factory za putovanja_istorija tabelu
  factory Putnik.fromPutovanjaIstorija(Map<String, dynamic> map) {
    return Putnik(
      id: map['id'], // ✅ UUID iz putovanja_istorija
      ime: map['putnik_ime'] as String? ?? '',
      polazak: MesecniHelpers.normalizeTime(map['vreme_polaska']?.toString()) ?? '6:00',
      pokupljen: map['status'] == 'pokupljen', // ✅ KORISTI samo status kolonu
      vremeDodavanja: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      mesecnaKarta: map['tip_putnika'] == 'mesecni',
      dan: _determineDanFromDatum(
        map['datum_putovanja'] as String? ?? map['datum'] as String?,
      ), // ✅ Izvlači dan iz datum_putovanja kolone
      datum: map['datum_putovanja'] as String? ?? map['datum'] as String?,
      status: map['status'] as String?, // ✅ DIREKTNO IZ NOVE KOLONE
      statusVreme: map['updated_at'] as String?, // ✅ KORISTI updated_at
      // vremePokupljenja: null, // ✅ NEMA U SHEMI - default je null
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null, // ✅ FIXED: Koristi vreme_placanja umesto datum_putovanja
      placeno: _parseDouble(map['cena']) > 0,
      cena: _parseDouble(map['cena']),
      naplatioVozac: _parseDouble(map['cena']) > 0
          ? VozacMappingService.getVozacImeWithFallbackSync(
              map['vozac_id'] as String?,
            )
          : null, // ✅ Samo ako je stvarno plaćeno
      // pokupioVozac: null, // ✅ NEMA U SHEMI - default je null
      dodaoVozac: VozacMappingService.getVozacImeWithFallbackSync(
            map['created_by'] as String?,
          ) ??
          _mapUuidToVozacHardcoded(map['created_by'] as String?), // ✅ FALLBACK za UUID mapiranje
      // Ako tabela sadrži ime u 'vozac' polju, koristi ga, inače pokušaj da
      // mapiramo 'vozac_id' (UUID) na ime pomoću VozacMappingService.
      vozac: (map['vozac'] as String?) ??
          VozacMappingService.getVozacImeWithFallbackSync(
            map['vozac_id'] as String?,
          ),
      grad: map['grad'] as String? ?? 'Bela Crkva', // ✅ KORISTI grad kolonu
      otkazaoVozac: map['otkazao_vozac'] as String?, // ✅ NOVA KOLONA za otkazivanje
      adresa: map['adresa'] as String?,
      adresaId: map['adresa_id'] as String?, // ✅ UUID reference u tabelu adrese
      obrisan: map['obrisan'] == true, // ✅ Sada čita iz obrisan kolone
      brojTelefona: map['broj_telefona'] as String?,
    );
  }

  // Helper metoda za čitanje polaska za određeni dan iz novih kolona
  // ...existing code...

  final dynamic id; // ✅ Može biti int (putovanja_istorija) ili String (mesecni_putnici)
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
  // ✅ DODANO: Nova polja za kompatibilnost sa DnevniPutnik modelom
  final String? rutaNaziv;
  final String? adresaKoordinate;

  // Getter-i za kompatibilnost
  String get destinacija => grad;
  String get vremePolaska => polazak;
  String get datumPolaska => DateTime.now().toIso8601String().split('T')[0]; // Današnji datum kao placeholder

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
  static List<Putnik> fromMesecniPutniciMultiple(Map<String, dynamic> map) {
    final ime = map['putnik_ime'] as String? ?? map['ime'] as String? ?? '';
    final danString = map['radni_dani'] as String? ?? 'pon';
    final status = map['status'] as String? ?? 'radi'; // ✅ JEDNOSTAVNO
    final vremeDodavanja = map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null;
    final vremePokupljenja = map['vreme_pokupljenja'] != null
        ? DateTime.parse(map['vreme_pokupljenja'] as String)
        : null; // ✅ FIXED: Koristi samo vreme_pokupljenja kolonu
    final vremePlacanja = map['vreme_placanja'] != null
        ? DateTime.parse(map['vreme_placanja'] as String)
        : null; // ✅ ČITAJ iz vreme_placanja
    final double iznosPlacanja = _parseDouble(map['cena']);
    final bool placeno = iznosPlacanja > 0; // čita iz cena kolone
    // ✅ ISPRAVKA: Koristi isti sistem mapiranja kao dnevni putnici
    final vozac = (map['vozac'] as String?) ??
        VozacMappingService.getVozacImeWithFallbackSync(
          map['vozac_id'] as String?,
        );
    final obrisan = map['aktivan'] == false;

    // Trenutni dan u nedelji kao kratica (pon, uto, sre, cet, pet)
    final danas = DateTime.now();
    final trenutniDan = _getDanNedeljeKratica(danas.weekday);

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
      trenutniDan,
    );
  }

  // NOVA METODA: Kreira putnik objekte za SPECIFIČAN DAN (umesto trenutni dan)
  static List<Putnik> fromMesecniPutniciMultipleForDay(
    Map<String, dynamic> map,
    String targetDan,
  ) {
    final ime = map['putnik_ime'] as String? ?? map['ime'] as String? ?? '';
    final danString = map['radni_dani'] as String? ?? 'pon';

    final status = map['status'] as String? ?? 'radi'; // ✅ JEDNOSTAVNO
    final vremeDodavanja = map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null;
    final vremePokupljenja = map['vreme_pokupljenja'] != null
        ? DateTime.parse(map['vreme_pokupljenja'] as String)
        : null; // ✅ FIXED: Koristi samo vreme_pokupljenja kolonu
    final vremePlacanja = map['vreme_placanja'] != null
        ? DateTime.parse(map['vreme_placanja'] as String)
        : null; // ✅ ČITAJ iz vreme_placanja
    final double iznosPlacanja = _parseDouble(map['cena']);
    final bool placeno = iznosPlacanja > 0; // čita iz cena kolone
    // ✅ ISPRAVKA: Koristi isti sistem mapiranja kao dnevni putnici
    final vozac = (map['vozac'] as String?) ??
        VozacMappingService.getVozacImeWithFallbackSync(
          map['vozac_id'] as String?,
        );
    final obrisan = map['aktivan'] == false;

    final result = _createPutniciForDay(
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
    );

    return result;
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
  ) {
    final List<Putnik> putnici = [];

    // ✅ NOVA LOGIKA: Čitaj vremena iz novih kolona po danima
    // Određi da li putnik radi za targetDan
    final radniDani = danString.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
    final normalizedTarget = targetDan.trim().toLowerCase();

    if (!radniDani.contains(normalizedTarget)) {
      return putnici; // Putnik ne radi za targetDan
    }

    // Čitaj vremena za targetDan koristeći helpers koji kombinuju JSON i stare kolone
    final polazakBC = MesecniHelpers.getPolazakForDay(map, targetDan, 'bc');
    final polazakVS = MesecniHelpers.getPolazakForDay(map, targetDan, 'vs');

    // ✅ NOVO: Čitaj adrese iz JOIN-a sa adrese tabelom (ako postoji)
    // JOIN format: adresa_bc: {id, naziv, ulica, broj, grad, koordinate}
    final adresaBcJoin = map['adresa_bc'] as Map<String, dynamic>?;
    final adresaVsJoin = map['adresa_vs'] as Map<String, dynamic>?;

    // Koristi naziv iz JOIN-a, fallback na staro TEXT polje
    final adresaBelaCrkva = adresaBcJoin?['naziv'] as String? ?? map['adresa_bela_crkva'] as String? ?? 'Bela Crkva';
    final adresaVrsac = adresaVsJoin?['naziv'] as String? ?? map['adresa_vrsac'] as String? ?? 'Vršac';

    // Kreiraj putnik za Bela Crkva ako ima polazak za targetDan
    if (polazakBC != null && polazakBC.isNotEmpty && polazakBC != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        final polazakSati = int.tryParse(polazakBC.split(':')[0]) ?? 0;
        final pokupljenSati = vremePokupljenja.hour;

        // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
        final razlika = (pokupljenSati - polazakSati).abs();
        pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
      }

      putnici.add(
        Putnik(
          id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: polazakBC,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: true,
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: status,
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenja,
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          naplatioVozac: placeno && (iznosPlacanja ?? 0) > 0
              ? (vozac?.isNotEmpty == true
                  ? vozac
                  : VozacMappingService.getVozacImeWithFallbackSync(
                      map['vozac_id'] as String?,
                    ))
              : null, // ✅ Samo ako je stvarno plaćeno
          pokupioVozac: map['pokupljanje_vozac'] as String?, // ✅ NOVA KOLONA za pokupljanje
          dodaoVozac: map['dodao_vozac'] as String?, // ✅ NOVA KOLONA za dodavanje
          vozac: vozac, // ✅ KORISTI vozač varijablu
          grad: 'Bela Crkva',
          adresa: adresaBelaCrkva, // ✅ KORISTI adresu iz JOIN-a sa adrese tabelom
          adresaId: map['adresa_bela_crkva_id'] as String?,
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
        ),
      );
    }

    // Kreiraj putnik za Vršac ako ima polazak za targetDan
    if (polazakVS != null && polazakVS.isNotEmpty && polazakVS != '00:00:00') {
      // 🕐 LOGIKA ZA SPECIFIČNI POLAZAK - proveri da li je pokupljen za ovaj polazak
      bool pokupljenZaOvajPolazak = false;
      if (vremePokupljenja != null && status != 'bolovanje' && status != 'godisnji' && status != 'otkazan') {
        final polazakSati = int.tryParse(polazakVS.split(':')[0]) ?? 0;
        final pokupljenSati = vremePokupljenja.hour;

        // Proveri da li je pokupljen u razumnom vremenskom okviru oko polaska
        final razlika = (pokupljenSati - polazakSati).abs();
        pokupljenZaOvajPolazak = razlika <= 3; // ± 3 sata tolerancija
      }

      putnici.add(
        Putnik(
          id: map['id'], // ✅ Direktno proslijedi ID bez parsiranja
          ime: ime,
          polazak: polazakVS,
          pokupljen: pokupljenZaOvajPolazak,
          vremeDodavanja: vremeDodavanja,
          mesecnaKarta: true,
          dan: (normalizedTarget[0].toUpperCase() + normalizedTarget.substring(1)),
          status: status,
          statusVreme: map['updated_at'] as String?,
          vremePokupljenja: vremePokupljenja,
          vremePlacanja: vremePlacanja,
          placeno: placeno,
          cena: iznosPlacanja,
          naplatioVozac: placeno && (iznosPlacanja ?? 0) > 0
              ? (vozac?.isNotEmpty == true
                  ? vozac
                  : VozacMappingService.getVozacImeWithFallbackSync(
                      map['vozac_id'] as String?,
                    ))
              : null, // ✅ Samo ako je stvarno plaćeno
          pokupioVozac: map['pokupljanje_vozac'] as String?, // ✅ NOVA KOLONA za pokupljanje
          dodaoVozac: map['dodao_vozac'] as String?, // ✅ NOVA KOLONA za dodavanje
          vozac: vozac, // ✅ KORISTI vozač varijablu
          grad: 'Vršac',
          adresa: adresaVrsac, // ✅ KORISTI adresu iz JOIN-a sa adrese tabelom
          adresaId: map['adresa_vrsac_id'] as String?,
          obrisan: obrisan,
          brojTelefona: map['broj_telefona'] as String?, // ✅ DODATO
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
  static String _determineGradFromMesecni(Map<String, dynamic> map) {
    // Odredi grad na osnovu AKTIVNOG polaska za danas
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];

    // Proveri koji polazak postoji za danas
    final bcPolazak = MesecniHelpers.getPolazakForDay(map, danKratica, 'bc');
    final vsPolazak = MesecniHelpers.getPolazakForDay(map, danKratica, 'vs');

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

  static String? _determineAdresaFromMesecni(Map<String, dynamic> map) {
    // Koristi istu logiku kao _determineGradFromMesecni za konzistentnost
    final weekday = DateTime.now().weekday;
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final danKratica = daniKratice[weekday - 1];

    final bcPolazak = MesecniHelpers.getPolazakForDay(map, danKratica, 'bc');
    final vsPolazak = MesecniHelpers.getPolazakForDay(map, danKratica, 'vs');

    final adresaBC = map['adresa_bela_crkva'] as String?;
    final adresaVS = map['adresa_vrsac'] as String?;

    // Ako ima BC polazak danas, koristi BC adresu (gde ga pokupljaš)
    if (bcPolazak != null && bcPolazak.toString().isNotEmpty) {
      return adresaBC ?? adresaVS ?? 'Adresa nije definisana';
    }

    // Ako ima VS polazak danas, koristi VS adresu (gde ga pokupljaš)
    if (vsPolazak != null && vsPolazak.toString().isNotEmpty) {
      return adresaVS ?? adresaBC ?? 'Adresa nije definisana';
    }

    // Fallback: vrati prvu dostupnu adresu
    return adresaBC ?? adresaVS ?? 'Adresa nije definisana';
  }

  static String? _determineAdresaIdFromMesecni(Map<String, dynamic> map, String grad) {
    // Koristi UUID reference na osnovu grada
    if (grad.toLowerCase().contains('bela')) {
      return map['adresa_bela_crkva_id'] as String?;
    } else {
      return map['adresa_vrsac_id'] as String?;
    }
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
        // map display day (Pon/Uto/...) to kratica used by mesecni_putnici
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
      // Ne uključujemo 'obrisan' kolonu za putovanja_istorija tabelu
      'created_at': vremeDodavanja?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Helper metoda - konvertuje dan u datum sledeće nedelje za taj dan
  String _getDateForDay(String dan) {
    final now = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final dayNamesLower = ['pon', 'uto', 'sre', 'čet', 'pet', 'sub', 'ned'];

    // Probaj sa originalnim formatom
    int targetDayIndex = dayNames.indexOf(dan);

    // Ako nije pronađen, probaj sa malim slovima
    if (targetDayIndex == -1) {
      targetDayIndex = dayNamesLower.indexOf(dan.toLowerCase());
    }

    if (targetDayIndex == -1) {
      // Ako dan nije valjan, koristi današnji datum
      return now.toIso8601String().split('T')[0];
    }
    final currentDayIndex = now.weekday - 1; // Monday = 0

    // Izračunaj koliko dana treba dodati da dođemo do ciljnog dana
    int daysToAdd;
    if (targetDayIndex >= currentDayIndex) {
      // Ciljni dan je u ovoj nedelji ili danas
      daysToAdd = targetDayIndex - currentDayIndex;
    } else {
      // Ciljni dan je u sledećoj nedelji
      daysToAdd = (7 - currentDayIndex) + targetDayIndex;
    }

    final targetDate = now.add(Duration(days: daysToAdd));
    final result = targetDate.toIso8601String().split('T')[0];
    return result;
  } // NOVI: Mapiranje za putovanja_istorija tabelu

  Map<String, dynamic> toPutovanjaIstorijaMap() {
    // ✅ ISPRAVKA: Uvek koristi _getDateForDay da izračuna pravi datum na osnovu dan vrednosti
    final datumZaUpis = _getDateForDay(dan);

    // ✅ KONVERTUJ IME VOZAČA U UUID SA FALLBACK-OM
    String? vozacUuid;
    if (dodaoVozac != null) {
      vozacUuid = VozacMappingService.getVozacUuidSync(dodaoVozac!);

      // 🆘 FALLBACK: Poznati UUID-ovi ako mapiranje ne radi
      if (vozacUuid == null) {
        switch (dodaoVozac!) {
          case 'Bojan':
            vozacUuid = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';
            break;
          case 'Svetlana':
            vozacUuid = '5b379394-084e-1c7d-76bf-fc193a5b6c7d';
            break;
          case 'Bruda':
            vozacUuid = '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f';
            break;
          case 'Bilevski':
            vozacUuid = '8e6ac6c7-3b5b-4f0g-a9f2-2f4c5d8e9f0g';
            break;
          default:
            vozacUuid = null; // Za nepoznate vozače
        }
      }
    }

    return {
      // 'id': id, // Uklonjen - Supabase će automatski generirati UUID
      'mesecni_putnik_id': mesecnaKarta == true ? id : null,
      'tip_putnika': mesecnaKarta == true ? 'mesecni' : 'dnevni',
      'datum_putovanja': datumZaUpis, // ✅ Za PutovanjaIstorijaService compatibility
      'vreme_polaska': polazak,
      'putnik_ime': ime,
      'grad': grad, // ✅ DODANO: grad kolona
      'adresa_id': null, // Ostaće null - adresa se dodaje asinhrono u toPutovanjaIstorijaMapWithAdresa
      'cena': iznosPlacanja ?? 0.0,
      'status': status ?? 'nije_se_pojavio',
      'obrisan': obrisan,
      'created_by': vozacUuid, // ✅ ISPRAVKA: koristimo UUID umesto imena vozača
      'action_log': {
        'actions': <Map<String, dynamic>>[],
        'created_at': DateTime.now().toIso8601String(),
        'created_by': vozacUuid,
        'primary_driver': vozacUuid,
      }, // ✅ ISPRAVKA: JSON objekat umesto jsonEncode string-a za constraint validation
      'created_at': vremeDodavanja?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// ✅ PRAVO REŠENJE: Asinhrono dodavanje adrese sa UUID reference
  Future<Map<String, dynamic>> toPutovanjaIstorijaMapWithAdresa() async {
    final baseMap = toPutovanjaIstorijaMap();

    // ✅ PRIORITET 1: Ako već imamo adresaId, koristi ga
    if (adresaId != null && adresaId!.isNotEmpty) {
      baseMap['adresa_id'] = adresaId;
      baseMap['napomene'] = 'Putovanje dodato ${DateTime.now().toIso8601String()}';
      return baseMap;
    }

    // ✅ PRIORITET 2: Ako imamo naziv adrese, kreiraj/pronađi adresu u tabeli
    if (adresa != null && adresa!.isNotEmpty && adresa != 'Adresa nije definisana') {
      try {
        // Pokušaj da pronađeš postojeću adresu ili kreiraj novu
        final adresaObj = await AdresaSupabaseService.createOrGetAdresa(
          naziv: adresa!,
          grad: grad,
        );
        if (adresaObj != null) {
          baseMap['adresa_id'] = adresaObj.id;
          baseMap['napomene'] = 'Putovanje dodato ${DateTime.now().toIso8601String()}'; // Ukloni adresu iz napomena
        }
      } catch (e) {
        // Ako ne može da kreira adresu, ostavi kako jeste sa adresom u napomenama
      }
    }

    return baseMap;
  }

  // Helper metoda za dobijanje kratice dana u nedelji

  static String _getDanNedeljeKratica(int weekday) {
    const daniKratice = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    return daniKratice[weekday - 1];
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
