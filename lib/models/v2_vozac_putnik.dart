/// Model za vezu vozač-putnik (v2_vozac_putnik tabela)
class V2VozacPutnik {
  final String id;
  final String vozacId;
  final String putnikId;
  final String putnikTabela;
  final String dan;
  final String grad;
  final String vreme;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2VozacPutnik({
    required this.id,
    required this.vozacId,
    required this.putnikId,
    required this.putnikTabela,
    required this.dan,
    required this.grad,
    required this.vreme,
    this.createdAt,
    this.updatedAt,
  });

  factory V2VozacPutnik.fromJson(Map<String, dynamic> json) {
    return V2VozacPutnik(
      id: json['id'] as String? ?? '',
      vozacId: json['vozac_id'] as String? ?? '',
      putnikId: json['putnik_id'] as String? ?? '',
      putnikTabela: json['putnik_tabela'] as String? ?? '',
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
      'putnik_id': putnikId,
      'putnik_tabela': putnikTabela,
      'dan': dan,
      'grad': grad,
      'vreme': vreme,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
