/// Model za kapacitet polazaka po gradu i vremenu (v2_kapacitet_polazaka tabela)
class V2KapacitetPolaska {
  final String id;
  final String grad;
  final String vreme;
  final int maxMesta;
  final bool aktivan;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  V2KapacitetPolaska({
    required this.id,
    required this.grad,
    required this.vreme,
    required this.maxMesta,
    this.aktivan = true,
    this.createdAt,
    this.updatedAt,
  });

  factory V2KapacitetPolaska.fromJson(Map<String, dynamic> json) {
    return V2KapacitetPolaska(
      id: json['id'] as String? ?? '',
      grad: json['grad'] as String? ?? '',
      vreme: json['vreme'] as String? ?? '',
      maxMesta: json['max_mesta'] as int? ?? 0,
      aktivan: json['aktivan'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'grad': grad,
      'vreme': vreme,
      'max_mesta': maxMesta,
      'aktivan': aktivan,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
