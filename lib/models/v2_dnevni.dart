/// Model za dnevne putnike (v2_dnevni tabela)
class V2Dnevni {
  final String id;
  final String ime;
  final String status;
  final String? telefon;
  final String? telefon2;
  final String? adresaBcId;
  final String? adresaVsId;
  final double? cena;
  final bool trebaRacun;
  final String? pin;
  final String? email;
  final int? brojMesta;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2Dnevni({
    required this.id,
    required this.ime,
    this.status = 'aktivan',
    this.telefon,
    this.telefon2,
    this.adresaBcId,
    this.adresaVsId,
    this.cena,
    this.trebaRacun = false,
    this.pin,
    this.email,
    this.brojMesta,
    this.createdAt,
    this.updatedAt,
  });

  factory V2Dnevni.fromJson(Map<String, dynamic> json) {
    return V2Dnevni(
      id: json['id'] as String? ?? '',
      ime: json['ime'] as String? ?? '',
      status: json['status'] as String? ?? 'aktivan',
      telefon: json['telefon'] as String?,
      telefon2: json['telefon_2'] as String?,
      adresaBcId: json['adresa_bc_id'] as String?,
      adresaVsId: json['adresa_vs_id'] as String?,
      cena: json['cena'] != null ? (json['cena'] as num).toDouble() : null,
      trebaRacun: json['treba_racun'] as bool? ?? false,
      pin: json['pin'] as String?,
      email: json['email'] as String?,
      brojMesta: json['broj_mesta'] as int?,
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
      'cena': cena,
      'treba_racun': trebaRacun,
      'pin': pin,
      'email': email,
      'broj_mesta': brojMesta,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
