class PutovanjaIstorija {
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final DateTime vremeAkcije;
  final String adresaPolaska;
  final String statusBelaCrkvaVrsac;
  final String statusVrsacBelaCrkva;
  final String putnikIme;
  final String? brojTelefona;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;

  PutovanjaIstorija({
    required this.id,
    this.mesecniPutnikId,
    required this.tipPutnika,
    required this.datum,
    required this.vremePolaska,
    required this.vremeAkcije,
    required this.adresaPolaska,
    this.statusBelaCrkvaVrsac = 'nije_se_pojavio',
    this.statusVrsacBelaCrkva = 'nije_se_pojavio',
    required this.putnikIme,
    this.brojTelefona,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    return PutovanjaIstorija(
      id: map['id'] as String,
      mesecniPutnikId: map['mesecni_putnik_id'] as String?,
      tipPutnika: map['tip_putnika'] as String,
      datum: DateTime.parse(map['datum'] as String),
      vremePolaska: map['vreme_polaska'] as String,
      vremeAkcije: DateTime.parse(map['vreme_akcije'] as String),
      adresaPolaska: map['adresa_polaska'] as String,
      statusBelaCrkvaVrsac:
          map['status_bela_crkva_vrsac'] as String? ?? 'nije_se_pojavio',
      statusVrsacBelaCrkva:
          map['status_vrsac_bela_crkva'] as String? ?? 'nije_se_pojavio',
      putnikIme: map['putnik_ime'] as String,
      brojTelefona: map['broj_telefona'] as String?,
      cena: (map['cena'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'vreme_akcije': vremeAkcije.toIso8601String(),
      'adresa_polaska': adresaPolaska,
      'status_bela_crkva_vrsac': statusBelaCrkvaVrsac,
      'status_vrsac_bela_crkva': statusVrsacBelaCrkva,
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  PutovanjaIstorija copyWith({
    String? id,
    String? mesecniPutnikId,
    String? tipPutnika,
    DateTime? datum,
    String? vremePolaska,
    DateTime? vremeAkcije,
    String? adresaPolaska,
    String? statusBelaCrkvaVrsac,
    String? statusVrsacBelaCrkva,
    String? putnikIme,
    String? brojTelefona,
    double? cena,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PutovanjaIstorija(
      id: id ?? this.id,
      mesecniPutnikId: mesecniPutnikId ?? this.mesecniPutnikId,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      datum: datum ?? this.datum,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      vremeAkcije: vremeAkcije ?? this.vremeAkcije,
      adresaPolaska: adresaPolaska ?? this.adresaPolaska,
      statusBelaCrkvaVrsac: statusBelaCrkvaVrsac ?? this.statusBelaCrkvaVrsac,
      statusVrsacBelaCrkva: statusVrsacBelaCrkva ?? this.statusVrsacBelaCrkva,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      cena: cena ?? this.cena,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper metodi za status
  bool get jePokupljenBelaCrkvaVrsac => statusBelaCrkvaVrsac == 'pokupljen';
  bool get jePokupljenVrsacBelaCrkva => statusVrsacBelaCrkva == 'pokupljen';
  bool get jeOtkazaoBelaCrkvaVrsac => statusBelaCrkvaVrsac == 'otkazao_poziv';
  bool get jeOtkazaoVrsacBelaCrkva => statusVrsacBelaCrkva == 'otkazao_poziv';
  bool get nijeSePojavioBelaCrkvaVrsac =>
      statusBelaCrkvaVrsac == 'nije_se_pojavio';
  bool get nijeSePojavioVrsacBelaCrkva =>
      statusVrsacBelaCrkva == 'nije_se_pojavio';

  bool get jeMesecni => tipPutnika == 'mesecni';
  bool get jeDnevni => tipPutnika == 'dnevni';

  @override
  String toString() {
    return 'PutovanjaIstorija(id: $id, ime: $putnikIme, datum: $datum, tip: $tipPutnika)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PutovanjaIstorija && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
