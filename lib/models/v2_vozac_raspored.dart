/// Model za raspored vožnji vozača (v2_vozac_raspored tabela)
class V2VozacRaspored {
  final String id;
  final String vozacId;
  final String dan;
  final String grad;
  final String vreme;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2VozacRaspored({
    required this.id,
    required this.vozacId,
    required this.dan,
    required this.grad,
    required this.vreme,
    this.createdAt,
    this.updatedAt,
  });

  factory V2VozacRaspored.fromJson(Map<String, dynamic> json) {
    return V2VozacRaspored(
      id: json['id'] as String? ?? '',
      vozacId: json['vozac_id'] as String? ?? '',
      dan: json['dan'] as String? ?? '',
      grad: json['grad'] as String? ?? '',
      vreme: json['vreme'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vozac_id': vozacId,
      'dan': dan,
      'grad': grad,
      'vreme': vreme,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
