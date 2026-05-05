/// Model za tabelu v3_gorivo
library;

class V3PumpaStanje {
  final String id;
  final double kapacitetLitri;
  final double trenutnoStanje;
  final double alarmNivoLitri;
  final double stanjeBrojacPistolj;
  final double cenaPoLitru;
  final double dugIznos;

  V3PumpaStanje({
    required this.id,
    this.kapacitetLitri = 0,
    required this.trenutnoStanje,
    this.alarmNivoLitri = 500,
    this.stanjeBrojacPistolj = 0,
    this.cenaPoLitru = 0,
    this.dugIznos = 0,
  });

  factory V3PumpaStanje.fromJson(Map<String, dynamic> json) {
    return V3PumpaStanje(
      id: json['id']?.toString() ?? '',
      kapacitetLitri: (json['kapacitet_litri'] as num?)?.toDouble() ?? 0,
      trenutnoStanje: (json['trenutno_stanje_litri'] as num?)?.toDouble() ?? 0,
      alarmNivoLitri: (json['alarm_nivo_litri'] as num?)?.toDouble() ?? 500,
      stanjeBrojacPistolj: (json['brojac_pistolj_litri'] as num?)?.toDouble() ?? 0,
      cenaPoLitru: (json['cena_po_litru'] as num?)?.toDouble() ?? 0,
      dugIznos: (json['dug_iznos'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'kapacitet_litri': kapacitetLitri,
        'trenutno_stanje_litri': trenutnoStanje,
        'alarm_nivo_litri': alarmNivoLitri,
        'brojac_pistolj_litri': stanjeBrojacPistolj,
        'cena_po_litru': cenaPoLitru,
        'dug_iznos': dugIznos,
      };
}

/// Model za tabelu v3_gorivo (rezervoar pogled)

class V3PumpaRezervoar {
  final String id;

  final double kapacitetMax;

  final double trenutnoLitara;

  final double alarmNivo;

  V3PumpaRezervoar({
    required this.id,
    this.kapacitetMax = 3000,
    required this.trenutnoLitara,
    this.alarmNivo = 500,
  });

  factory V3PumpaRezervoar.fromJson(Map<String, dynamic> json) {
    return V3PumpaRezervoar(
      id: json['id']?.toString() ?? '',
      kapacitetMax: (json['kapacitet_litri'] as num?)?.toDouble() ?? 3000,
      trenutnoLitara: (json['trenutno_stanje_litri'] as num?)?.toDouble() ?? 0,
      alarmNivo: (json['alarm_nivo_litri'] as num?)?.toDouble() ?? 500,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'kapacitet_litri': kapacitetMax,
        'trenutno_stanje_litri': trenutnoLitara,
        'alarm_nivo_litri': alarmNivo,
      };

  bool get ispodAlarma => trenutnoLitara <= alarmNivo;

  double get procentPunjenosti => kapacitetMax > 0 ? (trenutnoLitara / kapacitetMax * 100).clamp(0, 100) : 0;
}
