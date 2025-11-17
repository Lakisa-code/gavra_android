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
    this.rutaId,
    this.voziloId,
    this.adresaPolaskaId,
    this.adresaDolaskaId,
    // Vikend polasci
    this.polSubBc,
    this.polSubVs,
    this.polNedBc,
    this.polNedVs,
    // Dodatne informacije
    this.adresa,
    this.grad,
    this.firma,
    this.ukupnoVoznji = 0,
    this.activan = true,
    this.actionLog = const [],
    this.kreiran,
    this.azuriran,
    // Tracking polja
    this.dodaliVozaci = const [],
    this.putovanjaId,
    this.userId,
    this.tipPrevoza,
    this.placeno = false,
    this.datumPlacanja,
    this.posebneNapomene,
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
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      aktivan: map['aktivan'] as bool? ?? true,
      status: map['status'] as String? ?? 'aktivan',
      ukupnaCenaMeseca: (map['ukupna_cena_meseca'] as num?)?.toDouble() ?? 0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      obrisan: map['obrisan'] as bool? ?? false,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      statistics: Map<String, dynamic>.from(map['statistics'] as Map? ?? {}),
      // Nova polja
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'standard',
      vozacId: map['vozac_id'] as String?,
      pokupljen: map['pokupljen'] as bool? ?? false,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null,
      rutaId: map['ruta_id'] as String?,
      voziloId: map['vozilo_id'] as String?,
      adresaPolaskaId: map['adresa_polaska_id'] as String?,
      adresaDolaskaId: map['adresa_dolaska_id'] as String?,
      // Vikend polasci
      polSubBc: map['pol_sub_bc'] as String?,
      polSubVs: map['pol_sub_vs'] as String?,
      polNedBc: map['pol_ned_bc'] as String?,
      polNedVs: map['pol_ned_vs'] as String?,
      // Dodatne informacije
      adresa: map['adresa'] as String?,
      grad: map['grad'] as String?,
      firma: map['firma'] as String?,
      ukupnoVoznji: map['ukupno_voznji'] as int? ?? 0,
      activan: map['activan'] as bool? ?? true,
      actionLog: map['action_log'] as List? ?? [],
      kreiran: map['kreiran'] != null
          ? DateTime.parse(map['kreiran'] as String)
          : null,
      azuriran: map['azuriran'] != null
          ? DateTime.parse(map['azuriran'] as String)
          : null,
      // Tracking polja
      dodaliVozaci: map['dodali_vozaci'] as List? ?? [],
      putovanjaId: map['putovanja_id'] as String?,
      userId: map['user_id'] as String?,
      tipPrevoza: map['tip_prevoza'] as String?,
      placeno: map['placeno'] as bool? ?? false,
      datumPlacanja: map['datum_placanja'] != null
          ? DateTime.parse(map['datum_placanja'] as String)
          : null,
      posebneNapomene: map['posebne_napomene'] as String?,
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
  final String? rutaId;
  final String? voziloId;
  final String? adresaPolaskaId;
  final String? adresaDolaskaId;

  // Vikend polasci
  final String? polSubBc;
  final String? polSubVs;
  final String? polNedBc;
  final String? polNedVs;

  // Dodatne informacije
  final String? adresa;
  final String? grad;
  final String? firma;
  final int ukupnoVoznji;
  final bool activan;
  final List<dynamic> actionLog;
  final DateTime? kreiran;
  final DateTime? azuriran;

  // Tracking polja
  final List<dynamic> dodaliVozaci;
  final String? putovanjaId;
  final String? userId;
  final String? tipPrevoza;
  final bool placeno;
  final DateTime? datumPlacanja;
  final String? posebneNapomene;
  // Uklonjeno legacy polja: ime, prezime, datumPocetka, datumKraja

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
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'aktivan': aktivan,
      'status': status,
      'ukupna_cena_meseca': ukupnaCenaMeseca,
      'cena': cena,
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'vreme_pokupljenja': vremePokupljenja
          ?.toIso8601String(), // Koristi vremePokupljenja umesto poslednjePutovanje
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'placeni_mesec': placeniMesec,
      'placena_godina': placenaGodina,
      'statistics': stats,
      // Nova polja iz baze
      'tip_prikazivanja': tipPrikazivanja,
      'vozac_id': vozacId,
      'pokupljen': pokupljen,
      'ruta_id': rutaId,
      'vozilo_id': voziloId,
      'adresa_polaska_id': adresaPolaskaId,
      'adresa_dolaska_id': adresaDolaskaId,
      // Vikend polasci
      'pol_sub_bc': polSubBc,
      'pol_sub_vs': polSubVs,
      'pol_ned_bc': polNedBc,
      'pol_ned_vs': polNedVs,
      // Dodatne informacije
      'adresa': adresa,
      'grad': grad,
      'firma': firma,
      'ukupno_voznji': ukupnoVoznji,
      'activan': activan,
      'action_log': actionLog,
      'kreiran': kreiran?.toIso8601String(),
      'azuriran': azuriran?.toIso8601String(),
      // Tracking polja
      'dodali_vozaci': dodaliVozaci,
      'putovanja_id': putovanjaId,
      'user_id': userId,
      'tip_prevoza': tipPrevoza,
      'placeno': placeno,
      'datum_placanja': datumPlacanja?.toIso8601String(),
      'posebne_napomene': posebneNapomene,
      // Uklonjeno: ime, prezime, datum_pocetka, datum_kraja - duplikati
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
    // Nove kolone
    String? polSubBc,
    String? polSubVs,
    String? polNedBc,
    String? polNedVs,
    String? adresa,
    String? grad,
    String? firma,
    int? ukupnoVoznji,
    bool? activan,
    List<dynamic>? actionLog,
    DateTime? kreiran,
    DateTime? azuriran,
    List<dynamic>? dodaliVozaci,
    String? putovanjaId,
    String? userId,
    String? tipPrevoza,
    bool? placeno,
    DateTime? datumPlacanja,
    String? posebneNapomene,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
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
      // Nove kolone
      polSubBc: polSubBc ?? this.polSubBc,
      polSubVs: polSubVs ?? this.polSubVs,
      polNedBc: polNedBc ?? this.polNedBc,
      polNedVs: polNedVs ?? this.polNedVs,
      adresa: adresa ?? this.adresa,
      grad: grad ?? this.grad,
      firma: firma ?? this.firma,
      ukupnoVoznji: ukupnoVoznji ?? this.ukupnoVoznji,
      activan: activan ?? this.activan,
      actionLog: actionLog ?? this.actionLog,
      kreiran: kreiran ?? this.kreiran,
      azuriran: azuriran ?? this.azuriran,
      dodaliVozaci: dodaliVozaci ?? this.dodaliVozaci,
      putovanjaId: putovanjaId ?? this.putovanjaId,
      userId: userId ?? this.userId,
      tipPrevoza: tipPrevoza ?? this.tipPrevoza,
      placeno: placeno ?? this.placeno,
      datumPlacanja: datumPlacanja ?? this.datumPlacanja,
      posebneNapomene: posebneNapomene ?? this.posebneNapomene,
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
    return putnikIme.isNotEmpty &&
        tip.isNotEmpty &&
        polasciPoDanu.isNotEmpty &&
        id.isNotEmpty;
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
      errors['telefoni'] =
          'Jedan ili više brojeva telefona nije u ispravnom formatu';
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
    final daniList = radniDani
        .toLowerCase()
        .split(',')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();
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
    return radniDani
        .split(',')
        .map((d) => d.trim())
        .where((dan) => dan.isNotEmpty)
        .length;
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
}
