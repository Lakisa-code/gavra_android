/// Model za servisne zapise vozila (v2_vozila_servis tabela)
class V2VozilaServis {
  final String id;
  final String voziloId;
  final String tip;
  final DateTime datum;
  final int? km;
  final String? opis;
  final double? cena;
  final String? pozicija;
  final DateTime? createdAt;

  V2VozilaServis({
    required this.id,
    required this.voziloId,
    required this.tip,
    required this.datum,
    this.km,
    this.opis,
    this.cena,
    this.pozicija,
    this.createdAt,
  });

  factory V2VozilaServis.fromJson(Map<String, dynamic> json) {
    return V2VozilaServis(
      id: json['id'] as String? ?? '',
      voziloId: json['vozilo_id'] as String? ?? '',
      tip: json['tip'] as String? ?? '',
      datum: json['datum'] != null ? DateTime.tryParse(json['datum'] as String) ?? DateTime.now() : DateTime.now(),
      km: json['km'] as int?,
      opis: json['opis'] as String?,
      cena: json['cena'] != null ? (json['cena'] as num).toDouble() : null,
      pozicija: json['pozicija'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vozilo_id': voziloId,
      'tip': tip,
      'datum': datum.toIso8601String(),
      'km': km,
      'opis': opis,
      'cena': cena,
      'pozicija': pozicija,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
