import '../services/adresa_supabase_service.dart';
import '../utils/registrovani_helpers.dart';

/// Model za mesečne putnike - ažurirana verzija
class RegistrovaniPutnik {
  RegistrovaniPutnik({
    required this.id,
    required this.putnikIme,
    this.brojTelefona,
    this.brojTelefona2,
    this.brojTelefonaOca,
    this.brojTelefonaMajke,
    required this.tip,
    this.tipSkole,
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
    this.pin,
    this.email, // 📧 Email za kontakt i Google Play testing
    this.cenaPoDanu, // 🆕 Custom cena po danu (ako je NULL, koristi default: 700 radnik, 600 učenik)
    // 🧾 Polja za račune
    this.trebaRacun = false,
    this.firmaNaziv,
    this.firmaPib,
    this.firmaMb,
    this.firmaZiro,
    this.firmaAdresa,
    // Uklonjeno: ime, prezime, datumPocetka, datumKraja - duplikati
    // Uklonjeno: adresaBelaCrkva, adresaVrsac - koristimo UUID reference
  });

  factory RegistrovaniPutnik.fromMap(Map<String, dynamic> map) {
    // Parse polasciPoDanu using helper
    Map<String, List<String>> polasciPoDanu = {};
    final parsed = RegistrovaniHelpers.parsePolasciPoDanu(map['polasci_po_danu']);
    parsed.forEach((day, inner) {
      final List<String> list = [];
      final bc = inner['bc'];
      final vs = inner['vs'];
      if (bc != null && bc.isNotEmpty) list.add('$bc BC');
      if (vs != null && vs.isNotEmpty) list.add('$vs VS');
      if (list.isNotEmpty) polasciPoDanu[day] = list;
    });

    return RegistrovaniPutnik(
      id: map['id'] as String? ?? _generateUuid(),
      putnikIme: map['putnik_ime'] as String? ?? map['ime'] as String? ?? '',
      brojTelefona: map['broj_telefona'] as String?,
      brojTelefona2: map['broj_telefona_2'] as String?,
      brojTelefonaOca: map['broj_telefona_oca'] as String?,
      brojTelefonaMajke: map['broj_telefona_majke'] as String?,
      tip: map['tip'] as String? ?? 'radnik',
      tipSkole: map['tip_skole'] as String?,
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
      // Nova polja
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'standard',
      vozacId: map['vozac_id'] as String?,
      pokupljen: false,
      vremePokupljenja: null, // ✅ UKLONJENO: kolona obrisana iz baze
      // Computed fields za UI display (dolaze iz JOIN-a)
      adresa: map['adresa'] as String?,
      grad: map['grad'] as String?,
      actionLog: const [], // ✅ UKLONJENO: action_log više ne koristimo
      // Tracking polja
      dodaliVozaci: _parseDodaliVozaci(map['dodali_vozaci']),
      placeno: map['placeno'] as bool? ?? false,
      pin: map['pin'] as String?,
      email: map['email'] as String?, // 📧 Email
      cenaPoDanu: (map['cena_po_danu'] as num?)?.toDouble(), // 🆕 Custom cena po danu
      // 🧾 Polja za račune
      trebaRacun: map['treba_racun'] as bool? ?? false,
      firmaNaziv: map['firma_naziv'] as String?,
      firmaPib: map['firma_pib'] as String?,
      firmaMb: map['firma_mb'] as String?,
      firmaZiro: map['firma_ziro'] as String?,
      firmaAdresa: map['firma_adresa'] as String?,
      // Uklonjeno: ime, prezime - koristi se putnikIme
      // Uklonjeno: datumPocetka, datumKraja - koriste se datumPocetkaMeseca/datumKrajaMeseca
    );
  }
  final String id;
  final String putnikIme; // kombinovano ime i prezime
  final String? brojTelefona;
  final String? brojTelefona2; // drugi/alternativni telefon za radnike i dnevne
  final String? brojTelefonaOca; // dodatni telefon oca (za učenike)
  final String? brojTelefonaMajke; // dodatni telefon majke (za učenike)
  final String tip; // direktno string umesto enum-a
  final String? tipSkole;
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
  final String? pin; // 🔐 PIN za login
  final String? email; // 📧 Email za kontakt i Google Play testing
  final double? cenaPoDanu; // 🆕 Custom cena po danu (NULL = default 700/600)
  // 🧾 Polja za račune
  final bool trebaRacun;
  final String? firmaNaziv;
  final String? firmaPib;
  final String? firmaMb;
  final String? firmaZiro;
  final String? firmaAdresa;

