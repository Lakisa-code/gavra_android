import 'package:uuid/uuid.dart';
import 'putnik.dart';
import 'adresa.dart';
import 'ruta.dart';

/// Tip mesečnih putnika
enum MesecniPutnikTip {
  ucenik,
  penzioner,
  zaposlen,
  drugi,
}

extension MesecniPutnikTipExtension on MesecniPutnikTip {
  String get value {
    switch (this) {
      case MesecniPutnikTip.ucenik:
        return 'ucenik';
      case MesecniPutnikTip.penzioner:
        return 'penzioner';
      case MesecniPutnikTip.zaposlen:
        return 'zaposlen';
      case MesecniPutnikTip.drugi:
        return 'drugi';
    }
  }

  static MesecniPutnikTip fromString(String tip) {
    switch (tip.toLowerCase()) {
      case 'ucenik':
        return MesecniPutnikTip.ucenik;
      case 'penzioner':
        return MesecniPutnikTip.penzioner;
      case 'zaposlen':
        return MesecniPutnikTip.zaposlen;
      case 'drugi':
      default:
        return MesecniPutnikTip.drugi;
    }
  }
}

/// Model za mesečne putnike (normalizovana šema)
class MesecniPutnik {
  final String id;
  final String ime;
  final String prezime;
  final String? brojTelefona;
  final MesecniPutnikTip tip;
  final String? tipSkole;
  final String adresaId;
  final String rutaId;
  final Map<String, List<String>> polasciPoDanu; // dan -> lista vremena polaska
  final double cenaMesecneKarte;
  final DateTime datumPocetka;
  final DateTime datumKraja;
  final bool aktivan;
  final String? napomena;
  final DateTime? vremePlacanja;
  final String? naplatioVozacId;
  final DateTime? poslednjePutovanje;
  final int brojPutovanja;
  final int brojOtkazivanja;
  final bool obrisan;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Kompatibilnost sa starim modelom
  final String? brojTelefonaOca;
  final String? brojTelefonaMajke;
  final String? adresaBelaCrkva;
  final String? adresaVrsac;
  final String status;
  final String radniDani;
  final String tipPrikazivanja;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final double? cena;
  final double ukupnaCenaMeseca;
  final int? placeniMesec;
  final int? placenaGodina;
  final String? vozac;
  final bool pokupljen;
  final DateTime? vremePokupljenja;

