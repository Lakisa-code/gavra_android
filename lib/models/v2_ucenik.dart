/// Model za učenike (v2_ucenici tabela)
class V2Ucenik {
  final String id;
  final String ime;
  final String status;
  final String? telefon;
  final String? telefonOca;
  final String? telefonMajke;
  final String? adresaBcId;
  final String? adresaVsId;
  final String? pin;
  final String? email;
  final double? cenaPoDanu;
  final int? brojMesta;
  final bool trebaRacun;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2Ucenik({
    required this.id,
    required this.ime,
    this.status = 'aktivan',
    this.telefon,
    this.telefonOca,
    this.telefonMajke,
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

  factory V2Ucenik.fromJson(Map<String, dynamic> json) {
    return V2Ucenik(
      id: json['id'] as String? ?? '',
      ime: json['ime'] as String? ?? '',
      status: json['status'] as String? ?? 'aktivan',
      telefon: json['telefon'] as String?,
      telefonOca: json['telefon_oca'] as String?,
      telefonMajke: json['telefon_majke'] as String?,
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
      'telefon_oca': telefonOca,
      'telefon_majke': telefonMajke,
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
