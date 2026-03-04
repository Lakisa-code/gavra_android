/// Model za radnike (v2_radnici tabela)
class V2Radnik {
  final String id;
  final String ime;
  final String status;
  final String? telefon;
  final String? telefon2;
  final String? adresaBcId;
  final String? adresaVsId;
  final String? pin;
  final String? email;
  final double? cenaPoDanu;
  final int? brojMesta;
  final bool trebaRacun;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2Radnik({
    required this.id,
    required this.ime,
    this.status = 'aktivan',
    this.telefon,
    this.telefon2,
    this.adresaBcId,
    this.adresaVsId,
    this.pin,
    this.email,
    this.cenaPoDanu,
    this.brojMesta,
    this.trebaRacun = false,
    this.createdAt,
    this.updatedAt,
  });

  factory V2Radnik.fromJson(Map<String, dynamic> json) {
    return V2Radnik(
      id: json['id'] as String? ?? '',
      ime: json['ime'] as String? ?? '',
      status: json['status'] as String? ?? 'aktivan',
      telefon: json['telefon'] as String?,
      telefon2: json['telefon_2'] as String?,
      adresaBcId: json['adresa_bc_id'] as String?,
      adresaVsId: json['adresa_vs_id'] as String?,
      pin: json['pin'] as String?,
      email: json['email'] as String?,
      cenaPoDanu: json['cena_po_danu'] != null ? (json['cena_po_danu'] as num).toDouble() : null,
      brojMesta: json['broj_mesta'] as int?,
      trebaRacun: json['treba_racun'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ime': ime,
      'status': status,
      'telefon': telefon,
      'telefon_2': telefon2,
      'adresa_bc_id': adresaBcId,
      'adresa_vs_id': adresaVsId,
      'pin': pin,
      'email': email,
      'cena_po_danu': cenaPoDanu,
      'broj_mesta': brojMesta,
      'treba_racun': trebaRacun,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