  Map<String, dynamic> toMap() {
    // Build normalized polasci_po_danu structure
    final Map<String, Map<String, String?>> normalizedPolasci = {};
    polasciPoDanu.forEach((day, times) {
      String? bc;
      String? vs;
      for (final time in times) {
        final normalized = RegistrovaniHelpers.normalizeTime(time.split(' ')[0]);
        if (time.contains('BC')) {
          bc = normalized;
        } else if (time.contains('VS')) {
          vs = normalized;
        }
      }
      normalizedPolasci[day] = {'bc': bc, 'vs': vs};
    });

    // ⚔️ BINARYBITCH CLEAN toMap() - SAMO kolone koje postoje u bazi!
    Map<String, dynamic> result = {
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'broj_telefona_2': brojTelefona2,
      'broj_telefona_oca': brojTelefonaOca,
      'broj_telefona_majke': brojTelefonaMajke,
      'tip': tip,
      'tip_skole': tipSkole,
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
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'placeni_mesec': placeniMesec,
      'placena_godina': placenaGodina,
      'tip_prikazivanja': tipPrikazivanja,
      'vozac_id': vozacId,
      'pokupljen': pokupljen,
      'action_log': actionLog,
      'dodali_vozaci': dodaliVozaci,
      'placeno': placeno,
      'email': email, // 📧 Email
      'cena_po_danu': cenaPoDanu, // 🆕 Custom cena po danu
      // 🧾 Polja za račune
      'treba_racun': trebaRacun,
      'firma_naziv': firmaNaziv,
      'firma_pib': firmaPib,
      'firma_mb': firmaMb,
      'firma_ziro': firmaZiro,
      'firma_adresa': firmaAdresa,
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

  /// Stvarni iznos plaćanja
  double? get stvarniIznosPlacanja {
    // Ako postoji cena u registrovani_putnici, vrati je
    if (cena != null && cena! > 0) return cena;

    // Vraćamo cenu ili ukupnaCenaMeseca kao fallback
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
  RegistrovaniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? brojTelefona,
    String? brojTelefonaOca,
    String? brojTelefonaMajke,
    String? tip,
    String? tipSkole,
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
    // Computed fields za UI
    String? adresa,
    String? grad,
    List<dynamic>? actionLog,
    // Tracking
    List<dynamic>? dodaliVozaci,
    bool? placeno,
    // 🧾 Polja za račune
    bool? trebaRacun,
    String? firmaNaziv,
    String? firmaPib,
    String? firmaMb,
    String? firmaZiro,
    String? firmaAdresa,
  }) {
    return RegistrovaniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      brojTelefonaOca: brojTelefonaOca ?? this.brojTelefonaOca,
      brojTelefonaMajke: brojTelefonaMajke ?? this.brojTelefonaMajke,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
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
      // Computed fields za UI
      adresa: adresa ?? this.adresa,
      grad: grad ?? this.grad,
      actionLog: actionLog ?? this.actionLog,
      // Tracking
      dodaliVozaci: dodaliVozaci ?? this.dodaliVozaci,
      placeno: placeno ?? this.placeno,
      // 🧾 Polja za račune
      trebaRacun: trebaRacun ?? this.trebaRacun,
      firmaNaziv: firmaNaziv ?? this.firmaNaziv,
      firmaPib: firmaPib ?? this.firmaPib,
      firmaMb: firmaMb ?? this.firmaMb,
      firmaZiro: firmaZiro ?? this.firmaZiro,
      firmaAdresa: firmaAdresa ?? this.firmaAdresa,
    );
  }

  @override
  String toString() {
    return 'RegistrovaniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan)';
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

  /// ✅ HELPER: Generiši UUID ako nedostaje iz baze
  static String _generateUuid() {
    // Jednostavna UUID v4 simulacija za fallback
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toRadixString(36);
    return 'fallback-uuid-$random';
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
