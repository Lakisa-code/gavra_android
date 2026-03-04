/// Model za punjenja gorivne pumpe (v2_pumpa_punjenja tabela)
class V2PumpaPunjenje {
  final String id;
  final DateTime datum;
  final double litri;
  final double cenaPolitru;
  final double ukupnoCena;
  final String? napomena;
  final DateTime? createdAt;

  V2PumpaPunjenje({
    required this.id,
    required this.datum,
    required this.litri,
    required this.cenaPolitru,
    required this.ukupnoCena,
    this.napomena,
    this.createdAt,
  });

  factory V2PumpaPunjenje.fromJson(Map<String, dynamic> json) {
    return V2PumpaPunjenje(
      id: json['id'] as String? ?? '',
      datum: json['datum'] != null ? DateTime.tryParse(json['datum'] as String) ?? DateTime.now() : DateTime.now(),
      litri: (json['litri'] as num?)?.toDouble() ?? 0.0,
      cenaPolitru: (json['cena_po_litru'] as num?)?.toDouble() ?? 0.0,
      ukupnoCena: (json['ukupno_cena'] as num?)?.toDouble() ?? 0.0,
      napomena: json['napomena'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'datum': datum.toIso8601String(),
      'litri': litri,
      'cena_po_litru': cenaPolitru,
      'ukupno_cena': ukupnoCena,
      'napomena': napomena,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
