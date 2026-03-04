/// Model za točenja goriva iz pumpe (v2_pumpa_tocenja tabela)
class V2PumpaTocenje {
  final String id;
  final DateTime datum;
  final String voziloId;
  final double litri;
  final int? kmVozila;
  final String? napomena;
  final DateTime? createdAt;

  V2PumpaTocenje({
    required this.id,
    required this.datum,
    required this.voziloId,
    required this.litri,
    this.kmVozila,
    this.napomena,
    this.createdAt,
  });

  factory V2PumpaTocenje.fromJson(Map<String, dynamic> json) {
    return V2PumpaTocenje(
      id: json['id'] as String? ?? '',
      datum: json['datum'] != null ? DateTime.tryParse(json['datum'] as String) ?? DateTime.now() : DateTime.now(),
      voziloId: json['vozilo_id'] as String? ?? '',
      litri: (json['litri'] as num?)?.toDouble() ?? 0.0,
      kmVozila: json['km_vozila'] as int?,
      napomena: json['napomena'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'datum': datum.toIso8601String(),
      'vozilo_id': voziloId,
      'litri': litri,
      'km_vozila': kmVozila,
      'napomena': napomena,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
