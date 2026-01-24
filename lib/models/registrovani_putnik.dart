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
    this.obrisan = false,
    // Nova polja za database kompatibilnost
    this.tipPrikazivanja = 'standard',
    this.vozacId,
    // Computed fields za UI display (dolaze iz JOIN-a, ne šalju se u bazu)
    this.adresa,
    this.grad,
    // Tracking polja - UKLONJENO: pokupljen, placeno - sada u voznje_log
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
    this.brojMesta = 1, // 🆕 Broj rezervisanih mesta
    // Uklonjeno: ime, prezime, datumPocetka, datumKraja - duplikati
    // Uklonjeno: adresaBelaCrkva, adresaVrsac - koristimo UUID reference
  });

  /// Identifikator putnika
  final String id;

  /// Kombinovano ime i prezime putnika
  final String putnikIme;

  /// Broj telefona putnika
  final String? brojTelefona;

  /// Drugi/alternativni telefon za radnike i dnevne
  final String? brojTelefona2;

  /// Dodatni telefon oca (za učenike)
  final String? brojTelefonaOca;

  /// Dodatni telefon majke (za učenike)
  final String? brojTelefonaMajke;

  /// Tip putnika (radnik, učenik, itd.)
  final String tip;

  /// Tip škole (samo za učenike)
  final String? tipSkole;

  /// Polasci po danu - mapa gde je ključ dan, a vrednost lista vremena polaska
  final Map<String, List<String>> polasciPoDanu;

  /// UUID reference za adresu u Beloj Crkvi
  final String? adresaBelaCrkvaId;

  /// UUID reference za adresu u Vršcu
  final String? adresaVrsacId;

  /// Radni dani u formatu string (npr. pon,uto,sre,cet,pet)
  final String radniDani;

  /// Datum početka meseca
  final DateTime datumPocetkaMeseca;

  /// Datum kraja meseca
  final DateTime datumKrajaMeseca;

  /// Datum i vreme kreiranja zapisa
  final DateTime createdAt;

  /// Datum i vreme poslednje izmene zapisa
  final DateTime updatedAt;

  /// Da li je putnik aktivan
  final bool aktivan;

  /// Status putnika (aktivan, neaktivan, itd.)
  final String status;

  /// Da li je putnik obrisan (logičko brisanje)
  final bool obrisan;

  // Nova polja iz baze
  /// Tip prikazivanja putnika (standard, detaljno, itd.)
  final String tipPrikazivanja;

  /// ID vozača (ako je dodeljen)
  final String? vozacId;

  // Computed fields za UI display (dolaze iz JOIN-a, ne šalju se u bazu)
  /// Adresa putnika (izračunata polja)
  final String? adresa;

  /// Grad putnika (izračunata polja)
  final String? grad;

  // Tracking polja - UKLONJENO: pokupljen, placeno, vremePokupljenja - sada u voznje_log
  /// PIN za login
  final String? pin;

  /// Email za kontakt i Google Play testing
  final String? email;

  /// Custom cena po danu (NULL = default 700/600)
  final double? cenaPoDanu;
  // 🧾 Polja za račune
  /// Da li je potreban račun
  final bool trebaRacun;

  /// Naziv firme za račun
  final String? firmaNaziv;

  /// PIB firme za račun
  final String? firmaPib;

  /// MB firme za račun
  final String? firmaMb;

  /// Žiro račun firme za račun
  final String? firmaZiro;

  /// Adresa firme za račun
  final String? firmaAdresa;

  /// Broj rezervisanih mesta
  final int brojMesta;

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
      obrisan: map['obrisan'] as bool? ?? false,
      // Nova polja
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'standard',
      vozacId: map['vozac_id'] as String?,
      // Computed fields za UI display (dolaze iz JOIN-a)
      adresa: map['adresa'] as String?,
      grad: map['grad'] as String?,
      // Tracking polja - UKLONJENO: pokupljen, placeno - sada u voznje_log
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
      brojMesta: (map['broj_mesta'] as num?)?.toInt() ?? 1, // 🆕 Čitaj broj mesta
      // Uklonjeno: ime, prezime - koristi se putnikIme
      // Uklonjeno: datumPocetka, datumKraja - koriste se datumPocetkaMeseca/datumKrajaMeseca
    );
  }

  /// Konvertuje objekat u Map za bazu
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
      'obrisan': obrisan,
      'tip_prikazivanja': tipPrikazivanja,
      'vozac_id': vozacId,
      'email': email, // 📧 Email
      'cena_po_danu': cenaPoDanu, // 🆕 Custom cena po danu
      // 🧾 Polja za račune
      'treba_racun': trebaRacun,
      'firma_naziv': firmaNaziv,
      'firma_pib': firmaPib,
      'firma_mb': firmaMb,
      'firma_ziro': firmaZiro,
      'firma_adresa': firmaAdresa,
      'broj_mesta': brojMesta, // 🆕 Sačuvaj broj mesta
      // UKLONJENO iz baze: ukupna_cena_meseca, cena, broj_putovanja, broj_otkazivanja,
      // vreme_placanja, pokupljen, placeno - sada u voznje_log
    };

    // Dodaj id samo ako nije prazan (za UPDATE operacije)
    // Za INSERT operacije, ostavi id da baza generiše UUID
    if (id.isNotEmpty) {
      result['id'] = id;
    }

    return result;
  }

  String get punoIme => putnikIme;

  // UKLONJENO: jePlacen, iznosPlacanja, stvarniIznosPlacanja - sada se računa iz voznje_log

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
    bool? obrisan,
    // Computed fields za UI
    String? adresa,
    String? grad,
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
      obrisan: obrisan ?? this.obrisan,
      // Computed fields za UI
      adresa: adresa ?? this.adresa,
      grad: grad ?? this.grad,
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
}
