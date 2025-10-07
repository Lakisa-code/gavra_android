class PutovanjaIstorija {
  PutovanjaIstorija({
    required this.id,
    this.mesecniPutnikId,
    required this.tipPutnika,
    required this.datum,
    required this.vremePolaska,
    this.vremeAkcije, // OPCIONO
    required this.adresaPolaska,
    this.status = 'nije_se_pojavio', // DEFAULT vrednost
    this.statusBelaCrkvaVrsac = 'nije_se_pojavio', // DEPRECATED
    this.statusVrsacBelaCrkva = 'nije_se_pojavio', // DEPRECATED
    required this.putnikIme,
    this.brojTelefona,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
    // NOVA POLJA
    this.dan,
    this.grad,
    this.obrisan = false,
    this.pokupljen = false,
    this.vozac,
    this.vremePlacanja,
    this.vremePokupljenja,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    return PutovanjaIstorija(
      id: map['id'] as String,
      mesecniPutnikId: map['mesecni_putnik_id'] as String?,
      tipPutnika: map['tip_putnika'] as String,
      datum: DateTime.parse(map['datum_putovanja'] as String),
      vremePolaska: map['vreme_polaska'] as String,
      vremeAkcije: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null, // MAPIRAN na vreme_pokupljenja umesto vreme_akcije
      adresaPolaska: map['adresa_polaska'] as String,
      status: map['status'] as String? ??
          'nije_se_pojavio', // KORISTI status kolonu
      statusBelaCrkvaVrsac: map['status'] as String? ??
          'nije_se_pojavio', // DEPRECATED - za kompatibilnost
      statusVrsacBelaCrkva: map['status'] as String? ??
          'nije_se_pojavio', // DEPRECATED - za kompatibilnost
      putnikIme: map['putnik_ime'] as String,
      brojTelefona: map['broj_telefona'] as String?,
      cena: (map['cena'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      // NOVA POLJA
      dan: map['dan'] as String?,
      grad: map['grad'] as String?,
      obrisan: map['obrisan'] as bool? ?? false,
      pokupljen: map['pokupljen'] as bool? ?? false,
      vozac: map['vozac'] as String?,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? DateTime.parse(map['vreme_pokupljenja'] as String)
          : null,
    );
  }
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final DateTime? vremeAkcije; // OPCIONO - možda se mapira na vreme_pokupljenja
  final String adresaPolaska;
  final String status; // UMESTO statusBelaCrkvaVrsac i statusVrsacBelaCrkva
  final String? statusBelaCrkvaVrsac; // DEPRECATED - čuva se za kompatibilnost
  final String? statusVrsacBelaCrkva; // DEPRECATED - čuva se za kompatibilnost
  final String putnikIme;
  final String? brojTelefona;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;

  // NOVA POLJA koja postoje u bazi
  final String? dan;
  final String? grad;
  final bool obrisan;
  final bool pokupljen;
  final String? vozac;
  final DateTime? vremePlacanja;
  final DateTime? vremePokupljenja;

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum_putovanja': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'adresa_polaska': adresaPolaska,
      'status':
          status, // KORISTI status umesto status_bela_crkva_vrsac/status_vrsac_bela_crkva
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // NOVA POLJA
      'dan': dan,
      'grad': grad,
      'obrisan': obrisan,
      'pokupljen': pokupljen,
      'vozac': vozac,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
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
    String? status,
    String? statusBelaCrkvaVrsac,
    String? statusVrsacBelaCrkva,
    String? putnikIme,
    String? brojTelefona,
    double? cena,
    DateTime? createdAt,
    DateTime? updatedAt,
    // NOVA POLJA
    String? dan,
    String? grad,
    bool? obrisan,
    bool? pokupljen,
    String? vozac,
    DateTime? vremePlacanja,
    DateTime? vremePokupljenja,
  }) {
    return PutovanjaIstorija(
      id: id ?? this.id,
      mesecniPutnikId: mesecniPutnikId ?? this.mesecniPutnikId,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      datum: datum ?? this.datum,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      vremeAkcije: vremeAkcije ?? this.vremeAkcije,
      adresaPolaska: adresaPolaska ?? this.adresaPolaska,
      status: status ?? this.status,
      statusBelaCrkvaVrsac: statusBelaCrkvaVrsac ?? this.statusBelaCrkvaVrsac,
      statusVrsacBelaCrkva: statusVrsacBelaCrkva ?? this.statusVrsacBelaCrkva,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      cena: cena ?? this.cena,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // NOVA POLJA
      dan: dan ?? this.dan,
      grad: grad ?? this.grad,
      obrisan: obrisan ?? this.obrisan,
      pokupljen: pokupljen ?? this.pokupljen,
      vozac: vozac ?? this.vozac,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
    );
  }

  // Helper metodi za status - AŽURIRANI za novu status kolonu
  bool get jePokupljenBelaCrkvaVrsac => status == 'pokupljen' || pokupljen;
  bool get jePokupljenVrsacBelaCrkva => status == 'pokupljen' || pokupljen;
  bool get jeOtkazaoBelaCrkvaVrsac =>
      status == 'otkazao_poziv' || status == 'otkazano';
  bool get jeOtkazaoVrsacBelaCrkva =>
      status == 'otkazao_poziv' || status == 'otkazano';
  bool get nijeSePojavioBelaCrkvaVrsac => status == 'nije_se_pojavio';
  bool get nijeSePojavioVrsacBelaCrkva => status == 'nije_se_pojavio';

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
