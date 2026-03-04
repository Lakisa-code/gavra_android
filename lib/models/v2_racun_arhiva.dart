/// Model za arhivu izdatih računa (v2_racuni_arhiva tabela)
class V2RacunArhiva {
  final String id;
  final String racunId;
  final String putnikId;
  final String putnikTabela;
  final String brojRacuna;
  final DateTime datumIzdavanja;
  final double iznos;
  final String? opis;
  final bool stampan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2RacunArhiva({
    required this.id,
    required this.racunId,
    required this.putnikId,
    required this.putnikTabela,
    required this.brojRacuna,
    required this.datumIzdavanja,
    required this.iznos,
    this.opis,
    this.stampan = false,
    this.createdAt,
    this.updatedAt,
  });

  factory V2RacunArhiva.fromJson(Map<String, dynamic> json) {
    return V2RacunArhiva(
      id: json['id'] as String? ?? '',
      racunId: json['racun_id'] as String? ?? '',
      putnikId: json['putnik_id'] as String? ?? '',
      putnikTabela: json['putnik_tabela'] as String? ?? '',
      brojRacuna: json['broj_racuna'] as String? ?? '',
      datumIzdavanja: json['datum_izdavanja'] != null
          ? DateTime.tryParse(json['datum_izdavanja'] as String) ?? DateTime.now()
          : DateTime.now(),
      iznos: (json['iznos'] as num?)?.toDouble() ?? 0.0,
      opis: json['opis'] as String?,
      stampan: json['stampan'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'racun_id': racunId,
      'putnik_id': putnikId,
      'putnik_tabela': putnikTabela,
      'broj_racuna': brojRacuna,
      'datum_izdavanja': datumIzdavanja.toIso8601String(),
      'iznos': iznos,
      'opis': opis,
      'stampan': stampan,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