  MesecniPutnik({
    String? id,
    required this.ime,
    required this.prezime,
    this.brojTelefona,
    required this.tip,
    this.tipSkole,
    required this.adresaId,
    required this.rutaId,
    required this.polasciPoDanu,
    required this.cenaMesecneKarte,
    required this.datumPocetka,
    required this.datumKraja,
    this.aktivan = true,
    this.napomena,
    this.vremePlacanja,
    this.naplatioVozacId,
    this.poslednjePutovanje,
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.obrisan = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Kompatibilnost sa starim modelom
    this.brojTelefonaOca,
    this.brojTelefonaMajke,
    this.adresaBelaCrkva,
    this.adresaVrsac,
    this.status = 'aktivan',
    this.radniDani = 'pon,uto,sre,cet,pet',
    this.tipPrikazivanja = 'standard',
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    this.cena,
    double? ukupnaCenaMeseca,
    this.placeniMesec,
    this.placenaGodina,
    this.vozac,
    this.pokupljen = false,
    this.vremePokupljenja,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        datumPocetkaMeseca = datumPocetkaMeseca ?? datumPocetka,
        datumKrajaMeseca = datumKrajaMeseca ?? datumKraja,
        ukupnaCenaMeseca = ukupnaCenaMeseca ?? cenaMesecneKarte;

  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    return MesecniPutnik(
      id: map['id'] as String,
      ime: map['ime'] as String,
      prezime: map['prezime'] as String,
      brojTelefona: map['broj_telefona'] as String?,
      tip: MesecniPutnikTipExtension.fromString(
          map['tip'] as String? ?? 'drugi'),
      tipSkole: map['tip_skole'] as String?,
      adresaId: map['adresa_id'] as String,
      rutaId: map['ruta_id'] as String,
      polasciPoDanu: Map<String, List<String>>.from(
          (map['polasci_po_danu'] as Map<String, dynamic>? ?? {}).map(
              (key, value) => MapEntry(key, List<String>.from(value as List)))),
      cenaMesecneKarte: (map['cena_mesecne_karte'] as num).toDouble(),
      datumPocetka: DateTime.parse(map['datum_pocetka'] as String),
      datumKraja: DateTime.parse(map['datum_kraja'] as String),
      aktivan: map['aktivan'] as bool? ?? true,
      napomena: map['napomena'] as String?,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      naplatioVozacId: map['naplatio_vozac_id'] as String?,
      poslednjePutovanje: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje'] as String)
          : null,
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      obrisan: map['obrisan'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      // Kompatibilnost sa starim modelom
      brojTelefonaOca: map['broj_telefona_oca'] as String?,
      brojTelefonaMajke: map['broj_telefona_majke'] as String?,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
      status: map['status'] as String? ?? 'aktivan',
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'standard',
      datumPocetkaMeseca: map['datum_pocetka_meseca'] != null
          ? DateTime.parse(map['datum_pocetka_meseca'] as String)
          : null,
      datumKrajaMeseca: map['datum_kraja_meseca'] != null
          ? DateTime.parse(map['datum_kraja_meseca'] as String)
          : null,
      cena: (map['cena'] as num?)?.toDouble(),
      ukupnaCenaMeseca: (map['ukupna_cena_meseca'] as num?)?.toDouble(),
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      vozac: map['vozac_id'] as String?,
      pokupljen: map['pokupljen'] as bool? ?? false,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ime': ime,
      'prezime': prezime,
      'broj_telefona': brojTelefona,
      'tip': tip.value,
      'tip_skole': tipSkole,
      'adresa_id': adresaId,
      'ruta_id': rutaId,
      'polasci_po_danu': polasciPoDanu,
      'cena_mesecne_karte': cenaMesecneKarte,
      'datum_pocetka': datumPocetka.toIso8601String().split('T')[0],
      'datum_kraja': datumKraja.toIso8601String().split('T')[0],
      'aktivan': aktivan,
      'napomena': napomena,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'naplatio_vozac_id': naplatioVozacId,
      'poslednje_putovanje': poslednjePutovanje?.toIso8601String(),
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'obrisan': obrisan,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Kompatibilnost sa starim modelom
      'broj_telefona_oca': brojTelefonaOca,
      'broj_telefona_majke': brojTelefonaMajke,
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
      'status': status,
      'radni_dani': radniDani,
      'tip_prikazivanja': tipPrikazivanja,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'cena': cena,
      'ukupna_cena_meseca': ukupnaCenaMeseca,
      'placeni_mesec': placeniMesec,
      'placena_godina': placenaGodina,
      'vozac_id': vozac,
      'pokupljen': pokupljen,
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
    };
  }

  String get punoIme => '$ime $prezime';

  // Kompatibilnost sa starim modelom
  String get putnikIme => '$ime $prezime';

  bool get jePlacen => vremePlacanja != null;

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
    String? ime,
    String? prezime,
    String? brojTelefona,
    MesecniPutnikTip? tip,
    String? tipSkole,
    String? adresaId,
    String? rutaId,
    Map<String, List<String>>? polasciPoDanu,
    double? cenaMesecneKarte,
    DateTime? datumPocetka,
    DateTime? datumKraja,
    bool? aktivan,
    String? napomena,
    DateTime? vremePlacanja,
    String? naplatioVozacId,
    DateTime? poslednjePutovanje,
    int? brojPutovanja,
    int? brojOtkazivanja,
    bool? obrisan,
    // Legacy polja
    String? brojTelefonaOca,
    String? brojTelefonaMajke,
    String? adresaBelaCrkva,
    String? adresaVrsac,
    String? status,
    String? radniDani,
    String? tipPrikazivanja,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    double? cena,
    double? ukupnaCenaMeseca,
    int? placeniMesec,
    int? placenaGodina,
    String? vozac,
    bool? pokupljen,
    DateTime? vremePokupljenja,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      ime: ime ?? this.ime,
      prezime: prezime ?? this.prezime,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      adresaId: adresaId ?? this.adresaId,
      rutaId: rutaId ?? this.rutaId,
      polasciPoDanu: polasciPoDanu ?? this.polasciPoDanu,
      cenaMesecneKarte: cenaMesecneKarte ?? this.cenaMesecneKarte,
      datumPocetka: datumPocetka ?? this.datumPocetka,
      datumKraja: datumKraja ?? this.datumKraja,
      aktivan: aktivan ?? this.aktivan,
      napomena: napomena ?? this.napomena,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      naplatioVozacId: naplatioVozacId ?? this.naplatioVozacId,
      poslednjePutovanje: poslednjePutovanje ?? this.poslednjePutovanje,
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      obrisan: obrisan ?? this.obrisan,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      // Legacy polja
      brojTelefonaOca: brojTelefonaOca ?? this.brojTelefonaOca,
      brojTelefonaMajke: brojTelefonaMajke ?? this.brojTelefonaMajke,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
      status: status ?? this.status,
      radniDani: radniDani ?? this.radniDani,
      tipPrikazivanja: tipPrikazivanja ?? this.tipPrikazivanja,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      cena: cena ?? this.cena,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      placeniMesec: placeniMesec ?? this.placeniMesec,
      placenaGodina: placenaGodina ?? this.placenaGodina,
      vozac: vozac ?? this.vozac,
      pokupljen: pokupljen ?? this.pokupljen,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
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

  /// Konvertuje MesecniPutnik u listu legacy Putnik objekata za dati dan
  List<Putnik> toPutnikList(String targetDan, Adresa adresa, Ruta ruta) {
    final List<Putnik> putnici = [];
    final vremena = polasciPoDanu[targetDan] ?? [];

    for (final vreme in vremena) {
      putnici.add(Putnik(
        id: id,
        ime: '$ime $prezime',
        polazak: vreme,
        pokupljen: false, // TODO: Implementirati kada se doda status po polasku
        vremeDodavanja: DateTime.now(), // TODO: Koristiti createdAt
        mesecnaKarta: true,
        dan: targetDan,
        status: aktivan ? 'radi' : 'neaktivan',
        vremePokupljenja:
            null, // TODO: Implementirati kada se doda vreme po polasku
        vremePlacanja:
            null, // TODO: Implementirati kada se doda vreme po polasku
        placeno: false, // TODO: Implementirati kada se doda status po polasku
        iznosPlacanja:
            null, // TODO: Implementirati kada se doda cena po polasku
        vozac: null, // TODO: Dodati kada se implementira veza sa vozacima
        grad: adresa.grad,
        adresa: '${adresa.ulica} ${adresa.broj}',
        obrisan: !aktivan,
        brojTelefona: brojTelefona,
      ));
    }

    return putnici;
  }
}
