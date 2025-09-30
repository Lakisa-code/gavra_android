import 'package:uuid/uuid.dart';

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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
    };
  }

  String get punoIme => '$ime $prezime';

  bool get jePlacen => vremePlacanja != null;

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
}
