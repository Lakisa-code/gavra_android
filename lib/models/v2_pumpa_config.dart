/// Model za konfiguraciju gorivne pumpe (v2_pumpa_config tabela)
class V2PumpaConfig {
  final String id;
  final double kapacitetLitri;
  final double alarmNivo;
  final double pocetnoStanje;
  final DateTime? updatedAt;

  V2PumpaConfig({
    required this.id,
    required this.kapacitetLitri,
    required this.alarmNivo,
    required this.pocetnoStanje,
    this.updatedAt,
  });

  factory V2PumpaConfig.fromJson(Map<String, dynamic> json) {
    return V2PumpaConfig(
      id: json['id'] as String? ?? '',
      kapacitetLitri: (json['kapacitet_litri'] as num?)?.toDouble() ?? 0.0,
      alarmNivo: (json['alarm_nivo'] as num?)?.toDouble() ?? 0.0,
      pocetnoStanje: (json['pocetno_stanje'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kapacitet_litri': kapacitetLitri,
      'alarm_nivo': alarmNivo,
      'pocetno_stanje': pocetnoStanje,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
