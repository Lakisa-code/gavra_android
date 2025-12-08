import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/adresa_supabase_service.dart';
import '../utils/mesecni_helpers.dart';

/// Model za mesečne putnike - ažurirana verzija
class MesecniPutnik {
  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    this.brojTelefona,
    this.brojTelefonaOca,
    this.brojTelefonaMajke,
    required this.tip,
    this.tipSkole,
    this.napomena,
    required this.polasciPoDanu,
    this.adresaBelaCrkvaId,
    this.adresaVrsacId,
    this.radniDani = 'pon,uto,sre,cet,pet',
    required this.datumPocetkaMeseca,
    required this.datumKrajaMeseca,
    required this.createdAt,
    required this.updatedAt,
    this.aktivan = true,
    this.status = 'aktivan',
    this.ukupnaCenaMeseca = 0.0,
    this.cena,
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.obrisan = false,
    this.vremePlacanja,
    this.placeniMesec,
    this.placenaGodina,
    this.statistics = const {},
    // Nova polja za database kompatibilnost
    this.tipPrikazivanja = 'standard',
    this.vozacId,
    this.pokupljen = false,
    this.vremePokupljenja,
    // Computed fields za UI display (dolaze iz JOIN-a, ne šalju se u bazu)
    this.adresa,
    this.grad,
    this.actionLog = const [],
    // Tracking polja
    this.dodaliVozaci = const [],
    this.placeno = false,
    this.datumPlacanja,
    this.pin,
    this.cenaPoDanu, // 🆕 Custom cena po danu (ako je NULL, koristi default: 700 radnik, 600 učenik)
    // Uklonjeno: ime, prezime, datumPocetka, datumKraja - duplikati
    // Uklonjeno: adresaBelaCrkva, adresaVrsac - koristimo UUID reference
  });

  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    // Parse polasciPoDanu using helper
    Map<String, List<String>> polasciPoDanu = {};
    final parsed = MesecniHelpers.parsePolasciPoDanu(map['polasci_po_danu']);
    parsed.forEach((day, inner) {
      final List<String> list = [];
      final bc = inner['bc'];
      final vs = inner['vs'];
      if (bc != null && bc.isNotEmpty) list.add('$bc BC');
      if (vs != null && vs.isNotEmpty) list.add('$vs VS');
      if (list.isNotEmpty) polasciPoDanu[day] = list;
    });

    return MesecniPutnik(
      id: map['id'] as String? ?? _generateUuid(),
      putnikIme: map['putnik_ime'] as String? ?? map['ime'] as String? ?? '',
      brojTelefona: map['broj_telefona'] as String?,
      brojTelefonaOca: map['broj_telefona_oca'] as String?,
      brojTelefonaMajke: map['broj_telefona_majke'] as String?,
      tip: map['tip'] as String? ?? 'radnik',
      tipSkole: map['tip_skole'] as String?,
      napomena: map['napomena'] as String?,
      polasciPoDanu: polasciPoDanu,
      adresaBelaCrkvaId: map['adresa_bela_crkva_id'] as String?,
      adresaVrsacId: map['adresa_vrsac_id'] as String?,
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      datumPocetkaMeseca: map['datum_pocetka_meseca'] != null
          ? DateTime.parse(map['datum_pocetka_meseca'] as String)
          : DateTime(DateTime.now().year, DateTime.now().month),
      datumKrajaMeseca: map['datum_kraja_meseca'] != null
          ? DateTime.parse(map['datum_kraja_meseca'] as String)
          : DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
      aktivan: map['aktivan'] as bool? ?? true,
      status: map['status'] as String? ?? 'aktivan',
      ukupnaCenaMeseca: (map['ukupna_cena_meseca'] as num?)?.toDouble() ?? 0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      obrisan: map['obrisan'] as bool? ?? false,
      vremePlacanja: map['vreme_placanja'] != null ? DateTime.parse(map['vreme_placanja'] as String) : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      statistics: Map<String, dynamic>.from(map['statistics'] as Map? ?? {}),
      // Nova polja
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'standard',
      vozacId: map['vozac_id'] as String?,
      pokupljen: map['pokupljen'] as bool? ?? false,
      vremePokupljenja: map['vreme_pokupljenja'] != null ? DateTime.parse(map['vreme_pokupljenja'] as String) : null,
      // Computed fields za UI display (dolaze iz JOIN-a)
      adresa: map['adresa'] as String?,
      grad: map['grad'] as String?,
      actionLog: _parseActionLog(map['action_log']),
      // Tracking polja
      dodaliVozaci: _parseDodaliVozaci(map['dodali_vozaci']),
      placeno: map['placeno'] as bool? ?? false,
      datumPlacanja: map['datum_placanja'] != null ? DateTime.parse(map['datum_placanja'] as String) : null,
      pin: map['pin'] as String?,
      cenaPoDanu: (map['cena_po_danu'] as num?)?.toDouble(), // 🆕 Custom cena po danu
      // Uklonjeno: ime, prezime - koristi se putnikIme
      // Uklonjeno: datumPocetka, datumKraja - koriste se datumPocetkaMeseca/datumKrajaMeseca
    );
  }
  final String id;
  final String putnikIme; // kombinovano ime i prezime
  final String? brojTelefona;
  final String? brojTelefonaOca; // dodatni telefon oca
  final String? brojTelefonaMajke; // dodatni telefon majke
  final String tip; // direktno string umesto enum-a
  final String? tipSkole;
  final String? napomena;
  final Map<String, List<String>> polasciPoDanu; // dan -> lista vremena polaska
  final String? adresaBelaCrkvaId; // UUID reference u tabelu adrese
  final String? adresaVrsacId; // UUID reference u tabelu adrese
  final String radniDani;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool aktivan;
  final String status;
  // Ostali fields za kompatibilnost
  final double ukupnaCenaMeseca;
  final double? cena;
  final int brojPutovanja;
  final int brojOtkazivanja;
  final bool obrisan;
  final DateTime? vremePlacanja;
  final int? placeniMesec;
  final int? placenaGodina;
  final Map<String, dynamic> statistics;

  // Nova polja iz baze
  final String tipPrikazivanja;
  final String? vozacId;
  final bool pokupljen;
  final DateTime? vremePokupljenja;

  // Computed fields za UI display (dolaze iz JOIN-a, ne šalju se u bazu)
  final String? adresa;
  final String? grad;
  final List<dynamic> actionLog;

  // Tracking polja
  final List<dynamic> dodaliVozaci;
  final bool placeno;
  final DateTime? datumPlacanja;
  final String? pin; // 🔐 PIN za login
  final double? cenaPoDanu; // 🆕 Custom cena po danu (NULL = default 700/600)

  Map<String, dynamic> toMap() {
    // Build normalized polasci_po_danu structure
    final Map<String, Map<String, String?>> normalizedPolasci = {};
    polasciPoDanu.forEach((day, times) {
      String? bc;
      String? vs;
      for (final time in times) {
        final normalized = MesecniHelpers.normalizeTime(time.split(' ')[0]);
        if (time.contains('BC')) {
          bc = normalized;
        } else if (time.contains('VS')) {
          vs = normalized;
        }
      }
      normalizedPolasci[day] = {'bc': bc, 'vs': vs};
    });

    // Build statistics
    Map<String, dynamic> stats = Map.from(statistics);
    stats.addAll({
      'trips_total': brojPutovanja,
      'cancellations_total': brojOtkazivanja,
      'last_trip': vremePokupljenja?.toIso8601String(),
    });

    // ⚔️ BINARYBITCH CLEAN toMap() - SAMO kolone koje postoje u bazi!
    Map<String, dynamic> result = {
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'broj_telefona_oca': brojTelefonaOca,
      'broj_telefona_majke': brojTelefonaMajke,
      'tip': tip,
      'tip_skole': tipSkole,
      'napomena': napomena,
      'polasci_po_danu': normalizedPolasci,
      'adresa_bela_crkva_id': adresaBelaCrkvaId,
      'adresa_vrsac_id': adresaVrsacId,
      'radni_dani': radniDani,
      'datum_pocetka_meseca': datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'aktivan': aktivan,
      'status': status,
      'ukupna_cena_meseca': ukupnaCenaMeseca,
      'cena': cena,
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'placeni_mesec': placeniMesec,
      'placena_godina': placenaGodina,
      'statistics': stats,
      'tip_prikazivanja': tipPrikazivanja,
      'vozac_id': vozacId,
      'pokupljen': pokupljen,
      'action_log': actionLog,
      'dodali_vozaci': dodaliVozaci,
      'placeno': placeno,
      'datum_placanja': datumPlacanja?.toIso8601String(),
      'cena_po_danu': cenaPoDanu, // 🆕 Custom cena po danu
      // 'pin': pin, // PIN se ne šalje iz modela, čuva se posebno
    };

    // Dodaj id samo ako nije prazan (za UPDATE operacije)
    // Za INSERT operacije, ostavi id da baza generiše UUID
    if (id.isNotEmpty) {
      result['id'] = id;
    }

    return result;
  }

  String get punoIme => putnikIme;

  bool get jePlacen => vremePlacanja != null;

  /// Iznos plaćanja - kompatibilnost sa statistika_service
  double? get iznosPlacanja => cena ?? ukupnaCenaMeseca;

  /// Stvarni iznos plaćanja koji treba da se kombinuje sa putovanja_istorija
  /// Ovo je placeholder - potrebno je da se implementira kombinovanje sa istorijom
  double? get stvarniIznosPlacanja {
    // Ako postoji cena u mesecni_putnici, vrati je
    if (cena != null && cena! > 0) return cena;

    // Inače treba da se pretraži putovanja_istorija tabela
    // Za sada vraćamo cenu ili ukupnaCenaMeseca kao fallback
    return cena ?? (ukupnaCenaMeseca > 0 ? ukupnaCenaMeseca : null);
  }

  /// Polazak za Belu Crkvu za dati dan
  String? getPolazakBelaCrkvaZaDan(String dan) {
    final polasci = polasciPoDanu[dan] ?? [];
    for (final polazak in polasci) {
      if (polazak.toUpperCase().contains('BC')) {
        return polazak.replaceAll(' BC', '').trim();
      }
    }
    return null;
  }

  /// Polazak za Vršac za dati dan
  String? getPolazakVrsacZaDan(String dan) {
    final polasci = polasciPoDanu[dan] ?? [];
    for (final polazak in polasci) {
      if (polazak.toUpperCase().contains('VS')) {
        return polazak.replaceAll(' VS', '').trim();
      }
    }
    return null;
  }

  /// copyWith metoda za kreiranje kopije sa izmenjenim poljima
  MesecniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? brojTelefona,
    String? brojTelefonaOca,
    String? brojTelefonaMajke,
    String? tip,
    String? tipSkole,
    String? napomena,
    Map<String, List<String>>? polasciPoDanu,
    String? adresaBelaCrkvaId,
    String? adresaVrsacId,
    String? radniDani,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    bool? aktivan,
    String? status,
    double? ukupnaCenaMeseca,
    double? cena,
    DateTime? vremePlacanja,
    int? placeniMesec,
    int? placenaGodina,
    int? brojPutovanja,
    int? brojOtkazivanja,
    bool? obrisan,
    Map<String, dynamic>? statistics,
    // Computed fields za UI
    String? adresa,
    String? grad,
    List<dynamic>? actionLog,
    // Tracking
    List<dynamic>? dodaliVozaci,
    bool? placeno,
    DateTime? datumPlacanja,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      brojTelefonaOca: brojTelefonaOca ?? this.brojTelefonaOca,
      brojTelefonaMajke: brojTelefonaMajke ?? this.brojTelefonaMajke,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      napomena: napomena ?? this.napomena,
      polasciPoDanu: polasciPoDanu ?? this.polasciPoDanu,
      adresaBelaCrkvaId: adresaBelaCrkvaId ?? this.adresaBelaCrkvaId,
      adresaVrsacId: adresaVrsacId ?? this.adresaVrsacId,
      radniDani: radniDani ?? this.radniDani,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      aktivan: aktivan ?? this.aktivan,
      status: status ?? this.status,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      cena: cena ?? this.cena,
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      obrisan: obrisan ?? this.obrisan,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      placeniMesec: placeniMesec ?? this.placeniMesec,
      placenaGodina: placenaGodina ?? this.placenaGodina,
      statistics: statistics ?? this.statistics,
      // Computed fields za UI
      adresa: adresa ?? this.adresa,
      grad: grad ?? this.grad,
      actionLog: actionLog ?? this.actionLog,
      // Tracking
      dodaliVozaci: dodaliVozaci ?? this.dodaliVozaci,
      placeno: placeno ?? this.placeno,
      datumPlacanja: datumPlacanja ?? this.datumPlacanja,
    );
  }

  /// Lista svih vremena polaska za dati dan
  List<String> getPolasciZaDan(String dan) {
    return polasciPoDanu[dan] ?? [];
  }

  /// Dodaje vreme polaska za dati dan
  void dodajPolazak(String dan, String vreme) {
    if (!polasciPoDanu.containsKey(dan)) {
      polasciPoDanu[dan] = [];
    }
    if (!polasciPoDanu[dan]!.contains(vreme)) {
      polasciPoDanu[dan]!.add(vreme);
    }
  }

  /// Uklanja vreme polaska za dati dan
  void ukloniPolazak(String dan, String vreme) {
    polasciPoDanu[dan]?.remove(vreme);
    if (polasciPoDanu[dan]?.isEmpty ?? false) {
      polasciPoDanu.remove(dan);
    }
  }

  @override
  String toString() {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan)';
  }

  // ==================== VALIDATION METHODS ====================

  /// Validira da li su osnovna polja popunjena
  bool isValid() {
    return putnikIme.isNotEmpty && tip.isNotEmpty && polasciPoDanu.isNotEmpty && id.isNotEmpty;
  }

  /// Validira format telefona (srpski brojevi)
  bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return true; // Optional field
    final phoneRegex = RegExp(r'^(\+381|0)[6-9]\d{7,8}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  /// Validira da li su svi kontakt brojevi u ispravnom formatu
  bool hasValidPhoneNumbers() {
    return isValidPhoneNumber(brojTelefona) &&
        isValidPhoneNumber(brojTelefonaOca) &&
        isValidPhoneNumber(brojTelefonaMajke);
  }

  /// Validira da li putnik ima validnu adresu
  bool hasValidAddress() {
    return (adresaBelaCrkvaId != null && adresaBelaCrkvaId!.isNotEmpty) ||
        (adresaVrsacId != null && adresaVrsacId!.isNotEmpty);
  }

  /// Validira da li je period važenja valjan
  bool hasValidPeriod() {
    return datumKrajaMeseca.isAfter(datumPocetkaMeseca);
  }

  /// Kompletna validacija sa detaljnim rezultatom
  Map<String, String> validateFull() {
    final errors = <String, String>{};

    if (putnikIme.trim().isEmpty) {
      errors['putnikIme'] = 'Ime putnika je obavezno';
    }

    if (tip.isEmpty || !['radnik', 'ucenik'].contains(tip)) {
      errors['tip'] = 'Tip mora biti "radnik" ili "ucenik"';
    }

    if (tip == 'ucenik' && (tipSkole == null || tipSkole!.isEmpty)) {
      errors['tipSkole'] = 'Tip škole je obavezan za učenike';
    }

    if (!hasValidPhoneNumbers()) {
      errors['telefoni'] = 'Jedan ili više brojeva telefona nije u ispravnom formatu';
    }

    if (polasciPoDanu.isEmpty) {
      errors['polasciPoDanu'] = 'Mora biti definisan bar jedan polazak';
    }

    if (!hasValidPeriod()) {
      errors['period'] = 'Datum kraja mora biti posle datuma početka';
    }

    if (cena != null && cena! < 0) {
      errors['cena'] = 'Cena ne može biti negativna';
    }

    return errors;
  }

  // ==================== ADDRESS HELPERS ====================

  /// Dobija naziv adrese za Belu Crkvu
  Future<String?> getAdresaBelaCrkvaNaziv() async {
    if (adresaBelaCrkvaId == null) return null;
    return await AdresaSupabaseService.getNazivAdreseByUuid(adresaBelaCrkvaId);
  }

  /// Dobija naziv adrese za Vršac
  Future<String?> getAdresaVrsacNaziv() async {
    if (adresaVrsacId == null) return null;
    return await AdresaSupabaseService.getNazivAdreseByUuid(adresaVrsacId);
  }

  /// Dobija formatiran prikaz adresa (za UI)
  Future<String> getFormatiranePrikkazAdresa() async {
    final bcNaziv = await getAdresaBelaCrkvaNaziv();
    final vsNaziv = await getAdresaVrsacNaziv();

    final adrese = <String>[];
    if (bcNaziv != null) adrese.add(bcNaziv); // Uklonjen "BC:" prefiks
    if (vsNaziv != null) adrese.add(vsNaziv); // Uklonjen "VS:" prefiks

    return adrese.isEmpty ? 'Nema adresa' : adrese.join(' | ');
  }

  /// Dobija adresu za prikaz na osnovu selektovanog grada
  Future<String> getAdresaZaSelektovaniGrad(String? selektovaniGrad) async {
    final bcNaziv = await getAdresaBelaCrkvaNaziv();
    final vsNaziv = await getAdresaVrsacNaziv();

    // Logika: prikaži adresu za selektovani grad
    if (selektovaniGrad?.toLowerCase().contains('bela') == true) {
      // BC selektovano → prikaži BC adresu, fallback na VS
      if (bcNaziv != null) return bcNaziv;
      if (vsNaziv != null) return vsNaziv;
    } else {
      // VS selektovano → prikaži VS adresu, fallback na BC
      if (vsNaziv != null) return vsNaziv;
      if (bcNaziv != null) return bcNaziv;
    }

    return 'Nema adresa';
  }

  /// Legacy kompatibilnost - vraća TEXT naziv Bela Crkva adrese
  @Deprecated('Koristi getAdresaBelaCrkvaNaziv() umesto TEXT polja')
  Future<String?> get adresaBelaCrkva async => await getAdresaBelaCrkvaNaziv();

  /// Legacy kompatibilnost - vraća TEXT naziv Vršac adrese
  @Deprecated('Koristi getAdresaVrsacNaziv() umesto TEXT polja')
  Future<String?> get adresaVrsac async => await getAdresaVrsacNaziv();

  // ==================== RELATIONSHIP HELPERS ===================="

  /// Da li putnik ima mesečnu kartu (uvek true za MesecniPutnik)
  bool get hasMesecnaKarta => true;

  /// Da li je putnik učenik
  bool get isUcenik => tip == 'ucenik';

  /// Da li je putnik radnik
  bool get isRadnik => tip == 'radnik';

  /// Da li putnik radi danas
  bool radiDanas() {
    final today = DateTime.now();
    final days = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final todayKey = days[today.weekday - 1];
    final daniList = radniDani.toLowerCase().split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toList();
    return daniList.contains(todayKey);
  }

  /// Dobija polazna vremena za danas
  List<String> getPolasciZaDanas() {
    final today = DateTime.now();
    final days = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];
    final todayKey = days[today.weekday - 1];
    return polasciPoDanu[todayKey] ?? [];
  }

  /// Da li putnik treba da bude pokupljen u određeno vreme
  bool trebaPokupiti(String vreme) {
    final polasciDanas = getPolasciZaDanas();
    return polasciDanas.any((polazak) => polazak.contains(vreme));
  }

  /// Broj aktivnih dana u nedelji
  int get brojAktivnihDana {
    return radniDani.split(',').map((d) => d.trim()).where((dan) => dan.isNotEmpty).length;
  }

  /// Da li je plaćen za trenutni mesec
  bool get isPlacenZaTrenutniMesec {
    if (vremePlacanja == null) return false;
    final now = DateTime.now();
    return placeniMesec == now.month && placenaGodina == now.year;
  }

  /// Kalkuliše mesečnu cenu na osnovu broja aktivnih dana
  double kalkulirajMesecnuCenu(double dnevnaCena) {
    return dnevnaCena * brojAktivnihDana * 4; // 4 nedelje u mesecu
  }

  // ==================== UI HELPERS ====================

  /// Dobija boju na osnovu statusa
  Color getStatusColor() {
    if (!aktivan) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'aktivan':
      case 'radi':
        return Colors.green;
      case 'neaktivan':
      case 'pauza':
        return Colors.orange;
      case 'obrisan':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Formatiran prikaz perioda važenja
  String get formatiraniPeriod {
    final formatter = DateFormat('dd.MM.yyyy');
    return '${formatter.format(datumPocetkaMeseca)} - ${formatter.format(datumKrajaMeseca)}';
  }

  /// Kratki opis putnika za UI
  String get shortDescription {
    final tipText = isUcenik ? '👨‍🎓' : '👨‍💼';
    final statusText = aktivan ? '✅' : '❌';
    return '$tipText $putnikIme $statusText';
  }

  /// Detaljni opis za debug
  String get detailDescription {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan, status: $status, polasci: ${polasciPoDanu.length}, period: $formatiraniPeriod)';
  }

  /// ✅ HELPER: Generiši UUID ako nedostaje iz baze
  static String _generateUuid() {
    // Jednostavna UUID v4 simulacija za fallback
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toRadixString(36);
    return 'fallback-uuid-$random';
  }

  /// ✅ HELPER: Parsira action_log - može biti List, Map ili null
  static List<dynamic> _parseActionLog(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is Map) return [value]; // Wrap Map u List
    return [];
  }

  /// ✅ HELPER: Parsira dodali_vozaci - može biti List, Map ili null
  static List<dynamic> _parseDodaliVozaci(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    if (value is Map) return [value]; // Wrap Map u List
    if (value is String) return [value]; // Wrap String u List
    return [];
  }
}
